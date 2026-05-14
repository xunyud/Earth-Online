import 'package:flutter/material.dart';

/// 语音输入麦克风按钮
class VoiceMicButton extends StatelessWidget {
  final bool isListening;
  final bool isUploading;
  final VoidCallback onTap;

  const VoiceMicButton({
    super.key,
    required this.isListening,
    required this.isUploading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isUploading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isListening
              ? const Color(0xFFE53935).withAlpha(20)
              : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: isListening
                ? const Color(0xFFE53935).withAlpha(80)
                : const Color(0x225B8A58),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: isUploading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF5A7654),
                  ),
                )
              : Icon(
                  isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                  size: 22,
                  color: isListening
                      ? const Color(0xFFE53935)
                      : const Color(0xFF5A7654),
                ),
        ),
      ),
    );
  }
}
