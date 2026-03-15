# PRD-07：微信周报推送

## 1. 功能概述

在现有 `weekly-summary` Edge Function 基础上，增加自动/手动触发的微信推送能力，用户无需打开 App 即可在微信中收到周报。

## 2. 用户故事

- 作为用户，我希望每周自动收到微信周报，不用特意打开 App 查看。
- 作为用户，我希望可以手动触发推送，立即在微信中看到本周总结。
- 作为用户，我希望可以关闭自动推送，保持控制权。

## 3. 现状分析

### 已有基础
- `weekly-summary` Edge Function：已实现周报生成（查询 7 天任务 + LLM 总结），结果写入 `daily_logs`
- `wechat-webhook` Edge Function：已实现微信消息接收和回复（XML 格式）
- `profiles.wechat_openid`：已存储用户微信绑定信息
- 前端"📜 召唤村长周报"按钮：已实现手动触发

### 缺失项
- 无微信**主动推送**能力（当前只能被动回复）
- 无定时任务调度（Cron）
- 无推送偏好设置
- `weekly-summary` 未返回格式化的微信消息

### 微信推送限制（重要）
微信公众号/企业号有**主动推送限制**：
- **服务号**：每月 4 次模板消息（需申请模板）
- **订阅号**：无主动推送能力
- **企业微信**：应用消息无限制
- **客服消息**：用户 48 小时内有交互才能推送

## 4. 技术方案

### 4.1 推送通道选择

根据现有微信 Webhook 架构（公众号/企业微信），推荐两种方案：

**方案 A：客服消息（推荐，零成本）**
- 条件：用户 48 小时内与公众号有交互
- 实现：调用微信客服消息 API
- 优点：无需额外申请，文本格式自由
- 缺点：48 小时窗口限制

**方案 B：模板消息**
- 条件：服务号 + 已申请模板
- 实现：调用模板消息 API
- 优点：无时间窗口限制
- 缺点：需要服务号资质 + 审核模板

**V1 实现方案 A**，以 48 小时活跃用户为目标群体。

### 4.2 架构设计

```
定时触发（Supabase Cron / pg_cron）
    ↓
weekly-report-push Edge Function（新建）
    ↓
1. 查询所有启用推送 + 48h 内活跃 + 已绑定微信的用户
2. 对每个用户调用 weekly-summary 生成周报
3. 通过微信客服消息 API 推送
4. 记录推送结果
```

### 4.3 数据模型变更

```sql
-- profiles 新增推送偏好
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS weekly_push_enabled boolean DEFAULT true;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS last_wechat_interaction timestamptz;  -- 记录最后交互时间

-- 推送日志表
CREATE TABLE IF NOT EXISTS push_logs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id),
    push_type text NOT NULL DEFAULT 'weekly_report', -- weekly_report / achievement / reminder
    content_preview text,                            -- 推送内容摘要（前 100 字）
    status text NOT NULL DEFAULT 'pending',          -- pending / sent / failed / skipped
    error_message text,
    created_at timestamptz DEFAULT now(),
    sent_at timestamptz
);

ALTER TABLE push_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "用户查看自己的推送记录"
    ON push_logs FOR SELECT USING (auth.uid() = user_id);
```

### 4.4 wechat-webhook 变更
在现有 Webhook 中，每次收到用户消息时更新 `last_wechat_interaction`：

```typescript
// 在处理消息时追加
await supabase
    .from('profiles')
    .update({ last_wechat_interaction: new Date().toISOString() })
    .eq('wechat_openid', fromUser);
```

## 5. 新增 Edge Function：weekly-report-push

### 5.1 功能
```typescript
// supabase/functions/weekly-report-push/index.ts

// 1. 查询目标用户
const { data: users } = await supabase
    .from('profiles')
    .select('id, wechat_openid, last_wechat_interaction')
    .eq('weekly_push_enabled', true)
    .not('wechat_openid', 'is', null)
    .gte('last_wechat_interaction', fortyEightHoursAgo);

// 2. 逐用户生成周报
for (const user of users) {
    const summary = await generateWeeklySummary(user.id);

    // 3. 调用微信客服消息 API
    await sendWechatMessage(user.wechat_openid, formatForWechat(summary));

    // 4. 记录推送日志
    await logPush(user.id, summary, 'sent');
}
```

