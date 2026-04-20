import 'package:flutter_test/flutter_test.dart';
import 'package:functions_client/functions_client.dart';
import 'package:frontend/core/services/agent_service.dart';
import 'package:frontend/core/services/guide_service.dart';
import 'package:frontend/features/quest/models/agent_run.dart';
import 'package:frontend/features/quest/models/agent_step.dart';

void main() {
  test('AgentService 会将 ES256 鉴权拒绝映射为部署配置错误', () {
    final exception = mapAgentInvokeException(
      functionName: 'agent-run-status',
      error: const FunctionException(
        status: 401,
        details: {
          'code': 'UNAUTHORIZED_UNSUPPORTED_TOKEN_ALGORITHM',
          'message': 'Unsupported JWT algorithm ES256',
        },
      ),
    );

    expect(exception.type, GuideErrorType.service);
    expect(exception.statusCode, 401);
    expect(exception.message, contains('agent-run-status'));
    expect(exception.message, contains('ES256'));
  });

  test('AgentService 会将缺失函数映射为未部署错误', () {
    final exception = mapAgentInvokeException(
      functionName: 'agent-step-approve',
      error: const FunctionException(
        status: 404,
        details: {
          'code': 'NOT_FOUND',
          'message': 'Requested function was not found',
        },
      ),
    );

    expect(exception.type, GuideErrorType.service);
    expect(exception.statusCode, 404);
    expect(exception.message, contains('agent-step-approve'));
    expect(exception.message, contains('未部署'));
  });

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
