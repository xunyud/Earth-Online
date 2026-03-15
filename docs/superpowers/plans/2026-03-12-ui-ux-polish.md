# UI UX 体验全面重构 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完成 Quest 首页与 AI 画像相关 UI/UX 全面重构，去除刺眼配色并提升记忆展示与交互品质。

**Architecture:** 以现有 Flutter 页面和服务层为基础，不改核心业务链路。主要通过 Home 页面 UI 重绘、QuestController 提示风格重构、EverMemOS 画像数据结构增强来实现。交互升级采用渐进式增强：先保证可读，再加展开详情和温和错误反馈。

**Tech Stack:** Flutter (Material), fl_chart, Supabase, http, existing QuestTheme/AppColors.

---

## Chunk 1: 提示框与顶部操作区

### Task 1: 提示框白底化与边框语义重构

**Files:**
- Modify: `frontend/lib/features/quest/controllers/quest_controller.dart`

- [ ] Step 1: 将鼓励语提示改为白底深色文本 + 浅绿边框
- [ ] Step 2: 将任务完成提示改为白底浅绿边框
- [ ] Step 3: 将撤销任务提示改为白底灰边框
- [ ] Step 4: 跑 `flutter test` 验证无回归

### Task 2: 顶部按钮交互与视觉统一

**Files:**
- Modify: `frontend/lib/features/quest/screens/home_page.dart`

- [ ] Step 1: 上传按钮在上传中切换为轻量 loading 图标
- [ ] Step 2: 上传按钮文案增加描边/立体阴影效果
- [ ] Step 3: 生成画像按钮改用“水晶球”视觉（emoji/图标）并做对齐
- [ ] Step 4: 检查 AppBar actions 对齐与 spacing

## Chunk 2: 地球日记与记忆片段体验

### Task 3: 地球日记悬浮窗重塑 + 温和异常反馈

**Files:**
- Modify: `frontend/lib/features/quest/screens/home_page.dart`

- [ ] Step 1: 日记弹窗改米白底（书卷质感）
- [ ] Step 2: 重写文案为更温暖的人情化表达
- [ ] Step 3: 错误提示改为温和可重试文案

### Task 4: 近期记忆片段降噪 + 详情展开

**Files:**
- Modify: `frontend/lib/core/services/evermemos_service.dart`
- Modify: `frontend/lib/features/quest/screens/home_page.dart`
- Modify: `frontend/test/evermemos_service_test.dart`

- [ ] Step 1: 服务层输出结构化片段（时间、summary/content、full text）
- [ ] Step 2: 时间格式简化为“今天 HH:mm / M月d日”
- [ ] Step 3: UI 用卡片列表展示片段并支持点击查看详情
- [ ] Step 4: 优化 AI 分析文案深度（更具体）
- [ ] Step 5: 跑单测 + 全量测试

## Chunk 3: 视觉一致性与验证

### Task 5: 禁紫令与视觉复查

**Files:**
- Modify: `frontend/lib/core/constants/app_colors.dart`
- Modify: `frontend/lib/features/achievement/screens/achievement_page.dart`
- Modify: `frontend/lib/features/achievement/widgets/achievement_unlock_overlay.dart`
- Modify: `frontend/lib/features/reward/screens/inventory_page.dart`

- [ ] Step 1: 替换紫色 token/硬编码颜色为绿色系
- [ ] Step 2: 全仓扫描无紫色残留
- [ ] Step 3: 运行 Playwright 脚本观察 UI 回归

Plan complete and saved to `docs/superpowers/plans/2026-03-12-ui-ux-polish.md`.
