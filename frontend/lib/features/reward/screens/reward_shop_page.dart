import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/i18n/app_locale_controller.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/theme/quest_theme.dart';
import '../../quest/controllers/quest_controller.dart';
import '../controllers/reward_controller.dart';
import '../models/reward.dart';
import 'inventory_page.dart';
import '../../../shared/widgets/confirm_dialog.dart';

class RewardShopPage extends StatefulWidget {
  final QuestController questController;

  const RewardShopPage({super.key, required this.questController});

  @override
  State<RewardShopPage> createState() => _RewardShopPageState();
}

class _AddRewardDraft {
  final String title;
  final int cost;

  const _AddRewardDraft({required this.title, required this.cost});
}

class _RewardShopPageState extends State<RewardShopPage> {
  late final RewardController _controller;

  @override
  void initState() {
    super.initState();
    _controller = RewardController(quest: widget.questController);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.loadRewards();
      _controller.loadInventory();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toast(String message, {Color? background}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        backgroundColor: background,
        content: Text(message),
      ),
    );
  }

  void _closeDialogSafely(BuildContext dialogContext,
      [_AddRewardDraft? draft]) {
    if (!dialogContext.mounted) return;
    Navigator.of(dialogContext).pop<_AddRewardDraft?>(draft);
  }

  Future<void> _openAddReward() async {
    if (!mounted) return;
    final titleController = TextEditingController();
    final costController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    try {
      final theme = Theme.of(context).extension<QuestTheme>()!;

      final draft = await showDialog<_AddRewardDraft>(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withAlpha(130),
        builder: (dialogContext) {
          var submitting = false;
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Container(
                  width: 520,
                  constraints: const BoxConstraints(maxHeight: 640),
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  decoration: BoxDecoration(
                    color: theme.surfaceColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(32),
                        blurRadius: 32,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Form(
                    key: formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              context.tr('shop.add_reward'),
                              style: AppTextStyles.heading2.copyWith(
                                color: theme.primaryAccentColor,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: submitting
                                  ? null
                                  : () => _closeDialogSafely(ctx),
                              icon: const Icon(Icons.close_rounded),
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.softBlue.withAlpha(110),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            context.tr('shop.add_hint'),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.pureWhite.withAlpha(150),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              TextFormField(
                                controller: titleController,
                                textInputAction: TextInputAction.next,
                                maxLength: 20,
                                decoration: InputDecoration(
                                  hintText: context.tr('shop.reward_name'),
                                  prefixIcon: const Icon(
                                    Icons.card_giftcard_rounded,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.softBlue.withAlpha(70),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                validator: (v) {
                                  final value = (v ?? '').trim();
                                  if (value.isEmpty) {
                                    return context
                                        .tr('shop.input_name_required');
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: costController,
                                textInputAction: TextInputAction.done,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                decoration: InputDecoration(
                                  hintText: context.tr('shop.reward_cost'),
                                  prefixIcon:
                                      const Icon(Icons.monetization_on_rounded),
                                  suffixText: context.tr('shop.gold_unit'),
                                  filled: true,
                                  fillColor: AppColors.mintGreen.withAlpha(34),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                validator: (v) {
                                  final raw = (v ?? '').trim();
                                  if (raw.isEmpty) {
                                    return context
                                        .tr('shop.input_gold_required');
                                  }
                                  final parsed = int.tryParse(raw);
                                  if (parsed == null || parsed <= 0) {
                                    return context
                                        .tr('shop.input_gold_positive');
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: submitting
                                  ? null
                                  : () => _closeDialogSafely(ctx),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(90, 44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(context.tr('common.cancel')),
                            ),
                            const SizedBox(width: 10),
                            FilledButton.icon(
                              onPressed: submitting
                                  ? null
                                  : () {
                                      if (!(formKey.currentState?.validate() ??
                                          false)) {
                                        return;
                                      }
                                      final title = titleController.text.trim();
                                      final parsed = int.tryParse(
                                          costController.text.trim());
                                      if (title.isEmpty ||
                                          parsed == null ||
                                          parsed <= 0) {
                                        return;
                                      }
                                      setDialogState(() => submitting = true);
                                      _closeDialogSafely(
                                        ctx,
                                        _AddRewardDraft(
                                          title: title,
                                          cost: parsed,
                                        ),
                                      );
                                    },
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(110, 44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                backgroundColor: theme.primaryAccentColor,
                                foregroundColor: Colors.white,
                              ),
                              icon: submitting
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined, size: 18),
                              label: Text(submitting
                                  ? context.tr('shop.saving')
                                  : context.tr('shop.save')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

      if (!mounted) return;
      if (draft == null) return;
      if (draft.title.isEmpty || draft.cost <= 0) {
        _toast(
          '${context.tr('shop.input_name_required')} / ${context.tr('shop.input_gold_positive')}',
        );
        return;
      }

      await _controller.addReward(title: draft.title, cost: draft.cost);
      if (!mounted) return;
      _toast(context.tr('shop.added'), background: Colors.green.shade700);
    } catch (e) {
      if (!mounted) return;
      _toast(_friendlyErrorMessage(e));
    } finally {
      titleController.dispose();
      costController.dispose();
    }
  }

  String _friendlyErrorMessage(Object e) {
    final text = e.toString();
    final lower = text.toLowerCase();
    if (lower.contains('duplicate key') || lower.contains('already exists')) {
      return context.isEnglish
          ? 'A reward with the same name already exists.'
          : '同名商品已存在，请换个名称再试。';
    }
    if (lower.contains('permission') ||
        lower.contains('not logged in') ||
        lower.contains('unauthorized') ||
        lower.contains('jwt') ||
        lower.contains('session expired')) {
      return context.isEnglish
          ? 'Your session is invalid. Please sign in again.'
          : '当前登录状态异常，请重新登录后再试。';
    }
    if (lower.contains('gold') && lower.contains('positive')) {
      return context.tr('shop.input_gold_positive');
    }
    if ((lower.contains('reward') || lower.contains('name')) &&
        (lower.contains('empty') || lower.contains('required'))) {
      return context.tr('shop.input_name_required');
    }
    return context.tr('shop.add_failed');
  }

  Future<void> _redeem(Reward reward) async {
    final ok = await _controller.buyReward(reward);
    if (!mounted) return;
    if (ok) {
      _toast(context.tr('shop.buy_success'), background: Colors.green.shade700);
    } else {
      _toast(context.tr('shop.buy_failed_gold'),
          background: Colors.orange.shade800);
    }
  }

  Future<void> _deleteReward(Reward reward) async {
    final hide = await PreferencesService.hideShopDeleteConfirm();
    if (!mounted) return;
    var confirmed = hide;
    var dontAskAgain = false;

    if (!hide) {
      final res = await showConfirmWithDontAskDialog(
        context,
        title: context.tr('shop.delete_title'),
        message:
            context.tr('shop.delete_message', params: {'title': reward.title}),
      );
      if (!mounted) return;
      confirmed = res.confirmed;
      dontAskAgain = res.dontAskAgain;
    }

    if (!confirmed) return;
    if (dontAskAgain) {
      await PreferencesService.setHideShopDeleteConfirm(true);
    }

    try {
      await _controller.deleteReward(reward);
      if (!mounted) return;
      _toast(context.tr('shop.deleted'), background: Colors.green.shade700);
    } catch (e) {
      if (!mounted) return;
      _toast(e.toString());
    }
  }

  Widget _buildBalanceCard(QuestTheme theme, int gold) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              Colors.amber.withAlpha(40),
              theme.surfaceColor,
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border.all(color: AppColors.shadowColor),
        ),
        child: Row(
          children: [
            const Icon(Icons.monetization_on_rounded,
                color: Colors.amber, size: 20),
            const SizedBox(width: 8),
            Text(
              context.tr('shop.gold_balance'),
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Text(
                '$gold',
                key: ValueKey(gold),
                style: AppTextStyles.heading2.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.amber.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomShopTab(QuestTheme theme, int gold) {
    final items = _controller.customRewards;
    if (items.isEmpty) {
      return Center(
        child: Text(
          context.tr('shop.empty'),
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 92),
      itemBuilder: (context, i) {
        final r = items[i];
        final canBuy = gold >= r.cost;
        final busy = _controller.isRedeeming(r.id);
        final deleting = _controller.isDeleting(r.id);
        return _buildRewardCard(
          theme: theme,
          reward: r,
          subtitle: '${r.cost} ${context.tr('shop.gold_unit')}',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed:
                    (!canBuy || busy || deleting) ? null : () => _redeem(r),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      canBuy ? theme.primaryAccentColor : AppColors.textHint,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(context.tr('shop.buy_btn')),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: deleting ? null : () => _deleteReward(r),
                icon: deleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                      ),
              ),
            ],
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: items.length,
    );
  }

  Widget _buildRewardCard({
    required QuestTheme theme,
    required Reward reward,
    required String subtitle,
    required Widget trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.shadowColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ListTile(
        leading: const Icon(Icons.card_giftcard_rounded, color: Colors.amber),
        title: Text(
          reward.title.isEmpty ? context.tr('shop.unnamed') : reward.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.heading2.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        trailing: trailing,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<QuestTheme>()!;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          context.tr('shop.title'),
          style:
              AppTextStyles.heading1.copyWith(color: theme.primaryAccentColor),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.backpack_rounded),
            color: AppColors.textSecondary,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    InventoryPage(questController: widget.questController),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            color: AppColors.textSecondary,
            onPressed: _controller.loadRewards,
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: theme.primaryAccentColor,
        foregroundColor: Colors.white,
        tooltip: context.tr('shop.add_reward'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onPressed: _openAddReward,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          context.tr('shop.add_reward'),
          style: AppTextStyles.body.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([_controller, widget.questController]),
        builder: (context, _) {
          final gold = widget.questController.currentGold;

          return Column(
            children: [
              _buildBalanceCard(theme, gold),
              Expanded(
                child: _controller.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildCustomShopTab(theme, gold),
              ),
            ],
          );
        },
      ),
    );
  }
}
