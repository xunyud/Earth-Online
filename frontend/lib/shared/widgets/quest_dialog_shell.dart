import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/theme/quest_theme.dart';

Future<T?> showQuestDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  String barrierLabel = 'quest_dialog',
  Color? barrierColor,
  Duration transitionDuration = const Duration(milliseconds: 240),
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierLabel: barrierLabel,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor ?? Colors.black.withAlpha(132),
    transitionDuration: transitionDuration,
    pageBuilder: (dialogContext, _, __) => SafeArea(
      child: Material(
        color: Colors.transparent,
        child: Builder(builder: builder),
      ),
    ),
    transitionBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

class QuestDialogShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final Widget? leading;
  final VoidCallback? onClose;
  final double maxWidth;
  final double? maxHeight;
  final bool scrollable;
  final Color? accentColor;
  final EdgeInsetsGeometry contentPadding;

  const QuestDialogShell({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const <Widget>[],
    this.leading,
    this.onClose,
    this.maxWidth = 720,
    this.maxHeight,
    this.scrollable = false,
    this.accentColor,
    this.contentPadding = const EdgeInsets.fromLTRB(24, 18, 24, 22),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<QuestTheme>() ??
        QuestTheme.forestAdventure();
    final accent = accentColor ?? theme.primaryAccentColor;
    final viewport = MediaQuery.sizeOf(context);
    final resolvedMaxHeight = maxHeight ?? viewport.height * 0.86;
    final shellGradientStart =
        Color.lerp(theme.surfaceColor, const Color(0xFFFFF8E7), 0.58)!;
    final shellGradientEnd = Color.lerp(theme.surfaceColor, accent, 0.08)!;
    final headerGradientStart =
        Color.lerp(theme.surfaceColor, accent, 0.16)!.withAlpha(240);
    final headerGradientEnd =
        Color.lerp(theme.backgroundColor, const Color(0xFFFFF2D8), 0.74)!;

    final body = Padding(
      padding: contentPadding,
      child: child,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: resolvedMaxHeight,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [shellGradientStart, shellGradientEnd],
            ),
            border: Border.all(color: accent.withAlpha(34)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(42),
                blurRadius: 34,
                offset: const Offset(0, 22),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [headerGradientStart, headerGradientEnd],
                    ),
                    border: Border.all(color: accent.withAlpha(24)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (leading != null) ...[
                        leading!,
                        const SizedBox(width: 16),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: AppTextStyles.heading1.copyWith(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF203222),
                              ),
                            ),
                            if (subtitle != null &&
                                subtitle!.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                subtitle!,
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (onClose != null)
                        IconButton(
                          onPressed: onClose,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withAlpha(164),
                            foregroundColor: const Color(0xFF304532),
                            fixedSize: const Size(42, 42),
                          ),
                          icon: const Icon(Icons.close_rounded),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (scrollable)
                  Flexible(
                    child: SingleChildScrollView(child: body),
                  )
                else
                  body,
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.end,
                      children: actions,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class QuestDialogBadge extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final double size;
  final Color? accentColor;

  const QuestDialogBadge({
    super.key,
    this.icon,
    this.label,
    this.size = 72,
    this.accentColor,
  }) : assert(icon != null || label != null);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<QuestTheme>() ??
        QuestTheme.forestAdventure();
    final accent = accentColor ?? theme.primaryAccentColor;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(accent, Colors.black, 0.16)!,
            accent,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withAlpha(70),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Center(
        child: icon != null
            ? Icon(icon, color: Colors.white, size: size * 0.42)
            : Text(
                label!,
                style: AppTextStyles.heading1.copyWith(
                  color: Colors.white,
                  fontSize: size * 0.42,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}

class QuestDialogInfoCard extends StatelessWidget {
  final Widget child;
  final String? label;
  final IconData? icon;
  final Color? accentColor;
  final EdgeInsetsGeometry padding;

  const QuestDialogInfoCard({
    super.key,
    required this.child,
    this.label,
    this.icon,
    this.accentColor,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<QuestTheme>() ??
        QuestTheme.forestAdventure();
    final accent = accentColor ?? theme.primaryAccentColor;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Color.lerp(theme.backgroundColor, accent, 0.08)!.withAlpha(236),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((label != null && label!.trim().isNotEmpty) || icon != null) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 16,
                    color: accent,
                  ),
                  const SizedBox(width: 8),
                ],
                if (label != null)
                  Text(
                    label!,
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

class QuestDialogSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const QuestDialogSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<QuestTheme>() ??
        QuestTheme.forestAdventure();
    final style = OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF355537),
      side: BorderSide(color: theme.primaryAccentColor.withAlpha(48)),
      backgroundColor: Colors.white.withAlpha(172),
      minimumSize: const Size(112, 52),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      textStyle: AppTextStyles.body.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
    );
    if (icon == null) {
      return OutlinedButton(
        onPressed: onPressed,
        style: style,
        child: Text(label),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: style,
    );
  }
}

class QuestDialogPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool danger;

  const QuestDialogPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<QuestTheme>() ??
        QuestTheme.forestAdventure();
    final backgroundColor =
        danger ? const Color(0xFFF45D57) : theme.primaryAccentColor;
    final style = FilledButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: Colors.white,
      minimumSize: const Size(128, 54),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      textStyle: AppTextStyles.body.copyWith(
        fontWeight: FontWeight.w800,
        fontSize: 16,
        color: Colors.white,
      ),
    );
    if (icon == null) {
      return FilledButton(
        onPressed: onPressed,
        style: style,
        child: Text(label),
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: style,
    );
  }
}
