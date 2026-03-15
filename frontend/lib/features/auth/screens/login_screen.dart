import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/supabase_auth_service.dart';
import '../../../core/theme/quest_theme.dart';
import '../widgets/forest_particles.dart';
import '../widgets/parallax_background.dart';

enum _AuthMode { signIn, signUp }

class LoginScreen extends StatefulWidget {
  final WidgetBuilder homeBuilder;

  const LoginScreen({super.key, required this.homeBuilder});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  _AuthMode _authMode = _AuthMode.signIn;
  bool _otpSent = false;
  bool _submitting = false;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  late final AnimationController _introController;
  late final AnimationController _ambientController;
  late final Animation<double> _panelFade;
  late final Animation<double> _panelScale;
  late final Animation<double> _heroFade;
  late final Animation<Offset> _panelSlide;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 980),
    )..forward();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    _panelFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );
    _panelScale = Tween<double>(
      begin: 0.94,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.18, 0.78, curve: Curves.easeOutCubic),
      ),
    );
    _panelSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.1, 0.82, curve: Curves.easeOutCubic),
      ),
    );
    _heroFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.24, 1, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _introController.dispose();
    _ambientController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final value = email.trim();
    if (value.isEmpty) return false;
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  }

  bool get _isRegisterMode => _authMode == _AuthMode.signUp;

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
          backgroundColor: const Color(0xFF345D35),
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
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      _showMessage('请输入正确的邮箱地址');
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await SupabaseAuthService.instance.sendOtp(email);
      if (!mounted) return;
      setState(() => _otpSent = true);
      _startResendCountdown();
      _showMessage(
        _isRegisterMode ? '注册验证码已发送，请检查你的邮箱。' : '验证码已发送，请检查你的邮箱。',
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(
        _isRegisterMode ? '发送注册验证码失败：$e' : '发送验证码失败：$e',
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _verifyOtp() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    if (!_isValidEmail(email)) {
      _showMessage('请输入正确的邮箱地址');
      return;
    }
    if (otp.length != 6 || int.tryParse(otp) == null) {
      _showMessage('请输入 6 位数字验证码');
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await SupabaseAuthService.instance.verifyOtp(email: email, otp: otp);
      if (!mounted) return;
      _showMessage(
        _isRegisterMode ? '注册成功，欢迎来到任务森林。' : '登录成功，欢迎回到任务森林。',
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage('验证码错误或已过期，请重新尝试。');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _signInAnonymously() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await SupabaseAuthService.instance.signInAnonymously();
      if (!mounted) return;
      _showMessage('已进入匿名模式，先随便逛逛吧。');
    } catch (e) {
      if (!mounted) return;
      _showMessage('匿名登录失败：$e');
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
            child: Image.asset(
              'assets/images/backgrounds/forest/login_backdrop.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFF6F2DF),
                        Color(0xFFCDEBC7),
                        Color(0xFF78C784),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withAlpha(24),
                    const Color(0xFFE7F4D9).withAlpha(122),
                    const Color(0xFF8FD79C).withAlpha(78),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: _AnimatedForestGlow(
              animation: _ambientController,
              accentColor: questTheme.primaryAccentColor,
            ),
          ),
          const Positioned.fill(
            child: Opacity(
              opacity: 0.78,
              child: ParallaxBackground(
                autoScroll: true,
                scrollSpeed: 18,
                layers: <ParallaxLayer>[
                  ParallaxLayer(
                    assetPath: 'assets/images/backgrounds/forest/sky.png',
                    speed: 0,
                    fallbackColor: Color(0xFFF1F2D8),
                  ),
                  ParallaxLayer(
                    assetPath: 'assets/images/backgrounds/forest/far.png',
                    speed: 0.16,
                    fallbackColor: Color(0x7A7DAA72),
                  ),
                  ParallaxLayer(
                    assetPath: 'assets/images/backgrounds/forest/mid.png',
                    speed: 0.42,
                    fallbackColor: Color(0x88579B61),
                  ),
                  ParallaxLayer(
                    assetPath: 'assets/images/backgrounds/forest/near.png',
                    speed: 0.86,
                    fallbackColor: Color(0xAA3A6B3F),
                  ),
                ],
              ),
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: ForestParticles(enabled: true),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: FadeTransition(
                  opacity: _panelFade,
                  child: SlideTransition(
                    position: _panelSlide,
                    child: ScaleTransition(
                      scale: _panelScale,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 540),
                        child: AnimatedBuilder(
                          animation: _ambientController,
                          child: _LoginPanel(
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
                                    setState(() {
                                      _resetOtpState();
                                    });
                                  },
                          ),
                          builder: (context, child) {
                            final lift =
                                lerpDouble(-6, 8, _ambientController.value)!;
                            return Transform.translate(
                              offset: Offset(0, lift),
                              child: child,
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
    const secondaryColor = Color(0xFF6AA96B);
    final isRegisterMode = authMode == _AuthMode.signUp;
    final subtitle = isRegisterMode ? '创建你的现实副本' : '登录你的现实副本';
    final heroMailLabel = isRegisterMode ? '邮箱验证码注册' : '邮箱验证码登录';
    final introText = isRegisterMode
        ? '新邮箱会通过验证码创建账号，注册后就能开启今天的 Quest Log 节奏。'
        : '验证码会发送到你的邮箱，登录后就能继续今天的 Quest Log 节奏。';
    final sendButtonLabel = otpSent
        ? (resendSeconds > 0 ? '重新发送\n${resendSeconds}s' : '重新发送')
        : (isRegisterMode ? '发送注册验证码' : '发送验证码');
    final otpPrompt = isRegisterMode
        ? '注册验证码已发出，输入 6 位数字后就能创建你的现实副本。'
        : '验证码已发出，输入 6 位数字后就能继续进入任务板。';
    final primaryButtonLabel = submitting
        ? '请稍候...'
        : (otpSent
            ? (isRegisterMode ? '验证并创建账号' : '验证并登录')
            : (isRegisterMode ? '开始注册' : '继续登录'));

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(180),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: primaryColor.withAlpha(82),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(28),
                blurRadius: 34,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primaryColor.withAlpha(30),
                      const Color(0xFFF6F0D9),
                    ],
                  ),
                ),
                child: FadeTransition(
                  opacity: heroAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(170),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.shadowColor,
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.travel_explore_rounded,
                              color: primaryColor,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '地球 Online',
                                  style: AppTextStyles.heading1.copyWith(
                                    fontSize: 34,
                                    color: primaryColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  subtitle,
                                  style: AppTextStyles.body.copyWith(
                                    fontSize: 15,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          const _HeroChip(
                            icon: Icons.park_rounded,
                            label: '森林副本同步',
                            tint: Color(0xFFDCEFD8),
                          ),
                          _HeroChip(
                            icon: Icons.mail_outline_rounded,
                            label: heroMailLabel,
                            tint: const Color(0xFFE4F2E3),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AuthModeToggle(
                      selectedMode: authMode,
                      accentColor: primaryColor,
                      enabled: !submitting,
                      onSelected: onModeChanged,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      introText,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 430;
                        final emailField = _StyledInput(
                          controller: emailController,
                          enabled: canEditEmail,
                          labelText: '邮箱地址',
                          hintText: 'you@example.com',
                          prefixIcon: Icons.alternate_email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: otpSent
                              ? TextInputAction.done
                              : TextInputAction.next,
                        );
                        final sendButton = SizedBox(
                          height: 60,
                          child: OutlinedButton(
                            onPressed: submitting || resendSeconds > 0
                                ? null
                                : onSendOtp,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: primaryColor.withAlpha(128),
                              ),
                              foregroundColor: primaryColor,
                              backgroundColor: Colors.white.withAlpha(148),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: Text(
                              sendButtonLabel,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );

                        if (compact) {
                          return Column(
                            children: [
                              emailField,
                              const SizedBox(height: 12),
                              SizedBox(
                                  width: double.infinity, child: sendButton),
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: emailField),
                            const SizedBox(width: 12),
                            SizedBox(width: 146, child: sendButton),
                          ],
                        );
                      },
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: otpSent
                          ? Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Column(
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEAF6E3),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: secondaryColor.withAlpha(70),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.mark_email_read_rounded,
                                          size: 18,
                                          color: primaryColor,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            otpPrompt,
                                            style:
                                                AppTextStyles.caption.copyWith(
                                              fontSize: 13,
                                              height: 1.45,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _StyledInput(
                                    controller: otpController,
                                    labelText: '6 位验证码',
                                    hintText: '输入邮箱里的验证码',
                                    prefixIcon: Icons.password_rounded,
                                    keyboardType: TextInputType.number,
                                    textInputAction: TextInputAction.done,
                                    maxLength: 6,
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 18),
                    _AnimatedPrimaryButton(
                      accentColor: primaryColor,
                      enabled: !submitting,
                      label: primaryButtonLabel,
                      onPressed: submitting
                          ? null
                          : (otpSent ? onVerifyOtp : onSendOtp),
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
                          label: const Text('匿名试试看'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                          ),
                        ),
                        if (otpSent)
                          TextButton.icon(
                            onPressed: onResetOtp,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('返回修改邮箱'),
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
  final ValueChanged<_AuthMode> onSelected;

  const _AuthModeToggle({
    required this.selectedMode,
    required this.accentColor,
    required this.enabled,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(146),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accentColor.withAlpha(70)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AuthModeButton(
              label: '登录',
              selected: selectedMode == _AuthMode.signIn,
              accentColor: accentColor,
              enabled: enabled,
              onTap: () => onSelected(_AuthMode.signIn),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _AuthModeButton(
              label: '注册',
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
                  color: accentColor.withAlpha(46),
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
                color: selected ? Colors.white : const Color(0xFF355B39),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedForestGlow extends StatelessWidget {
  final Animation<double> animation;
  final Color accentColor;

  const _AnimatedForestGlow({
    required this.animation,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final driftingCenter = Alignment.lerp(
          const Alignment(-0.78, -0.85),
          const Alignment(0.88, 0.1),
          animation.value,
        )!;
        final counterCenter = Alignment.lerp(
          const Alignment(0.85, -0.55),
          const Alignment(-0.25, 0.75),
          animation.value,
        )!;
        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: driftingCenter,
                    radius: 0.86,
                    colors: const [
                      Color(0x77FFF6CF),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: counterCenter,
                    radius: 0.7,
                    colors: [
                      accentColor.withAlpha(38),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
        fillColor: Colors.white.withAlpha(182),
        prefixIcon: Icon(prefixIcon, color: const Color(0xFF4C8A52)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0x774C8A52)),
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
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.82, end: enabled ? 1 : 0.92),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: accentColor.withAlpha(enabled ? 68 : 24),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        );
      },
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(58),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
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

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color tint;

  const _HeroChip({
    required this.icon,
    required this.label,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(160)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF3A7442)),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF355B39),
            ),
          ),
        ],
      ),
    );
  }
}