### 5.2 微信客服消息 API 调用
```typescript
async function sendWechatMessage(openId: string, content: string) {
    // 获取 access_token（缓存机制）
    const token = await getWechatAccessToken();

    // 发送客服消息
    const res = await fetch(
        `https://api.weixin.qq.com/cgi-bin/message/custom/send?access_token=${token}`,
        {
            method: 'POST',
            body: JSON.stringify({
                touser: openId,
                msgtype: 'text',
                text: { content }
            })
        }
    );

    const result = await res.json();
    if (result.errcode !== 0) {
        throw new Error(`微信推送失败: ${result.errmsg}`);
    }
}
```

### 5.3 周报格式化（微信文本）
```
📊 本周任务周报

🎯 完成任务：12 个
⭐ 获得经验：480 XP
🔥 连续签到：5 天

📝 村长总结：
这周你在"项目重构"主线任务上取得了很大进展...

💪 下周建议：
继续保持节奏，争取把"API 优化"完成！

—— 地球 Online · 周报系统
```

### 5.4 定时调度

**方案 A：Supabase pg_cron（推荐）**
```sql
-- 每周日 20:00 UTC+8 触发
SELECT cron.schedule(
    'weekly-report-push',
    '0 12 * * 0',  -- UTC 12:00 = 北京时间 20:00
    $$
    SELECT net.http_post(
        url := 'https://ndbhxjvrgxeuyykrlyxl.supabase.co/functions/v1/weekly-report-push',
        headers := jsonb_build_object(
            'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
        ),
        body := '{}'::jsonb
    );
    $$
);
```

**方案 B：外部 Cron 服务**
- 使用 Upstash QStash 或 cron-job.org
- 定时 POST 调用 Edge Function

## 6. 前端变更

### 6.1 推送设置
在设置页新增：
```
┌─────────────────────────────┐
│ 📬 微信推送设置              │
│                             │
│ 周报自动推送    [开关 ✅]    │
│ 每周日 20:00 自动发送        │
│                             │
│ 上次推送：2026-03-02 20:00  │
│ 状态：✅ 已送达              │
└─────────────────────────────┘
```

### 6.2 手动推送按钮
在人生日记页"📜 召唤村长周报"按钮旁增加"📤 推送到微信"：
- 点击后调用 `weekly-report-push` 函数（仅推送当前用户）
- 显示发送状态

## 7. 环境变量
```
WECHAT_APP_ID       # 微信公众号 AppID
WECHAT_APP_SECRET   # 微信公众号 AppSecret
```

## 8. 边界情况
- **48 小时窗口过期**：跳过该用户，push_logs 记录 `status='skipped'`，原因 "用户 48h 内无交互"
- **access_token 缓存**：微信 token 2 小时有效，使用 Redis/内存缓存
- **推送失败重试**：失败后不重试（避免骚扰），记录错误日志
- **未绑定微信**：自动跳过
- **周报内容为空**：本周无完成任务时，推送鼓励消息而非空报
- **并发安全**：使用分布式锁或幂等 key 防止重复推送
- **微信文本长度限制**：客服消息文本限制 2048 字符，超长时截断

## 9. 依赖项
- Supabase pg_cron 扩展（如未启用需开启）
- 微信公众平台客服消息权限

## 10. 验收标准
- [ ] 手动触发推送，微信收到格式化周报
- [ ] 设置页可开关自动推送
- [ ] 48 小时无交互的用户自动跳过
- [ ] 未绑定微信的用户自动跳过
- [ ] push_logs 正确记录推送结果
- [ ] 定时任务每周日 20:00 自动触发
- [ ] 本周无任务时推送鼓励消息
