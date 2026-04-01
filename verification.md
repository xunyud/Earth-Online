# Verification
## 2026-04-01 Supabase migration remote apply verification

- 执行者：Codex
- 目标项目：`ndbhxjvrgxeuyykrlyxl`
- 执行命令：
  - `.\supabase.ps1 db push`
  - `.\supabase.ps1 db push`（二次验证）
- 执行结果：
  - 首次 `db push` 成功，远端实际应用了以下待推 migration：
    - `20260326100000_fix_checkin_rpc_date_cast.sql`
    - `20260326200000_makeup_checkin.sql`
    - `20260331174000_add_daily_due_minutes_to_quest_nodes.sql`
  - 二次 `db push` 返回 `Remote database is up to date.`，说明远端 migration 状态已与本地对齐。
- 补充观察：
  - `.\supabase.ps1 migration list` 曾因数据库直连 TLS timeout 失败，但不影响通过 pooler workaround 执行的 `db push` 成功，也不影响二次 `db push` 的对齐验证。

## 2026-04-01 Windows NuGet availability verification

- 执行者：Codex
- 执行步骤：
  - 将现有构建目录中的 `nuget.exe` 复制到 `C:\Users\pclou\.local\bin\nuget.exe`
  - 执行 `where.exe nuget`
  - 执行 `flutter build windows --debug`
- 验证结果：
  - `where.exe nuget` 返回 `C:\Users\pclou\.local\bin\nuget.exe`
  - `flutter build windows --debug` 成功，输出 `✓ Built build\windows\x64\runner\Debug\frontend.exe`
  - 重新验证过程中已不再出现 `Nuget is not installed.` 提示
- 补充观察：
  - `webview_windows` 仍会输出一个 CMake 开发告警（`CMP0175`），但不影响构建成功。
  - 如果重复执行 `flutter run -d windows`，仍需先关闭已打开的应用窗口，否则可能再次遇到 DLL/EXE 文件锁定问题。


## 2026-03-31 手动创建任务语义修正验证

- 执行者：Codex
- 变更结论：
  - 手动创建默认任务类型改为主线任务，支线任务必须明确选择所属主线。
  - 日常任务改为使用 `daily_due_minutes` 表达“每天几点截止”，不再复用日期型 `due_date`。
  - 每日任务重置逻辑已真正接入任务加载流程，跨天后会自动恢复为未完成。
- 验证命令：
  - `flutter test test/quest_manual_creation_source_test.dart test/quest_controller_daily_reset_source_test.dart test/quest_node_test.dart`
  - `dart analyze lib/features/quest/controllers/quest_controller.dart lib/features/quest/screens/home_page.dart lib/features/quest/widgets/quest_edit_sheet.dart lib/features/quest/widgets/quest_item.dart`
- 验证结果：
  - 上述测试全部通过。
  - 上述静态分析全部通过，无新增问题。
- 风险说明：
  - 本轮尚未执行全量 Flutter 测试，仅覆盖任务语义与相关文件。
  - 数据库侧新增了 `supabase/migrations/20260331174000_add_daily_due_minutes_to_quest_nodes.sql`，需要在目标 Supabase 环境执行后，日常截止时间字段才能完整落库。

- 日期：2026-03-15
- 执行者：Codex

## 已验证内容

- 抽屉顶部个人资料区已重构为更有层次的渐变头部，保留原有菜单导航能力。
- 用户可以在抽屉内直接修改昵称，保存后会写入 `SharedPreferences`，再次加载时仍可恢复。
- 用户可以选择本地照片作为头像，头像会先压缩再转为 base64 存储，重新进入页面后仍可显示。
- 新增资料控制层后，没有改动现有任务控制器、设置入口、专属向导入口和退出登录流程。

## 命令结果摘要

- `flutter analyze lib/core/services/preferences_service.dart lib/core/widgets/app_drawer.dart lib/features/profile/controllers/user_profile_controller.dart lib/features/profile/services/profile_avatar_picker.dart test/preferences_service_test.dart test/profile_preferences_source_test.dart test/app_drawer_profile_source_test.dart test/user_profile_controller_test.dart test/app_drawer_profile_widget_test.dart`：通过，无新增问题。
- `flutter test test/profile_preferences_source_test.dart test/app_drawer_profile_source_test.dart test/preferences_service_test.dart test/user_profile_controller_test.dart test/app_drawer_profile_widget_test.dart`：通过，9/9 测试通过。

## 风险说明

