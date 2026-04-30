-- 为 guide_portraits 表添加 epoch 字段，支持画像时间线功能
-- epoch 使用 ISO 周标识（如 "2026-W17"），标记画像所属的时间段
-- 需求来源：Requirements 3.1, 3.3

ALTER TABLE public.guide_portraits
  ADD COLUMN IF NOT EXISTS epoch text NOT NULL DEFAULT '';

-- 同 epoch 同用户唯一约束（仅 epoch 非空时生效）
-- 保证同一用户在同一 epoch 下最多存在一张画像，重复生成时走 upsert 覆盖
CREATE UNIQUE INDEX IF NOT EXISTS idx_guide_portraits_user_epoch
  ON public.guide_portraits (user_id, epoch)
  WHERE epoch != '';

-- epoch 排序索引，支持按时间线倒序查询画像列表
CREATE INDEX IF NOT EXISTS idx_guide_portraits_user_epoch_order
  ON public.guide_portraits (user_id, epoch DESC);

NOTIFY pgrst, 'reload schema';
