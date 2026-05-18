import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../i18n/app_locale_controller.dart';
import '../services/preferences_service.dart';

/// 检查是否已同意隐私协议，未同意则弹窗。
/// 返回 true 表示用户同意，false 表示拒绝。
Future<bool> ensurePrivacyConsent(BuildContext context) async {
  final agreed = await PreferencesService.privacyAgreed();
  if (agreed) return true;

  final result = await showDialog<bool>(
    context: context, // ignore: use_build_context_synchronously
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => const _PrivacyConsentDialog(),
  );

  if (result == true) {
    await PreferencesService.setPrivacyAgreed(true);
    return true;
  }
  return false;
}

class _PrivacyConsentDialog extends StatelessWidget {
  const _PrivacyConsentDialog();

  @override
  Widget build(BuildContext context) {
    final isZh = !AppLocaleController.instance.isEnglish;

    // 覆盖全局 ScrollBehavior，移除鼠标拖拽以避免 Windows 桌面端手势冲突
    return ScrollConfiguration(
      behavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.trackpad},
      ),
      child: AlertDialog(
        title: Text(isZh ? '用户协议与隐私政策' : 'Terms & Privacy Policy'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isZh
                      ? '欢迎使用 Earth Online！在使用本应用前，请阅读以下内容：'
                      : 'Welcome to Earth Online! Before using this app, please read the following:',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                _buildSection(
                  isZh ? '📋 我们收集的信息' : '📋 Information We Collect',
                  isZh
                      ? '• 账户信息（邮箱或第三方登录标识）\n'
                          '• 您创建的任务内容和完成状态\n'
                          '• 与AI助手的对话记录（用于提供个性化服务）\n'
                          '• 基础设备信息（用于性能优化）'
                      : '• Account info (email or third-party login ID)\n'
                          '• Tasks you create and their completion status\n'
                          '• Conversations with AI assistant (for personalized service)\n'
                          '• Basic device info (for performance optimization)',
                ),
                _buildSection(
                  isZh ? '🔒 信息用途与保护' : '🔒 How We Use & Protect Your Data',
                  isZh
                      ? '• 数据通过 HTTPS 加密传输\n'
                          '• 任务内容可能发送给 AI 服务以提供解析和对话功能\n'
                          '• 我们不会将您的个人数据出售给第三方\n'
                          '• 您可以随时删除账户和所有关联数据'
                      : '• Data is encrypted in transit via HTTPS\n'
                          '• Task content may be sent to AI services for parsing and chat\n'
                          '• We do not sell your personal data to third parties\n'
                          '• You can delete your account and all associated data at any time',
                ),
                _buildSection(
                  isZh ? '👤 您的权利' : '👤 Your Rights',
                  isZh
                      ? '• 查看、导出或删除您的个人信息\n'
                          '• 撤回对数据处理的同意\n'
                          '• 联系我们进行数据相关咨询'
                      : '• View, export, or delete your personal information\n'
                          '• Withdraw consent for data processing\n'
                          '• Contact us for data-related inquiries',
                ),
                const SizedBox(height: 8),
                Text(
                  isZh
                      ? '点击"同意"即表示您已阅读并同意上述条款。'
                      : 'By tapping "Agree", you confirm you have read and accept the above terms.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
              exit(0);
            },
            child: Text(isZh ? '不同意并退出' : 'Disagree & Exit'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(isZh ? '同意' : 'Agree'),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(content, style: const TextStyle(fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}
