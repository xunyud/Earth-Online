import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_text_styles.dart';
import 'core/constants/app_keys.dart';
import 'core/i18n/app_locale_controller.dart';
import 'core/services/preferences_service.dart';
import 'core/services/supabase_auth_service.dart';
import 'core/theme/quest_theme.dart';
import 'features/auth/screens/forest_login_page.dart';
import 'features/auth/screens/forest_login_web_page_stub.dart'
    if (dart.library.html) 'features/auth/screens/forest_login_web_page_web.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/quest/screens/home_page.dart';
import 'features/quest/screens/life_diary_page.dart';
import 'features/quest/services/weekly_summary_job_service.dart';

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

@visibleForTesting
bool shouldUseForestLoginExperience({
  required bool isWeb,
  required TargetPlatform platform,
}) {
  return isWeb || platform == TargetPlatform.windows;
}

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

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  String _currentThemeId = 'forest_adventure';
  final AppLocaleController _localeController = AppLocaleController.instance;
  final WeeklySummaryJobService _weeklySummaryJobService =
      WeeklySummaryJobService.instance;
  bool _weeklySummaryDialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _weeklySummaryJobService.addListener(_handleWeeklySummaryReminder);
    unawaited(_loadLocalPreferences());
    unawaited(WeeklySummaryJobService.instance.initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _weeklySummaryJobService.removeListener(_handleWeeklySummaryReminder);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_weeklySummaryJobService.refreshStatus());
    }
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

  void _handleWeeklySummaryReminder() {
    if (!mounted || _weeklySummaryDialogOpen) return;
    final reminder = _weeklySummaryJobService.pendingReminder;
    final dialogContext = rootNavigatorKey.currentContext;
    if (reminder == null || dialogContext == null) return;

    _weeklySummaryDialogOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final context = rootNavigatorKey.currentContext;
      if (context == null) {
        _weeklySummaryDialogOpen = false;
        return;
      }

      final shouldOpenDiary = await showDialog<bool>(
            context: context,
            useRootNavigator: true,
            builder: (context) => AlertDialog(
              title: Text(
                reminder.isSuccess
                    ? context.tr('weekly.summary.ready_title')
                    : context.tr('weekly.summary.failed_title'),
              ),
              content: Text(
                reminder.isSuccess
                    ? context.tr('weekly.summary.ready_body')
                    : context.tr('weekly.summary.failed_body'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    reminder.isSuccess
                        ? context.tr('weekly.summary.later')
                        : context.tr('weekly.summary.acknowledge'),
                  ),
                ),
                if (reminder.isSuccess)
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(context.tr('weekly.summary.open_now')),
                  ),
              ],
            ),
          ) ??
          false;

      await _weeklySummaryJobService.acknowledgeReminder(reminder.id);
      _weeklySummaryDialogOpen = false;

      if (shouldOpenDiary) {
        final navigator = rootNavigatorKey.currentState;
        if (navigator != null) {
          await navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => const LifeDiaryPage(),
            ),
          );
        }
      }
    });
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleWeeklySummaryReminder();
    });
    return AnimatedBuilder(
      animation: _localeController,
      builder: (context, _) {
        final questTheme = _resolveQuestTheme(_currentThemeId);
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
          title: 'Earth Online',
          debugShowCheckedModeBanner: false,
          scrollBehavior: _AppScrollBehavior(),
          navigatorKey: rootNavigatorKey,
          scaffoldMessengerKey: scaffoldMessengerKey,
          theme: baseTheme.copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: questTheme.primaryAccentColor,
              primary: questTheme.primaryAccentColor,
              surface: questTheme.surfaceColor,
            ),
            textTheme: AppTextStyles.applyFontFallback(
              baseTheme.textTheme,
              isEnglish: _localeController.isEnglish,
            ),
            primaryTextTheme: AppTextStyles.applyFontFallback(
              baseTheme.primaryTextTheme,
              isEnglish: _localeController.isEnglish,
            ),
            extensions: [questTheme],
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
              if (shouldUseForestLoginExperience(
                isWeb: kIsWeb,
                platform: defaultTargetPlatform,
              )) {
                if (kIsWeb) {
                  return ForestLoginWebPage(
                    homeBuilder: (_) => home,
                  );
                }
                return ForestLoginPage(
                  homeBuilder: (_) => home,
                );
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
