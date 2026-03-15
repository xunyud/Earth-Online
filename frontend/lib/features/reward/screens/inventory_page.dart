import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/i18n/app_locale_controller.dart';
import '../../../core/theme/quest_theme.dart';
import '../../quest/controllers/quest_controller.dart';
import '../controllers/reward_controller.dart';
import '../models/inventory_item.dart';

class InventoryPage extends StatefulWidget {
  final QuestController questController;

  const InventoryPage({super.key, required this.questController});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  late final RewardController _controller;

  static const _effectIcons = <String, (IconData, Color)>{
    'xp_boost': (Icons.bolt_rounded, Color(0xFFFFA726)),
    'confetti_style': (Icons.celebration_rounded, Color(0xFFEF5350)),
    'streak_protect': (Icons.shield_moon_rounded, Color(0xFF42A5F5)),
    'theme_unlock': (Icons.palette_rounded, Color(0xFF2E7D32)),
    'card_border': (Icons.crop_square_rounded, Color(0xFFFFD54F)),
    'complete_effect': (Icons.auto_awesome_rounded, Color(0xFF66BB6A)),
  };

  @override
  void initState() {
    super.initState();
    _controller = RewardController(quest: widget.questController);
    WidgetsBinding.instance.addPostFrameCallback((_) {
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

  Future<void> _use(InventoryItem item) async {
    try {
      await _controller.useItem(item);
      if (!mounted) return;
      if (item.effectType != null) {
        _toast(context.tr('inventory.used'), background: Colors.green.shade700);
      } else {
        _toast(
          context
              .tr('inventory.used_custom', params: {'title': item.rewardTitle}),
          background: Colors.green.shade700,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _toast(e.toString());
    }
  }

  Future<void> _toggleEquip(InventoryItem item) async {
    try {
      await _controller.toggleEquip(item);
      if (!mounted) return;
      _toast(
        item.isEquipped
            ? context.tr(
                'inventory.unequipped_toast',
                params: {'title': item.rewardTitle},
              )
            : context.tr(
                'inventory.equipped_toast',
                params: {'title': item.rewardTitle},
              ),
        background: Colors.green.shade700,
      );
    } catch (e) {
      if (!mounted) return;
      _toast(e.toString());
    }
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: AppTextStyles.heading2.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(InventoryItem item, QuestTheme theme,
      {required bool canUse}) {
    final busy = _controller.isUsing(item.id);
    final meta = _effectIcons[item.effectType];
    final iconData = meta?.$1 ?? Icons.inventory_2_rounded;
    final iconColor = meta?.$2 ?? Colors.amber;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(iconData, size: 22, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.rewardTitle,
                    style: AppTextStyles.heading2.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (item.effectType != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _effectLabel(item.effectType!, item.effectValue),
                        style: AppTextStyles.caption.copyWith(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            if (canUse)
              SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: busy ? null : () => _use(item),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          context.tr('inventory.use'),
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              )
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  context.tr('inventory.active'),
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipCard(InventoryItem item, QuestTheme theme,
      {required bool isEquipped}) {
    final busy = _controller.isUsing(item.id);
    final meta = _effectIcons[item.effectType];
    final iconData = meta?.$1 ?? Icons.inventory_2_rounded;
    final iconColor = meta?.$2 ?? Colors.amber;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isEquipped
                    ? iconColor.withAlpha(30)
                    : AppColors.textHint.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                iconData,
                size: 22,
                color: isEquipped ? iconColor : AppColors.textHint,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.rewardTitle,
                    style: AppTextStyles.heading2.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isEquipped ? null : AppColors.textHint,
                    ),
                  ),
                  if (item.effectType != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _effectLabel(item.effectType!, item.effectValue),
                        style: AppTextStyles.caption.copyWith(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 32,
              child: ElevatedButton(
                onPressed: busy ? null : () => _toggleEquip(item),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isEquipped
                      ? Colors.grey.shade600
                      : Colors.lightBlue.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        isEquipped
                            ? context.tr('inventory.unequip')
                            : context.tr('inventory.equip'),
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _effectLabel(String type, String? value) {
    final english = context.isEnglish;
    switch (type) {
      case 'xp_boost':
        return english
            ? 'XP ${value ?? "2.0"}x Boost'
            : 'XP ${value ?? "2.0"}x 加成';
      case 'confetti_style':
        return english
            ? 'Completion FX: ${value ?? "fireworks"}'
            : '完成特效：${value ?? "fireworks"}';
      case 'streak_protect':
        return english
            ? 'Streak Protect (${value ?? "1"} use)'
            : '断签保护（${value ?? "1"} 次）';
      case 'theme_unlock':
        return english ? 'Theme: ${value ?? ""}' : '主题：${value ?? ""}';
      case 'card_border':
        return english ? 'Border: ${value ?? ""}' : '边框：${value ?? ""}';
      case 'complete_effect':
        return english
            ? 'Completion Animation: ${value ?? ""}'
            : '完成动画：${value ?? ""}';
      default:
        return type;
    }
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
          context.tr('inventory.title'),
          style:
              AppTextStyles.heading1.copyWith(color: theme.primaryAccentColor),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            color: AppColors.textSecondary,
            onPressed: _controller.loadInventory,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.isInventoryLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final usable = _controller.usableItems;
          final equipped = _controller.equippedItems;
          final unequipped = _controller.unequippedItems;
          final custom = _controller.customItems;

          if (usable.isEmpty &&
              equipped.isEmpty &&
              unequipped.isEmpty &&
              custom.isEmpty) {
            return Center(
              child: Text(
                context.tr('inventory.empty'),
                style:
                    AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
            );
          }

          final sections = <Widget>[];

          if (usable.isNotEmpty) {
            sections.add(
              _buildSectionHeader(
                context.tr('inventory.section.usable'),
                Icons.flash_on_rounded,
                const Color(0xFFFFA726),
              ),
            );
            for (final item in usable) {
              sections.add(_buildItemCard(item, theme, canUse: true));
            }
          }

          if (equipped.isNotEmpty) {
            sections.add(
              _buildSectionHeader(
                context.tr('inventory.section.equipped'),
                Icons.auto_awesome_rounded,
                const Color(0xFF42A5F5),
              ),
            );
            for (final item in equipped) {
              sections.add(_buildEquipCard(item, theme, isEquipped: true));
            }
          }

          if (unequipped.isNotEmpty) {
            sections.add(
              _buildSectionHeader(
                context.tr('inventory.section.unequipped'),
                Icons.inventory_2_rounded,
                AppColors.textHint,
              ),
            );
            for (final item in unequipped) {
              sections.add(_buildEquipCard(item, theme, isEquipped: false));
            }
          }

          if (custom.isNotEmpty) {
            sections.add(
              _buildSectionHeader(
                context.tr('inventory.section.custom'),
                Icons.card_giftcard_rounded,
                Colors.amber,
              ),
            );
            for (final item in custom) {
              sections.add(_buildItemCard(item, theme, canUse: true));
            }
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            children: sections,
          );
        },
      ),
    );
  }
}