- 本次验证聚焦于改动相关的测试子集，尚未执行全量 Flutter 测试。
- 头像目前为本地持久化方案；如果未来需要跨设备同步，还需要与后端用户资料打通。

## 2026-03-15 交互收口补充验证

### 已验证内容

- 登录页顶部已移除“轻微动态氛围”入口。
- 抽屉资料头部已移除“更换头像”按钮，只保留“修改昵称”入口。
- 点击头像会直接调用头像选择逻辑，不再先弹出重复的底部操作面板。

### 命令结果摘要

- `flutter test test/app_drawer_profile_source_test.dart test/app_drawer_profile_widget_test.dart test/login_screen_source_test.dart`：通过，4/4 测试通过。
- `flutter analyze lib/core/widgets/app_drawer.dart lib/features/auth/screens/login_screen.dart test/app_drawer_profile_source_test.dart test/app_drawer_profile_widget_test.dart test/login_screen_source_test.dart`：通过，无新增问题。

## 2026-03-15 头像上传根因修复

### 根因结论

- 当前运行环境为 Windows 桌面端。
- 头像上传原先使用 `image_picker`，用户反馈“点击头像无法上传”。
- 结合当前桌面端运行环境与依赖链检查，本次将头像选择服务改为更直接的 `file_picker` 文件选择路径，以规避原桌面链路不稳定问题。

### 已验证内容

- 抽屉头部已删除“本地资料”标签。
- 头像选择服务已不再依赖 `image_picker`，改为 `file_picker`。
- 点击头像后仍能完成昵称编辑之外的头像上传主路径。

### 命令结果摘要

- `flutter test test/app_drawer_profile_source_test.dart test/profile_avatar_picker_source_test.dart test/app_drawer_profile_widget_test.dart test/login_screen_source_test.dart`：通过，5/5 测试通过。
- `flutter analyze lib/core/widgets/app_drawer.dart lib/features/profile/services/profile_avatar_picker.dart lib/features/auth/screens/login_screen.dart test/app_drawer_profile_source_test.dart test/profile_avatar_picker_source_test.dart test/app_drawer_profile_widget_test.dart test/login_screen_source_test.dart`：通过，无新增问题。
## 2026-03-23 微信转型第一阶段验证

### 外部信息核验

- 使用 `exa` 检索了 2026-03-22 微信 ClawBot / OpenClaw 相关公开信息。
- 交叉得到的稳定结论是：这次更新的定位更接近“官方消息通道”，当前公开边界包括逐步放量、个人单点使用、不能加入群聊、不会自动操作用户微信。
- 参考来源：
  - https://cloud.tencent.com/developer/article/2643875
  - https://finance.sina.com.cn/tech/roll/2026-03-22/doc-inhrvnpc5217319.shtml
  - https://finance.sina.com.cn/wm/2026-03-22/doc-inhrvnpc5220673.shtml?froms=ggmp

### 已验证内容

- `guide_dialog_logs` 已新增结构化建议任务承载位对应的 migration，供微信“收下建议”复用。
- `guide_engine` 已支持写入 assistant 结构化 `suggested_task` / `quick_actions`，并能读取、接受最近一次微信建议任务。
- `wechat-webhook` 已支持三类已绑定消息分流：
  - `问村长：...` 走记忆驱动对话
  - `收下建议` 接受最近一次建议任务
  - 其他文本继续走原有任务录入与 `parse-quest` 异步解析

### 命令结果摘要

- `deno test --allow-env supabase/functions/_shared/guide_engine_test.ts supabase/functions/_shared/wechat_agent_test.ts`
  - 通过，9/9 测试通过
- `deno check supabase/functions/wechat-webhook/index.ts`
  - 通过，无类型错误

### 风险说明

- 本轮主要验证了共享逻辑与 webhook 编译/分流能力，尚未做真实微信环境联调。
- `guide_dialog_logs.extra_payload` 需要在目标 Supabase 环境执行新 migration 后，微信“收下建议”才能完整依赖结构化日志工作。
## 2026-03-23 助手名账号级同步验证

### 已验证内容

- `guide_user_settings` 已补充 `display_name` migration，用于存储账号级助手名。
- `GuideService` 已支持读取服务端助手名并在编辑时写回服务端。
- `HomePage` 已在本地缓存与服务端之间做同步，保证 App 改名后微信链路能读到同一名字。
- `guide_engine` / `wechat-webhook` 已统一使用服务端优先的名字解析结果，微信回复会带上同步后的助手名。

### 命令结果摘要

