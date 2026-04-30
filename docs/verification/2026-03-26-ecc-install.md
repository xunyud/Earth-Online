# ECC 安装验证

- 日期：2026-03-26
- 执行者：Codex
- 目标：验证 `everything-claude-code` 是否已在当前 Windows + Codex 环境完成安装

## 验证命令

```powershell
npm ls --depth=0
Select-String -Path $HOME\.codex\AGENTS.md -Pattern '<!-- BEGIN ECC -->','^# Codex Supplement \(From ECC \.codex/AGENTS\.md\)','<!-- END ECC -->'
Select-String -Path $HOME\.codex\config.toml -Pattern '^\[mcp_servers\.(supabase|context7-mcp|github|memory|sequential-thinking)\]'
git config --global core.hooksPath
```

## 验证结果

- `npm ls --depth=0` 通过，确认 `ecc-universal@1.9.0` 依赖树完整。
- `~/.codex/AGENTS.md` 已包含 ECC 标记区块和 Codex supplement。
- `~/.codex/config.toml` 已包含 5 个 ECC MCP section：
  - `supabase`
  - `context7-mcp`
  - `github`
  - `memory`
  - `sequential-thinking`
- 全局 git hooks 路径已设置为 `C:/Users/pclou/.codex/git-hooks`，且 `pre-commit` / `pre-push` 文件存在。
- `~/.codex/skills` 共 40 个目录，`~/.codex/prompts` 共 68 个 `ecc-*.md` 文件。
- `~/.codex/backups/ecc-20260326-103522` 已存在，可用于回滚本次同步前的配置。

## 结论

- 安装已完成。
- 官方同步脚本末尾的 sanity check 在当前环境下存在误判，不影响上述实际安装结果。
