import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../../core/services/supabase_auth_service.dart';

/// 森林主题 WebView 登录页
///
/// 通过加载本地 HTML（含 Canvas 粒子、CSS 视差动画）实现 100% 视觉还原。
/// 使用 WebView2 虚拟主机映射直接从磁盘加载图片，避免 base64 内存溢出。
class ForestLoginPage extends StatefulWidget {
  final WidgetBuilder homeBuilder;

  const ForestLoginPage({super.key, required this.homeBuilder});

  @override
  State<ForestLoginPage> createState() => _ForestLoginPageState();
}

class _ForestLoginPageState extends State<ForestLoginPage> {
  final _controller = WebviewController();
  StreamSubscription? _msgSub;
  bool _ready = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  /// 获取 Flutter assets 在磁盘上的绝对路径
  String _getFlutterAssetsPath() {
    // Windows: <exe目录>/data/flutter_assets/
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    return '$exeDir\\data\\flutter_assets';
  }

  Future<void> _initWebView() async {
    try {
      await _controller.initialize();
      await _controller.setBackgroundColor(const Color(0xFF2A3A1E));

      // 将 Flutter assets 目录映射为虚拟主机，让 HTML 可通过 URL 访问图片
      final assetsPath = _getFlutterAssetsPath();
      await _controller.addVirtualHostNameMapping(
        'local.assets',
        assetsPath,
        WebviewHostResourceAccessKind.allow,
      );

      // 监听来自 JS 的 postMessage
      _msgSub = _controller.webMessage.listen(_onBridgeMessage);

      // 加载 HTML 模板，替换图片占位符为虚拟主机 URL
      String html = await rootBundle.loadString('assets/web/login.html');
      html = html
          .replaceAll('{{IMG_SKY}}',
              'https://local.assets/assets/images/backgrounds/forest/sky.png')
          .replaceAll('{{IMG_FAR}}',
              'https://local.assets/assets/images/backgrounds/forest/far.png')
          .replaceAll('{{IMG_MID}}',
              'https://local.assets/assets/images/backgrounds/forest/mid.png')
          .replaceAll('{{IMG_NEAR}}',
              'https://local.assets/assets/images/backgrounds/forest/near.png');

      await _controller.loadStringContent(html);
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      debugPrint('初始化 WebView 失败: $e');
      if (mounted) setState(() => _ready = true);
    }
  }

  /// 处理来自 JS postMessage 的消息
  void _onBridgeMessage(dynamic message) {
    try {
      final data = message is Map<String, dynamic>
          ? message
          : (message is String
              ? jsonDecode(message) as Map<String, dynamic>
              : <String, dynamic>{});

      final action = data['action'] as String?;
      debugPrint('LoginChannel 收到: $data');

      switch (action) {
        case 'login':
          _handleLogin(
            email: data['email'] as String? ?? '',
            otp: data['otp'] as String? ?? '',
            isSignUp: data['authMode'] == 'signUp',
          );
          break;
        case 'sendOtp':
          _handleSendOtp(email: data['email'] as String? ?? '');
          break;
        case 'guest':
          _handleGuest();
          break;
      }
    } catch (e) {
      debugPrint('解析 JS Bridge 消息失败: $e');
    }
  }

  Future<void> _handleSendOtp({required String email}) async {
    try {
      await SupabaseAuthService.instance.sendOtp(email);
      // 触发 HTML 端倒计时 + toast 提示
      _controller.executeScript("window._onOtpSent('${_escapeJs(email)}')");
    } catch (e) {
      _controller.executeScript(
          "window._showError('${_escapeJs(e.toString())}')");
    }
  }

  Future<void> _handleLogin({
    required String email,
    required String otp,
    bool isSignUp = false,
  }) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await SupabaseAuthService.instance.verifyOtp(
        email: email,
        otp: otp,
        isSignUp: isSignUp,
      );
    } catch (e) {
      _controller.executeScript(
          "window._showError('${_escapeJs(e.toString())}')");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handleGuest() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await SupabaseAuthService.instance.signInAnonymously();
    } catch (e) {
      _controller.executeScript(
          "window._showError('${_escapeJs(e.toString())}')");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _escapeJs(String s) {
    return s
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n');
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF2A3A1E),
      body: Stack(
        children: [
          if (_ready) Webview(_controller),
          if (!_ready)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF5BA34A),
              ),
            ),
        ],
      ),
    );
  }
}
