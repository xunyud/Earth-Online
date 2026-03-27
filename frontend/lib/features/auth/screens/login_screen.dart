import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/i18n/app_locale_controller.dart';
import '../../../core/services/supabase_auth_service.dart';
import '../../../core/theme/quest_theme.dart';
import '../widgets/soft_auth_background.dart';

enum _AuthMode { signIn, signUp }

class LoginScreen extends StatefulWidget {
  final WidgetBuilder homeBuilder;

  const LoginScreen({super.key, required this.homeBuilder});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  _AuthMode _authMode = _AuthMode.signIn;
  bool _otpSent = false;
  bool _submitting = false;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  late final AnimationController _introController;
  late final Animation<double> _panelFade;
  late final Animation<double> _panelScale;
  late final Animation<double> _heroFade;
  late final Animation<Offset> _panelSlide;

  bool get _isRegisterMode => _authMode == _AuthMode.signUp;

  _AuthCopy get _copy => _AuthCopy(
        isEnglish: AppLocaleController.instance.isEnglish,
        isRegisterMode: _isRegisterMode,
      );

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 920),
    )..forward();
    _panelFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );
    _panelScale = Tween<double>(
      begin: 0.95,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.18, 0.82, curve: Curves.easeOutCubic),
      ),
    );
    _panelSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.08, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    _heroFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.18, 1, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _introController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final value = email.trim();
    if (value.isEmpty) return false;
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  }

  void _resetOtpState() {
    _resendTimer?.cancel();
    _otpSent = false;
    _resendSeconds = 0;
    _otpController.clear();
  }

  void _switchAuthMode(_AuthMode mode) {
    if (_submitting || _authMode == mode) return;
    setState(() {
      _authMode = mode;
      _resetOtpState();
    });
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF355B38),
          content: Text(message),
        ),
      );
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
        return;
      }
      setState(() => _resendSeconds -= 1);
    });
  }

  Future<void> _sendOtp() async {
    final copy = _copy;
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      _showMessage(copy.invalidEmail);
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await SupabaseAuthService.instance.sendOtp(email);
      if (!mounted) return;
      setState(() => _otpSent = true);
      _startResendCountdown();
      _showMessage(copy.codeSentMessage);
    } catch (e) {
      if (!mounted) return;
      _showMessage(copy.sendCodeFailed(e));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _verifyOtp() async {
    final copy = _copy;
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    if (!_isValidEmail(email)) {
      _showMessage(copy.invalidEmail);
      return;
    }
    if (otp.length != 6 || int.tryParse(otp) == null) {
      _showMessage(copy.invalidCode);
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await SupabaseAuthService.instance.verifyOtp(
        email: email,
        otp: otp,
        isSignUp: _authMode == _AuthMode.signUp,
      );
      if (!mounted) return;
      _showMessage(copy.verifySuccessMessage);
    } catch (_) {
      if (!mounted) return;
      _showMessage(copy.verifyFailedMessage);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _signInAnonymously() async {
    final copy = _copy;
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await SupabaseAuthService.instance.signInAnonymously();
      if (!mounted) return;
      _showMessage(copy.guestSuccessMessage);
    } catch (e) {
      if (!mounted) return;
      _showMessage(copy.guestFailedMessage(e));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final questTheme = Theme.of(context).extension<QuestTheme>() ??
        QuestTheme.forestAdventure();
    final canEditEmail = !_otpSent && !_submitting;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: SoftAuthBackground(
              accentColor: questTheme.primaryAccentColor,
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: FadeTransition(
                  opacity: _panelFade,
                  child: SlideTransition(
                    position: _panelSlide,
                    child: ScaleTransition(
                      scale: _panelScale,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: AnimatedBuilder(
                          animation: AppLocaleController.instance,
                          builder: (context, _) {
                            return _LoginPanel(
                              theme: questTheme,
                              heroAnimation: _heroFade,
                              authMode: _authMode,
                              canEditEmail: canEditEmail,
                              otpSent: _otpSent,
                              submitting: _submitting,
                              resendSeconds: _resendSeconds,
                              emailController: _emailController,
                              otpController: _otpController,
                              onModeChanged: _switchAuthMode,
                              onSendOtp: _sendOtp,
                              onVerifyOtp: _verifyOtp,
                              onAnonymous: _signInAnonymously,
                              onResetOtp: _submitting
                                  ? null
                                  : () {
                                      setState(_resetOtpState);
                                    },
                            );
                          },
                        ),
                      ),
                    ),
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

class _LoginPanel extends StatelessWidget {
  final QuestTheme theme;
  final Animation<double> heroAnimation;
  final _AuthMode authMode;
  final bool canEditEmail;
  final bool otpSent;
  final bool submitting;
  final int resendSeconds;
  final TextEditingController emailController;
  final TextEditingController otpController;
  final ValueChanged<_AuthMode> onModeChanged;
  final VoidCallback onSendOtp;
  final VoidCallback onVerifyOtp;
  final VoidCallback onAnonymous;
  final VoidCallback? onResetOtp;

  const _LoginPanel({
    required this.theme,
    required this.heroAnimation,
    required this.authMode,
    required this.canEditEmail,
    required this.otpSent,
    required this.submitting,
    required this.resendSeconds,
    required this.emailController,
    required this.otpController,
    required this.onModeChanged,
    required this.onSendOtp,
    required this.onVerifyOtp,
    required this.onAnonymous,
    required this.onResetOtp,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = theme.primaryAccentColor;
    final isRegisterMode = authMode == _AuthMode.signUp;
    final copy = _AuthCopy(
      isEnglish: AppLocaleController.instance.isEnglish,
      isRegisterMode: isRegisterMode,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(202),
            borderRadius: BorderRadius.circular(34),
            border: Border.all(
              color: primaryColor.withAlpha(40),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 38,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFFFFCF7),
                      const Color(0xFFF6F3E8),
                      primaryColor.withAlpha(14),
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: primaryColor.withAlpha(24),
                    ),
                  ),
                ),
                child: FadeTransition(
                  opacity: heroAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _BrandMark(accentColor: primaryColor),
                          const Spacer(),
                          _LanguageToggle(
                            accentColor: primaryColor,
                            isEnglish: copy.isEnglish,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        copy.welcomeTitle,
                        style: AppTextStyles.heading1.copyWith(
                          fontSize: 29,
                          height: 1.18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF395D3E),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AuthModeToggle(
                      selectedMode: authMode,
                      accentColor: primaryColor,
                      enabled: !submitting,
                      signInLabel: copy.signInLabel,
                      signUpLabel: copy.signUpLabel,
                      onSelected: onModeChanged,
                    ),
                    const SizedBox(height: 18),
                    _StyledInput(
                      controller: emailController,
                      enabled: canEditEmail,
                      labelText: copy.emailLabel,
                      hintText: copy.emailHint,
                      prefixIcon: Icons.alternate_email_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 410;
                        final codeField = _StyledInput(
                          controller: otpController,
                          enabled: !submitting,
                          labelText: copy.codeLabel,
                          hintText: copy.codeHint,
                          prefixIcon: Icons.password_rounded,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          maxLength: 6,
                        );
                        final sendButton = SizedBox(
                          height: 56,
                          child: OutlinedButton(
                            onPressed: submitting || resendSeconds > 0
                                ? null
                                : onSendOtp,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: primaryColor.withAlpha(110),
                              ),
                              foregroundColor: primaryColor,
                              backgroundColor: Colors.white.withAlpha(156),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: Text(
                              copy.sendButtonLabel(resendSeconds),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                height: 1.2,
                              ),
                            ),
                          ),
                        );

                        if (compact) {
                          return Column(
                            children: [
                              codeField,
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: sendButton,
                              ),
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: codeField),
                            const SizedBox(width: 12),
                            SizedBox(width: 132, child: sendButton),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F8F2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: primaryColor.withAlpha(26),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.mark_email_unread_rounded,
                            size: 16,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              copy.otpPrompt(otpSent),
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 12.5,
                                height: 1.45,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _AnimatedPrimaryButton(
                      accentColor: primaryColor,
                      enabled: !submitting && otpSent,
                      label: copy.primaryButtonLabel,
                      onPressed: submitting || !otpSent ? null : onVerifyOtp,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: submitting ? null : onAnonymous,
                          icon: const Icon(Icons.explore_outlined, size: 18),
                          label: Text(copy.exploreLabel),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                          ),
                        ),
                        if (otpSent)
                          TextButton.icon(
                            onPressed: onResetOtp,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: Text(copy.editEmailLabel),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthModeToggle extends StatelessWidget {
  final _AuthMode selectedMode;
  final Color accentColor;
  final bool enabled;
  final String signInLabel;
  final String signUpLabel;
  final ValueChanged<_AuthMode> onSelected;

  const _AuthModeToggle({
    required this.selectedMode,
    required this.accentColor,
    required this.enabled,
    required this.signInLabel,
    required this.signUpLabel,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7).withAlpha(220),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accentColor.withAlpha(36)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AuthModeButton(
              label: signInLabel,
              selected: selectedMode == _AuthMode.signIn,
              accentColor: accentColor,
              enabled: enabled,
              onTap: () => onSelected(_AuthMode.signIn),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _AuthModeButton(
              label: signUpLabel,
              selected: selectedMode == _AuthMode.signUp,
              accentColor: accentColor,
              enabled: enabled,
              onTap: () => onSelected(_AuthMode.signUp),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accentColor;
  final bool enabled;
  final VoidCallback onTap;

  const _AuthModeButton({
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? accentColor : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: accentColor.withAlpha(26),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : const Color(0xFF48624B),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  final Color accentColor;
  final bool isEnglish;

  const _LanguageToggle({
    required this.accentColor,
    required this.isEnglish,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(188),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accentColor.withAlpha(34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LanguageChip(
            label: '中文',
            selected: !isEnglish,
            accentColor: accentColor,
            onTap: () {
              unawaited(AppLocaleController.instance.setLanguageCode('zh'));
            },
          ),
          const SizedBox(width: 4),
          _LanguageChip(
            label: 'English',
            selected: isEnglish,
            accentColor: accentColor,
            onTap: () {
              unawaited(AppLocaleController.instance.setLanguageCode('en'));
            },
          ),
        ],
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _LanguageChip({
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: selected ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? accentColor : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF4D6650),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  final Color accentColor;

  const _BrandMark({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(196),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withAlpha(32)),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.public_rounded,
            color: accentColor,
            size: 28,
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBF5),
                shape: BoxShape.circle,
                border: Border.all(color: accentColor.withAlpha(30)),
              ),
              child: Icon(
                Icons.check_rounded,
                size: 10,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StyledInput extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final String labelText;
  final String hintText;
  final IconData prefixIcon;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final int? maxLength;

  const _StyledInput({
    required this.controller,
    required this.labelText,
    required this.hintText,
    required this.prefixIcon,
    required this.keyboardType,
    required this.textInputAction,
    this.enabled = true,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        counterText: '',
        filled: true,
        fillColor: Colors.white.withAlpha(176),
        prefixIcon: Icon(prefixIcon, color: const Color(0xFF4C8A52)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0x704C8A52)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFF2F7B35),
            width: 1.6,
          ),
        ),
      ),
    );
  }
}

class _AnimatedPrimaryButton extends StatelessWidget {
  final Color accentColor;
  final bool enabled;
  final String label;
  final VoidCallback? onPressed;

  const _AnimatedPrimaryButton({
    required this.accentColor,
    required this.enabled,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: accentColor.withAlpha(44),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          disabledBackgroundColor: accentColor.withAlpha(70),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white.withAlpha(190),
          minimumSize: const Size.fromHeight(56),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class _AuthCopy {
  final bool isEnglish;
  final bool isRegisterMode;

  const _AuthCopy({
    required this.isEnglish,
    required this.isRegisterMode,
  });

  String get welcomeTitle =>
      isEnglish ? 'Welcome to Earth Online' : '欢迎来到地球Online';

  String get signInLabel => isEnglish ? 'Sign in' : '登录';

  String get signUpLabel => isEnglish ? 'Sign up' : '注册';

  String get emailLabel => isEnglish ? 'Email' : '邮箱地址';

  String get emailHint => 'you@example.com';

  String sendButtonLabel(int resendSeconds) {
    if (resendSeconds > 0) {
      return isEnglish
          ? 'Resend\n${resendSeconds}s'
          : '重新发送\n${resendSeconds}s';
    }
    return isEnglish ? 'Send code' : '发送验证码';
  }

  String otpPrompt(bool otpSent) {
    if (isEnglish) {
      if (!otpSent) {
        return isRegisterMode
            ? 'Send the sign-up code first, then enter 6 digits to create your account.'
            : 'Send the code first, then enter 6 digits to continue.';
      }
      return isRegisterMode
          ? 'Sign-up code sent. Enter 6 digits to create your account.'
          : 'Code sent. Enter 6 digits to continue.';
    }
    if (!otpSent) {
      return isRegisterMode ? '先发送注册码，再输入6位数字完成注册。' : '先发送验证码，再输入6位数字继续登录。';
    }
    return isRegisterMode ? '注册码已发送，请输入6位数字完成注册。' : '验证码已发送，请输入6位数字继续登录。';
  }

  String get codeLabel => isEnglish ? '6-digit code' : '6位验证码';

  String get codeHint =>
      isEnglish ? 'Enter the code from your inbox' : '输入邮箱里的验证码';

  String get primaryButtonLabel {
    if (isRegisterMode) {
      return isEnglish ? 'Create account' : '创建账号';
    }
    return isEnglish ? 'Continue' : '继续登录';
  }

  String get exploreLabel => isEnglish ? 'Explore first' : '先随便看看';

  String get editEmailLabel => isEnglish ? 'Edit email' : '修改邮箱';

  String get invalidEmail =>
      isEnglish ? 'Enter a valid email address.' : '请输入正确的邮箱地址';

  String get invalidCode => isEnglish ? 'Enter the 6-digit code.' : '请输入6位验证码';

  String get codeSentMessage {
    if (isEnglish) {
      return isRegisterMode
          ? 'Sign-up code sent. Check your inbox.'
          : 'Code sent. Check your inbox.';
    }
    return isRegisterMode ? '注册码已发送，请检查你的邮箱。' : '验证码已发送，请检查你的邮箱。';
  }

  String sendCodeFailed(Object error) {
    if (isEnglish) {
      return isRegisterMode
          ? 'Could not send the sign-up code: $error'
          : 'Could not send the code: $error';
    }
    return isRegisterMode ? '发送注册码失败：$error' : '发送验证码失败：$error';
  }

  String get verifySuccessMessage {
    if (isEnglish) {
      return isRegisterMode ? 'Account created.' : 'Signed in.';
    }
    return isRegisterMode ? '账号创建完成。' : '登录成功。';
  }

  String get verifyFailedMessage =>
      isEnglish ? 'The code is invalid or expired.' : '验证码错误或已过期。';

  String get guestSuccessMessage =>
      isEnglish ? 'Guest mode started.' : '已进入访客模式。';

  String guestFailedMessage(Object error) =>
      isEnglish ? 'Could not start guest mode: $error' : '开启访客模式失败：$error';
}
