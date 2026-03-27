# PRD-08-产品定位与体验对齐

## 文档信息

- 日期：2026-03-25
- 执行者：Codex
- 范围：README、部署站首屏、产品核心体验、演示视频

## 背景

Earth Online 当前已经具备任务板、等级成长、奖励系统、记忆感知助手、日常事件、记忆画像、周报与生活日记等能力，但“效率游戏”“记忆感知”“陪伴引导”这三个核心卖点在不同触点上的传达强度不一致。

当前主要问题不是“继续解释产品是什么”，而是让用户在进入部署站、观看视频、阅读 README、实际体验产品时，都能稳定感受到同一件事：

> Earth Online 是一个有记忆、会引导、带陪伴感的效率游戏。

## 核心目标

1. 让“效率游戏”被产品体验本身证明，而不只停留在文案。
2. 让“记忆感知能力”在界面和流程中可见、可理解、可复述。
3. 让“陪伴感”从功能描述升级为真实连续体验。
4. 让 README、演示视频、部署站首屏围绕同一定位完全对齐。
5. 让新用户在首屏和前 1 分钟内就理解产品差异性。

## 需求清单与当前状态

### 1. “效率游戏”概念要被产品体验证明

状态：部分解决

当前已具备：

- Quest Board、XP、等级、奖励、成就、背包等成长反馈已经存在。
- 新手引导任务明确带用户经历“输入任务 -> 完成任务 -> 助手对话 -> 查看记忆画像”。
- README 已把产品表述为 “memory-aware productivity game”。

当前不足：

- 部署站首屏仍然更像通用登录页，没有在第一眼强调“这是一个效率游戏”。
- 应用标题仍是 `Gamified Quest Log`，与 Earth Online 品牌和“陪伴式效率游戏”定位未完全统一。
- 用户未登录前，很难直接感受到“持续反馈”和“演化感”。

证据：

- `README.md`
- `README.zh-CN.md`
- `frontend/lib/main.dart`
- `frontend/lib/features/auth/screens/login_screen.dart`
- `frontend/lib/features/quest/screens/home_page.dart`

### 2. “记忆感知能力”要更可见

状态：部分解决，接近完成

当前已具备：

- 首页启动时会调用 `guide-bootstrap`，将 `memoryDigest` 和行为信号带入引导体验。
- Guide 面板中明确展示“{name} 记得 / {name} Remembers”以及记忆摘要。
- 对话回复会显示引用了多少段近期记忆。
- 每日事件会展示“记忆依据 / Memory Basis”。
- 记忆画像直接以“Memory-Driven Portrait / 记忆驱动画像”命名。
- README 与演示视频脚本都明确解释了系统会记住什么，以及为什么建议不是模板化输出。

当前不足：

- 首次进入登录页时，记忆能力仍然不可见。
- 产品中已经有“记忆摘要”和“引用条数”，但“系统记住了什么”还可以更结构化展示，比如最近完成事项、节奏变化、恢复信号等。
- 这些能力在主导航与首页首屏中的入口优先级仍不够高。

证据：

- `frontend/lib/features/quest/screens/home_page.dart`
- `frontend/lib/core/i18n/app_locale_controller.dart`
- `README.md`
- `README.zh-CN.md`
- `promo-video/src/scenes.ts`
- `promo-video/src/scenes.zh.ts`

### 3. “陪伴感”需要更强的真实感

状态：部分解决

当前已具备：

- 助手可命名，具备稳定身份感。
- 首页首次打开会主动发起一句问候。
- Guide 面板提供“陪我聊聊 / Stay with me”等动作入口。
- 夜间反思、周报、生活日记构成了跨时段反馈链路。
- 助手对话、每日事件和记忆画像都共享同一层记忆能力。

当前不足：

- 陪伴感主要集中在已登录后的 Guide 面板，不是整个产品外显气质。
- 部署站首屏和登录页没有明显传达“这是会持续陪着你推进的一位助手”。
- 当前体验仍有较强“任务面板 + 弹窗助手”的结构感，连续陪伴感还不够自然。

证据：

- `frontend/lib/features/quest/screens/home_page.dart`
- `frontend/lib/core/i18n/app_locale_controller.dart`
- `README.zh-CN.md`

### 4. README、演示视频、部署站需要彻底对齐

状态：部分解决

当前已具备：