- `deno test --allow-env supabase/functions/_shared/guide_engine_test.ts supabase/functions/_shared/wechat_agent_test.ts`
  - 通过，11/11 测试通过。
- `deno check supabase/functions/wechat-webhook/index.ts`
  - 通过，无类型错误。
- `flutter test test/home_page_guide_name_sync_source_test.dart`
  - 通过，1/1 测试通过。
- `dart format lib/core/services/guide_service.dart lib/features/quest/screens/home_page.dart test/home_page_guide_name_sync_source_test.dart`
  - 通过，格式化 3 个文件。
- `deno fmt supabase/functions/_shared/guide_engine.ts supabase/functions/_shared/guide_engine_test.ts supabase/functions/_shared/wechat_agent.ts supabase/functions/_shared/wechat_agent_test.ts supabase/functions/wechat-webhook/index.ts`
  - 通过，检查/格式化 5 个文件。

### 风险说明

- 目标环境仍需执行 `supabase/migrations/20260323103000_add_guide_display_name_to_settings.sql`，否则微信侧拿不到账号级助手名。
- 本轮尚未做真实微信环境联调，当前验证范围是本地测试、静态检查和 Edge Function 编译链路。
## 2026-03-23 微信真实联调与第二阶段验证

### 线上前置条件执行结果

- 通过真实线上函数 `apply-display-name-migration` 临时执行 SQL，补齐了：
  - `guide_user_settings.display_name`
  - `guide_dialog_logs.extra_payload`
- 通过真实线上探测确认 `wechat-webhook` 在关闭 JWT 校验并重新部署后，`GET /functions/v1/wechat-webhook?echostr=...` 已从 `401` 变为 `200`，可被微信服务器无鉴权访问。
- 真实测试链路已完成并清理测试数据：
  - 创建临时测试用户
  - 写入绑定码并通过真实 webhook 完成绑定
  - 设置账号级助手名 `Amu`
  - 发送微信聊天消息并收到带 `Amu：` 前缀的真实回复
  - 发送 `收下建议` 并确认真实写入 `quest_nodes`
  - 删除临时测试用户、绑定码、日志、任务与设置数据

### 第二阶段自动分流验证

- 不带前缀的求助句 `我现在很乱，帮我稳一下节奏` 已在真实线上走聊天分流，并返回带助手名前缀的回复。
- 明显待办句 `明天下午去医院复诊` 已在真实线上继续走任务录入分流，并返回“任务已收到，正在由 AI 解析中”。
- 本地解析规则新增了自然语言求助/恢复建议识别，显式前缀、`收下建议` 与原任务录入路径保持不变。

### 命令结果摘要

- `deno test --allow-env supabase/functions/_shared/guide_engine_test.ts supabase/functions/_shared/wechat_agent_test.ts`
  - 通过，13/13 测试通过。
- `deno check supabase/functions/wechat-webhook/index.ts`
  - 通过，无类型错误。
- 线上执行 `POST /functions/v1/apply-display-name-migration`
  - 返回 `success: true`，并确认两列均存在。
- 线上执行 `GET /functions/v1/wechat-webhook?echostr=codex-live-check-2`
  - 返回 `200` 与原样 `echostr`。

### 风险说明

- 本轮第二阶段采用的是轻量规则分流，不是模型级意图分类；复杂模糊句子仍可能存在误判空间。
- `supabase/.temp/cli-latest` 仅有行尾差异，为 CLI 运行时文件变化，不影响功能。

## 2026-03-23 compact 中断后的定点复核

### 已验证内容

- 仅围绕微信 / guide / display name / task suggestion 相关未提交改动复核，未重做实现。
- 当前工作区中的主线能力仍保持可用：
  - `guide_engine` 的建议任务结构化日志与“收下建议”接受逻辑
  - `wechat-webhook` 的显式前缀聊天、自然语言轻分流与原任务录入链路
  - `HomePage` 与 `GuideService` 的助手显示名账号级同步

### 命令结果摘要

- `deno test --allow-env supabase/functions/_shared/guide_engine_test.ts supabase/functions/_shared/wechat_agent_test.ts`
  - 通过，13/13 测试通过。
- `deno check supabase/functions/wechat-webhook/index.ts`
  - 通过，无类型错误。
- `flutter test test/home_page_guide_name_sync_source_test.dart`
  - 通过，1/1 测试通过。

### 风险说明

