import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/binding/screens/binding_view.dart';
import '../../features/memory/screens/memory_page.dart';
import '../../features/profile/controllers/user_profile_controller.dart';
import '../../features/profile/services/profile_avatar_picker.dart';
import '../../features/quest/controllers/quest_controller.dart';
import '../../features/quest/screens/life_diary_page.dart';
import '../../features/quest/screens/recycle_bin_page.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../i18n/app_locale_controller.dart';
import '../theme/quest_theme.dart';
import '../utils/snackbar_utils.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/quest_dialog_shell.dart';

typedef AvatarPickerCallback = Future<String?> Function();

class AppDrawer extends StatefulWidget {
  final QuestController questController;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenGuide;
  final VoidCallback? onOpenTutorial;
  final String? userEmail;
  final UserProfileController? profileController;
  final AvatarPickerCallback? onPickAvatarBase64;

  const AppDrawer({
    super.key,
    required this.questController,
    required this.onOpenSettings,
    required this.onOpenGuide,
    this.onOpenTutorial,
    this.userEmail,
    this.profileController,
    this.onPickAvatarBase64,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  late final UserProfileController _profileController;
  late final bool _ownsProfileController;
  late final ProfileAvatarPicker _avatarPicker;

  bool _isPickingAvatar = false;

  @override
  void initState() {
    super.initState();
    _ownsProfileController = widget.profileController == null;
    _profileController = widget.profileController ??
        UserProfileController(email: _resolveCurrentUserEmail());
    _avatarPicker = const ProfileAvatarPicker();
    _profileController.load();
  }

  @override
  void dispose() {
    if (_ownsProfileController) {
      _profileController.dispose();
    }
    super.dispose();
  }

  String? _resolveCurrentUserEmail() {
    final configuredEmail = widget.userEmail?.trim();
    if (configuredEmail != null && configuredEmail.isNotEmpty) {
      return configuredEmail;
    }

    try {
      return Supabase.instance.client.auth.currentUser?.email?.trim();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final questTheme = Theme.of(context).extension<QuestTheme>()!;

    return Drawer(
      width: 300,
      child: Container(
        color: questTheme.surfaceColor,
        child: Column(
          children: [
            _buildUserHeader(context, questTheme),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 18),
                children: [
                  _buildMenuItem(
                    context,
                    questTheme: questTheme,
                    icon: Icons.menu_book_rounded,
                    title: context.tr('drawer.diary'),
                    subtitle: context.tr('drawer.diary.desc'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LifeDiaryPage(),
                        ),
                      );
                    },
                  ),
                  _buildMenuItem(
                    context,
                    questTheme: questTheme,
                    icon: Icons.memory_rounded,
                    title: context.tr('drawer.memory'),
                    subtitle: context.tr('drawer.memory.desc'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MemoryPage(),
                        ),
                      );
                    },
                  ),
                  _buildMenuItem(
                    context,
                    questTheme: questTheme,
                    icon: Icons.delete_outline_rounded,
                    title: context.tr('drawer.recycle'),
                    subtitle: context.tr('drawer.recycle.desc'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RecycleBinPage(
                            controller: widget.questController,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildMenuItem(
                    context,
                    questTheme: questTheme,
                    icon: Icons.smart_toy_rounded,
                    title: context.tr('drawer.guide'),
                    subtitle: context.tr('drawer.guide.desc'),
                    onTap: () {
                      Navigator.pop(context);
                      Future.microtask(widget.onOpenGuide);
                    },
                  ),
                  _buildMenuItem(
                    context,
                    questTheme: questTheme,
                    icon: Icons.link_rounded,
                    title: context.tr('drawer.binding'),
                    subtitle: context.tr('drawer.binding.desc'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BindingView(),
                        ),
                      );
                    },
                  ),
                  if (widget.onOpenTutorial != null)
                    _buildMenuItem(
                      context,
                      questTheme: questTheme,
                      icon: Icons.help_outline_rounded,
                      title: context.tr('drawer.tutorial'),
                      subtitle: context.tr('drawer.tutorial.desc'),
                      onTap: () {
                        Navigator.pop(context);
                        Future.microtask(widget.onOpenTutorial!);
                      },
                    ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(18, 18, 18, 10),
                    child: Divider(height: 1),
                  ),
                  _buildMenuItem(
                    context,
                    questTheme: questTheme,
                    icon: Icons.settings_rounded,
                    title: context.tr('drawer.settings'),
                    subtitle: context.tr('drawer.settings.desc'),
                    onTap: () {
                      Navigator.pop(context);
                      Future.microtask(widget.onOpenSettings);
                    },
                  ),
                  _buildMenuItem(
                    context,
                    questTheme: questTheme,
                    icon: Icons.logout_rounded,
                    title: context.tr('drawer.logout'),
                    subtitle: context.tr('drawer.logout.desc'),
                    iconColor: Colors.red.shade400,
                    onTap: () => _handleLogout(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserHeader(BuildContext context, QuestTheme questTheme) {
    final topPadding = MediaQuery.of(context).padding.top;

    return AnimatedBuilder(
      animation: _profileController,
      builder: (context, _) {
        final displayName = _profileController.displayName.isNotEmpty
            ? _profileController.displayName
            : context.tr('common.not_logged_in');
        final email = _profileController.email.isNotEmpty
            ? _profileController.email
            : context.tr('common.not_logged_in');
        final avatarBytes = _profileController.avatarBytes;

        return Container(
          padding: EdgeInsets.fromLTRB(20, topPadding + 20, 20, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                questTheme.primaryAccentColor.withValues(alpha: 0.94),
                questTheme.mainQuestColor.withValues(alpha: 0.92),
              ],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: questTheme.primaryAccentColor.withValues(alpha: 0.18),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -10,
                top: 8,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                left: 56,
                top: 62,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AvatarButton(
                        key: const Key('drawer-profile-avatar-button'),
                        avatarBytes: avatarBytes,
                        accentColor: questTheme.primaryAccentColor,
                        loading: _isPickingAvatar,
                        onTap: _handleAvatarChange,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    displayName,
                                    style: AppTextStyles.heading1.copyWith(
                                      color: Colors.white,
                                      fontSize: 24,
                                      height: 1.05,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              email,
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white.withValues(alpha: 0.86),
                                fontSize: 13,
                                height: 1.35,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _HeaderActionChip(
                                  key: const Key('drawer-profile-edit-name'),
                                  icon: Icons.edit_rounded,
                                  label: context.tr('drawer.profile.edit_name'),
                                  onTap: _promptDisplayName,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: ListenableBuilder(
                      listenable: widget.questController,
                      builder: (context, _) {
                        final totalXp = widget.questController.totalXp;
                        final levelProgress =
                            widget.questController.levelProgress;
                        final remainingXp = (levelProgress.nextLevelXp -
                                levelProgress.currentLevelXp)
                            .clamp(0, levelProgress.nextLevelXp);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Lv.${levelProgress.level}',
                                  style: AppTextStyles.heading2.copyWith(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '$totalXp XP',
                                  style: AppTextStyles.body.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: levelProgress.progress.clamp(0.0, 1.0),
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.24),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                                minHeight: 8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.tr(
                                'drawer.profile.progress_hint',
                                params: {'xp': '$remainingXp'},
                              ),
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required QuestTheme questTheme,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final resolvedIconColor = iconColor ?? questTheme.primaryAccentColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: resolvedIconColor.withValues(alpha: 0.14),
              ),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadowColor,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: resolvedIconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: resolvedIconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.heading2.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AppTextStyles.caption.copyWith(
                          height: 1.35,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textHint.withValues(alpha: 0.9),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _promptDisplayName() async {
    final editingController = TextEditingController(
      text: _profileController.displayName,
    );

    final currentName = _profileController.displayName.trim().isEmpty
        ? (widget.userEmail?.trim().isNotEmpty == true
            ? widget.userEmail!.trim()
            : 'Profile')
        : _profileController.displayName.trim();
    final nextName = await showQuestDialog<String>(
      context: context,
      barrierLabel: 'drawer_profile_name_dialog',
      builder: (dialogContext) => QuestDialogShell(
        title: context.tr('drawer.profile.name_title'),
        subtitle: context.tr('drawer.profile.name_hint'),
        maxWidth: 540,
        leading: QuestDialogBadge(label: currentName.characters.first),
        onClose: () => Navigator.pop(dialogContext),
        actions: [
          QuestDialogSecondaryButton(
            label: context.tr('common.cancel'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          QuestDialogPrimaryButton(
            label: context.tr('drawer.profile.name_action'),
            onPressed: () =>
                Navigator.pop(dialogContext, editingController.text),
          ),
        ],
        child: QuestDialogInfoCard(
          label: context.tr('drawer.profile.edit_name'),
          icon: Icons.edit_rounded,
          child: TextField(
            key: const Key('drawer-profile-name-input'),
            controller: editingController,
            autofocus: true,
            maxLength: 18,
            decoration: InputDecoration(
              hintText: context.tr('drawer.profile.name_hint'),
              filled: true,
              fillColor: Colors.white.withAlpha(170),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: Theme.of(dialogContext)
                      .extension<QuestTheme>()!
                      .primaryAccentColor
                      .withAlpha(34),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: Theme.of(dialogContext)
                      .extension<QuestTheme>()!
                      .primaryAccentColor
                      .withAlpha(34),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: Theme.of(dialogContext)
                      .extension<QuestTheme>()!
                      .primaryAccentColor,
                  width: 1.6,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (nextName == null) {
      return;
    }

    await _profileController.updateDisplayName(nextName);
    if (!mounted) {
      return;
    }
    showForestSnackBar(context, context.tr('drawer.profile.name_saved'));
  }

  Future<void> _handleAvatarChange() async {
    if (_isPickingAvatar) {
      return;
    }

    setState(() => _isPickingAvatar = true);

    try {
      final nextAvatarBase64 = await (widget.onPickAvatarBase64?.call() ??
          _avatarPicker.pickAvatarBase64());
      if (nextAvatarBase64 == null || nextAvatarBase64.trim().isEmpty) {
        return;
      }

      await _profileController.updateAvatarBase64(nextAvatarBase64);
      if (!mounted) {
        return;
      }
      showForestSnackBar(context, context.tr('drawer.profile.avatar_saved'));
    } catch (_) {
      if (!mounted) {
        return;
      }
      showForestSnackBar(context, context.tr('drawer.profile.avatar_failed'));
    } finally {
      if (mounted) {
        setState(() => _isPickingAvatar = false);
      }
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: context.tr('drawer.logout.title'),
      message: context.tr('drawer.logout.message'),
      confirmText: context.tr('drawer.logout.confirm'),
      cancelText: context.tr('common.cancel'),
      danger: true,
    );

    if (confirmed && context.mounted) {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    }
  }
}

class _AvatarButton extends StatelessWidget {
  final Uint8List? avatarBytes;
  final Color accentColor;
  final bool loading;
  final VoidCallback onTap;

  const _AvatarButton({
    super.key,
    required this.avatarBytes,
    required this.accentColor,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Ink(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: avatarBytes == null
                        ? Container(
                            color: Colors.white.withValues(alpha: 0.12),
                            child: const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 34,
                            ),
                          )
                        : Image.memory(
                            avatarBytes!,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: loading
                      ? Padding(
                          padding: const EdgeInsets.all(7),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              accentColor,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.camera_alt_rounded,
                          color: accentColor,
                          size: 16,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HeaderActionChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
