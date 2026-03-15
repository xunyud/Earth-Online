-- 测试用：为所有用户增加 10000 XP 和 10000 金币
UPDATE public.profiles
SET total_xp = total_xp + 10000,
    gold     = gold + 10000;
