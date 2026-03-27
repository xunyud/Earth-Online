import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:math' as math;
import '../controllers/quest_controller.dart';
import '../models/quest_node.dart';
import '../../../core/theme/quest_theme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/i18n/app_locale_controller.dart';
import 'quest_item.dart';

class QuestBoard extends StatefulWidget {
  final List<TimelineEntry> entries;
  final List<QuestNode> quests;
  final ValueChanged<QuestNode> onQuestCompleted;
  final ValueChanged<String> onQuestDeleted;
  final ValueChanged<String> onQuestToggleExpanded;
  final void Function(String questId, int dropIndex, int targetDepth) onQuestMove;
  final QuestDetailsUpdater onQuestUpdateDetails;
  final bool isAnalyzing;
  final String guideName;

  const QuestBoard({
    Key? key,
    required this.entries,
    required this.quests,
    required this.onQuestCompleted,
    required this.onQuestDeleted,
    required this.onQuestToggleExpanded,
    required this.onQuestMove,
    required this.onQuestUpdateDetails,
    this.isAnalyzing = false,
    this.guideName = '',
  }) : super(key: key);

  @override
  State<QuestBoard> createState() => _QuestBoardState();
}

class _QuestBoardState extends State<QuestBoard> {
  static const double _indentStep = 32.0;
  static const double _gutterWidth = 28.0;
  static const double _itemGap = 10.0;

  static bool _didShowWelcome = false;
  static const List<String> _warmQuotes = [
    '新的一天，地球Online又为你准备了全新的冒险。',
    '慢慢来，所有的伟大都是由日常的琐碎构成的。',
    '你已经在路上了，这本身就很了不起。',
    '把今天过好，就是最强的成长。',
    '允许自己不完美，但别忘了继续前进。',
    '别急，进度条会一点点被你点亮。',
    '今天也请温柔地对待自己。',
    '每一次勾选，都是对未来的投资。',
  ];

  final GlobalKey _boardKey = GlobalKey();
  double _baseOffsetX = 0;

  int? _hoverEntryIndex;
  bool _hoverIsTop = true;
  int _targetDepth = 0;
  DragPayload? _activePayload;

