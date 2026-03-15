alter table public.profiles
add column if not exists total_xp int not null default 0;

create or replace function public.increment_total_xp(delta int)
returns void
language plpgsql
as $$
begin
  if delta is null then
    return;
  end if;
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  update public.profiles
    set total_xp = total_xp + delta
    where id = auth.uid();
end;
$$;

grant execute on function public.increment_total_xp(int) to authenticated;
