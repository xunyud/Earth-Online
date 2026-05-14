#!/usr/bin/env python3
"""Transform home_page.dart to use GuideController - v4 with reliable parsing."""

import re

FILE = 'frontend/lib/features/quest/screens/home_page.dart'

def read_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.readlines()

def write_file(path, content):
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

def find_method_body_end(lines, method_start):
    """Find the end of a method body, handling named parameters correctly."""
    # First, find the end of the parameter list by tracking parentheses
    paren_depth = 0
    found_open_paren = False
    body_start = None

    for i in range(method_start, min(method_start + 20, len(lines))):
        for j, ch in enumerate(lines[i]):
            if ch == '(':
                paren_depth += 1
                found_open_paren = True
            elif ch == ')':
                paren_depth -= 1
                if found_open_paren and paren_depth == 0:
                    # Found end of params. Now find the opening { of the body
                    # It might be on the same line after ) or on the next line
                    rest = lines[i][j+1:]
                    if '{' in rest:
                        body_start = (i, j + 1 + rest.index('{'))
                    else:
                        # Look at next lines for opening {
                        for k in range(i + 1, min(i + 5, len(lines))):
                            if '{' in lines[k]:
                                body_start = (k, lines[k].index('{'))
                                break
                    break
        if body_start:
            break

    if not body_start:
        # Fallback: simple brace counting from start
        depth = 0
        for i in range(method_start, len(lines)):
            for ch in lines[i]:
                if ch == '{':
                    depth += 1
                elif ch == '}':
                    depth -= 1
                    if depth == 0:
                        return i
        return method_start

    # Now count braces from the body start
    bi, bj = body_start
    depth = 0
    for i in range(bi, len(lines)):
        start_j = bj if i == bi else 0
        for j in range(start_j, len(lines[i])):
            ch = lines[i][j]
            if ch == '{':
                depth += 1
            elif ch == '}':
                depth -= 1
                if depth == 0:
                    return i
    return method_start

def find_closing_brace(lines, start):
    """Find the line with the matching closing brace (for simple cases like classes)."""
    depth = 0
    for i in range(start, len(lines)):
        for ch in lines[i]:
            if ch == '{':
                depth += 1
            elif ch == '}':
                depth -= 1
                if depth == 0:
                    return i
    return start

def find_class_end(lines, class_start):
    """Find the closing brace of the class."""
    depth = 0
    for i in range(class_start, len(lines)):
        for ch in lines[i]:
            if ch == '{':
                depth += 1
            elif ch == '}':
                depth -= 1
                if depth == 0:
                    return i
    return len(lines) - 1

def find_all_methods(lines, class_start):
    """Find all method/getter ranges in _HomePageState."""
    methods = []
    class_end = find_class_end(lines, class_start)
    i = class_start + 1  # skip class declaration line

    while i < class_end:
        line = lines[i]

        # Check if this line starts a method or getter
        # Methods have a return type followed by _name( or get _name
        # We look for the pattern: indented, has a type, has _name, and the body starts with {
        is_method = False
        method_name = None

        # Check for getter: "  Type get _name {"
        getter_match = re.match(r'^\s+\S.*\s+get\s+(_\w+)\s*\{', line)
        if getter_match:
            is_method = True
            method_name = getter_match.group(1)
        else:
            # Check for method: "  ReturnType _name(" - opening brace may be on same or next line
            method_match = re.match(r'^\s+\S.*\s+(_\w+)\s*\(', line)
            if method_match:
                name = method_match.group(1)
                # Verify it's not a variable declaration (no = on the line before ()
                # and the body (with {) exists in the next few lines
                has_body = False
                # Check current line and next 4 lines for opening brace
                for j in range(i, min(i + 5, len(lines))):
                    if '{' in lines[j]:
                        has_body = True
                        break
                    # If we see = before {, it's a variable, not a method
                    if '=' in lines[j] and '{' not in lines[j]:
                        break

                if has_body:
                    # Make sure this isn't a variable declaration like "final Type _name = ..."
                    if not re.match(r'^\s+(?:final|const|static|late|var)\s', line):
                        is_method = True
                        method_name = name

        if is_method and method_name:
            end = find_method_body_end(lines, i)
            if end > i:
                methods.append((method_name, i, end))
                i = end + 1
                continue

        i += 1

    return methods