  @override
  void initState() {
    super.initState();
    if (_didShowWelcome) return;
    _didShowWelcome = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;
        final pickIndex =
            DateTime.now().microsecondsSinceEpoch % _warmQuotes.length;
        final quote = _warmQuotes[pickIndex];

        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentMaterialBanner();
        messenger.showMaterialBanner(
          MaterialBanner(
            backgroundColor: Theme.of(context).extension<QuestTheme>()!.surfaceColor,
            leading: Icon(
              Icons.wb_sunny_rounded,
              color:
                  Theme.of(context).extension<QuestTheme>()!.primaryAccentColor,
            ),
            content: Text(
              quote,
              style: AppTextStyles.body.copyWith(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: messenger.hideCurrentMaterialBanner,
                child: Text(
                  '知道了',
                  style: AppTextStyles.caption.copyWith(
                    color: Theme.of(context)
                        .extension<QuestTheme>()!
                        .primaryAccentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );

        Future.delayed(const Duration(seconds: 5), () {
          if (!mounted) return;
          messenger.hideCurrentMaterialBanner();
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<QuestTheme>()!;
    final entries = widget.entries;
    final items = _buildSliverItems(entries);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) return;
      final dx = box.localToGlobal(Offset.zero).dx + 20 + _gutterWidth;
      if ((dx - _baseOffsetX).abs() > 0.5) {
        setState(() => _baseOffsetX = dx);
      }
    });

    return Container(
      key: _boardKey,
      color: theme.backgroundColor,
      child: ScrollConfiguration(
        behavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        child: CustomScrollView(
          slivers: [
            if (widget.isAnalyzing)
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.primaryAccentColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        context.tr('quest.analyzing', params: {'name': widget.guideName}),
                        style: AppTextStyles.body.copyWith(
                          color: theme.primaryAccentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    if (i >= items.length) return null;
                    return items[i];
                  },
                  childCount: items.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 80),
            ),
          ],
        ),
      ),
    );
  }

  int _depthFromGlobalDx(double globalDx) {
    final depth =
        ((globalDx - _baseOffsetX) / _indentStep).floor().clamp(0, 8);
    return depth;
  }

  int _maxAllowedDepthForDropIndex(int dropIndex) {
    if (dropIndex <= 0) return 0;
    if (dropIndex - 1 >= widget.entries.length) return 0;
    final prev = widget.entries[dropIndex - 1];
    return prev.depth + 1;
  }

  Widget _buildEntry(BuildContext context, TimelineEntry entry, int entryIndex) {
    final q = entry.node;
    final color = q.isCompleted ? Colors.lightBlue : Colors.grey.shade300;

    final payload = DragPayload(
      questId: q.id,
      baseDepth: entry.depth,
    );

    Widget buildCard({required Widget? dragHandle}) {
      return _TimelineFrame(
      depth: entry.depth,
      gutterWidth: _gutterWidth,
      indentStep: _indentStep,
      bottomGap: _itemGap,
      color: color,
      lineWidth: q.questTier == 'Main_Quest' ? 4 : 2,
      child: QuestItem(
        key: ValueKey('quest-${q.id}'),
        quest: q,
        quests: widget.quests,
        onCompleted: widget.onQuestCompleted,
        onDelete: () => widget.onQuestDeleted(q.id),
        onToggleExpanded: () => widget.onQuestToggleExpanded(q.id),
        onUpdateDetails: widget.onQuestUpdateDetails,
        dragHandle: dragHandle,
      ),
      );
    }

    final feedbackCard = buildCard(dragHandle: null);
    final dragHandle = LongPressDraggable<DragPayload>(
      data: payload,
      delay: const Duration(milliseconds: 150),
      feedback: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width - 40,
          ),
          child: Transform.scale(
            scale: 1.02,
            child: Opacity(opacity: 0.9, child: feedbackCard),
          ),
        ),
      ),
      childWhenDragging: const Icon(
        Icons.drag_indicator_rounded,
        color: AppColors.textHint,
        size: 22,
      ),
      onDragStarted: () {
        setState(() {
          _activePayload = payload;
          _hoverEntryIndex = null;
          _targetDepth = payload.baseDepth;
        });
      },
      onDragEnd: (_) {
        setState(() {
          _activePayload = null;
          _hoverEntryIndex = null;
        });
      },
      child: const Padding(
        padding: EdgeInsets.only(left: 6),
        child: Icon(
          Icons.drag_indicator_rounded,
          color: AppColors.textSecondary,
          size: 22,
        ),
      ),
    );

    final card = buildCard(dragHandle: dragHandle);

    if (_activePayload == null) return card;

    final showIndicator = _hoverEntryIndex == entryIndex;
    final isTop = _hoverIsTop;
    final indicatorDepth = _targetDepth;

