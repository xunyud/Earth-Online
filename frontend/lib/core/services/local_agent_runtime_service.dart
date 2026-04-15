import 'dart:io';

import '../models/local_tool_call.dart';
import '../models/local_tool_result.dart';

typedef LocalAgentCurrentDirectoryProvider = String Function();
typedef LocalAgentProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
});
typedef LocalAgentBusinessActionHandler = Future<LocalToolResult> Function(
  Map<String, dynamic> arguments,
);

class LocalAgentRuntimeService {
  const LocalAgentRuntimeService({
    String? workspaceRootPath,
    LocalAgentCurrentDirectoryProvider? currentDirectoryProvider,
    LocalAgentProcessRunner? processRunner,
    LocalAgentBusinessActionHandler? questCreateHandler,
    LocalAgentBusinessActionHandler? questUpdateHandler,
    LocalAgentBusinessActionHandler? questSplitHandler,
    LocalAgentBusinessActionHandler? chatFreeformHandler,
    LocalAgentBusinessActionHandler? weeklySummaryGenerateHandler,
    LocalAgentBusinessActionHandler? rewardRedeemHandler,
    LocalAgentBusinessActionHandler? navigationOpenHandler,
  })  : _workspaceRootPath = workspaceRootPath,
        _currentDirectoryProvider =
            currentDirectoryProvider ?? _defaultCurrentDirectoryProvider,
        _processRunner = processRunner ?? _defaultProcessRunner,
        _questCreateHandler = questCreateHandler,
        _questUpdateHandler = questUpdateHandler,
        _questSplitHandler = questSplitHandler,
        _chatFreeformHandler = chatFreeformHandler,
        _weeklySummaryGenerateHandler = weeklySummaryGenerateHandler,
        _rewardRedeemHandler = rewardRedeemHandler,
        _navigationOpenHandler = navigationOpenHandler;

  static const int _maxResultChars = 12000;

  final String? _workspaceRootPath;
  final LocalAgentCurrentDirectoryProvider _currentDirectoryProvider;
  final LocalAgentProcessRunner _processRunner;
  final LocalAgentBusinessActionHandler? _questCreateHandler;
  final LocalAgentBusinessActionHandler? _questUpdateHandler;
  final LocalAgentBusinessActionHandler? _questSplitHandler;
  final LocalAgentBusinessActionHandler? _chatFreeformHandler;
  final LocalAgentBusinessActionHandler? _weeklySummaryGenerateHandler;
  final LocalAgentBusinessActionHandler? _rewardRedeemHandler;
  final LocalAgentBusinessActionHandler? _navigationOpenHandler;

  static String _defaultCurrentDirectoryProvider() => Directory.current.path;

