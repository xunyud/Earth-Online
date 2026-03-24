[English](./README.md) | [中文](./README.zh-CN.md)

# Earth Online

Earth Online 是一款具备记忆感知能力的效率游戏，把日常计划转化成持续演化的任务日志。它结合 Flutter 客户端、Supabase Edge Functions 与轻量后端，让用户既能记录真实任务、回看近期上下文，也能获得基于既往行为、记忆的引导与建议。

> 你可以把它理解成：任务面板、有记忆、懂陪伴的助手。

## 核心体验

### 1. 把真实生活变成 Quest Board

Earth Online 会把普通待办转成更有推进感的任务流：

- 在任务面板里创建、整理、完成 Quest
- 累积 XP、等级、奖励、背包与成就进度
- 让产品始终围绕真实任务，而不是只有抽象聊天

### 2. 一个有记忆感的助手

这个助手不是无状态聊天机器人，而是会参考近期信号来回应你：

- 近期记忆与行为信号会被打包进入向导提示
- 助手会结合上下文和记忆给出恢复型或推进型建议
- 每日事件、主动开场、夜间反思等链路共用同一层记忆能力

### 3. 微信成为真实可用的交互面

当前微信链路强调的是随时能记录任务：

- 在 App 中绑定微信账号
- 直接发普通文本，继续走现有任务录入链路
- 在微信里求助，收到助手风格回复
- 直接把最近一条建议任务收进任务树

### 4. 一个持续运转的个人循环

除了聊天和任务录入，产品当前还已经包含：

- 用于保留短期上下文的生活日记与回收站
- 支持头像和助手名编辑的个人资料定制
- 用于展示进展的统计、奖励商城与背包系统
- 根据长期记忆，助手生成对您的用户画像

## 功能快照

| 模块 | 当前能力 |
| --- | --- |
| 任务录入 | Quest Board、异步 `parse-quest`、支持层级插入 |
| 向导层 | 记忆感知聊天、主动消息、每日事件、夜间反思 |
| 微信入口 | 绑定、记任务、Guide Chat、收下建议、自然语言分流 |
| 身份同步 | App 助手名与微信助手名前缀共享同一份服务端来源 |
| 成长系统 | XP、等级、奖励、成就、统计、背包 |
| 商城系统 | 自行设置奖励激励自己 |

## 演示

### 项目介绍视频

点击下方海报即可观看中文版演示视频：

[![Earth Online 中文演示视频](./output/earth-online-poster-zh.png)](./output/earth-online-intro-zh.mp4)

- 视频链接：[中文介绍视频](./output/earth-online-intro-zh.mp4)
- 海报预览：[中文海报](./output/earth-online-poster-zh.png)

### 在线访问地址

在线地址：[https://earth-online-wine.vercel.app](https://earth-online-wine.vercel.app)

## 仓库导览

### 主要目录

- `frontend/`：Flutter 应用，包含任务面板、向导面板、微信绑定界面、个人资料、日记、奖励、统计与成就
- `backend/`：Node.js / Express 服务，用于 webhook 接入与消息防抖处理
- `supabase/`：数据库迁移、共享向导逻辑，以及用于任务解析、向导对话、记忆同步、周总结、画像生成和微信流程的 Edge Functions
- `docs/`：产品说明、实现计划与补充参考资料


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
