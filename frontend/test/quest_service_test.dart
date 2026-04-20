import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/quest_service.dart';
import 'package:http/http.dart';

void main() {
  test('parseQuest 在 socket 类错误后会重试并成功返回', () async {
    var attempts = 0;

    final result = await QuestService.parseQuest(
      '整理今天的任务',
      'user_123',
      accessTokenOverride: 'token',
      retryDelay: Duration.zero,
      invoker: ({required accessToken, required body}) async {
        attempts += 1;
        if (attempts == 1) {
          throw ClientException(
            'Connection failed',
            Uri.parse('https://example.com/functions/v1/parse-quest'),
          );
        }
        return const ParseQuestFunctionResult(
          status: 200,
          data: {
            'cheer': '慢慢来',
            'tasks': [
              {
                'title': '整理今天的任务',
                'parent_index': null,
                'xpReward': 30,
              },
            ],
          },
        );
      },
    );

    expect(attempts, 2);
    expect(result.cheer, '慢慢来');
    expect(result.quests, hasLength(1));
    expect(result.quests.first.title, '整理今天的任务');
  });

  test('parseQuest 在服务异常时会回退到本地基础解析', () async {
    var attempts = 0;

    final result = await QuestService.parseQuest(
      '整理今天的任务',
      'user_123',
      accessTokenOverride: 'token',
      retryDelay: Duration.zero,
      invoker: ({required accessToken, required body}) async {
        attempts += 1;
        return const ParseQuestFunctionResult(
          status: 500,
          data: {'error': 'boom'},
        );
      },
    );

    expect(attempts, 1);
    expect(result.quests, hasLength(1));
    expect(result.quests.first.title, '整理今天的任务');
  });
}
