# EverMemOS 黑客松三分钟 Demo 视频设计规格

> 日期：2026-04-02
> 执行者：Codex

## 1. 背景

本视频用于 EverMemOS 黑客松 / 比赛场景下的三分钟产品 demo。用户当前参赛作品面向个人用户，核心价值不是“又一个任务管理器”，而是通过长期记忆帮助用户记住任务、承接日程、生成总结，并在恰当的时候主动提醒与关心用户，从而降低压力。

已确认的制作前提：

- 视频主语言为英文。
- 用户可提供真实产品录屏，并可补录操作过程。
- 产品最核心的情绪价值是“主动提醒 / 主动关心”。
- 最合适的叙事方向为 `Stress Relief Arc`：从压力感进入，到被记住、被承接、被照顾，最后落到轻松与清晰感。

## 2. 目标

- 在 30 秒内让评委理解产品不是普通待办工具，而是 memory-native companion。
- 在 3 分钟内证明产品具备三个连续价值：
  - 记住任务与上下文
  - 减少用户重复组织信息的负担
  - 在合适时间主动提醒与关心
- 用真实录屏证明产品能力，用 Remotion 动效放大节奏、情绪和信息密度。

## 3. 非目标

- 不把视频拍成技术架构讲解。
- 不用纯动画替代真实产品证据。
- 不追求一次展示全部功能，而是只保留最强的 5 个证明片段。
- 不新增独立视频工程；后续实现应尽量复用现有 `promo-video` 的 Remotion 结构。

## 4. 核心叙事

### 4.1 主线

整支视频采用 `压力 -> 记忆 -> 主动关心 -> 缓解压力` 的单线叙事。

### 4.2 核心定位句

建议视频始终围绕以下定位展开：

`This is not just task management. It is memory that helps people feel less overwhelmed, more organized, and more cared for.`

### 4.3 评委应感知到的结论

- 产品记住的是“用户真实生活里的任务与状态”，不是单次 prompt。
- 记忆的结果不是堆数据，而是更轻的认知负担。
- 主动提醒和主动关心不是硬推送，而是来自被记住的上下文。

## 5. 三分钟时间轴

### 5.1 0:00 - 0:20 Problem

- 目标：先让观众感受到 mental overload。
- 画面：任务、提醒、日程、笔记的高压快切；可混合真实 UI 截图和 Remotion 卡片动画。
- 英文旁白：
  - `Most people are not short on goals. They are short on mental space.`
- 屏幕文案：
  - `Too many tasks.`
  - `Too many reminders.`
  - `Too much to hold alone.`

### 5.2 0:20 - 0:40 Product Promise

- 目标：明确产品不是传统任务工具。
- 画面：主界面平稳出场，整体节奏由紧张转为清晰。
- 英文旁白：
  - `We built a memory-native companion that remembers what matters, follows up at the right time, and helps reduce daily stress.`
- 屏幕文案：
  - `Remember. Follow up. Reduce stress.`

### 5.3 0:40 - 1:10 Memory Across Tasks

- 目标：证明系统可以记住任务、上下文和优先级。
- 画面：用户录入任务和背景；稍后再次打开时，系统自然接上上下文。
- 英文旁白：
  - `Instead of asking users to repeat themselves, our system keeps track of tasks, context, and priorities over time.`
- 屏幕文案：
  - `No repeated setup.`
  - `No lost context.`

### 5.4 1:10 - 1:40 Less Cognitive Load

- 目标：把“记住”转化成“更清楚现在该做什么”。
- 画面：产品整理优先级、展示 next step、突出 urgent / can wait 等信息。
- 英文旁白：
  - `That memory becomes useful structure. It helps the user see what needs attention now, without carrying every detail in their head.`
- 屏幕文案：
  - `Clarity, not clutter.`

### 5.5 1:40 - 2:20 Proactive Care

- 目标：打出整支视频最重要的情绪峰值。
- 画面：系统在合适时机主动提醒、提示用户停下来整理、或给出柔和关心。
- 英文旁白：
  - `But the real value is not just recall. It is timing.`
  - `When the system notices pressure building, it can check in gently, remind the user what matters, and help them feel supported.`
