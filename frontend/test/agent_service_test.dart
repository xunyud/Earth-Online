import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/agent_service.dart';
import 'package:frontend/features/quest/models/agent_run.dart';
import 'package:frontend/features/quest/models/agent_step.dart';

void main() {
  test('AgentRunSnapshot 保留最新 step', () {
    final snapshot = AgentRunSnapshot(
      run: AgentRun.fromJson(const {
        'id': 'run-1',
        'user_id': 'user-1',
        'goal': '读取 README',
        'status': 'running',
      }),
      steps: [
        AgentStep.fromJson(const {
          'id': 'step-1',
          'run_id': 'run-1',
          'step_index': 0,
          'kind': 'message',
          'status': 'succeeded',
          'summary': '已理解目标',
        }),
        AgentStep.fromJson(const {
          'id': 'step-2',
          'run_id': 'run-1',
          'step_index': 1,
          'kind': 'tool_call',
          'tool_name': 'file.read_text',
          'status': 'ready',
          'summary': '读取 README',
        }),
      ],
    );

    expect(snapshot.latestStep?.id, 'step-2');
    expect(snapshot.run.status, 'running');
  });
}
