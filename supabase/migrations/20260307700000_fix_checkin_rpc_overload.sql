DROP FUNCTION IF EXISTS public.checkin_and_get_multiplier(date);

GRANT EXECUTE ON FUNCTION public.checkin_and_get_multiplier(text) TO authenticated;

NOTIFY pgrst, 'reload schema';
