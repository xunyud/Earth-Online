import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/quest/models/agent_run.dart';
import 'package:frontend/features/quest/models/agent_step.dart';

void main() {
  test('AgentRun.fromJson 会识别等待审批与终态', () {
    final waiting = AgentRun.fromJson(const {
      'id': 'run-1',
      'user_id': 'user-1',
      'goal': '执行命令',
      'status': 'waiting_approval',
    });
    final done = AgentRun.fromJson(const {
      'id': 'run-2',
      'user_id': 'user-1',
      'goal': '完成任务',
      'status': 'succeeded',
    });

    expect(waiting.isWaitingApproval, isTrue);
    expect(waiting.isTerminal, isFalse);
    expect(done.isTerminal, isTrue);
  });

  test('AgentStep.fromJson 会识别 tool call 与等待审批', () {
    final step = AgentStep.fromJson(const {
      'id': 'step-1',
      'run_id': 'run-1',
      'step_index': 1,
      'kind': 'tool_call',
      'tool_name': 'shell.exec',
      'risk_level': 'high',
      'needs_confirmation': true,
      'status': 'waiting_approval',
      'summary': '执行 npm install',
      'arguments_json': {
        'command': 'npm install',
      },
    });

    expect(step.isToolCall, isTrue);
    expect(step.isWaitingApproval, isTrue);
    expect(step.argumentsJson['command'], 'npm install');
  });
}
