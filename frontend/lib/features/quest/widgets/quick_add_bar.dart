import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/i18n/app_locale_controller.dart';
import '../../../core/theme/quest_theme.dart';

class QuickAddBar extends StatefulWidget {
  final Function(String) onSubmitted;
  final bool isLoading;

  const QuickAddBar({
    Key? key,
    required this.onSubmitted,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<QuickAddBar> createState() => _QuickAddBarState();
}

class _QuickAddBarState extends State<QuickAddBar>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _glowAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _focusNode.addListener(() {
      final hasFocus = _focusNode.hasFocus;
      if (hasFocus) {
        _glowController.repeat(reverse: true);
      } else {
        _glowController.stop();
        _glowController.value = 0;
      }
      setState(() => _isFocused = hasFocus);
    });
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _glowController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final text = _controller.text;
    if (text.isNotEmpty) {
      widget.onSubmitted(text);
      _controller.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<QuestTheme>()!;
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, _) {
        final glow = _isFocused ? _glowAnimation.value : 0.0;
        return Container(
          margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
          decoration: BoxDecoration(
            color: theme.surfaceColor,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: _isFocused
                  ? Color.lerp(
                      theme.primaryAccentColor.withAlpha(80),
                      theme.primaryAccentColor,
                      glow,
                    )!
                  : AppColors.textHint.withAlpha(45),
              width: _isFocused ? 1.6 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowColor,
                offset: const Offset(0, 8),
                blurRadius: _isFocused ? 26 : 20,
                spreadRadius: 0,
              ),
              if (_isFocused)
                BoxShadow(
                  color: theme.primaryAccentColor.withValues(
                    alpha: 0.18 + 0.14 * glow,
                  ),
                  blurRadius: 14.0 + 10.0 * glow,
                  spreadRadius: 1.0 + 1.2 * glow,
                ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: !widget.isLoading,
                    style: AppTextStyles.body,
                    decoration: InputDecoration(
                      hintText: context.tr('quick_add.hint'),
                      hintStyle: AppTextStyles.caption.copyWith(
                        color: AppColors.textHint,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    onSubmitted: (_) => _handleSubmit(),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: widget.isLoading || _controller.text.isEmpty
                        ? Colors.transparent
                        : theme.primaryAccentColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: widget.isLoading ? null : _handleSubmit,
                    icon: widget.isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.primaryAccentColor,
                              ),
                            ),
                          )
                        : const Icon(Icons.arrow_upward_rounded),
                    color: widget.isLoading || _controller.text.isEmpty
                        ? AppColors.textHint
                        : AppColors.pureWhite,
                    tooltip: context.tr('common.send'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
