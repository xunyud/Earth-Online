import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/local_tool_call.dart';
import 'package:frontend/core/models/local_tool_result.dart';
import 'package:frontend/core/services/local_agent_runtime_service.dart';

void main() {
  test('LocalAgentRuntimeService can read a workspace text file', () async {
    final repoRoot = Directory.current.parent.path;
    final service = LocalAgentRuntimeService(
      currentDirectoryProvider: () => Directory.current.path,
    );

    final result = await service.execute(
      const LocalToolCall(
        stepId: 'step-readme',
        toolName: 'file.read_text',
        arguments: <String, dynamic>{'path': 'README.md'},
      ),
    );

    expect(result.success, isTrue);
    expect(result.outputText, contains('README.md'));
    expect(result.resultJson?['workspace_root'], repoRoot);
    expect('${result.resultJson?['text'] ?? ''}', isNotEmpty);
    expect(result.errorText, anyOf(isNull, isEmpty));
  });

  test('LocalAgentRuntimeService can execute an allowed readonly shell command',
      () async {
    final service = LocalAgentRuntimeService(
      workspaceRootPath: Directory.current.parent.path,
      processRunner: (
        String executable,
        List<String> arguments, {
        String? workingDirectory,
      }) async {
        final normalizedWorkingDirectory =
            workingDirectory?.replaceAll(RegExp(r'[\\/]+$'), '');
        expect(executable, isNotEmpty);
        expect(arguments.join(' '), contains('git status'));
        expect(normalizedWorkingDirectory, Directory.current.parent.path);
        return ProcessResult(
          1,
          0,
          'On branch codex/business-agent',
          '',
        );
      },
    );

    final result = await service.execute(
      const LocalToolCall(
        stepId: 'step-shell',
        toolName: 'shell.exec',
        arguments: <String, dynamic>{'command': 'git status', 'cwd': '.'},
      ),
    );

    expect(result.success, isTrue);
    expect(result.outputText, contains('git status'));
    expect(result.outputText, contains('On branch'));
    expect(result.errorText, anyOf(isNull, isEmpty));
  });

  test('LocalAgentRuntimeService blocks high-risk shell commands', () async {
    final service = LocalAgentRuntimeService(
      workspaceRootPath: Directory.current.parent.path,
    );

    final result = await service.execute(
      const LocalToolCall(
        stepId: 'step-blocked',
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

  test('LocalAgentRuntimeService can execute app.quest.create', () async {
    Map<String, dynamic>? receivedArguments;
    final service = LocalAgentRuntimeService(
      workspaceRootPath: Directory.current.parent.path,
      questCreateHandler: (arguments) async {
        receivedArguments = arguments;
        return const LocalToolResult(
          success: true,
          outputText: 'Created task: Prepare meeting materials',
          resultJson: <String, dynamic>{
            'created_task_id': 'quest-1',
            'created_task_title': 'Prepare meeting materials',
          },
        );
      },
    );

    final result = await service.execute(
      const LocalToolCall(
        stepId: 'step-create',
        toolName: 'app.quest.create',
        arguments: <String, dynamic>{
          'source_text': 'Help me create a task: Prepare meeting materials',
          'title': 'Prepare meeting materials',
        },
      ),
    );

    expect(receivedArguments?['title'], 'Prepare meeting materials');
    expect(result.success, isTrue);
    expect(result.resultJson?['created_task_id'], 'quest-1');
  });

  test('LocalAgentRuntimeService can execute app.quest.update', () async {
    Map<String, dynamic>? receivedArguments;
    final service = LocalAgentRuntimeService(
      workspaceRootPath: Directory.current.parent.path,
      questUpdateHandler: (arguments) async {
        receivedArguments = arguments;
        return const LocalToolResult(
          success: true,
          outputText: 'Updated task: Prepare weekly sync',
          resultJson: <String, dynamic>{'updated_task_id': 'quest-2'},
        );
      },
    );

    final result = await service.execute(
      const LocalToolCall(
        stepId: 'step-update',
        toolName: 'app.quest.update',
        arguments: <String, dynamic>{'task_title': 'Prepare weekly sync'},
      ),
    );

    expect(receivedArguments?['task_title'], 'Prepare weekly sync');
    expect(result.success, isTrue);
    expect(result.resultJson?['updated_task_id'], 'quest-2');
  });

  test('LocalAgentRuntimeService can execute app.quest.split', () async {
    Map<String, dynamic>? receivedArguments;
    final service = LocalAgentRuntimeService(
      workspaceRootPath: Directory.current.parent.path,
      questSplitHandler: (arguments) async {
        receivedArguments = arguments;
        return const LocalToolResult(
          success: true,
          outputText: 'Split task: Prepare weekly sync',
          resultJson: <String, dynamic>{
            'created_subtasks': <String>[
              'Confirm agenda',
              'Gather notes',
              'Send time update',
            ],
          },
        );
      },
    );

    final result = await service.execute(
      const LocalToolCall(
        stepId: 'step-split',
        toolName: 'app.quest.split',
        arguments: <String, dynamic>{'task_title': 'Prepare weekly sync'},
      ),
    );

    expect(receivedArguments?['task_title'], 'Prepare weekly sync');
    expect(result.success, isTrue);
    expect(result.resultJson?['created_subtasks'], isNotNull);
  });

  test('LocalAgentRuntimeService can execute app.chat.freeform.respond',
      () async {
    final service = LocalAgentRuntimeService(
      workspaceRootPath: Directory.current.parent.path,
      chatFreeformHandler: (arguments) async {
        expect(arguments['source_text'], 'who are you');
        return const LocalToolResult(
          success: true,
          outputText:
              'I am Xiaoyi, here to keep chatting with your recent context in view.',
          resultJson: <String, dynamic>{
            'guide_chat_result': <String, dynamic>{
              'reply':
                  'I am Xiaoyi, here to keep chatting with your recent context in view.',
              'intent': 'companion',
              'quick_actions': <String>[
                'Continue with today',
                'Review last week',
                'Give me a recovery task',
              ],
            },
          },
        );
      },
    );

    final result = await service.execute(
      const LocalToolCall(
        stepId: 'step-chat',
        toolName: 'app.chat.freeform.respond',
        arguments: <String, dynamic>{'source_text': 'who are you'},
      ),
    );

    expect(result.success, isTrue);
    expect(result.outputText, contains('Xiaoyi'));
    expect(result.resultJson?['guide_chat_result'], isNotNull);
  });

  test('LocalAgentRuntimeService can execute app.weekly_summary.generate',
      () async {
    final service = LocalAgentRuntimeService(
      workspaceRootPath: Directory.current.parent.path,
      weeklySummaryGenerateHandler: (arguments) async {
        expect(arguments['source_text'], 'generate this week summary');
        return const LocalToolResult(
          success: true,
          outputText: 'Started weekly summary generation',
          resultJson: <String, dynamic>{'navigation_target': 'weekly_summary'},
        );
      },
    );

    final result = await service.execute(
      const LocalToolCall(
        stepId: 'step-weekly',
        toolName: 'app.weekly_summary.generate',
        arguments: <String, dynamic>{
          'source_text': 'generate this week summary',
        },
      ),
    );

    expect(result.success, isTrue);
    expect(result.resultJson?['navigation_target'], 'weekly_summary');
  });

  test('LocalAgentRuntimeService can execute app.reward.redeem', () async {
    final service = LocalAgentRuntimeService(
      workspaceRootPath: Directory.current.parent.path,
      rewardRedeemHandler: (arguments) async {
        expect(arguments['reward_title'], 'Forest Theme');
        return const LocalToolResult(
          success: true,
          outputText: 'Redeemed reward: Forest Theme',
        );
      },
    );

    final result = await service.execute(
      const LocalToolCall(
        stepId: 'step-redeem',
        toolName: 'app.reward.redeem',
        arguments: <String, dynamic>{'reward_title': 'Forest Theme'},
      ),
    );

    expect(result.success, isTrue);
    expect(result.outputText, contains('Forest Theme'));
  });

  test('LocalAgentRuntimeService can execute app.navigation.open', () async {
    Map<String, dynamic>? receivedArguments;
    final service = LocalAgentRuntimeService(
      workspaceRootPath: Directory.current.parent.path,
      navigationOpenHandler: (arguments) async {
        receivedArguments = arguments;
        return const LocalToolResult(
          success: true,
          outputText: 'Opened stats page',
          resultJson: <String, dynamic>{
            'navigation_target': 'stats',
          },
        );
      },
    );

    final result = await service.execute(
      const LocalToolCall(
        stepId: 'step-nav',
        toolName: 'app.navigation.open',
        arguments: <String, dynamic>{'target': 'stats'},
      ),
    );

    expect(receivedArguments?['target'], 'stats');
    expect(result.success, isTrue);
    expect(result.resultJson?['navigation_target'], 'stats');
  });
}