- 屏幕文案：
  - `The right reminder.`
  - `At the right time.`

### 5.6 2:20 - 2:45 Weekly Summary

- 目标：证明记忆不仅用于提醒，也用于沉淀。
- 画面：周报、总结卡片、阶段性反思页面。
- 英文旁白：
  - `Because memory compounds, the product can also turn a week of scattered tasks into a clear summary, a useful report, and a better starting point for the next week.`
- 屏幕文案：
  - `From scattered days to clear reflection.`

### 5.7 2:45 - 3:00 Closing

- 目标：留下稳定定位与轻松收束。
- 画面：平静的尾屏、产品名称、简洁 tagline。
- 英文旁白：
  - `This is not just task management. It is memory that helps people feel less overwhelmed, more organized, and more cared for.`
- 屏幕文案：
  - `A memory-native companion for everyday life.`

## 6. 录制素材清单

后续优先录制以下 5 段真实 proof clips，每段建议保留 20-45 秒原始素材，便于后期裁剪：

1. 用户输入任务、日程和当前压力背景
2. 稍后重新进入产品，系统自然承接之前任务与上下文
3. 产品帮助用户理清当下优先级或下一步动作
4. 产品主动提醒、主动 check-in、或主动关心用户
5. 产品输出周报 / 总结 / 阶段性反思

录制要求：

- 优先 1080p 横屏录制。
- 一段只证明一件事，避免把多个功能塞进同一条录屏。
- 鼠标移动和页面切换尽量稳，留足头尾缓冲。
- 如果可能加入时间感变化，能更好证明“跨时刻记忆”。

## 7. Remotion 分工

### 7.1 真实录屏负责

- 核心产品功能证明
- 记忆 continuity 的真实界面表现
- 主动提醒 / 主动关心的可信时刻
- 周报 / 总结的真实产物

### 7.2 Remotion 负责

- 开头压力蒙太奇
- 字幕系统与 scene title
- “记住了什么”的高亮标注
- 从焦虑到平静的转场
- 结尾定位页与整体节奏包装

### 7.3 制作原则

- 动画只负责 framing，不负责虚构核心能力。
- 任何主价值证明必须来自真实产品录屏。
- 如果某一段真实证据不够强，优先补录，不用动画硬补。

## 8. 与现有工程的集成方式

后续视频实现建议复用现有 `promo-video` 结构：

- `promo-video/src/Root.tsx`
  - 当前已通过 `Composition` 注册视频入口，适合新增 EverMemOS 专用 composition。
- `promo-video/src/scenes.ts`
  - 当前采用 scene 数据驱动，适合复用为新的 demo scene 配置文件。
- `promo-video/src/voice-lines.json`
  - 若后续需要自动化旁白生成，可继续沿用该模式。
- `promo-video/public`
  - 用于存放录屏素材、静态卡片、截图等资源。

建议新增而非覆盖现有 Earth Online 相关组件，以避免和当前未提交修改冲突。

## 9. 最小制作路径

建议后续制作顺序如下：

1. 先录完 5 段 proof clips
2. 根据本设计规格，裁出 3 分钟粗剪
3. 在 Remotion 中补开头压力段、字幕、callout、转场和结尾
4. 最后统一检查节奏、字幕可读性和音频平衡

## 10. 风险与控制

- 风险：开头 20 秒太慢，评委无法快速进入问题场景
  - 控制：用快切和高对比字幕迅速建立压力感
- 风险：主动关心片段不够自然，容易显得“假温柔”
  - 控制：只展示真实最稳的 check-in 场景，不堆多条提醒
- 风险：功能展示过多，削弱主线
  - 控制：坚持只服务三件事：记住、减压、主动关心

## 11. 交付结论

当前视频设计已确认通过，后续应直接进入素材录制与 Remotion 实现阶段。优先顺序不是“先做动效”，而是“先拿到真实证据，再做节奏包装”。
