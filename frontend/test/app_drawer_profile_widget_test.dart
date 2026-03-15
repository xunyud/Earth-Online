import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/preferences_service.dart';
import 'package:frontend/core/theme/quest_theme.dart';
import 'package:frontend/core/widgets/app_drawer.dart';
import 'package:frontend/features/profile/controllers/user_profile_controller.dart';
import 'package:frontend/features/quest/controllers/quest_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'https://example.supabase.co',
        anonKey: 'test-anon-key',
      );
    } catch (_) {}
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.resetCache();
  });

  testWidgets('抽屉支持修改昵称且点击头像会直接上传头像', (tester) async {
    final profileController = UserProfileController.test(
      email: 'forest.hero@qq.com',
      readDisplayName: () async => '森林旅人',
      writeDisplayName: (_) async {},
      readAvatarBase64: () async => null,
      writeAvatarBase64: (_) async {},
    );
    await profileController.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          extensions: <ThemeExtension<dynamic>>[
            QuestTheme.forestAdventure(),
          ],
        ),
        home: Scaffold(
          body: AppDrawer(
            questController: QuestController(),
            onOpenSettings: () {},
            onOpenGuide: () {},
            userEmail: 'forest.hero@qq.com',
            profileController: profileController,
            onPickAvatarBase64: () async =>
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+X2ioAAAAASUVORK5CYII=',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('森林旅人'), findsOneWidget);

    await tester.tap(find.byKey(const Key('drawer-profile-edit-name')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '暮色旅人');
    await tester.tap(find.text('保存昵称'));
    await tester.pumpAndSettle();

    expect(profileController.displayName, '暮色旅人');
    expect(find.text('更换头像'), findsNothing);

    await tester.tap(find.byKey(const Key('drawer-profile-avatar-button')));
    await tester.pumpAndSettle();

    expect(profileController.avatarBytes, isNotNull);
  });
}
