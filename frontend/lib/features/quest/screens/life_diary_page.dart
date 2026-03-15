import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme/quest_theme.dart';
import '../models/quest_node.dart';

class LifeDiaryPage extends StatefulWidget {
  const LifeDiaryPage({super.key});

  @override
  State<LifeDiaryPage> createState() => _LifeDiaryPageState();
}

class _LifeDiaryPageState extends State<LifeDiaryPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _loading = true;
  bool _summoningWeekly = false;
  bool _pushingToWechat = false;
  String? _error;
  List<_DiaryDay> _days = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _dateId(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  DateTime _parseDateId(String s) {
    final parts = s.split('-');
    if (parts.length != 3) return DateTime.now();
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return DateTime.now();
    return DateTime(
      y,
      m,
      d,
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final questRows = await _supabase
          .from('quest_nodes')
          .select()
          .eq('is_completed', true)
          .order('completed_at', ascending: false)
          .limit(500);
      final completed = (questRows as List)
          .map((e) => QuestNode.fromJson(e))
          .where((q) => q.completedAt != null)
          .toList();

      final byDateId = <String, List<QuestNode>>{};
      for (final q in completed) {
        final local = q.completedAt!.toLocal();
        final day = DateTime(local.year, local.month, local.day);
        final id = _dateId(day);
        (byDateId[id] ??= <QuestNode>[]).add(q);
      }

      final questDateIds = byDateId.keys.toList();
      final dailyLogById = <String, Map<String, dynamic>>{};
      if (questDateIds.isNotEmpty) {
        final logs = await _supabase
            .from('daily_logs')
            .select()
            .inFilter('date_id', questDateIds);
        for (final row in (logs as List)) {
          final id = row['date_id'] as String?;
          if (id != null) dailyLogById[id] = row as Map<String, dynamic>;
        }
      }

      // 额外获取近 30 天 daily_logs，确保周报等纯日记条目不遗漏
      final recentCutoff = DateTime.now().subtract(const Duration(days: 30));
      final recentLogs = await _supabase
          .from('daily_logs')
          .select()
          .gte('date_id', _dateId(recentCutoff))
          .order('date_id', ascending: false);
      for (final row in (recentLogs as List)) {
        final id = row['date_id']?.toString();
        if (id == null) continue;
        dailyLogById.putIfAbsent(id, () => row as Map<String, dynamic>);
        byDateId.putIfAbsent(id, () => <QuestNode>[]);
      }

      final dateIds = byDateId.keys.toList()..sort((a, b) => b.compareTo(a));
      final days = <_DiaryDay>[];
      for (final id in dateIds) {
        final quests = byDateId[id] ?? const <QuestNode>[];
        quests.sort((a, b) => (b.completedAt ?? DateTime(0))
            .compareTo(a.completedAt ?? DateTime(0)));
        final log = dailyLogById[id];
        days.add(
          _DiaryDay(
            date: _parseDateId(id),
            dateId: id,
            quests: quests,
            completedCount: (log?['completed_count'] as int?) ?? quests.length,
            isPerfect: log?['is_perfect'] == true,
            encouragement: log?['encouragement'] as String?,
          ),
        );
      }

      setState(() {
        _days = days;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _toast(String message, {Color? background}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        backgroundColor: background,
        content: Text(message),
      ),
    );
  }

  Future<void> _summonWeeklySummary() async {
    if (_summoningWeekly) return;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      _toast('未登录，无法召唤周报');
      return;
    }

    setState(() {
      _summoningWeekly = true;
    });

    var dialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '村长正在翻阅你的卷宗，奋笔疾书中...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final response = await _supabase.functions.invoke('weekly-summary',
          body: {'user_id': userId}).timeout(const Duration(seconds: 45));
      final data = response.data;
      final ok = data is Map && data['success'] == true;
      if (!ok) {
        final reason =
            data is Map ? (data['error']?.toString() ?? 'unknown') : 'unknown';
        throw Exception(reason);
      }

      if (mounted && dialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpen = false;
      }
      _toast('🎉 村长的信件已送达！', background: Colors.green.shade700);
      await _load();
    } catch (e) {
      if (mounted && dialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpen = false;
      }
      // 从 FunctionException 中提取后端返回的实际错误信息
      String errorMsg;
      if (e is FunctionException) {
        final details = e.details;
        if (details is Map && details['error'] != null) {
          errorMsg = details['error'].toString();
        } else {
          errorMsg = e.reasonPhrase ?? '未知错误 (${e.status})';
        }
      } else {
        errorMsg = e.toString();
      }
      _toast('召唤失败：$errorMsg');
    } finally {
      if (mounted) {
        setState(() {
          _summoningWeekly = false;
        });
      }
    }
  }

  /// PRD-07: 手动推送周报到微信
  Future<void> _pushToWechat() async {
    if (_pushingToWechat) return;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      _toast('未登录，无法推送');
      return;
    }

    setState(() => _pushingToWechat = true);

    try {
      final response = await _supabase.functions
          .invoke('weekly-report-push', body: {'user_id': userId})
          .timeout(const Duration(seconds: 60));
      final data = response.data;
      final ok = data is Map && data['success'] == true;
      final pushed = data is Map ? (data['pushed'] ?? 0) : 0;
      if (!ok) {
        final reason =
            data is Map ? (data['error']?.toString() ?? '未知错误') : '未知错误';
        throw Exception(reason);
      }
      if (pushed == 0) {
        final msg = (data['message']?.toString() ?? '暂无可推送内容');
        _toast(msg);
      } else {
        _toast('📩 周报已推送到微信！', background: Colors.green.shade700);
      }
    } catch (e) {
      String errorMsg;
      if (e is FunctionException) {
        final details = e.details;
        if (details is Map && details['error'] != null) {
          errorMsg = details['error'].toString();
        } else {
          errorMsg = e.reasonPhrase ?? '未知错误 (${e.status})';
        }
      } else {
        errorMsg = e.toString();
      }
      _toast('推送失败：$errorMsg');
    } finally {
      if (mounted) setState(() => _pushingToWechat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<QuestTheme>()!;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          '人生日记',
          style:
              AppTextStyles.heading1.copyWith(color: theme.primaryAccentColor),
        ),
        actions: [
          IconButton(
            tooltip: '📜 召唤村长周报',
            onPressed: _summoningWeekly ? null : _summonWeeklySummary,
            icon: const Icon(Icons.auto_stories_rounded),
            color: theme.primaryAccentColor,
          ),
          IconButton(
            tooltip: '📩 推送周报到微信',
            onPressed: _pushingToWechat ? null : _pushToWechat,
            icon: _pushingToWechat
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.primaryAccentColor,
                    ),
                  )
                : const Icon(Icons.send_rounded),
            color: theme.primaryAccentColor,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(theme.primaryAccentColor),
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '加载失败',
                          style: AppTextStyles.heading2,
                        ),
                        const SizedBox(height: 8),
                        Text(_error!, style: AppTextStyles.caption),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _load,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryAccentColor,
                          ),
                          child: const Text('重试', style: AppTextStyles.button),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    itemCount: _days.length,
                    itemBuilder: (context, i) {
                      final day = _days[i];
                      return _DiaryDayCard(day: day);
                    },
                  ),
                ),
    );
  }
}

