-- 支持永久道具装备/卸下切换
-- 1. 把现有永久道具标记为 is_equipped=true
-- 2. 修改 buy_reward RPC，永久道具购买时自动 is_equipped=true

-- 1. 现有永久道具全部标记为已装备
UPDATE inventory
SET is_equipped = true
WHERE is_used = false
  AND effect_type IN ('theme_unlock', 'card_border', 'complete_effect');

-- 2. 重写 buy_reward，永久道具自动装备
CREATE OR REPLACE FUNCTION public.buy_reward(r_id uuid)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_gold int;
    v_cost int;
    v_title text;
    v_effect_type text;
    v_effect_value text;
    v_is_permanent boolean;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'not_authenticated';
    END IF;

    SELECT cost, title, effect_type, effect_value
    INTO v_cost, v_title, v_effect_type, v_effect_value
    FROM rewards
    WHERE id = r_id AND is_active = true;

    IF v_cost IS NULL THEN
        RAISE EXCEPTION 'reward_not_found';
    END IF;

    -- 判断是否为永久道具
    v_is_permanent := v_effect_type IN ('theme_unlock', 'card_border', 'complete_effect');

    SELECT gold INTO v_gold
    FROM profiles
    WHERE id = auth.uid()
    FOR UPDATE;

    IF v_gold < v_cost THEN
        RETURN false;
    END IF;

    UPDATE profiles SET gold = gold - v_cost WHERE id = auth.uid();

    -- 永久道具自动装备
    INSERT INTO inventory (user_id, reward_id, reward_title, cost, effect_type, effect_value, is_equipped)
    VALUES (auth.uid(), r_id, v_title, v_cost, v_effect_type, v_effect_value, v_is_permanent);

    RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION public.buy_reward(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
