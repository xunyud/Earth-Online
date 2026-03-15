-- 下架废弃主题：深海主题 / 樱花主题 / 熔岩主题
-- 保留历史购买记录，不影响 inventory，仅移除商城在售项。

UPDATE public.rewards
SET is_active = false
WHERE is_system = true
  AND (
    title IN ('深海主题', '樱花主题', '熔岩主题')
    OR effect_value IN ('ocean_deep', 'sakura', 'lava')
  );

NOTIFY pgrst, 'reload schema';
