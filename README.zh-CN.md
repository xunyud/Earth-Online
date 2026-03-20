[English](./README.md) | [中文](./README.zh-CN.md)

# Earth Online

Earth Online 是一款具备记忆感知能力的效率游戏，把日常计划转化成持续演化的任务日志。项目结合了 Flutter 客户端、轻量 Node 后端与 Supabase Functions，让用户能够记录每天的上下文、回看近期记忆，并获得基于既往行为的任务建议。

## 比赛提交说明

### 1. 项目完整源代码

本仓库包含 Earth Online 的全部源代码。

- `frontend/`：Flutter 应用，包含任务面板、记忆向导对话框、个人资料定制、微信绑定流程、生活日记、回收站、统计、奖励和成就等界面。
- `backend/`：Node.js / Express 服务，用于 webhook 接入与消息防抖处理。
- `supabase/`：数据库迁移、共享向导逻辑，以及用于任务解析、向导对话、记忆同步、周总结、画像生成和微信相关流程的 Supabase Edge Functions。
- `docs/`：开发过程中使用的产品说明、实现计划与参考资料。

当前源代码中已经包含的核心产品能力包括：

- 以游戏化方式创建、整理和完成任务的 Quest 面板。
- 能读取近期行为信号并在对话中提出恢复型或推进型任务的记忆向导。
- 用于保留短期上下文和找回已删除内容的生活日记与回收站。
- 支持头像上传与昵称编辑的个人资料定制。
- 用于把提醒与状态更新连接到现实消息渠道的微信绑定能力。
- 包含 XP、等级、奖励、背包、成就与统计等成长系统。

### 2. 项目介绍视频

点击下方海报即可观看中文版演示视频：

[![Earth Online 中文演示视频](./output/earth-online-poster-zh.png)](./output/earth-online-intro-zh.mp4)

- 视频链接：[中文介绍视频](./output/earth-online-intro-zh.mp4)
- 海报预览：[中文海报](./output/earth-online-poster-zh.png)

Memory Genesis Competition 2026 的项目介绍视频建议覆盖以下内容：

1. Earth Online 的核心功能。
2. Earth Online 如何使用记忆，包括近期上下文、长期行为信号与向导引用。
3. 这些记忆如何帮助用户重新启动、恢复状态，并更顺畅地推进真实任务。

### 3. 在线访问地址

在线地址：[https://earth-online-wine.vercel.app](https://earth-online-wine.vercel.app)

仓库已经包含部署所需的主要前端、后端与 Supabase 组件。当前公开 Web 版本已部署在上方的 Vercel 地址。

## 技术栈

- Flutter + Dart
- Supabase
- Node.js + Express
- Redis
- TypeScript

## 仓库状态

- GitHub 仓库：[https://github.com/xunyud/Earth-Online](https://github.com/xunyud/Earth-Online)
- 主分支：`main`
- 许可证：MIT