- README 中英双语版本已经围绕“有记忆的效率游戏”和“懂陪伴的助手”展开。
- 演示视频脚本已经围绕“记忆 -> 引导 -> 陪伴式推进”的完整故事编排。
- 中英双语视频与海报产物已存在。

当前不足：

- 部署站首屏没有同步 README 和视频中的核心卖点强度。
- 在线站入口仍无法快速复述“有记忆、会引导、像陪伴式效率游戏”这组核心标签。
- README 和视频的叙事强于真实落地首屏，存在认知落差。

证据：

- `README.md`
- `README.zh-CN.md`
- `output/earth-online-intro.mp4`
- `output/earth-online-intro-zh.mp4`
- `promo-video/src/scenes.ts`
- `promo-video/src/scenes.zh.ts`
- `frontend/lib/features/auth/screens/login_screen.dart`

### 5. 部署首页要更快传达核心价值

状态：未解决

当前问题：

- 登录页核心信息仍然只有 “Welcome to Earth Online”。
- 页面没有在首屏明确回答“这是什么”“与普通待办工具有什么不同”“为什么值得继续体验”。
- 首屏缺少强定位文案、核心卖点摘要和清晰的体验入口设计。

结论：

- 这是当前最明显的短板。
- 如果要优先改一处，应该优先改部署站首屏和登录前落地页。

证据：

- `frontend/lib/features/auth/screens/login_screen.dart`
- `frontend/lib/main.dart`

### 6. 演示视频应该展示完整用户故事

状态：已较好解决

当前已具备：

- 视频脚本按照“进入产品 -> 输入任务 -> 完成任务 -> 记忆沉淀 -> 助手读取记忆 -> 给出建议 -> 每日事件接入任务板 -> 日记/周报形成连续故事”的顺序组织。
- 不只是静态展示页面，而是在讲一个完整体验链路。
- 中英双语脚本都保持了同样的叙事结构。

当前风险：

- 需要保证后续 UI 演进时，视频同步更新，不让视频再次落后于线上产品。

证据：

- `promo-video/src/scenes.ts`
- `promo-video/src/scenes.zh.ts`
- `promo-video/src/voice-lines.json`
- `promo-video/src/voice-lines.zh.json`

### 7. 核心亮点需要更可被复述

状态：部分解决

当前已具备：

- README 中已经能提炼出“memory-aware productivity game”“quest board + assistant that remembers”。
- 中文 README 也已经接近“任务面板、有记忆、懂陪伴的助手”的一句话标签。
- 视频脚本已经在不断重复“记忆不是存档，而是帮助用户带着上下文重新启动”。

当前不足：

- 这些标签还没有在部署站首屏被固定成一句极强的产品介绍。
- 当前线上入口还不足以让第一次访问者快速复述项目独特性。
- 项目内对外标题仍不统一，比如 `Gamified Quest Log` 过于通用。

建议优先候选标签：

- 有记忆的任务助手
- 陪伴式效率游戏
- 基于历史行为的引导系统

证据：

- `README.md`
- `README.zh-CN.md`
- `frontend/lib/main.dart`
- `promo-video/src/scenes.ts`
- `promo-video/src/scenes.zh.ts`

## 当前总评

### 已经做得较好的部分

- README 定位已经比较清楚。
- 视频脚本与视频资产已经开始围绕“记忆驱动的效率体验”讲故事。
- 已登录后的产品内体验，尤其是 Guide、每日事件、记忆画像、周报与日记，已经能支撑“记忆感知”和“陪伴引导”。

### 当前最需要优先补的部分

1. 部署站首屏价值传达
2. 登录前后的核心定位统一
3. “效率游戏”在首分钟体验中的显性证明
4. “记忆系统记住了什么”的更结构化可见化

## 后续执行建议

### P0

- 重做部署站首屏或登录首屏文案与结构，让用户 10 秒内理解核心定位。
- 统一产品对外一句话标签，并替换 `Gamified Quest Log` 等泛化命名。

### P1

- 在首页或 Guide 首屏增加更明确的“记忆证据面板”。
- 把“为什么推荐这件事”与“系统记住了哪些线索”表达得更直白。

### P2

- 将 README、视频文案、首屏文案统一为同一套核心表述。
- 每次 UI 或流程调整后同步审查视频脚本与 README 是否仍匹配。
