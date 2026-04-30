import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/i18n/app_locale_controller.dart';
import '../../../core/services/memory_service.dart';
import '../../../core/theme/quest_theme.dart';

class QuickAddBar extends StatefulWidget {
  final Function(String) onSubmitted;
  final VoidCallback? onPlusTap;
  final bool isLoading;
  /// 图片识别成功且含任务标题时回调，将标题预填到任务创建流程
  final Function(String)? onImageTaskRecognized;

  const QuickAddBar({
    Key? key,
    required this.onSubmitted,
    this.onPlusTap,
    this.isLoading = false,
    this.onImageTaskRecognized,
  }) : super(key: key);

  @override
  State<QuickAddBar> createState() => _QuickAddBarState();
}

class _QuickAddBarState extends State<QuickAddBar>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  /// 图片识别进行中标记
  bool _imageRecognizing = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _glowAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _focusNode.addListener(() {
      final hasFocus = _focusNode.hasFocus;
      if (hasFocus) {
        _glowController.repeat(reverse: true);
      } else {
        _glowController.stop();
        _glowController.value = 0;
      }
      setState(() => _isFocused = hasFocus);
    });
    _controller.addListener(() => setState(() {}));
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (_) {
        if (mounted) setState(() => _isListening = false);
      },
      onStatus: (status) {
        if (status == 'notListening' || status == 'done') {
          if (mounted) setState(() => _isListening = false);
        }
      },
    );
  }

  @override
  void dispose() {
    if (_isListening) _speech.stop();
    _glowController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final text = _controller.text;
    if (text.isNotEmpty) {
      widget.onSubmitted(text);
      _controller.clear();
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }
    if (!_speechAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('quick_add.voice.unavailable'))),
        );
      }
      return;
    }
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        if (mounted) {
          _controller.text = result.recognizedWords;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
        }
      },
      localeId: context.isEnglish ? 'en_US' : 'zh_CN',
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
      ),
    );
  }

  /// 选择图片并调用后端多模态 LLM 识别
  ///
  /// 流程：
  /// 1. 用户通过 file_picker 选择图片（拍照/图库）
  /// 2. 上传到 Supabase Storage image-memories bucket
  /// 3. 调用后端识别 API，返回 ImageRecognitionResult
  /// 4. 含任务标题时预填到任务创建流程（复用 simulateAIParsing）
  /// 5. 将识别结果写入 EverMemOS
  /// 6. 识别失败时显示错误提示，允许用户手动输入
  Future<void> pickAndRecognizeImage() async {
    if (_imageRecognizing || widget.isLoading) return;

    // 1. 选择图片
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final filePath = result.files.single.path;
    if (filePath == null) return;

    final imageFile = File(filePath);
    if (!imageFile.existsSync()) return;

    setState(() => _imageRecognizing = true);

    try {
      // 2-5. 上传 + 识别 + 写入记忆
      final service = MemoryService();
      final recognition = await service.recognizeImage(imageFile);

      if (!mounted) return;

      if (recognition == null) {
        // 6. 识别失败：显示错误提示，允许手动输入
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('memory.image.recognize_failed')),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      // 4. 含任务标题时预填到任务创建流程
      if (recognition.suggestedTaskTitle.isNotEmpty) {
        if (widget.onImageTaskRecognized != null) {
          widget.onImageTaskRecognized!(recognition.suggestedTaskTitle);
        } else {
          // 降级：将标题填入输入框
          _controller.text = recognition.suggestedTaskTitle;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('memory.image.recognize_failed')),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _imageRecognizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<QuestTheme>()!;
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, _) {
        final glow = _isFocused ? _glowAnimation.value : 0.0;
        return Container(
          margin: const EdgeInsets.only(bottom: 24, left: 24, right: 16),
          child: Row(
            children: [
              // 输入框
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.surfaceColor,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: _isFocused
                          ? Color.lerp(
                              theme.primaryAccentColor.withAlpha(80),
                              theme.primaryAccentColor,
                              glow,
                            )!
                          : AppColors.textHint.withAlpha(45),
                      width: _isFocused ? 1.6 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadowColor,
                        offset: const Offset(0, 8),
                        blurRadius: _isFocused ? 26 : 20,
                        spreadRadius: 0,
                      ),
                      if (_isFocused)
                        BoxShadow(
                          color: theme.primaryAccentColor.withValues(
                            alpha: 0.18 + 0.14 * glow,
                          ),
                          blurRadius: 14.0 + 10.0 * glow,
                          spreadRadius: 1.0 + 1.2 * glow,
                        ),
                    ],
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Row(
                      children: [
                        // 语音按钮
                        _VoiceButton(
                          isListening: _isListening,
                          onTap: widget.isLoading ? null : _toggleListening,
                          accentColor: theme.primaryAccentColor,
                        ),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            enabled: !widget.isLoading,
                            style: AppTextStyles.body,
                            decoration: InputDecoration(
                              hintText: _isListening
                                  ? context.tr('quick_add.voice.listening')
                                  : context.tr('quick_add.hint'),
                              hintStyle: AppTextStyles.caption.copyWith(
                                color: _isListening
                                    ? const Color(0xFFE53935)
                                    : AppColors.textHint,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 14,
                              ),
                            ),
                            onSubmitted: (_) => _handleSubmit(),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // 发送按钮
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: widget.isLoading || _controller.text.isEmpty
                                ? Colors.transparent
                                : theme.primaryAccentColor,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: widget.isLoading ? null : _handleSubmit,
                            icon: widget.isLoading
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        theme.primaryAccentColor,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.arrow_upward_rounded),
                            color: widget.isLoading || _controller.text.isEmpty
                                ? AppColors.textHint
                                : AppColors.pureWhite,
                            tooltip: context.tr('common.send'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // "+" 玻璃鹅卵石按钮
              _GlassPlusButton(onTap: widget.onPlusTap),
            ],
          ),
        );
      },
    );
  }
}

