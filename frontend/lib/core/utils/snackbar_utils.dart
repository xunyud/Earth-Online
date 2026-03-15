import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/app_text_styles.dart';

void showForestSnackBar(BuildContext context, String message, {Duration duration = const Duration(milliseconds: 2000)}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  
  // Forest/Gold colors
  final bgColor = isDark
      ? const Color(0xFF1A2F1A).withValues(alpha: 0.85) // Dark Forest Green
      : const Color(0xFFE8F5E9).withValues(alpha: 0.90); // Light Mint/Forest
  
  final borderColor = isDark
      ? const Color(0xFFD4AF37).withValues(alpha: 0.6) // Gold
      : const Color(0xFF4CAF50).withValues(alpha: 0.5); // Green
      
  final textColor = isDark
      ? const Color(0xFFE0E0E0)
      : const Color(0xFF2E4D2E);

  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      duration: duration,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.all(16),
      content: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.forest_rounded,
                  color: isDark ? const Color(0xFFD4AF37) : const Color(0xFF388E3C),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: AppTextStyles.body.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