class _DiaryDay {
  final DateTime date;
  final String dateId;
  final List<QuestNode> quests;
  final int completedCount;
  final bool isPerfect;
  final String? encouragement;

  const _DiaryDay({
    required this.date,
    required this.dateId,
    required this.quests,
    required this.completedCount,
    required this.isPerfect,
    required this.encouragement,
  });
}

class _DiaryDayCard extends StatelessWidget {
  final _DiaryDay day;

  const _DiaryDayCard({required this.day});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<QuestTheme>()!;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                day.dateId,
                style: AppTextStyles.heading2.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (day.isPerfect) ...[
                const SizedBox(width: 8),
                const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
              ],
              const Spacer(),
              Text(
                '完成了 ${day.completedCount} 项任务',
                style:
                    AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if ((day.encouragement ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildEncouragementOrSummary(day.encouragement!, theme),
          ],
          const SizedBox(height: 10),
          ...day.quests.map((q) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 16, color: theme.primaryAccentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      q.title,
                      style: AppTextStyles.body.copyWith(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${q.xpReward} XP',
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static const _weeklySummaryPrefix = '【本周总结】';

  /// 判断是周报还是普通鼓励语，返回对应卡片
  Widget _buildEncouragementOrSummary(String text, QuestTheme theme) {
    if (text.startsWith(_weeklySummaryPrefix)) {
      final md = text.substring(_weeklySummaryPrefix.length).trim();
      return _buildWeeklySummaryCard(md, theme);
    }
    return _buildEncouragementCard(text);
  }

  /// 普通鼓励语（Perfect Day）— 保持原有样式
  Widget _buildEncouragementCard(String text) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.amber.withAlpha(18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_rounded,
              color: Colors.amber, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.body.copyWith(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// 周报卡片 — 村长信件风格 + Markdown 渲染
  Widget _buildWeeklySummaryCard(String markdown, QuestTheme theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: theme.primaryAccentColor.withAlpha(12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.primaryAccentColor.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_stories_rounded,
                  color: theme.primaryAccentColor, size: 18),
              const SizedBox(width: 8),
              Text(
                '村长的信',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.primaryAccentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          MarkdownBody(
            data: markdown,
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              p: AppTextStyles.body.copyWith(fontSize: 14, height: 1.6),
              h1: AppTextStyles.heading1.copyWith(fontSize: 18),
              h2: AppTextStyles.heading2.copyWith(fontSize: 16),
              h3: AppTextStyles.heading2.copyWith(
                  fontSize: 15, fontWeight: FontWeight.w600),
              listBullet: AppTextStyles.body.copyWith(fontSize: 14),
              blockquote: AppTextStyles.body.copyWith(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
              blockquoteDecoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: theme.primaryAccentColor.withAlpha(80),
                    width: 3,
                  ),
                ),
              ),
              blockquotePadding:
                  const EdgeInsets.only(left: 12, top: 4, bottom: 4),
              horizontalRuleDecoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.textHint.withAlpha(60),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