/// 玻璃鹅卵石风格的 "+" 按钮，与 QuestBoardFab 一致
class _GlassPlusButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _GlassPlusButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    final questTheme = Theme.of(context).extension<QuestTheme>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = questTheme.surfaceColor;
    final glassTint = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : surface.withValues(alpha: 0.55);

    const double size = 46;
    const double radius = 15;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: CustomPaint(
              painter: _GlassPainter(glassTint: glassTint, isDark: isDark),
              child: SizedBox(
                width: size,
                height: size,
                child: Center(
                  child: Icon(
                    Icons.add_rounded,
                    color: Colors.black.withValues(alpha: 0.72),
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassPainter extends CustomPainter {
  final Color glassTint;
  final bool isDark;

  _GlassPainter({required this.glassTint, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(15));

    canvas.drawRRect(rrect, Paint()..color = glassTint);

    final highlightRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.52);
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(
      highlightRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: isDark ? 0.12 : 0.45),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(highlightRect),
    );
    canvas.restore();

    canvas.drawRRect(
      rrect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: isDark ? 0.28 : 0.65),
            Colors.white.withValues(alpha: isDark ? 0.05 : 0.12),
          ],
        ).createShader(rect),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = (isDark ? Colors.white : Colors.black)
            .withValues(alpha: isDark ? 0.10 : 0.06),
    );
  }

  @override
  bool shouldRepaint(_GlassPainter oldDelegate) =>
      glassTint != oldDelegate.glassTint || isDark != oldDelegate.isDark;
}

class _VoiceButton extends StatelessWidget {
  final bool isListening;
  final VoidCallback? onTap;
  final Color accentColor;

  const _VoiceButton({
    required this.isListening,
    this.onTap,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: isListening
              ? const Color(0xFFE53935).withAlpha(20)
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
          size: 20,
          color: isListening ? const Color(0xFFE53935) : AppColors.textHint,
        ),
      ),
    );
  }
}