  static Future<ProcessResult> _defaultProcessRunner(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) {
    return Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: false,
    );
  }

  Future<LocalToolResult> execute(LocalToolCall call) async {
    final toolName = call.toolName.trim();
    if (toolName.isEmpty) {
      return const LocalToolResult(
        success: false,
        outputText: '',
        errorText: 'tool_name 不能为空',
      );
    }

    switch (toolName) {
      case 'file.read_text':
        return _executeReadText(call);
      case 'shell.exec':
        return _executeShellExec(call);
      case 'app.quest.create':
        return _executeBusinessAction(
          call,
          handler: _questCreateHandler,
          unsupportedMessage: '当前未接入 app.quest.create 执行器',
          unsupportedCode: 'quest_create_not_supported',
        );
      case 'app.quest.update':
        return _executeBusinessAction(
          call,
          handler: _questUpdateHandler,
          unsupportedMessage: '当前未接入 app.quest.update 执行器',
          unsupportedCode: 'quest_update_not_supported',
        );
      case 'app.quest.split':
        return _executeBusinessAction(
          call,
          handler: _questSplitHandler,
          unsupportedMessage: '当前未接入 app.quest.split 执行器',
          unsupportedCode: 'quest_split_not_supported',
        );
      case 'app.chat.freeform.respond':
        return _executeBusinessAction(
          call,
          handler: _chatFreeformHandler,
          unsupportedMessage: '当前未接入 app.chat.freeform.respond 执行器',
          unsupportedCode: 'chat_freeform_not_supported',
        );
      case 'app.weekly_summary.generate':
        return _executeBusinessAction(
          call,
          handler: _weeklySummaryGenerateHandler,
          unsupportedMessage: '当前未接入 app.weekly_summary.generate 执行器',
          unsupportedCode: 'weekly_summary_generate_not_supported',
        );
      case 'app.reward.redeem':
        return _executeBusinessAction(
          call,
          handler: _rewardRedeemHandler,
          unsupportedMessage: '当前未接入 app.reward.redeem 执行器',
          unsupportedCode: 'reward_redeem_not_supported',
        );
      case 'app.navigation.open':
        return _executeBusinessAction(
          call,
          handler: _navigationOpenHandler,
          unsupportedMessage: '当前未接入 app.navigation.open 执行器',
          unsupportedCode: 'navigation_open_not_supported',
        );
      case 'browser.open':
        return _unsupportedBrowserCall(
          call,
          reason: '当前平台尚未接入 browser.open 执行',
        );
      case 'browser.extract_text':
        return _unsupportedBrowserCall(
          call,
          reason: '当前平台尚未接入 browser.extract_text 执行',
        );
      default:
        return LocalToolResult(
          success: false,
          outputText: '暂不支持本地执行工具：$toolName',
          errorText: 'unsupported_local_tool',
          resultJson: <String, dynamic>{
            'tool_name': toolName,
            'step_id': call.stepId,
            'arguments': call.arguments,
          },
        );
    }
  }

  Future<LocalToolResult> _executeBusinessAction(
    LocalToolCall call, {
    required LocalAgentBusinessActionHandler? handler,
    required String unsupportedMessage,
    required String unsupportedCode,
  }) async {
    if (handler == null) {
      return _toolError(
        call,
        message: unsupportedMessage,
        code: unsupportedCode,
      );
    }
    return handler(Map<String, dynamic>.from(call.arguments));
  }

  Future<LocalToolResult> _executeReadText(LocalToolCall call) async {
    final rawPath = '${call.arguments['path'] ?? ''}'.trim();
    if (rawPath.isEmpty) {
      return _toolError(
        call,
        message: 'file.read_text 缺少 path 参数',
        code: 'missing_file_path',
      );
    }

    final workspaceRoot = _resolveWorkspaceRoot();
    final resolvedPath = _resolvePath(workspaceRoot, rawPath);
    if (!_isWithinRoot(resolvedPath, workspaceRoot)) {
      return _toolError(
        call,
        message: '只允许读取工作区内的文件',
        code: 'path_outside_workspace',
        extra: <String, dynamic>{
          'path': rawPath,
          'workspace_root': workspaceRoot,
        },
      );
    }

    final file = File(resolvedPath);
    if (!await file.exists()) {
      return _toolError(
        call,
        message: '文件不存在：$rawPath',
        code: 'file_not_found',
        extra: <String, dynamic>{'path': rawPath},
      );
    }

    final text = await file.readAsString();
    final trimmedText = text.trim();
    final truncatedText = _truncateText(trimmedText);
    final displayPath = _displayPath(resolvedPath, workspaceRoot);
    return LocalToolResult(
      success: true,
      outputText: '已读取 $displayPath，${trimmedText.length} 字符。',
      resultJson: <String, dynamic>{
        'tool_name': call.toolName,
        'step_id': call.stepId,
        'path': displayPath,
        'workspace_root': workspaceRoot,
        'text': truncatedText,
        'truncated': truncatedText.length != trimmedText.length,
        'char_count': trimmedText.length,
      },
      errorText: null,
    );
  }

  Future<LocalToolResult> _executeShellExec(LocalToolCall call) async {
    final command = '${call.arguments['command'] ?? ''}'.trim();
    if (command.isEmpty) {
      return _toolError(
        call,
        message: 'shell.exec 缺少 command 参数',
        code: 'missing_shell_command',
      );
    }

    if (_isDeniedShellCommand(command)) {
      return _toolError(
        call,
        message: '当前仅允许只读命令，本次命令已被拒绝',
        code: 'shell_command_blocked',
        extra: <String, dynamic>{'command': command},
      );
    }

    if (!_isAllowedShellCommand(command)) {
      return _toolError(
        call,
        message: '当前业务型 agent 仅支持白名单 shell 命令',
        code: 'shell_command_not_allowlisted',
        extra: <String, dynamic>{'command': command},
      );
    }

    final workspaceRoot = _resolveWorkspaceRoot();
    final rawCwd = '${call.arguments['cwd'] ?? '.'}'.trim();
    final resolvedCwd = _resolvePath(
      workspaceRoot,
      rawCwd.isEmpty ? '.' : rawCwd,
    );
    if (!_isWithinRoot(resolvedCwd, workspaceRoot)) {
      return _toolError(
        call,
        message: 'shell.exec 只能在工作区内执行',
        code: 'cwd_outside_workspace',
        extra: <String, dynamic>{
          'cwd': rawCwd,
          'workspace_root': workspaceRoot,
        },
      );
    }

    final shellExecutable = Platform.isWindows ? 'powershell' : '/bin/sh';
    final shellArguments = Platform.isWindows
        ? <String>['-NoProfile', '-Command', command]
        : <String>['-lc', command];
    final result = await _processRunner(
      shellExecutable,
      shellArguments,
      workingDirectory: resolvedCwd,
    );

    final stdoutText = '${result.stdout ?? ''}'.trim();
    final stderrText = '${result.stderr ?? ''}'.trim();
    final outputSummary =
        _buildShellOutputSummary(command, stdoutText, stderrText);
    final success = result.exitCode == 0;

    return LocalToolResult(
      success: success,
      outputText: outputSummary,
      errorText: success ? null : (stderrText.isEmpty ? '命令执行失败' : stderrText),
      resultJson: <String, dynamic>{
        'tool_name': call.toolName,
        'step_id': call.stepId,
        'command': command,
        'cwd': _displayPath(resolvedCwd, workspaceRoot),
        'exit_code': result.exitCode,
        'stdout': _truncateText(stdoutText),
        'stderr': _truncateText(stderrText),
      },
    );
  }

  LocalToolResult _unsupportedBrowserCall(
    LocalToolCall call, {
    required String reason,
  }) {
    return LocalToolResult(
      success: false,
      outputText: reason,
      errorText: 'browser_execution_not_supported',
      resultJson: <String, dynamic>{
        'tool_name': call.toolName,
        'step_id': call.stepId,
        'arguments': call.arguments,
      },
    );
  }

  LocalToolResult _toolError(
    LocalToolCall call, {
    required String message,
    required String code,
    Map<String, dynamic>? extra,
  }) {
    return LocalToolResult(
      success: false,
      outputText: message,
      errorText: code,
      resultJson: <String, dynamic>{
        'tool_name': call.toolName,
        'step_id': call.stepId,
        'arguments': call.arguments,
        if (extra != null) ...extra,
      },
    );
  }

  String _resolveWorkspaceRoot() {
    final configured = _workspaceRootPath?.trim() ?? '';
    if (configured.isNotEmpty) {
      return Directory(configured).absolute.path;
    }

    final current = Directory(_currentDirectoryProvider()).absolute.path;
    var cursor = current;
    while (true) {
      if (_looksLikeWorkspaceRoot(cursor)) {
        return cursor;
      }
      final parent = Directory(cursor).parent.path;
      if (parent == cursor) break;
      cursor = parent;
    }
    return current;
  }

  bool _looksLikeWorkspaceRoot(String path) {
    final directory = Directory(path);
    if (!directory.existsSync()) return false;

    final gitDirectory = Directory(_joinPath(path, '.git'));
    if (gitDirectory.existsSync()) return true;

    final frontendDirectory = Directory(_joinPath(path, 'frontend'));
    final supabaseDirectory = Directory(_joinPath(path, 'supabase'));
    return frontendDirectory.existsSync() && supabaseDirectory.existsSync();
  }

  String _resolvePath(String workspaceRoot, String rawPath) {
    if (_isAbsolutePath(rawPath)) {
      return File(rawPath).absolute.path;
    }
    final resolvedUri = Directory(workspaceRoot).absolute.uri.resolve(
          rawPath.replaceAll('\\', '/'),
        );
    return resolvedUri.toFilePath(windows: Platform.isWindows);
  }

  bool _isAbsolutePath(String path) {
    if (path.startsWith('/') || path.startsWith('\\')) return true;
    return RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path);
  }

  bool _isWithinRoot(String targetPath, String rootPath) {
    final normalizedTarget = _comparisonPath(targetPath);
    final normalizedRoot = _comparisonPath(rootPath);
    return normalizedTarget == normalizedRoot ||
        normalizedTarget.startsWith('$normalizedRoot/');
  }

  String _comparisonPath(String value) {
    final normalized =
        value.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }

  String _displayPath(String value, String workspaceRoot) {
    final normalizedValue = value.replaceAll('\\', '/');
    final normalizedRoot = workspaceRoot.replaceAll('\\', '/');
    final comparableValue =
        Platform.isWindows ? normalizedValue.toLowerCase() : normalizedValue;
    final comparableRoot =
        Platform.isWindows ? normalizedRoot.toLowerCase() : normalizedRoot;
    if (comparableValue == comparableRoot) return '.';
    final prefix = '$comparableRoot/';
    if (comparableValue.startsWith(prefix)) {
      return normalizedValue.substring(normalizedRoot.length + 1);
    }
    return normalizedValue;
  }

  String _joinPath(String left, String right) {
    final normalizedLeft =
        left.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
    final normalizedRight =
        right.replaceAll('\\', '/').replaceAll(RegExp(r'^/+'), '');
    final separator = Platform.pathSeparator;
    return '$normalizedLeft/$normalizedRight'.replaceAll('/', separator);
  }

  bool _isAllowedShellCommand(String command) {
    final normalized = command.trim().toLowerCase();
    final allowedPatterns = <RegExp>[
      RegExp(r'^git\s+status(\s|$)'),
      RegExp(r'^git\s+diff(\s|$)'),
      RegExp(r'^flutter\s+analyze(\s|$)'),
      RegExp(r'^flutter\s+test(\s|$)'),
      RegExp(r'^pwd(\s|$)'),
      RegExp(r'^dir(\s|$)'),
    ];
    return allowedPatterns.any((pattern) => pattern.hasMatch(normalized));
  }

  bool _isDeniedShellCommand(String command) {
    final normalized = command.toLowerCase();
    final deniedPattern = RegExp(
      r'\b('
      r'rm|rmdir|del|erase|mv|move|ren|rename|cp|copy|'
      r'git\s+(add|commit|push|reset|checkout|restore|clean|rebase|merge|cherry-pick)|'
      r'npm\s+(install|publish|unpublish)|'
      r'pnpm\s+(add|remove|install|publish)|'
      r'yarn\s+(add|remove|install|publish)|'
      r'flutter\s+pub\s+(add|remove)|'
      r'dart\s+pub\s+(add|remove)|'
      r'pip\s+install|'
      r'cargo\s+publish'
      r')\b',
      caseSensitive: false,
    );
    return deniedPattern.hasMatch(normalized);
  }

  String _buildShellOutputSummary(
    String command,
    String stdoutText,
    String stderrText,
  ) {
    if (stdoutText.isNotEmpty) {
      return '命令执行完成：$command\n${_truncateText(stdoutText)}';
    }
    if (stderrText.isNotEmpty) {
      return '命令执行完成（stderr）：$command\n${_truncateText(stderrText)}';
    }
    return '命令执行完成：$command';
  }

  String _truncateText(String text) {
    if (text.length <= _maxResultChars) return text;
    return '${text.substring(0, _maxResultChars)}\n...[truncated]';
  }
}