    Widget buildHalfTarget(bool top) {
      return DragTarget<DragPayload>(
        onWillAcceptWithDetails: (details) {
          if (details.data.questId == q.id) return false;
          setState(() {
            _hoverEntryIndex = entryIndex;
            _hoverIsTop = top;
          });
          return true;
        },
        onMove: (details) {
          final dropIndex = top ? entryIndex : entryIndex + 1;
          final maxAllowedDepth = _maxAllowedDepthForDropIndex(dropIndex);
          final calculated = _depthFromGlobalDx(details.offset.dx);
          final clampedDepth = calculated.clamp(0, maxAllowedDepth);
          if (_hoverEntryIndex != entryIndex ||
              _hoverIsTop != top ||
              _targetDepth != clampedDepth) {
            setState(() {
              _hoverEntryIndex = entryIndex;
              _hoverIsTop = top;
              _targetDepth = clampedDepth;
            });
          }
        },
        onLeave: (_) {
          if (_hoverEntryIndex == entryIndex && _hoverIsTop == top) {
            setState(() => _hoverEntryIndex = null);
          }
        },
        onAcceptWithDetails: (details) {
          var depth = _targetDepth;
          final dropIndex = top ? entryIndex : entryIndex + 1;
          if (!top && depth > entry.depth) {
            depth = entry.depth + 1;
          }
          setState(() {
            _hoverEntryIndex = null;
            _activePayload = null;
          });
          widget.onQuestMove(details.data.questId, dropIndex, depth);
        },
        builder: (context, candidateData, rejectedData) {
          return const SizedBox.expand();
        },
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        Positioned.fill(
          child: Column(
            children: [
              Expanded(child: buildHalfTarget(true)),
              Expanded(child: buildHalfTarget(false)),
            ],
          ),
        ),
        if (showIndicator)
          Positioned.fill(
            child: IgnorePointer(
              child: _DropIndicator(
                depth: indicatorDepth,
                gutterWidth: _gutterWidth,
                indentStep: _indentStep,
                isTop: isTop,
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildSliverItems(
    List<TimelineEntry> entries,
  ) {
    final items = <Widget>[];

    Widget buildGlobalHeader() {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            const Icon(Icons.public_rounded, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Text(
              '地球Online',
              style: AppTextStyles.heading2.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    Widget globalHeaderDropAnchor() {
      return DragTarget<DragPayload>(
        onWillAcceptWithDetails: (details) {
          setState(() => _targetDepth = 0);
          return true;
        },
        onMove: (details) {
          if (_targetDepth != 0) setState(() => _targetDepth = 0);
        },
        onAcceptWithDetails: (details) {
          setState(() {
            _hoverEntryIndex = null;
            _activePayload = null;
          });
          widget.onQuestMove(details.data.questId, 0, 0);
        },
        builder: (context, candidateData, rejectedData) {
          final isActive = candidateData.isNotEmpty;
          return SizedBox(
            height: 20,
            child: isActive
                ? const _DropIndicator(
                    depth: 0,
                    gutterWidth: _gutterWidth,
                    indentStep: _indentStep,
                    isTop: false,
                  )
                : const SizedBox.shrink(),
          );
        },
      );
    }

    items.add(buildGlobalHeader());
    items.add(globalHeaderDropAnchor());

    for (var i = 0; i < entries.length; i++) {
      items.add(_buildEntry(context, entries[i], i));
    }

    return items;
  }
}

class DragPayload {
  final String questId;
  final int baseDepth;

  DragPayload({
    required this.questId,
    required this.baseDepth,
  });
}

class _DropIndicator extends StatelessWidget {
  final int depth;
  final double gutterWidth;
  final double indentStep;
  final bool isTop;

  const _DropIndicator({
    required this.depth,
    required this.gutterWidth,
    required this.indentStep,
    required this.isTop,
  });

  @override
  Widget build(BuildContext context) {
    final left = gutterWidth + (depth * indentStep);
    final safeLineLeft = math.max(16.0, left);
    final safeBadgeLeft = math.max(6.0, safeLineLeft - 10);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: safeLineLeft,
          right: 0,
          top: isTop ? 0 : null,
          bottom: isTop ? null : 0,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Positioned(
          left: safeBadgeLeft,
          top: isTop ? -8 : null,
          bottom: isTop ? null : -8,
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Colors.lightBlue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowColor,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '${depth + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineFrame extends StatelessWidget {
  final int depth;
  final double gutterWidth;
  final double indentStep;
  final double bottomGap;
  final Color color;
  final double lineWidth;
  final Widget child;

  const _TimelineFrame({
    required this.depth,
    required this.gutterWidth,
    required this.indentStep,
    required this.bottomGap,
    required this.color,
    required this.lineWidth,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final left = gutterWidth + (depth * indentStep);
    return CustomPaint(
      painter: _TimelinePainter(
        color: color,
        lineWidth: lineWidth,
        gutterWidth: gutterWidth,
        dotX: depth == 0 ? gutterWidth / 2 : left,
        drawHook: depth > 0,
      ),
      child: Padding(
        padding: EdgeInsets.only(left: left, bottom: bottomGap),
        child: child,
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  final Color color;
  final double lineWidth;
  final double gutterWidth;
  final double dotX;
  final bool drawHook;

  _TimelinePainter({
    required this.color,
    required this.lineWidth,
    required this.gutterWidth,
    required this.dotX,
    required this.drawHook,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final trunkX = gutterWidth / 2;
    const dotY = 22.0;

    final paintLine = Paint()
      ..color = color
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(trunkX, 0), Offset(trunkX, size.height), paintLine);
    if (drawHook) {
      canvas.drawLine(Offset(trunkX, dotY), Offset(dotX, dotY), paintLine);
    }

    final dotFill = Paint()..color = color;
    canvas.drawCircle(Offset(dotX, dotY), lineWidth >= 4 ? 6 : 4.5, dotFill);
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.lineWidth != lineWidth ||
        oldDelegate.gutterWidth != gutterWidth ||
        oldDelegate.dotX != dotX ||
        oldDelegate.drawHook != drawHook;
  }
}
