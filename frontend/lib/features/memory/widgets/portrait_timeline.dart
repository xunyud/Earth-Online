import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/i18n/app_locale_controller.dart';
import '../../../core/theme/quest_theme.dart';
import '../models/portrait_timeline_item.dart';

/// 0-1 张画像时的引导文案
class PortraitTimelineGuide extends StatelessWidget {
  final PortraitTimelineItem? portrait;
  final QuestTheme theme;

  const PortraitTimelineGuide({
    super.key,
    required this.portrait,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1A5B8A58)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (portrait != null && portrait!.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                portrait!.imageUrl,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholderIcon(),
              ),
            )
          else
            _placeholderIcon(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('memory.portrait_timeline.title'),
                  style: AppTextStyles.caption.copyWith(
                    color: theme.primaryAccentColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  portrait == null
                      ? context.tr('memory.portrait_timeline.guide_empty')
                      : context.tr('memory.portrait_timeline.guide_single'),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderIcon() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5EE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        color: Color(0xFF8AAE87),
        size: 24,
      ),
    );
  }
}

/// 多张画像的可滑动时间线
class PortraitTimelineCarousel extends StatefulWidget {
  final List<PortraitTimelineItem> portraits;
  final int initialIndex;
  final QuestTheme theme;
  final ValueChanged<int> onPageChanged;

  const PortraitTimelineCarousel({
    super.key,
    required this.portraits,
    required this.initialIndex,
    required this.theme,
    required this.onPageChanged,
  });

  @override
  State<PortraitTimelineCarousel> createState() =>
      _PortraitTimelineCarouselState();
}

class _PortraitTimelineCarouselState extends State<PortraitTimelineCarousel> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(
      initialPage: widget.initialIndex,
      viewportFraction: 0.88,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.portraits.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              widget.onPageChanged(index);
            },
            itemBuilder: (context, index) {
              return _PortraitCard(
                portrait: widget.portraits[index],
                isActive: index == _currentIndex,
                theme: widget.theme,
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        _buildPageIndicator(),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.portraits.length, (index) {
        final isActive = index == _currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive
                ? widget.theme.primaryAccentColor
                : widget.theme.primaryAccentColor.withAlpha(50),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

class _PortraitCard extends StatelessWidget {
  final PortraitTimelineItem portrait;
  final bool isActive;
  final QuestTheme theme;

  const _PortraitCard({
    required this.portrait,
    required this.isActive,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: EdgeInsets.fromLTRB(6, isActive ? 4 : 8, 6, isActive ? 4 : 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive
              ? theme.primaryAccentColor.withAlpha(80)
              : const Color(0x1A5B8A58),
          width: isActive ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isActive ? 14 : 6),
            blurRadius: isActive ? 12 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Row(
          children: [
            if (portrait.imageUrl.isNotEmpty)
              SizedBox(
                width: 120,
                child: Image.network(
                  portrait.imageUrl,
                  fit: BoxFit.cover,
                  height: double.infinity,
                  errorBuilder: (_, __, ___) => _imagePlaceholder(),
                ),
              )
            else
              _imagePlaceholder(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryAccentColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        portrait.epoch,
                        style: AppTextStyles.caption.copyWith(
                          color: theme.primaryAccentColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        portrait.summary.isNotEmpty
                            ? portrait.summary
                            : context.tr('memory.portrait_timeline.no_summary'),
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          height: 1.45,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 12,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          context.tr('memory.portrait_timeline.label'),
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textHint,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 120,
      color: const Color(0xFFF0F5EE),
      child: const Center(
        child: Icon(
          Icons.image_rounded,
          color: Color(0xFFB8D4B5),
          size: 36,
        ),
      ),
    );
  }
}
