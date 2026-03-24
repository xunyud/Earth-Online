import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('系统商城迁移会停用旧系统商品并仅保留日常奖励商品', () async {
    final source = await File(
      '../supabase/migrations/20260324153000_keep_only_daily_system_rewards.sql',
    ).readAsString();

    expect(source, contains('UPDATE rewards'));
    expect(source, contains('is_active = false'));
    expect(source, contains("title NOT IN ("));
    expect(source, contains("'听一首歌'"));
    expect(source, contains("'散步二十分钟'"));
    expect(source, contains("'看一集喜欢的内容'"));
    expect(source, contains("'买一杯喜欢的饮料'"));
    expect(source, contains("'躺平放空半小时'"));
    expect(source, contains("'喝杯奶茶'"));
    expect(source, contains("'点一份喜欢的小甜点'"));
    expect(source, contains("'玩游戏一小时'"));
  });
}
