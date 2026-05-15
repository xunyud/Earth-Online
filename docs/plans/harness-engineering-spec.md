# Harness Engineering Spec

> 日期：2026-05-15
> 目标：将项目测试基础设施从手动运行提升为 CI 自动化质量门禁

---

## Phase 1：CI 接入现有测试

**目标**：让已有的 123+ 测试在每次 push/PR 时自动执行，阻止红色代码合入。

**交付物**：`.github/workflows/ci.yml`

**步骤**：

1. 新建 `ci.yml` workflow，触发条件：`push` to main + `pull_request`
2. Job 1 — Flutter 检查：
   - `flutter pub get`
   - `flutter analyze --fatal-infos`
   - `flutter test` （全量单元 + widget 测试）
3. Job 2 — Supabase Functions 检查：
   - 安装 Deno（pinned version）
   - `deno check supabase/functions/_shared/*.ts`
   - `deno test --no-check supabase/functions/`
4. 两个 Job 并行执行，任一失败则 workflow 红色

**验收标准**：
- [ ] Push 到 main 自动触发 CI
- [ ] PR 页面可见检查状态
- [ ] Flutter 73 测试 + Supabase 59 测试全绿
- [ ] 任一测试失败会阻止 merge（需配合 branch protection）

---

## Phase 2：后端测试框架搭建

**目标**：给 `backend/` 加上测试基础设施和核心逻辑覆盖。

**交付物**：
- `backend/vitest.config.ts`
- `backend/test/auth.test.ts`
- `backend/test/webhook.test.ts`
- `backend/test/validation.test.ts`

**步骤**：

1. 安装 vitest + 必要依赖：`vitest`, `@types/express`, `supertest`
2. 配置 `vitest.config.ts`（TypeScript 支持，路径别名）
3. 编写测试用例：
   - `auth.test.ts`：验证 `requireAuth` middleware（有效/无效/缺失 token）
   - `webhook.test.ts`：验证 `/webhook` 端点的输入校验和路由
   - `validation.test.ts`：验证 body 长度限制、content 最大字符数
4. 在 `package.json` 中更新 `"test": "vitest run"`
5. 在 Phase 1 的 CI workflow 中追加 Job 3 — Backend 检查：
   - `npm ci`
   - `npm test`

**验收标准**：
- [ ] `npm test` 本地可执行并全绿
- [ ] auth middleware 正向/反向用例覆盖
- [ ] CI 中 backend job 通过
- [ ] 覆盖率 > 0%（有基础就行，后续迭代补充）

---

## Phase 3：Pre-commit Hook

**目标**：提交前自动执行快速检查，防止明显错误进入 git 历史。

**交付物**：
- `.husky/pre-commit`
- 根目录 `package.json`（husky + lint-staged 配置）

**步骤**：

1. 在项目根目录初始化 `package.json`（如不存在）并安装 `husky` + `lint-staged`
2. 配置 lint-staged：
   - `*.dart` → `dart analyze --fatal-infos`（仅分析变更文件所在包）
   - `*.ts` → `deno check`（仅分析变更的 ts 文件）
3. 配置 husky pre-commit hook → 调用 `npx lint-staged`
4. 验证：故意引入类型错误 → commit 被拦截

**验收标准**：
- [ ] `git commit` 时自动触发 lint-staged
- [ ] Dart 类型错误被拦截
- [ ] TypeScript 类型错误被拦截
- [ ] 无错误时提交正常通过（< 5 秒延迟）

---

## Phase 4：Vercel 部署后 Smoke Test

**目标**：每次 Vercel 部署成功后自动验证核心页面可访问。

**交付物**：
- `.github/workflows/smoke-test.yml`
- `scripts/smoke-test.sh`

**步骤**：

1. 编写 `scripts/smoke-test.sh`：
   - `curl` 检查 Vercel 部署 URL 返回 200
   - 验证 HTML 中包含 `<title>Earth Online</title>` 或 Flutter bootstrap 标记
   - 可选：检查关键静态资源（main.dart.js / flutter.js）可达
2. 新建 `smoke-test.yml` workflow：
   - 触发条件：`deployment_status` event（Vercel 部署完成时 GitHub 会发此事件）
   - 或备选：`workflow_run`（ci.yml 成功后触发）
   - 执行 smoke-test.sh，失败时发 GitHub Issue 或 annotation warning
3. 超时 60 秒（等待 Vercel CDN 刷新）

**验收标准**：
- [ ] 部署成功后自动触发 smoke test
- [ ] 页面不可达时 workflow 报红
- [ ] 正常部署时 workflow 绿色通过
- [ ] 脚本可本地独立运行验证

---

## 执行顺序

```
Phase 1 (CI 测试) → Phase 2 (后端测试) → Phase 3 (Pre-commit) → Phase 4 (Smoke Test)
        ↓                    ↓                    ↓                      ↓
   最高 ROI            补齐盲区          防御性提升           闭环验证
   ~30 min             ~45 min           ~20 min              ~20 min
```

## 风险与约束

- Flutter CI 需要较大 runner（~2GB），GitHub Actions 免费额度够用
- Deno edge-runtime 类型声明本地无法解析，CI 中需 `--no-check` 或配置 import map
- Pre-commit 对 Windows 用户需确认 husky 兼容性（PowerShell hook）
- Vercel deployment_status 事件需仓库有 Vercel GitHub App 集成
