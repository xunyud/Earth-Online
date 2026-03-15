# Flutter Frontend Design System: "Fresh Breath"

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 全面升级 Flutter 前端界面，打造“清新、简约、留白”的视觉体验。

**Design Direction:**
- **Tone:** 清新治愈 (Fresh & Healing), 极简主义 (Minimalist), 呼吸感 (Airy).
- **Palette:**
    - Primary: Mint Green (薄荷绿) - 清新、活力
    - Secondary: Sky Blue (天蓝) - 开阔、平静
    - Background: Off-White (米白/Warm White) - 柔和、护眼
    - Surface: Pure White - 干净、突出
    - Text: Dark Grey (深灰) - 清晰、不刺眼
- **Typography:** 现代无衬线字体 (Sans Serif), 强调字重对比 (Bold Headings vs Light Body).
- **Shape:** 大圆角 (Rounded Corners), 柔和阴影 (Soft Shadows).

**Architecture:**
- **Theme:** Refactor `QuestTheme` to support the new system.
- **Components:** Redesign `QuestItem`, `QuickAddBar`, `TierSection`.
- **Layout:** Optimize spacing and padding in `QuestBoard`.

---

### Task 1: 定义设计系统 (Design System)

**Files:**
- Modify: `frontend/lib/core/theme/quest_theme.dart`
- Create: `frontend/lib/core/constants/app_colors.dart`
- Create: `frontend/lib/core/constants/app_text_styles.dart`

**Step 1: 定义调色板 (AppColors)**
- `mintGreen`: 0xFF98FF98
- `skyBlue`: 0xFF87CEEB
- `warmWhite`: 0xFFFDFDF0
- `pureWhite`: 0xFFFFFFFF
- `textPrimary`: 0xFF333333
- `textSecondary`: 0xFF666666

**Step 2: 定义排版 (AppTextStyles)**
- `heading1`: 24sp, Bold, textPrimary
- `heading2`: 20sp, SemiBold, textPrimary
- `body`: 16sp, Regular, textSecondary
- `caption`: 14sp, Light, textSecondary

**Step 3: 更新 QuestTheme**
- 更新 `QuestTheme` 扩展，使其支持这些新定义的颜色和样式。
- 移除旧的 "Dark Souls" 风格，专注于 "Fresh Breath" 风格（虽然保留接口，但主力实现新风格）。

### Task 2: 重构基础组件 (Base Components)

**Files:**
- Modify: `frontend/lib/features/quest/widgets/quest_item.dart`
- Modify: `frontend/lib/features/quest/widgets/quick_add_bar.dart`

**Step 1: Redesign QuestItem**
- **Card**: 使用 `pureWhite` 背景，大圆角 (16dp)，超柔和阴影 (blur: 10, spread: 0, color: black05)。
- **Checkbox**: 自定义圆形 Checkbox，选中时变成实心薄荷绿。
- **Typography**: 标题使用 `heading2`，副标题使用 `caption`。
- **Animation**: 增加 Hover 时的轻微上浮效果（Scale + Shadow）。

**Step 2: Redesign QuickAddBar**
- **Container**: 悬浮感设计，圆角矩形，离底部有一定距离。
- **TextField**: 去除边框，背景透明或极淡灰色，占位符文字颜色更浅。
- **Button**: 圆形按钮，薄荷绿背景，白色图标，点击波纹效果。

### Task 3: 优化布局与层级 (Layout & Hierarchy)

**Files:**
- Modify: `frontend/lib/features/quest/widgets/quest_board.dart`
- Modify: `frontend/lib/features/quest/widgets/tier_section.dart`

**Step 1: Redesign TierSection**
- 移除背景色块，改为纯文字标题 + 装饰性小图标（如小叶子）。
- 增加上下间距 (Padding: vertical 24)。

**Step 2: Optimize QuestBoard**
- 增加整体 `ListView` 的 Padding (horizontal 20)。
- 调整 Item 之间的间距 (SizedBox height 12)。

### Task 4: 细节与微交互 (Micro-interactions)

**Files:**
- Modify: `frontend/lib/features/quest/screens/home_page.dart`

**Step 1: Loading Animation**
- 替换默认的 CircularProgressIndicator 为更符合主题的动画（如薄荷绿的脉冲圆点）。

**Step 2: Transitions**
- 确保列表项插入时的动画流畅。

---

### Execution Plan

1.  **Foundations**: Create Colors & Styles. Update Theme.
2.  **Components**: Redesign Item & Input.
3.  **Layout**: Polish Board & Sections.
4.  **Review**: Verify visual consistency.
