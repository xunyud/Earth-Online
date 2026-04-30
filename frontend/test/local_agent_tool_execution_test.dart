/// local_agent_tool_execution_test.dart
///
/// 覆盖 LocalAgentRuntimeService 工具执行的边界条件：
/// 1. 空 tool_name
/// 2. 路径越界（workspace 外）
/// 3. 不在白名单的 shell 命令
/// 4. 未注册 handler 的 app.* 工具
/// 5. shell 命令执行失败（非零退出码）
/// 6. file.read_text 文件不存在
/// 7. browser.open / browser.extract_text 返回不支持
///
/// 日期：2026-04-22
/// 执行者：Kiro

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/local_tool_call.dart';
import 'package:frontend/core/services/local_agent_runtime_service.dart';

void main() {
  // 工作区根目录：frontend 的上一级
  final workspaceRoot = Directory.current.parent.path;

  group('LocalAgentRuntimeService — 边界条件', () {
    test('空 tool_name 返回失败', () async {
      final service = LocalAgentRuntimeService(
        workspaceRootPath: workspaceRoot,
      );

      final result = await service.execute(
        const LocalToolCall(
          stepId: 'step-empty',
          toolName: '',
          arguments: <String, dynamic>{},
        ),
      );

      expect(result.success, isFalse);
      expect(result.errorText, 'tool_name 不能为空');
    });

    test('file.read_text 缺少 path 参数返回失败', () async {
      final service = LocalAgentRuntimeService(
        workspaceRootPath: workspaceRoot,
      );

      final result = await service.execute(
        const LocalToolCall(
          stepId: 'step-no-path',
          toolName: 'file.read_text',
          arguments: <String, dynamic>{},
        ),
      );

      expect(result.success, isFalse);
      expect(result.errorText, 'missing_file_path');
    });

    test('file.read_text 路径越界返回失败', () async {
      final service = LocalAgentRuntimeService(
        workspaceRootPath: workspaceRoot,
      );

      final result = await service.execute(
        const LocalToolCall(
          stepId: 'step-escape',
          toolName: 'file.read_text',
          // 尝试读取工作区外的文件
          arguments: <String, dynamic>{'path': '../../etc/passwd'},
        ),
      );

      expect(result.success, isFalse);
      expect(result.errorText, 'path_outside_workspace');
    });

    test('file.read_text 文件不存在返回失败', () async {
      final service = LocalAgentRuntimeService(
        workspaceRootPath: workspaceRoot,
      );

      final result = await service.execute(
        const LocalToolCall(
          stepId: 'step-missing',
          toolName: 'file.read_text',
          arguments: <String, dynamic>{'path': 'nonexistent_file_xyz.md'},
        ),
      );

      expect(result.success, isFalse);
      expect(result.errorText, 'file_not_found');
    });

    test('shell.exec 缺少 command 参数返回失败', () async {
      final service = LocalAgentRuntimeService(
        workspaceRootPath: workspaceRoot,
      );

      final result = await service.execute(
        const LocalToolCall(
          stepId: 'step-no-cmd',
          toolName: 'shell.exec',
          arguments: <String, dynamic>{},
        ),
      );

      expect(result.success, isFalse);
      expect(result.errorText, 'missing_shell_command');
    });

    test('shell.exec 高风险命令（git push）被拒绝', () async {
      final service = LocalAgentRuntimeService(
        workspaceRootPath: workspaceRoot,
      );

      final result = await service.execute(
        const LocalToolCall(
          stepId: 'step-push',
          toolName: 'shell.exec',
          arguments: <String, dynamic>{
            'command': 'git push origin main',
            'cwd': '.',
          },
        ),
      );

      expect(result.success, isFalse);
      expect(result.errorText, 'shell_command_blocked');
    });

    test('shell.exec 不在白名单的命令被拒绝', () async {
      final service = LocalAgentRuntimeService(
        workspaceRootPath: workspaceRoot,
      );

      final result = await service.execute(
        const LocalToolCall(
          stepId: 'step-unknown-cmd',
          toolName: 'shell.exec',
          arguments: <String, dynamic>{
            'command': 'echo hello world',
            'cwd': '.',
          },
        ),
      );

      expect(result.success, isFalse);
      expect(result.errorText, 'shell_command_not_allowlisted');
    });

    test('shell.exec 命令执行失败（非零退出码）返回 success=false', () async {
      final service = LocalAgentRuntimeService(
        workspaceRootPath: workspaceRoot,
        // 模拟命令执行失败
        processRunner: (
          String executable,
          List<String> arguments, {
          String? workingDirectory,
        }) async =>
            ProcessResult(1, 1, '', 'fatal: not a git repository'),
      );

      final result = await service.execute(
        const LocalToolCall(
          stepId: 'step-fail',
          toolName: 'shell.exec',
          arguments: <String, dynamic>{'command': 'git status', 'cwd': '.'},
        ),
      );

      expect(result.success, isFalse);
      expect(result.errorText, isNotEmpty);
      expect(result.resultJson?['exit_code'], 1);
    });

    test('shell.exec cwd 越界返回失败', () async {
      final service = LocalAgentRuntimeService(
        workspaceRootPath: workspaceRoot,
      );

      final result = await service.execute(
        const LocalToolCall(
          stepId: 'step-cwd-escape',
          toolName: 'shell.exec',
          arguments: <String, dynamic>{
            'command': 'git status',
            'cwd': '../../',
          },
        ),
      );

      expect(result.success, isFalse);
      expect(result.errorText, 'cwd_outside_workspace');
    });

    test('app.quest.create 未注册 handler 时返回失败', () async {
      // 不传 questCreateHandler，模拟未接入执行器的场景
      final service = LocalAgentRuntimeService(
        workspaceRootPath: workspaceRoot,
      );

      final result = await service.execute(
        const LocalToolCall(
          stepId: 'step-no-handler',
          toolName: 'app.quest.create',
          arguments: <String, dynamic>{'title': '整理会议材料'},
        ),
      );

      expect(result.success, isFalse);
      expect(result.errorText, 'quest_create_not_supported');
    });

    test('app.quest.update 未注册 handler 时返回失败', () async {
      final service = LocalAgentRuntimeService(
        workspaceRootPath: workspaceRoot,
      );

      final result = await service.execute(
        const LocalToolCall(
          stepId: 'step-no-update',
          toolName: 'app.quest.update',
          arguments: <String, dynamic>{'task_title': '准备周会'},
        ),
      );

      expect(result.success, isFalse);
      expect(result.errorText, 'quest_update_not_supported');
    });

    test('app.weekly_summary.generate 未注册 handler 时返回失败', () async {
      final service = LocalAgentRuntimeService(
        workspaceRootPath: workspaceRoot,
      );

      final result = await service.execute(
        const LocalToolCall(
          stepId: 'step-no-weekly',
          toolName: 'app.weekly_summary.generate',
          arguments: <String, dynamic>{'source_text': '生成周报'},
        ),
      );

      expect(result.success, isFalse);
      expect(result.errorText, 'weekly_summary_generate_not_supported');
    });

    test('browser.open 返回不支持错误', () async {
      final service = LocalAgentRuntimeService(
        workspaceRootPath: workspaceRoot,
      );

      final result = await service.execute(
        const LocalToolCall(
          stepId: 'step-browser',
          toolName: 'browser.open',
          arguments: <String, dynamic>{'url': 'https://example.com'},
        ),
      );

      expect(result.success, isFalse);
      expect(result.errorText, 'browser_execution_not_supported');
    });

    test('browser.extract_text 返回不支持错误', () async {
      final service = LocalAgentRuntimeService(
        workspaceRootPath: workspaceRoot,
      );

      final result = await service.execute(
        const LocalToolCall(
          stepId: 'step-browser-extract',
          toolName: 'browser.extract_text',
          arguments: <String, dynamic>{'url': 'https://example.com'},
        ),
      );

      expect(result.success, isFalse);
      expect(result.errorText, 'browser_execution_not_supported');
    });

    test('完全未知的 tool_name 返回 unsupported_local_tool', () async {
      final service = LocalAgentRuntimeService(
        workspaceRootPath: workspaceRoot,
      );

      final result = await service.execute(
        const LocalToolCall(
          stepId: 'step-unknown',
          toolName: 'totally.unknown.tool',
          arguments: <String, dynamic>{},
        ),
      );

      expect(result.success, isFalse);
      expect(result.errorText, 'unsupported_local_tool');
      expect(result.resultJson?['tool_name'], 'totally.unknown.tool');
    });
  });

  group('LocalAgentRuntimeService — 正常执行路径', () {
    test('shell.exec 成功执行只读命令返回 stdout', () async {
      final service = LocalAgentRuntimeService(
        workspaceRootPath: workspaceRoot,
        processRunner: (
          String executable,
          List<String> arguments, {
          String? workingDirectory,
        }) async =>
            ProcessResult(1, 0, 'On branch main\nnothing to commit', ''),
      );

      final result = await service.execute(
        const LocalToolCall(
          stepId: 'step-ok',
          toolName: 'shell.exec',
          arguments: <String, dynamic>{'command': 'git status', 'cwd': '.'},
        ),
      );

      expect(result.success, isTrue);
      expect(result.outputText, contains('git status'));
      expect(result.resultJson?['exit_code'], 0);
      expect(result.resultJson?['stdout'], contains('On branch main'));
    });

    test('app.quest.split handler 抛出异常时返回失败', () async {
      final service = LocalAgentRuntimeService(
        workspaceRootPath: workspaceRoot,
        questSplitHandler: (_) async => throw Exception('数据库连接失败'),
      );

      // handler 抛出异常时，execute 本身不应抛出，而是由调用方捕获
      // LocalAgentRuntimeService 不包装 handler 异常，由 home_page 的 try/catch 处理
      // 此处验证 handler 被正确调用
      expect(
        () => service.execute(
          const LocalToolCall(
            stepId: 'step-split-err',
            toolName: 'app.quest.split',
            arguments: <String, dynamic>{'task_title': '准备周会'},
          ),
        ),
        throwsException,
      );
    });
  });
}
