# Earth Online README Design

> 日期：2026-03-25
> 执行者：Codex

## Goal

将 `README.md` 与 `README.zh-CN.md` 从简短项目介绍重构为适合作品集展示的完整双语 README，并保持两份文档的结构同步。

## Chosen Direction

采用“产品案例型”叙事，而不是纯工程说明页。

核心判断如下：

- 先解释 Earth Online 是什么，以及它与普通待办工具的差异。
- 再用功能、演示、架构与运行方式证明“效率游戏、记忆感知、陪伴引导”不是空泛文案。
- 双语版本使用同一套章节骨架，避免信息层级漂移。

## Structure

两份 README 统一使用以下结构：

1. Title + One-line Positioning
2. Why
3. Core Features
4. Demo / Live Experience
5. Differentiators
6. Tech Stack
7. Architecture / System Design
8. Getting Started
9. Screenshots / Preview Assets
10. Roadmap
11. Design Philosophy

## Content Sources

README 内容仅引用仓库中已有的真实信息：

- 在线地址：`https://earth-online-wine.vercel.app`
- 英文演示视频：`output/earth-online-intro.mp4`
- 中文演示视频：`output/earth-online-intro-zh.mp4`
- 英文海报：`output/earth-online-poster.png`
- 中文海报：`output/earth-online-poster-zh.png`
- Flutter 入口与依赖：`frontend/pubspec.yaml`
- 轻量后端入口与依赖：`backend/package.json`
- Supabase Functions 目录：`supabase/functions/`
- 视频生成命令：`promo-video/package.json`

## Writing Principles

- 语气专业、清晰、克制，不使用夸张营销语言。
- 重点让读者能够复述三个卖点：
  - 有记忆感知能力
  - 会基于历史行为与上下文进行引导
  - 像陪伴式效率游戏，而不是普通任务清单
- Getting Started 只写真实存在的命令与模块，不写占位描述。
- 中文版不是逐字翻译，而是在保持结构一致的前提下采用自然中文表达。
