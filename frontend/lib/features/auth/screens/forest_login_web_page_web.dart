import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/supabase_auth_service.dart';

class ForestLoginWebPage extends StatefulWidget {
  final WidgetBuilder homeBuilder;

  const ForestLoginWebPage({super.key, required this.homeBuilder});

  @override
  State<ForestLoginWebPage> createState() => _ForestLoginWebPageState();
}

class _ForestLoginWebPageState extends State<ForestLoginWebPage> {
  static int _nextViewId = 0;

  late final String _viewType;
  late final html.IFrameElement _iframe;
  StreamSubscription<html.MessageEvent>? _messageSub;
  bool _ready = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'forest-login-web-${_nextViewId++}';
    _iframe = html.IFrameElement()
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#2A3A1E';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return _iframe;
    });
    _messageSub = html.window.onMessage.listen(_handleBridgeMessage);
    unawaited(_loadHtml());
  }

  Future<void> _loadHtml() async {
    try {
      var htmlContent = await rootBundle.loadString('assets/web/login.html');
      final base = Uri.base;
      htmlContent = htmlContent
          .replaceAll('{{IMG_LOGO}}', base.resolve('assets/assets/images/branding/earth_online_logo.png').toString())
          .replaceAll('{{IMG_SKY}}', base.resolve('assets/assets/images/backgrounds/forest/sky.png').toString())
          .replaceAll('{{IMG_FAR}}', base.resolve('assets/assets/images/backgrounds/forest/far.png').toString())
          .replaceAll('{{IMG_MID}}', base.resolve('assets/assets/images/backgrounds/forest/mid.png').toString())
          .replaceAll('{{IMG_NEAR}}', base.resolve('assets/assets/images/backgrounds/forest/near.png').toString());
      _iframe.srcdoc = htmlContent;
      if (mounted) {
        setState(() => _ready = true);
      }
    } catch (error) {
      debugPrint('加载 web 森林登录页失败: $error');
      if (mounted) {
        setState(() => _ready = true);
      }
    }
  }

  void _handleBridgeMessage(html.MessageEvent event) {
    if (event.source != _iframe.contentWindow) {
      return;
    }
    final data = event.data;
    Map<String, dynamic>? payload;
    if (data is String) {
      try {
        payload = jsonDecode(data) as Map<String, dynamic>;
      } catch (_) {
        return;
      }
    } else if (data is Map) {
      payload = Map<String, dynamic>.from(data as Map);
    }
    if (payload == null) {
      return;
    }

    final action = payload['action'] as String?;
    if (action == null) {
      return;
    }

    switch (action) {
      case 'sendOtp':
        _handleSendOtp(email: payload['email'] as String? ?? '');
        break;
      case 'login':
        _handleLogin(
          email: payload['email'] as String? ?? '',
          otp: payload['otp'] as String? ?? '',
          isSignUp: payload['authMode'] == 'signUp',
        );
        break;
      case 'guest':
        _handleGuest();
        break;
    }
  }

  void _postToIframe(Map<String, dynamic> message) {
    _iframe.contentWindow?.postMessage(jsonEncode(message), '*');
  }

  Future<void> _handleSendOtp({required String email}) async {
    try {
      await SupabaseAuthService.instance.sendOtp(email);
      _postToIframe(<String, dynamic>{'type': 'otpSent', 'email': email});
    } catch (error) {
      _postToIframe(<String, dynamic>{
        'type': 'error',
        'message': error.toString(),
      });
    }
  }

  Future<void> _handleLogin({
    required String email,
    required String otp,
    required bool isSignUp,
  }) async {
    if (_submitting) {
      return;
    }
    setState(() => _submitting = true);
    try {
      await SupabaseAuthService.instance.verifyOtp(
        email: email,
        otp: otp,
        isSignUp: isSignUp,
      );
    } catch (error) {
      _postToIframe(<String, dynamic>{
        'type': 'error',
        'message': error.toString(),
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _handleGuest() async {
    if (_submitting) {
      return;
    }
    setState(() => _submitting = true);
    try {
      await SupabaseAuthService.instance.signInAnonymously();
    } catch (error) {
      _postToIframe(<String, dynamic>{
        'type': 'error',
        'message': error.toString(),
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF2A3A1E),
      body: Stack(
        children: [
          if (_ready) HtmlElementView(viewType: _viewType),
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
