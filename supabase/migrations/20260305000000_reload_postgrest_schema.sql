-- 多次迁移后刷新 PostgREST schema 缓存
NOTIFY pgrst, 'reload schema';
