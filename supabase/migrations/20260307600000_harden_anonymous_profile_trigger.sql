ALTER TABLE IF EXISTS public.profiles
  ADD COLUMN IF NOT EXISTS email text;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  BEGIN
    INSERT INTO public.profiles (id, email)
    VALUES (new.id, new.email)
    ON CONFLICT (id) DO UPDATE
      SET email = COALESCE(EXCLUDED.email, public.profiles.email);
  EXCEPTION
    WHEN undefined_column THEN
      INSERT INTO public.profiles (id)
      VALUES (new.id)
      ON CONFLICT (id) DO NOTHING;
  END;

  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE PROCEDURE public.handle_new_user();

NOTIFY pgrst, 'reload schema';
