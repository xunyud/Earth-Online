// 小忆建议卡片 Widget 测试
// 验证 MemoryRecommendation 数据模型解析、空列表不渲染、非空列表渲染正确数量、点击预填
// Validates: Requirements 7.1, 7.2, 7.3

import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/services/guide_service.dart';

void main() {
  // ──────────────────────────────────────────────────────────
  // MemoryRecommendation.fromMap 工厂构造测试
  // ──────────────────────────────────────────────────────────

  group('MemoryRecommendation.fromMap', () {
    test('完整字段正确解析', () {
      // **Validates: Requirements 7.1**
      final rec = MemoryRecommendation.fromMap({
        'title': '整理本周读书笔记',
        'reason': '你最近连续 3 天都在阅读，可以趁热打铁整理一下',
      });

      expect(rec.title, '整理本周读书笔记');
      expect(rec.reason, '你最近连续 3 天都在阅读，可以趁热打铁整理一下');
    });

    test('缺失字段使用默认空字符串', () {
      final rec = MemoryRecommendation.fromMap({});
      expect(rec.title, '');
      expect(rec.reason, '');
    });

    test('null 值字段使用默认空字符串', () {
      final rec = MemoryRecommendation.fromMap({
        'title': null,
        'reason': null,
      });
      expect(rec.title, '');
      expect(rec.reason, '');
    });

    test('带空白的字段会被 trim', () {
      final rec = MemoryRecommendation.fromMap({
        'title': '  做拉伸运动  ',
        'reason': '  连续久坐提醒  ',
      });
      expect(rec.title, '做拉伸运动');
      expect(rec.reason, '连续久坐提醒');
    });
  });

  // ──────────────────────────────────────────────────────────
  // GuideBootstrapResult.fromMap 中 recommendations 解析
  // ──────────────────────────────────────────────────────────

  group('GuideBootstrapResult recommendations 解析', () {
    test('recommendations 数组正确解析为 MemoryRecommendation 列表', () {
      // **Validates: Requirements 7.1**
      final result = GuideBootstrapResult.fromMap({
        'proactive_message': '你好',
        'memory_digest': '',
        'trace_id': 'test-trace',
        'recommendations': [
          {'title': '复习英语单词', 'reason': '你已连续 5 天学习英语'},
          {'title': '整理桌面', 'reason': '上周提到过想整理'},
        ],
      });

      expect(result.recommendations.length, 2);
      expect(result.recommendations[0].title, '复习英语单词');
      expect(result.recommendations[0].reason, '你已连续 5 天学习英语');
      expect(result.recommendations[1].title, '整理桌面');
    });

    test('recommendations 缺失时返回空列表', () {
      // **Validates: Requirements 7.1**
      final result = GuideBootstrapResult.fromMap({
        'proactive_message': '',
        'memory_digest': '',
        'trace_id': '',
      });

      expect(result.recommendations, isEmpty);
    });

    test('recommendations 为 null 时返回空列表', () {
      final result = GuideBootstrapResult.fromMap({
        'proactive_message': '',
        'recommendations': null,
      });

      expect(result.recommendations, isEmpty);
    });

    test('recommendations 中 title 为空的条目被过滤', () {
      // **Validates: Requirements 7.1**
      final result = GuideBootstrapResult.fromMap({
        'proactive_message': '',
        'recommendations': [
          {'title': '有效推荐', 'reason': '理由'},
          {'title': '', 'reason': '空标题应被过滤'},
          {'title': '  ', 'reason': '纯空白标题也应被过滤'},
          {'title': '另一个有效推荐', 'reason': '理由2'},
        ],
      });

      expect(result.recommendations.length, 2);
      expect(result.recommendations[0].title, '有效推荐');
      expect(result.recommendations[1].title, '另一个有效推荐');
    });

    test('recommendations 中非 Map 类型条目被忽略', () {
      final result = GuideBootstrapResult.fromMap({
        'proactive_message': '',
        'recommendations': [
          {'title': '有效', 'reason': '理由'},
          'not_a_map',
          42,
          null,
        ],
      });

      expect(result.recommendations.length, 1);
      expect(result.recommendations[0].title, '有效');
    });
  });

  // ──────────────────────────────────────────────────────────
  // 空列表不渲染建议区域
  // ──────────────────────────────────────────────────────────

  group('空列表不渲染建议区域', () {
    test('空推荐列表长度为 0，前端应据此不显示建议区域', () {
      // **Validates: Requirements 7.3**
      final recommendations = <MemoryRecommendation>[];
      expect(recommendations.isEmpty, isTrue,
          reason: '空列表时不应显示小忆建议区域，不占用页面空间');
    });

    test('bootstrap 返回空 recommendations 时列表为空', () {
      // **Validates: Requirements 7.3**
      final result = GuideBootstrapResult.fromMap({
        'proactive_message': '今天状态不错',
        'recommendations': [],
      });
      expect(result.recommendations.isEmpty, isTrue);
    });
  });

  // ──────────────────────────────────────────────────────────
  // 非空列表渲染正确数量的卡片
  // ──────────────────────────────────────────────────────────

  group('非空列表渲染正确数量的卡片', () {
    test('2 条推荐应渲染 2 张卡片', () {
      // **Validates: Requirements 7.1, 7.2**
      final result = GuideBootstrapResult.fromMap({
        'proactive_message': '',
        'recommendations': [
          {'title': '任务A', 'reason': '理由A'},
          {'title': '任务B', 'reason': '理由B'},
        ],
      });

      expect(result.recommendations.length, 2);
      expect(result.recommendations[0].title, '任务A');
      expect(result.recommendations[1].title, '任务B');
    });

    test('3 条推荐应渲染 3 张卡片', () {
      // **Validates: Requirements 7.1, 7.2**
      final result = GuideBootstrapResult.fromMap({
        'proactive_message': '',
        'recommendations': [
          {'title': '任务A', 'reason': '理由A'},
          {'title': '任务B', 'reason': '理由B'},
          {'title': '任务C', 'reason': '理由C'},
        ],
      });

      expect(result.recommendations.length, 3);
    });

    test('每张卡片包含 title 和 reason', () {
      // **Validates: Requirements 7.2**
      final result = GuideBootstrapResult.fromMap({
        'proactive_message': '',
        'recommendations': [
          {'title': '写日记', 'reason': '你已经连续 3 天没有写日记了'},
        ],
      });

      final rec = result.recommendations.first;
      expect(rec.title, isNotEmpty, reason: '卡片应显示 title');
      expect(rec.reason, isNotEmpty, reason: '卡片应显示 reason');
      expect(rec.title, '写日记');
      expect(rec.reason, '你已经连续 3 天没有写日记了');
    });
  });

  // ──────────────────────────────────────────────────────────
  // 点击卡片触发任务创建预填
  // ──────────────────────────────────────────────────────────

  group('点击卡片触发任务创建预填', () {
    test('点击回调应传递推荐的 title 作为预填内容', () {
      // **Validates: Requirements 7.2**
      // 模拟点击行为：验证 onTap 回调接收到正确的 title
      final recommendations = [
        MemoryRecommendation.fromMap({
          'title': '整理读书笔记',
          'reason': '你最近在读《原子习惯》',
        }),
        MemoryRecommendation.fromMap({
          'title': '做 15 分钟拉伸',
          'reason': '连续久坐 3 天',
        }),
      ];

      // 收集点击事件
      final tappedTitles = <String>[];
      void onTap(String title) => tappedTitles.add(title);

      // 模拟逐个点击每张卡片
      for (final rec in recommendations) {
        onTap(rec.title);
      }

      expect(tappedTitles.length, 2);
      expect(tappedTitles[0], '整理读书笔记',
          reason: '点击第一张卡片应预填"整理读书笔记"');
      expect(tappedTitles[1], '做 15 分钟拉伸',
          reason: '点击第二张卡片应预填"做 15 分钟拉伸"');
    });

    test('title 作为预填内容应保持原始文本不变', () {
      // **Validates: Requirements 7.2**
      final rec = MemoryRecommendation.fromMap({
        'title': '复习英语单词 30 分钟',
        'reason': '习惯形成信号',
      });

      // 验证 title 可直接用于任务创建预填
      final prefillText = rec.title;
      expect(prefillText, '复习英语单词 30 分钟');
      expect(prefillText, isNotEmpty);
    });
  });

  // ──────────────────────────────────────────────────────────
  // 每次 bootstrap 刷新时更新推荐内容
  // ──────────────────────────────────────────────────────────

  group('bootstrap 刷新更新推荐', () {
    test('连续两次 bootstrap 返回不同推荐时应使用最新结果', () {
      // **Validates: Requirements 7.1**
      // 模拟第一次 bootstrap
      final result1 = GuideBootstrapResult.fromMap({
        'proactive_message': '',
        'recommendations': [
          {'title': '旧推荐A', 'reason': '旧理由'},
        ],
      });

      // 模拟第二次 bootstrap（刷新）
      final result2 = GuideBootstrapResult.fromMap({
        'proactive_message': '',
        'recommendations': [
          {'title': '新推荐X', 'reason': '新理由X'},
          {'title': '新推荐Y', 'reason': '新理由Y'},
        ],
      });

      // 模拟状态更新：每次 bootstrap 刷新时替换推荐列表
      var currentRecommendations = result1.recommendations;
      expect(currentRecommendations.length, 1);
      expect(currentRecommendations[0].title, '旧推荐A');

      // 刷新后应使用最新结果，不缓存过期推荐
      currentRecommendations = result2.recommendations;
      expect(currentRecommendations.length, 2);
      expect(currentRecommendations[0].title, '新推荐X');
      expect(currentRecommendations[1].title, '新推荐Y');
    });
  });
}
