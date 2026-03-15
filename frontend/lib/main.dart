import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_keys.dart';
import 'core/i18n/app_locale_controller.dart';
import 'core/services/preferences_service.dart';
import 'core/services/supabase_auth_service.dart';
import 'core/theme/quest_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/quest/screens/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ndbhxjvrgxeuyykrlyxl.supabase.co',
    anonKey: 'sb_publishable_oqeYb0IhGpRlPmYCWqLomQ_Jr4yrwT9',
  );
  try {
    await SupabaseAuthService.instance.ensureActiveSession();
  } catch (_) {
    // 启动阶段优先恢复会话，网络抖动时交给后续按需重试。
  }

  runApp(const MyApp());
}

@visibleForTesting
bool shouldShowHomeForSession({required bool hasSession}) => hasSession;

const Set<String> _supportedThemeIds = <String>{
  'forest_adventure',
  'default',
};

@visibleForTesting
String normalizeThemeId(String themeId) {
  return _supportedThemeIds.contains(themeId) ? themeId : 'forest_adventure';
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class _MyAppState extends State<MyApp> {
  String _currentThemeId = 'forest_adventure';
  final AppLocaleController _localeController = AppLocaleController.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_loadLocalPreferences());
  }

  Future<void> _loadLocalPreferences() async {
    final savedTheme = await PreferencesService.selectedTheme();
    final normalizedTheme = normalizeThemeId(savedTheme);
    if (savedTheme != normalizedTheme) {
      await PreferencesService.setSelectedTheme(normalizedTheme);
    }
    if (mounted && normalizedTheme != _currentThemeId) {
      setState(() => _currentThemeId = normalizedTheme);
    }
    await _localeController.load();
  }

  QuestTheme _resolveQuestTheme(String themeId) {
    switch (themeId) {
      case 'default':
        return QuestTheme.freshBreath();
      case 'forest_adventure':
        return QuestTheme.forestAdventure();
      default:
        return QuestTheme.forestAdventure();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _localeController,
      builder: (context, _) {
        final baseTheme = ThemeData.light();
        final home = HomePage(
          currentThemeId: _currentThemeId,
          onThemeChange: (themeId) async {
            final normalizedTheme = normalizeThemeId(themeId);
            setState(() => _currentThemeId = normalizedTheme);
            await PreferencesService.setSelectedTheme(normalizedTheme);
          },
        );

        return MaterialApp(
          title: 'Gamified Quest Log',
          debugShowCheckedModeBanner: false,
          scrollBehavior: _AppScrollBehavior(),
          scaffoldMessengerKey: scaffoldMessengerKey,
          theme: baseTheme.copyWith(
            extensions: [
              _resolveQuestTheme(_currentThemeId),
            ],
          ),
          locale: _localeController.locale,
          supportedLocales: const [
            Locale('zh', 'CN'),
            Locale('en', 'US'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: StreamBuilder<AuthState>(
            stream: SupabaseAuthService.instance.authStateChanges,
            builder: (context, snapshot) {
              final stateSession = snapshot.data?.session;
              final effectiveSession = stateSession ??
                  SupabaseAuthService.instance.getCurrentSession();
              final hasSession = effectiveSession != null;
              if (shouldShowHomeForSession(hasSession: hasSession)) {
                return home;
              }
              return LoginScreen(
                homeBuilder: (_) => home,
              );
            },
          ),
        );
      },
    );
  }
}
