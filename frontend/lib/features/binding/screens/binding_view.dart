import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme/quest_theme.dart';
import '../../../shared/widgets/confirm_dialog.dart';

class BindingView extends StatefulWidget {
  const BindingView({super.key});

  @override
  State<BindingView> createState() => _BindingViewState();
}

class _BindingViewState extends State<BindingView> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Random _rng = Random.secure();

  String? _bindingCode;
  String? _wechatOpenId;
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _expiresAtUtc;
  int _remainingSeconds = 0;
  Timer? _timer;
  RealtimeChannel? _profileChannel;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await _supabase
          .from('profiles')
          .select('wechat_openid')
          .eq('id', userId)
          .single();
      if (!mounted) return;
      setState(() {
        _wechatOpenId = response['wechat_openid'] as String?;
      });
      if (_wechatOpenId == null) {
        _subscribeToProfile();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _formatError(error);
      });
    }
  }

  void _subscribeToProfile() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || _profileChannel != null) return;

    _profileChannel = _supabase
        .channel('public:profiles:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) {
            if (!mounted) return;
            final nextOpenId = payload.newRecord['wechat_openid'];
            if (nextOpenId == null) return;
            setState(() {
              _wechatOpenId = nextOpenId as String?;
              _bindingCode = null;
            });
            _stopCountdown();
            _unsubscribeProfile();
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Color(0xFF2E7D32),
                  content: Text(
                      '\u7ed1\u5b9a\u6210\u529f\uff0c\u5fae\u4fe1\u540c\u6b65\u5df2\u5f00\u542f'),
                ),
              );
          },
        )
        .subscribe();
  }

  void _unsubscribeProfile() {
    final channel = _profileChannel;
    if (channel == null) return;
    _supabase.removeChannel(channel);
    _profileChannel = null;
  }

  void _stopCountdown() {
    _timer?.cancel();
    _timer = null;
    _expiresAtUtc = null;
    _remainingSeconds = 0;
    if (mounted) {
      setState(() {});
    }
  }

  void _startCountdown(DateTime expiresAtUtc) {
    _timer?.cancel();
    _expiresAtUtc = expiresAtUtc;
    _remainingSeconds =
        expiresAtUtc.difference(DateTime.now().toUtc()).inSeconds.clamp(0, 900);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final expires = _expiresAtUtc;
      if (expires == null) return;
      final left = expires.difference(DateTime.now().toUtc()).inSeconds;
      if (left <= 0) {
        _stopCountdown();
        return;
      }
      if (mounted) {
        setState(() {
          _remainingSeconds = left;
        });
      }
    });
    if (mounted) {
      setState(() {});
    }
  }

  String _random4Digits() {
    final number = _rng.nextInt(10000);
    return number.toString().padLeft(4, '0');
  }

  String _formatError(Object error) {
    final message = error.toString().trim();
    return message.replaceFirst(RegExp(r'^Exception:\s*'), '');
  }

  Future<void> _generateCode() async {
    if (_remainingSeconds > 0) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception(
            '\u8bf7\u5148\u767b\u5f55\u540e\u518d\u7ed1\u5b9a\u5fae\u4fe1');
      }

      final expiresAtUtc =
          DateTime.now().toUtc().add(const Duration(minutes: 15));
      String? code;
      Object? lastError;

      for (var i = 0; i < 6; i++) {
        final nextCode = _random4Digits();
        try {
          await _supabase.from('wechat_bind_codes').insert({
            'code': nextCode,
            'user_id': userId,
            'expires_at': expiresAtUtc.toIso8601String(),
          });
          code = nextCode;
          break;
        } catch (error) {
          lastError = error;
        }
      }

      if (code == null) {
        throw lastError ??
            Exception('\u751f\u6210\u7ed1\u5b9a\u9a8c\u8bc1\u7801\u5931\u8d25');
      }

      setState(() {
        _bindingCode = code;
      });
      _startCountdown(expiresAtUtc);
    } catch (error) {
      setState(() {
        _errorMessage = _formatError(error);
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _unbind() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _errorMessage =
            '\u8bf7\u5148\u767b\u5f55\u540e\u518d\u89e3\u9664\u7ed1\u5b9a';
      });
      return;
    }

    final ok = await showConfirmDialog(
      context,
      title: '\u89e3\u9664\u7ed1\u5b9a',
      message:
          '\u786e\u5b9a\u8981\u89e3\u9664\u4e0e\u5fae\u4fe1\u7684\u7ed1\u5b9a\u5417\uff1f\u89e3\u9664\u540e\uff0c\u516c\u4f17\u53f7\u6d88\u606f\u5c06\u4e0d\u4f1a\u518d\u540c\u6b65\u5230\u4efb\u52a1\u677f\u3002',
      confirmText: '\u786e\u8ba4\u89e3\u9664',
      danger: true,
    );
    if (!ok) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _supabase
          .from('profiles')
          .update({'wechat_openid': null}).eq('id', userId);

      if (!mounted) return;
      setState(() {
        _wechatOpenId = null;
        _bindingCode = null;
      });
      _stopCountdown();
      _subscribeToProfile();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _formatError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _unsubscribeProfile();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<QuestTheme>() ??
        QuestTheme.forestAdventure();
    final isBound = _wechatOpenId != null;
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    final canGenerate = !isBound && !_isLoading && _remainingSeconds == 0;

    return Scaffold(
      backgroundColor: Color.lerp(theme.backgroundColor, Colors.white, 0.55) ??
          theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          '\u7ed1\u5b9a\u5fae\u4fe1',
          style: AppTextStyles.heading1.copyWith(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1F2E20),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 860;
          return Stack(
            children: [
              Positioned(
                top: -120,
                right: -80,
                child: _BackdropOrb(
                  size: compact ? 240 : 320,
                  color: theme.mainQuestColor.withAlpha(32),
                ),
              ),
              Positioned(
                left: -40,
                top: compact ? 180 : 260,
                child: _BackdropOrb(
                  size: compact ? 180 : 260,
                  color: theme.sideQuestColor.withAlpha(24),
                ),
              ),
              Positioned(
                bottom: -120,
                right: compact ? -40 : 120,
                child: _BackdropOrb(
                  size: compact ? 220 : 280,
                  color: theme.primaryAccentColor.withAlpha(22),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _BindingHeroCard(
                            compact: compact,
                            theme: theme,
                            isBound: isBound,
                          ),
                          const SizedBox(height: 22),
                          compact
                              ? Column(
                                  children: [
                                    _BindingMainPanel(
                                      compact: true,
                                      theme: theme,
                                      isBound: isBound,
                                      isLoading: _isLoading,
                                      bindingCode: _bindingCode,
                                      remainingSeconds: _remainingSeconds,
                                      minutes: minutes,
                                      seconds: seconds,
                                      errorMessage: _errorMessage,
                                      canGenerate: canGenerate,
                                      wechatOpenId: _wechatOpenId,
                                      onGenerateCode: () => _generateCode(),
                                      onUnbind: () => _unbind(),
                                    ),
                                    const SizedBox(height: 18),
                                    _BindingGuideRail(
                                      compact: true,
                                      theme: theme,
                                      isBound: isBound,
                                    ),
                                  ],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 7,
                                      child: _BindingMainPanel(
                                        compact: false,
                                        theme: theme,
                                        isBound: isBound,
                                        isLoading: _isLoading,
                                        bindingCode: _bindingCode,
                                        remainingSeconds: _remainingSeconds,
                                        minutes: minutes,
                                        seconds: seconds,
                                        errorMessage: _errorMessage,
                                        canGenerate: canGenerate,
                                        wechatOpenId: _wechatOpenId,
                                        onGenerateCode: () => _generateCode(),
                                        onUnbind: () => _unbind(),
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      flex: 5,
                                      child: _BindingGuideRail(
                                        compact: false,
                                        theme: theme,
                                        isBound: isBound,
                                      ),
                                    ),
                                  ],
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BindingHeroCard extends StatelessWidget {
  const _BindingHeroCard({
    required this.compact,
    required this.theme,
    required this.isBound,
  });

  final bool compact;
  final QuestTheme theme;
  final bool isBound;

  @override
  Widget build(BuildContext context) {
    final surface = Color.lerp(theme.surfaceColor, Colors.white, 0.42) ??
        theme.surfaceColor;
    final chips = [
      _StatusPill(
        icon: isBound ? Icons.check_circle_rounded : Icons.bolt_rounded,
        label: isBound
            ? '\u540c\u6b65\u5df2\u5f00\u542f'
            : '\u516c\u4f17\u53f7\u540c\u6b65',
        color: theme.primaryAccentColor,
      ),
      const _StatusPill(
        icon: Icons.timer_rounded,
        label: '15 \u5206\u949f\u9a8c\u8bc1\u7801',
        color: Color(0xFF5D7C3B),
      ),
      _StatusPill(
        icon: Icons.mark_chat_unread_rounded,
        label: isBound
            ? '\u4efb\u52a1\u63d0\u9192\u53ef\u9001\u8fbe'
            : '\u5148\u7ed1\u5b9a\u518d\u63a5\u6536',
        color: const Color(0xFF456A8B),
      ),
    ];

    return Container(
      key: const Key('binding-hero-card'),
      padding: EdgeInsets.all(compact ? 22 : 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: LinearGradient(
          colors: [
            surface,
            theme.mainQuestColor.withAlpha(36),
            theme.sideQuestColor.withAlpha(24),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: theme.primaryAccentColor.withAlpha(42)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BindingHeroHeader(isBound: isBound),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: chips,
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: _BindingHeroHeader(isBound: isBound)),
                const SizedBox(width: 22),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.end,
                      children: chips,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _BindingHeroHeader extends StatelessWidget {
  const _BindingHeroHeader({required this.isBound});

  final bool isBound;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              colors: [Color(0xFF2F8F43), Color(0xFF8DB845)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2F8F43).withAlpha(52),
                blurRadius: 20,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: const Icon(
            Icons.chat_bubble_rounded,
            color: Colors.white,
            size: 38,
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isBound
                    ? '\u5fae\u4fe1\u5df2\u8fde\u63a5'
                    : '\u8ba9\u516c\u4f17\u53f7\u6d88\u606f\u540c\u6b65\u8fdb\u6765',
                style: AppTextStyles.heading1.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E2B1D),
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  isBound
                      ? '\u73b0\u5728\u53ef\u4ee5\u628a\u4efb\u52a1\u63d0\u9192\u3001\u6062\u590d\u63d0\u793a\u548c\u5173\u952e\u72b6\u6001\u901a\u8fc7\u516c\u4f17\u53f7\u5e26\u56de\u73b0\u5b9e\u8282\u594f\u3002'
                      : '\u751f\u6210\u4e00\u4e2a 4 \u4f4d\u9a8c\u8bc1\u7801\uff0c\u53d1\u9001\u7ed9\u516c\u4f17\u53f7\u540e\uff0c\u5c0f\u5fc6\u4f1a\u81ea\u52a8\u8bc6\u522b\u5e76\u628a\u5fae\u4fe1\u901a\u9053\u63a5\u5165\u4f60\u7684\u4efb\u52a1\u9762\u677f\u3002',
                  style: AppTextStyles.body.copyWith(
                    color: const Color(0xFF4B5A47),
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BindingMainPanel extends StatelessWidget {
  const _BindingMainPanel({
    required this.compact,
    required this.theme,
    required this.isBound,
    required this.isLoading,
    required this.bindingCode,
    required this.remainingSeconds,
    required this.minutes,
    required this.seconds,
    required this.errorMessage,
    required this.canGenerate,
    required this.wechatOpenId,
    required this.onGenerateCode,
    required this.onUnbind,
  });

  final bool compact;
  final QuestTheme theme;
  final bool isBound;
  final bool isLoading;
  final String? bindingCode;
  final int remainingSeconds;
  final String minutes;
  final String seconds;
  final String? errorMessage;
  final bool canGenerate;
  final String? wechatOpenId;
  final VoidCallback onGenerateCode;
  final VoidCallback onUnbind;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('binding-main-panel'),
      padding: EdgeInsets.all(compact ? 20 : 24),
      decoration: BoxDecoration(
        color: theme.surfaceColor.withAlpha(244),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: theme.primaryAccentColor.withAlpha(26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isBound ? '\u540c\u6b65\u72b6\u6001' : '\u5f00\u59cb\u7ed1\u5b9a',
            style: AppTextStyles.heading1.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF21311F),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isBound
                ? '\u5fae\u4fe1\u901a\u9053\u5df2\u63a5\u5165\uff0c\u4f60\u53ef\u4ee5\u7ee7\u7eed\u4fdd\u7559\u63d0\u9192\u94fe\u8def\uff0c\u6216\u5728\u9700\u8981\u65f6\u89e3\u9664\u7ed1\u5b9a\u3002'
                : '\u628a\u4e0b\u9762\u7684\u9a8c\u8bc1\u7801\u53d1\u9001\u7ed9\u516c\u4f17\u53f7\uff0c\u7cfb\u7edf\u8bc6\u522b\u540e\u4f1a\u81ea\u52a8\u5b8c\u6210\u8fde\u63a5\uff0c\u65e0\u9700\u624b\u52a8\u5237\u65b0\u3002',
            style: AppTextStyles.body.copyWith(
              color: const Color(0xFF596857),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 22),
          isBound
              ? _BoundStateView(
                  compact: compact,
                  theme: theme,
                  wechatOpenId: wechatOpenId,
                  onUnbind: onUnbind,
                )
              : _UnboundStateView(
                  compact: compact,
                  theme: theme,
                  isLoading: isLoading,
                  bindingCode: bindingCode,
                  remainingSeconds: remainingSeconds,
                  minutes: minutes,
                  seconds: seconds,
                  errorMessage: errorMessage,
                  canGenerate: canGenerate,
                  onGenerateCode: onGenerateCode,
                ),
        ],
      ),
    );
  }
}

class _UnboundStateView extends StatelessWidget {
  const _UnboundStateView({
    required this.compact,
    required this.theme,
    required this.isLoading,
    required this.bindingCode,
    required this.remainingSeconds,
    required this.minutes,
    required this.seconds,
    required this.errorMessage,
    required this.canGenerate,
    required this.onGenerateCode,
  });

  final bool compact;
  final QuestTheme theme;
  final bool isLoading;
  final String? bindingCode;
  final int remainingSeconds;
  final String minutes;
  final String seconds;
  final String? errorMessage;
  final bool canGenerate;
  final VoidCallback onGenerateCode;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        children: [
          _BindingCodeCard(
            theme: theme,
            bindingCode: bindingCode,
            remainingSeconds: remainingSeconds,
            minutes: minutes,
            seconds: seconds,
          ),
          const SizedBox(height: 18),
          _BindingActionCard(
            theme: theme,
            isLoading: isLoading,
            errorMessage: errorMessage,
            canGenerate: canGenerate,
            remainingSeconds: remainingSeconds,
            onGenerateCode: onGenerateCode,
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _BindingCodeCard(
            theme: theme,
            bindingCode: bindingCode,
            remainingSeconds: remainingSeconds,
            minutes: minutes,
            seconds: seconds,
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: _BindingActionCard(
            theme: theme,
            isLoading: isLoading,
            errorMessage: errorMessage,
            canGenerate: canGenerate,
            remainingSeconds: remainingSeconds,
            onGenerateCode: onGenerateCode,
          ),
        ),
      ],
    );
  }
}

class _BoundStateView extends StatelessWidget {
  const _BoundStateView({
    required this.compact,
    required this.theme,
    required this.wechatOpenId,
    required this.onUnbind,
  });

  final bool compact;
  final QuestTheme theme;
  final String? wechatOpenId;
  final VoidCallback onUnbind;

  String _maskOpenId(String? value) {
    if (value == null || value.isEmpty) {
      return '\u672a\u8bfb\u53d6\u5230 OpenID';
    }
    if (value.length <= 10) return value;
    return '${value.substring(0, 4)} **** ${value.substring(value.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final cards = [
      _FeatureCard(
        icon: Icons.notifications_active_rounded,
        title: '\u516c\u4f17\u53f7\u63d0\u9192',
        description:
            '\u5173\u952e\u4efb\u52a1\u66f4\u65b0\u3001\u6062\u590d\u63d0\u9192\u548c\u8282\u594f\u63d0\u793a\u90fd\u80fd\u4ece\u5fae\u4fe1\u5e26\u56de\u73b0\u5b9e\u3002',
        accentColor: theme.primaryAccentColor,
      ),
      const _FeatureCard(
        icon: Icons.auto_awesome_rounded,
        title: '\u540c\u6b65\u72b6\u6001',
        description:
            '\u7ed1\u5b9a\u6210\u529f\u540e\uff0c\u5c0f\u5fc6\u4f1a\u5728\u9002\u5408\u7684\u65f6\u673a\u63d0\u9192\u4f60\u7ee7\u7eed\u63a8\u8fdb\u6216\u77ed\u6682\u505c\u9760\u3002',
        accentColor: Color(0xFF688B3F),
      ),
      const _FeatureCard(
        icon: Icons.link_off_rounded,
        title: '\u53ef\u968f\u65f6\u89e3\u9664',
        description:
            '\u5982\u679c\u60f3\u6362\u53f7\u6216\u6682\u505c\u540c\u6b65\uff0c\u53ef\u4ee5\u76f4\u63a5\u5728\u8fd9\u91cc\u5b8c\u6210\u89e3\u7ed1\u3002',
        accentColor: Color(0xFF9B5A5A),
      ),
    ];

    final list = compact
        ? Column(
            children: [
              for (final card in cards) ...[
                card,
                const SizedBox(height: 12),
              ],
            ],
          )
        : Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                Expanded(child: cards[i]),
                if (i != cards.length - 1) const SizedBox(width: 12),
              ],
            ],
          );

    return Container(
      key: const Key('binding-success-card'),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBF3),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: theme.primaryAccentColor.withAlpha(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.primaryAccentColor.withAlpha(18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.verified_rounded,
                  color: theme.primaryAccentColor,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\u5f53\u524d\u5fae\u4fe1\u5df2\u8fde\u63a5',
                      style: AppTextStyles.heading2.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF20301E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _maskOpenId(wechatOpenId),
                      style: AppTextStyles.body.copyWith(
                        color: const Color(0xFF5A6956),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          list,
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onUnbind,
              icon: const Icon(Icons.link_off_rounded),
              label: const Text('\u89e3\u9664\u7ed1\u5b9a'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB04D4D),
                side: const BorderSide(color: Color(0xFFE7B0B0)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BindingCodeCard extends StatelessWidget {
  const _BindingCodeCard({
    required this.theme,
    required this.bindingCode,
    required this.remainingSeconds,
    required this.minutes,
    required this.seconds,
  });

  final QuestTheme theme;
  final String? bindingCode;
  final int remainingSeconds;
  final String minutes;
  final String seconds;

  @override
  Widget build(BuildContext context) {
    final showCode = bindingCode ?? '----';
    return Container(
      key: const Key('binding-code-card'),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: [
            Colors.white,
            theme.mainQuestColor.withAlpha(22),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: theme.primaryAccentColor.withAlpha(22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '\u5f53\u524d\u9a8c\u8bc1\u7801',
            style: AppTextStyles.heading2.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF233221),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '\u628a\u8fd9 4 \u4f4d\u6570\u5b57\u53d1\u9001\u7ed9\u516c\u4f17\u53f7\uff0c\u7cfb\u7edf\u4f1a\u81ea\u52a8\u8bc6\u522b\u4f60\u7684\u8d26\u53f7\u5e76\u5b8c\u6210\u7ed1\u5b9a\u3002',
            style: AppTextStyles.body.copyWith(
              color: const Color(0xFF5E6C5A),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FBF4),
                borderRadius: BorderRadius.circular(24),
                border:
                    Border.all(color: theme.primaryAccentColor.withAlpha(30)),
              ),
              child: Text(
                showCode,
                style: AppTextStyles.heading1.copyWith(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF355D2A),
                  letterSpacing: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          _StatusPill(
            icon: Icons.schedule_rounded,
            label: remainingSeconds > 0
                ? '\u5269\u4f59\u65f6\u95f4 $minutes:$seconds'
                : '\u9a8c\u8bc1\u7801\u6709\u6548\u671f\u4e3a 15 \u5206\u949f',
            color: const Color(0xFF57723D),
          ),
        ],
      ),
    );
  }
}

class _BindingActionCard extends StatelessWidget {
  const _BindingActionCard({
    required this.theme,
    required this.isLoading,
    required this.errorMessage,
    required this.canGenerate,
    required this.remainingSeconds,
    required this.onGenerateCode,
  });

  final QuestTheme theme;
  final bool isLoading;
  final String? errorMessage;
  final bool canGenerate;
  final int remainingSeconds;
  final VoidCallback onGenerateCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('binding-action-card'),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBF7),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFD9E7D2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '\u53d1\u9001\u8bf4\u660e',
            style: AppTextStyles.heading2.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF233221),
            ),
          ),
          const SizedBox(height: 16),
          const _BindingStepCard(
            index: '01',
            title: '\u751f\u6210\u9a8c\u8bc1\u7801',
            description:
                '\u70b9\u51fb\u4e0b\u65b9\u6309\u94ae\uff0c\u9886\u53d6\u672c\u6b21\u7ed1\u5b9a\u7528\u7684 4 \u4f4d\u6570\u5b57\u3002',
          ),
          const SizedBox(height: 12),
          const _BindingStepCard(
            index: '02',
            title: '\u53d1\u7ed9\u516c\u4f17\u53f7',
            description:
                '\u628a\u9a8c\u8bc1\u7801\u539f\u6837\u53d1\u9001\u7ed9\u516c\u4f17\u53f7\uff0c\u65e0\u9700\u989d\u5916\u6307\u4ee4\u3002',
          ),
          const SizedBox(height: 12),
          const _BindingStepCard(
            index: '03',
            title: '\u4fdd\u6301\u9875\u9762\u6253\u5f00',
            description:
                '\u68c0\u6d4b\u5230\u7ed1\u5b9a\u6210\u529f\u540e\uff0c\u8fd9\u4e2a\u9875\u9762\u4f1a\u81ea\u5df1\u5207\u6362\u5230\u5df2\u8fde\u63a5\u72b6\u6001\u3002',
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFF3B6B6)),
              ),
              child: Text(
                errorMessage!,
                style: AppTextStyles.body.copyWith(
                  color: const Color(0xFF9D4747),
                  fontSize: 14,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canGenerate ? onGenerateCode : null,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bolt_rounded),
              label: Text(
                remainingSeconds > 0
                    ? '\u8bf7\u7a0d\u5019\u518d\u751f\u6210'
                    : '\u751f\u6210\u9a8c\u8bc1\u7801',
                style: AppTextStyles.button.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: theme.primaryAccentColor,
                disabledBackgroundColor: const Color(0xFFD8E1D1),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BindingGuideRail extends StatelessWidget {
  const _BindingGuideRail({
    required this.compact,
    required this.theme,
    required this.isBound,
  });

  final bool compact;
  final QuestTheme theme;
  final bool isBound;

  @override
  Widget build(BuildContext context) {
    final steps = [
      const _BindingStepData(
        icon: Icons.mark_chat_read_rounded,
        title: '\u4e09\u6b65\u5b8c\u6210\u7ed1\u5b9a',
        description:
            '\u751f\u6210\u9a8c\u8bc1\u7801\u3001\u53d1\u9001\u7ed9\u516c\u4f17\u53f7\u3001\u7b49\u5f85\u81ea\u52a8\u8bc6\u522b\uff0c\u5168\u7a0b\u4e0d\u9700\u8981\u624b\u52a8\u5237\u65b0\u3002',
      ),
      const _BindingStepData(
        icon: Icons.memory_rounded,
        title: '\u548c\u4efb\u52a1\u677f\u4fdd\u6301\u540c\u6b65',
        description:
            '\u7ed1\u5b9a\u540e\uff0c\u5fae\u4fe1\u53ef\u63a5\u6536\u4efb\u52a1\u8282\u594f\u63d0\u9192\u3001\u6062\u590d\u5efa\u8bae\u548c\u5173\u952e\u72b6\u6001\u53d8\u5316\u3002',
      ),
      const _BindingStepData(
        icon: Icons.lock_clock_rounded,
        title: '\u9a8c\u8bc1\u7801\u77ed\u65f6\u751f\u6548',
        description:
            '\u6bcf\u7ec4\u9a8c\u8bc1\u7801\u4ec5\u5728 15 \u5206\u949f\u5185\u6709\u6548\uff0c\u8fc7\u671f\u540e\u53ef\u76f4\u63a5\u91cd\u65b0\u751f\u6210\u3002',
      ),
    ];

    return Container(
      key: const Key('binding-guide-rail'),
      padding: EdgeInsets.all(compact ? 20 : 24),
      decoration: BoxDecoration(
        color: (Color.lerp(theme.surfaceColor, Colors.white, 0.32) ??
                theme.surfaceColor)
            .withAlpha(246),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: theme.primaryAccentColor.withAlpha(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(14),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isBound
                ? '\u8fde\u63a5\u540e\u7684\u8282\u594f'
                : '\u7ed1\u5b9a\u5c0f\u6284',
            style: AppTextStyles.heading2.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF223021),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isBound
                ? '\u901a\u9053\u63a5\u5165\u540e\uff0c\u4f60\u4f1a\u66f4\u65e9\u6536\u5230\u63a8\u8fdb\u63d0\u9192\uff0c\u4e5f\u80fd\u628a\u73b0\u5b9e\u4e16\u754c\u91cc\u7684\u53cd\u9988\u5e26\u56de\u4efb\u52a1\u7cfb\u7edf\u3002'
                : '\u628a\u8fd9\u9875\u5f53\u6210\u4e00\u4e2a\u5c0f\u578b\u4efb\u52a1\u9762\u677f\uff0c\u8ddf\u7740\u6b65\u9aa4\u8d70\u5c31\u80fd\u5b8c\u6210\u7ed1\u5b9a\u3002',
            style: AppTextStyles.body.copyWith(
              color: const Color(0xFF5A6756),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < steps.length; i++) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: i == 0
                    ? theme.primaryAccentColor.withAlpha(12)
                    : Colors.white.withAlpha(210),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: i == 0
                      ? theme.primaryAccentColor.withAlpha(36)
                      : const Color(0xFFE3EBD9),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: theme.primaryAccentColor.withAlpha(16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      steps[i].icon,
                      color: theme.primaryAccentColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].title,
                          style: AppTextStyles.heading2.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF243223),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          steps[i].description,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 14,
                            color: const Color(0xFF5C6957),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (i != steps.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _BindingStepCard extends StatelessWidget {
  const _BindingStepCard({
    required this.index,
    required this.title,
    required this.description,
  });

  final String index;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7ECDE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F2DD),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              index,
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF35552A),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.heading2.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF273625),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 14,
                    color: const Color(0xFF647160),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.accentColor,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accentColor.withAlpha(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withAlpha(16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: AppTextStyles.heading2.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF243223),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: AppTextStyles.body.copyWith(
              fontSize: 14,
              color: const Color(0xFF63705E),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackdropOrb extends StatelessWidget {
  const _BackdropOrb({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withAlpha(0),
            ],
          ),
        ),
      ),
    );
  }
}

class _BindingStepData {
  const _BindingStepData({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}