def main():
    lines = read_file(FILE)
    print(f"Original: {len(lines)} lines")

    # Find _HomePageState class start
    class_start = None
    for i, line in enumerate(lines):
        if 'class _HomePageState extends State<HomePage>' in line:
            class_start = i
            break

    if class_start is None:
        print("ERROR: Could not find _HomePageState class")
        return

    print(f"Found _HomePageState at line {class_start + 1}")

    # Find all methods
    methods = find_all_methods(lines, class_start)
    print(f"Found {len(methods)} methods")

    # Print all found methods
    for name, start, end in methods:
        print(f"  {name}: lines {start+1}-{end+1}")

    # Methods to REMOVE
    # Only remove methods that are pure logic (no UI/BuildContext dependencies)
    # Methods with context.tr(), showForestSnackBar, setState, Navigator, etc. must STAY
    # Also remove dead code methods whose listeners were removed
    REMOVE_METHODS = {
        '_onAgentRunStateChanged',
        '_localDateId',
        '_shouldOfferOnboardingTutorial',
        '_currentAgentRunResult',
        '_findAgentTargetTaskByArguments',
        '_parseAgentDueDate',
        '_parseAgentSubtasks',
        '_executeAgentQuestCreate',
        '_executeAgentQuestUpdate',
        '_executeAgentQuestSplit',
        '_guideChatResultToJson',
        '_extractGuideChatResultFromAgentLocalResult',
        '_buildOpenAIChatUri',
        '_shouldShowAgentStepMessage',
        '_executeAgentWeeklySummaryGenerate',
        '_executeAgentNavigationOpen',
        '_waitForLocalAgentStepResult',
        '_visibleGuideMessages',
        '_shouldRouteToAgent',
        '_classifyGuideIntent',
        '_containsGuideCjk',
        '_normalizeGuideLookup',
        '_matchGuideAction',
        '_extractQuotedText',
        '_guessGuideTaskTitleFromModifyText',
        '_findGuideTargetTask',
        '_extractGuideXp',
        '_parseGuideDigitText',
        '_extractGuideNaturalTitleFromModifyText',
        '_extractGuideDueDate',
        '_shouldGuideGenerateSubtasks',
        '_isGuideConfirmationText',
        '_isGuideCancellationText',
        '_extractGuideStepTitles',
        '_findGuideTaskById',
        '_rememberRecentlyDeletedGuideTasks',
        '_deleteQuestWithGuideMemory',
        '_deleteAllQuestsWithGuideMemory',
        '_shouldKeepPendingGuideTaskEditDraft',
        '_statusFromError',
        '_extractQuotedGuidePhrase',
        '_parseAgentInt',
    }

    # Build removal set
    remove_lines = set()
    for name, start, end in methods:
        if name in REMOVE_METHODS:
            for i in range(start, end + 1):
                remove_lines.add(i)
            print(f"  Removing: {name} (lines {start+1}-{end+1})")

    # Only remove types that were extracted to widgets or renamed.
    # STAY methods still use _GuideTurnResponse, _GuideRewardMatch, _GuideActionType, _AgentRunResult.
    # Those will be renamed via replacements below.

    # Remove inner classes
    for i, line in enumerate(lines):
        stripped = line.strip()
        for cls in ['_PortraitInsightData', '_PortraitInsightChart',
                     '_PortraitReadableMetricGrid', '_PortraitEvaluationSection',
                     '_PortraitBarDatum', '_PortraitMetricDatum',
                     '_PlusMenuItem', '_SettingsSectionCard',
                     '_QuickCreateDialogResult', '_QuickCreateDialogBody',
                     '_QuickCreateDialogBodyState', '_SettingsToggleTile',
                     '_SettingsChoicePill', '_MemoryRecommendationCards',
                     '_MemoryRecommendationChip', '_GuideChatMessage']:
            if stripped.startswith(f'class {cls}'):
                end = find_closing_brace(lines, i)
                for j in range(i, end + 1):
                    remove_lines.add(j)

    # Remove standalone helper functions outside the class
    STANDALONE_TO_REMOVE = ['_buildPortraitEvaluations', '_readableMetricLevel', '_readableMetricDetail']
    for i, line in enumerate(lines):
        for func in STANDALONE_TO_REMOVE:
            if line.strip().startswith(f'{func}(') or re.match(rf'^\S.*\b{re.escape(func)}\b', line.strip()):
                end = find_method_body_end(lines, i)
                for j in range(i, end + 1):
                    remove_lines.add(j)

    # Build new file
    new_lines = [lines[i] for i in range(len(lines)) if i not in remove_lines]
    content = ''.join(new_lines)

    # Normalize line endings to \n for consistent string replacement
    content = content.replace('\r\n', '\n')

    # --- String replacements ---

    # Add imports
    content = content.replace(
        "import '../controllers/quest_controller.dart';",
        "import '../controllers/quest_controller.dart';\nimport '../controllers/guide_controller.dart';\nimport '../models/guide_chat_message.dart';\nimport '../widgets/quick_create_dialog_content.dart';\nimport '../widgets/portrait_insight_chart.dart';\nimport '../widgets/home_settings_widgets.dart';\nimport '../widgets/memory_recommendation_cards.dart';",
    )

    # Replace state variables
    old_vars = """  final Set<String> _runningLocalAgentStepIds = <String>{};
  final Set<String> _finishedLocalAgentStepIds = <String>{};
  final Map<String, LocalToolResult> _localAgentStepResults =
      <String, LocalToolResult>{};
  String? _trackedAgentRunId;

  int _previousUncompletedCount = -1;
  bool _isSyncingMemory = false;
  bool _isGeneratingProfile = false;
  bool _isGuideBootstrapping = false;
  bool _isGuideEventHandling = false;
  _GuideConnectionStatus _guideStatus = _GuideConnectionStatus.ready;

  final List<_GuideChatMessage> _guideMessages = <_GuideChatMessage>[];
  GuideDailyEvent? _latestDailyEvent;
  /// 小忆建议推荐列表，每次 bootstrap 刷新时更新，不缓存过期推荐
  List<MemoryRecommendation> _recommendations = const <MemoryRecommendation>[];
  String? _guideDisplayName;
  String? _profileDisplayName;
  String _guideMemoryDigest = '';
  List<String> _guideBehaviorSignals = const <String>[];
  GuideTaskEditDraft? _pendingGuideTaskEditDraft;
  DateTime? _pendingGuideTaskDueDate;
  final List<String> _recentlyDeletedGuideTaskTitles = <String>[];"""

    new_vars = """  late final GuideController _guideController;

  int _previousUncompletedCount = -1;
  bool _isSyncingMemory = false;
  bool _isGeneratingProfile = false;"""

    content = content.replace(old_vars, new_vars)

    # Remove old service fields
    content = content.replace("  final GuideService _guideService = GuideService();\n", "")
    content = content.replace("  final AgentRunService _agentRunService = AgentRunService();\n", "")
    content = content.replace("  late final LocalAgentRuntimeService _localAgentRuntimeService;\n", "")

    # Update initState
    old_init = """  @override
  void initState() {
    super.initState();
    _localAgentRuntimeService = LocalAgentRuntimeService(
      questCreateHandler: _executeAgentQuestCreate,
      questUpdateHandler: _executeAgentQuestUpdate,
      questSplitHandler: _executeAgentQuestSplit,
      chatFreeformHandler: _executeAgentFreeformChat,
      weeklySummaryGenerateHandler: _executeAgentWeeklySummaryGenerate,
      rewardRedeemHandler: _executeAgentRewardRedeem,
      navigationOpenHandler: _executeAgentNavigationOpen,
    );
    _controller.addListener(_onQuestStateChanged);
    _agentRunService.addListener(_onAgentRunStateChanged);
    _initFuture = _controller.init();
    unawaited(_loadGuideDisplayName());
    unawaited(_loadProfileDisplayName());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runGuideBootstrapIfNeeded());
    });
  }"""

    new_init = """  @override
  void initState() {
    super.initState();
    _guideController = GuideController(questController: _controller);
    _controller.addListener(_onQuestStateChanged);
    _guideController.addListener(_onGuideStateChanged);
    _initFuture = _controller.init();
    unawaited(_guideController.init(_initFuture));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_guideController.runBootstrapIfNeeded(_initFuture));
    });
  }"""

    content = content.replace(old_init, new_init)

    # Update dispose
    old_dispose = """  @override
  void dispose() {
    _controller.removeListener(_onQuestStateChanged);
    _agentRunService.removeListener(_onAgentRunStateChanged);
    _agentRunService.dispose();
    _evermemosService.dispose();
    _confetti.dispose();
    _controller.dispose();
    super.dispose();
  }"""

    new_dispose = """  @override
  void dispose() {
    _controller.removeListener(_onQuestStateChanged);
    _guideController.removeListener(_onGuideStateChanged);
    _guideController.dispose();
    _evermemosService.dispose();
    _confetti.dispose();
    _controller.dispose();
    super.dispose();
  }"""

    content = content.replace(old_dispose, new_dispose)

    # Add _onGuideStateChanged after _onQuestStateChanged
    marker = "    _previousUncompletedCount = uncompleted;\n  }\n\n\n  Future<void> _onCoachMarksComplete"
    replacement = "    _previousUncompletedCount = uncompleted;\n  }\n\n  void _onGuideStateChanged() {\n    if (mounted) setState(() {});\n  }\n\n  Future<void> _onCoachMarksComplete"
    content = content.replace(marker, replacement)

    # --- Reference replacements ---
    # Only replace references to:
    # 1. State variables that moved to GuideController
    # 2. SAFE methods that were removed from home_page.dart
    # 3. Type renames (private → public)
    # Do NOT replace references to STAY methods (they remain in home_page.dart)
    replacements = [
        # State variables → GuideController
        ('_guideStatus', '_guideController.guideStatus'),
        ('_isGuideBootstrapping', '_guideController.isGuideBootstrapping'),
        ('_isGuideEventHandling', '_guideController.isGuideEventHandling'),
        ('_guideMessages', '_guideController.guideMessages'),
        ('_latestDailyEvent', '_guideController.latestDailyEvent'),
        ('_recommendations', '_guideController.recommendations'),
        ('_guideDisplayName', '_guideController.guideDisplayName'),
        ('_profileDisplayName', '_guideController.profileDisplayName'),
        ('_guideMemoryDigest', '_guideController.guideMemoryDigest'),
        ('_guideBehaviorSignals', '_guideController.guideBehaviorSignals'),
        ('_pendingGuideTaskEditDraft', '_guideController.pendingGuideTaskEditDraft'),
        ('_pendingGuideTaskDueDate', '_guideController.pendingGuideTaskDueDate'),
        ('_recentlyDeletedGuideTaskTitles', '_guideController.recentlyDeletedGuideTaskTitles'),
        ('_runningLocalAgentStepIds', '_guideController.runningLocalAgentStepIds'),
        ('_finishedLocalAgentStepIds', '_guideController.finishedLocalAgentStepIds'),
        ('_localAgentStepResults', '_guideController.localAgentStepResults'),
        ('_trackedAgentRunId', '_guideController.trackedAgentRunId'),
        ('_agentRunService', '_guideController.agentRunService'),
        ('_localOnboardingEventId', 'localOnboardingEventId'),
        # SAFE methods removed from home_page.dart → redirect to GuideController
        ('_localDateId()', '_guideController.localDateId()'),
        ('_containsGuideCjk(', '_guideController.containsGuideCjk('),
        ('_normalizeGuideLookup(', '_guideController.normalizeGuideLookup('),
        ('_matchGuideAction(', '_guideController.matchGuideAction('),
        ('_extractQuotedText(', '_guideController.extractQuotedText('),
        ('_guessGuideTaskTitleFromModifyText(', '_guideController.guessGuideTaskTitleFromModifyText('),
        ('_findGuideTargetTask(', '_guideController.findGuideTargetTask('),
        ('_extractGuideXp(', '_guideController.extractGuideXp('),
        ('_parseGuideDigitText(', '_guideController.parseGuideDigitText('),
        ('_extractGuideNaturalTitleFromModifyText(', '_guideController.extractGuideNaturalTitleFromModifyText('),
        ('_extractGuideDueDate(', '_guideController.extractGuideDueDate('),
        ('_shouldGuideGenerateSubtasks(', '_guideController.shouldGuideGenerateSubtasks('),
        ('_isGuideConfirmationText(', '_guideController.isGuideConfirmationText('),
        ('_isGuideCancellationText(', '_guideController.isGuideCancellationText('),
        ('_extractGuideStepTitles(', '_guideController.extractGuideStepTitles('),
        ('_findGuideTaskById(', '_guideController.findGuideTaskById('),
        ('_rememberRecentlyDeletedGuideTasks(', '_guideController.rememberRecentlyDeletedGuideTasks('),
        ('_deleteQuestWithGuideMemory(', '_guideController.deleteQuestWithGuideMemory('),
        ('_deleteAllQuestsWithGuideMemory()', '_guideController.deleteAllQuestsWithGuideMemory()'),
        ('_shouldKeepPendingGuideTaskEditDraft(', '_guideController.shouldKeepPendingGuideTaskEditDraft('),
        ('_shouldRouteToAgent(', '_guideController.shouldRouteToAgent('),
        ('_shouldShowAgentStepMessage(', '_guideController.shouldShowAgentStepMessage('),
        ('_classifyGuideIntent(', '_guideController.classifyGuideIntent('),
        ('_statusFromError(', '_guideController.statusFromError('),
        ('_visibleGuideMessages()', '_guideController.visibleGuideMessages()'),
        ('_currentAgentRunResult()', '_guideController.currentAgentRunResult()'),
        ('_waitForLocalAgentStepResult(', '_guideController.waitForLocalAgentStepResult('),
        ('_shouldOfferOnboardingTutorial()', '_guideController.shouldOfferOnboardingTutorial()'),
        ('_parseAgentInt(', '_guideController.parseAgentInt('),
        ('_extractQuotedGuidePhrase(', '_guideController.extractQuotedGuidePhrase('),
        ('_buildOpenAIChatUri()', '_guideController.buildOpenAIChatUri()'),
        ('_guideChatResultToJson(', '_guideController.guideChatResultToJson('),
        ('_extractGuideChatResultFromAgentLocalResult(', '_guideController.extractGuideChatResultFromAgentLocalResult('),
        ('_executeAgentQuestCreate(', '_guideController.executeAgentQuestCreate('),
        ('_executeAgentQuestUpdate(', '_guideController.executeAgentQuestUpdate('),
        ('_executeAgentQuestSplit(', '_guideController.executeAgentQuestSplit('),
        ('_executeAgentWeeklySummaryGenerate(', '_guideController.executeAgentWeeklySummaryGenerate('),
        ('_executeAgentNavigationOpen(', '_guideController.executeAgentNavigationOpen('),
        ('_parseAgentSubtasks(', '_guideController.parseAgentSubtasks('),
        ('_parseAgentDueDate(', '_guideController.parseAgentDueDate('),
        ('_findAgentTargetTaskByArguments(', '_guideController.findAgentTargetTaskByArguments('),
        # GuideService → GuideController (specific first, then general)
        ('_guideService.saveDisplayName(', '_guideController.saveDisplayName('),
        ('_guideService.nightReflection(', '_guideController.nightReflection('),
        ('_guideService.generatePortrait(', '_guideController.generatePortrait('),
        ('_guideService.acceptEvent(', '_guideController.acceptEvent('),
        ('_guideService.', '_guideController.guideService.'),
        # Type renames (private → public)
        ('_GuideConnectionStatus.ready', 'GuideConnectionStatus.ready'),
        ('_GuideConnectionStatus', 'GuideConnectionStatus'),
        ('_GuideChatMessage(', 'GuideChatMessage('),
        ('_GuideChatMessage', 'GuideChatMessage'),
        ('_GuideTurnResponse', 'GuideTurnResponse'),
        ('_GuideRewardMatch', 'GuideRewardMatch'),
        ('_GuideActionType', 'GuideActionType'),
        ('_AgentRunResult', 'AgentRunResult'),
        ('_QuickCreateMode', 'QuickCreateMode'),
        ('_QuickCreateDialogResult', 'QuickCreateDialogResult'),
        ('_QuickCreateDialogBody', 'QuickCreateDialogBody'),
        ('_PortraitInsightData', 'PortraitInsightData'),
        ('_PortraitInsightChart', 'PortraitInsightChart'),
        ('_PortraitEvaluationSection', 'PortraitEvaluationSection'),
        ('_PortraitReadableMetricGrid', 'PortraitReadableMetricGrid'),
        ('_PlusMenuItem', 'PlusMenuItem'),
        ('_SettingsSectionCard', 'SettingsSectionCard'),
        ('_SettingsToggleTile', 'SettingsToggleRow'),
        ('_SettingsChoicePill', 'SettingsChoicePill'),
        ('_MemoryRecommendationCards', 'MemoryRecommendationCards'),
    ]

    for old, new in replacements:
        content = content.replace(old, new)

    # Fix double controller references
    content = content.replace('_guideController._guideController.', '_guideController.')
    content = content.replace('_guideController.guideController.', '_guideController.')

    # Remove unused imports (keep ones STAY methods still need)
    unused_imports = [
        "import 'package:fl_chart/fl_chart.dart';\n",
        "import '../services/agent_run_service.dart';\n",
        "import '../services/weekly_summary_job_service.dart';\n",
        "import '../../../core/services/local_agent_runtime_service.dart';\n",
    ]
    for imp in unused_imports:
        content = content.replace(imp, '')

    # Clean up blank lines
    content = re.sub(r'\n{4,}', '\n\n\n', content)

    lines_out = content.split('\n')
    print(f"Final: {len(lines_out)} lines")
    write_file(FILE, content)
    print("Done!")

if __name__ == '__main__':
    main()