- 这次复核没有新增业务改动，主要是确认 compact 中断前的工作区代码仍然一致可用。
- 自动分流仍依赖轻量规则；若后续线上出现模糊句误判，应优先在 `supabase/functions/_shared/wechat_agent.ts` 补针对性规则与测试。

## 2026-03-23 旧本地助手名首次回填验证

### 已验证内容

- 发现并补齐了一个未实现收口：旧版本已存在的本地助手名，在首次进入新版 HomePage 时现在会补写到 `guide_user_settings.display_name`。
- 这意味着老用户即使不重新手动改名，微信侧后续也能读取到已有的自定义助手名。

### 命令结果摘要

- `flutter test test/home_page_guide_name_sync_source_test.dart`
  - 首轮新增断言失败，确认缺口存在；修复后再次执行通过，2/2 测试通过。
- `deno test --allow-env supabase/functions/_shared/guide_engine_test.ts supabase/functions/_shared/wechat_agent_test.ts`
  - 再次通过，13/13 测试通过。
- `deno check supabase/functions/wechat-webhook/index.ts`
  - 再次通过，无类型错误。

### 风险说明

- 这次补的是首次回填路径，前提仍然是用户已经登录且 `HomePage` 正常触发 `resolveDisplayName`。

## 2026-04-01 快速创建弹窗重设计

### 已验证内容
- 快速创建弹窗已改为三模式卡片面板：
  - 新建主线并添加支线
  - 挂到已有主线
  - 日常任务
- “挂到已有主线创建支线”能力仍保留在同一弹窗内。
- 新建主线模式支持在同一弹窗内补充多条支线草稿，并在提交时先建主线、再顺序建支线。
- 日常任务仍使用每日 HH:mm 截止时间逻辑。

### 命令结果摘要
- `dart analyze frontend/lib/features/quest/screens/home_page.dart frontend/test/quest_manual_creation_source_test.dart`
  - 通过，`No issues found!`
- `flutter test test/quest_manual_creation_source_test.dart test/quest_controller_daily_reset_source_test.dart test/quest_node_test.dart`
  - 通过，`All tests passed!`

### 风险说明
- 本轮主要做快速创建弹窗结构与样式重设计，尚未做桌面端实际截图回归；如需继续细抠视觉，可下一步直接运行 `flutter run -d windows` 做实机微调。


# 2026-04-01 Codex

## 快速创建加号入口修复

- 修改点：`frontend/lib/features/quest/screens/home_page.dart` 中 `QuickAddBar` 新增 `onPlusTap: _showPlusMenu`。
- 验证命令：
  - `dart analyze lib/features/quest/screens/home_page.dart test/quest_manual_creation_source_test.dart`
  - `flutter test test/quest_manual_creation_source_test.dart test/quest_controller_daily_reset_source_test.dart test/quest_node_test.dart`
- 验证结果：全部通过。
- 结论：快速创建条左侧加号已重新接回现有菜单入口；原有“新建主线并添加支线 / 挂到已有主线 / 日常任务”弹窗逻辑保持不变。

# 2026-04-01 Codex

## 快速创建弹窗文案去重

- 修改点：删除 `frontend/lib/features/quest/screens/home_page.dart` 中快速创建弹窗顶部的 `创建策略` 总说明卡片，保留三张选择卡自身的说明文案。
- 验证命令：
  - `dart analyze lib/features/quest/screens/home_page.dart test/quest_manual_creation_source_test.dart`
  - `flutter test test/quest_manual_creation_source_test.dart test/quest_controller_daily_reset_source_test.dart test/quest_node_test.dart`
- 验证结果：全部通过。
- 结论：弹窗首屏只保留模式选择必要信息，不再重复解释同一件事。

# 2026-04-01 Codex

## 快速创建按钮文案与挂载说明修复

- 修改点：`frontend/lib/features/quest/screens/home_page.dart` 中 `_confirmLabel` 改为明确按钮文案，同时把“挂到已有主线”面板文案改成用户可理解的话术。
- 行为约束：`attachToExistingMain` 仍然只提交单个 `title` + 单个 `parentMainQuestId`，不支持一次挂载多个支线。
- 验证命令：
  - `dart analyze lib/features/quest/screens/home_page.dart test/quest_manual_creation_source_test.dart`
  - `flutter test test/quest_manual_creation_source_test.dart test/quest_controller_daily_reset_source_test.dart test/quest_node_test.dart`
- 验证结果：全部通过。
- 结论：右下角创建按钮已不再显示问号；挂载面板已去除面向版本/实现的碎碎念文案；已有主线挂载模式维持单条支线创建。
