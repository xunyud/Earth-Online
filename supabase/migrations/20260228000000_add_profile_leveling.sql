alter table public.profiles
add column if not exists level int not null default 1,
add column if not exists current_xp int not null default 0,
add column if not exists max_xp int not null default 500;

create or replace function public.grant_xp(delta int)
returns table(level int, current_xp int, max_xp int, total_xp int)
language plpgsql
as $$
declare
  v_level int;
  v_current int;
  v_max int;
  v_total int;
begin
  if delta is null or delta <= 0 then
    select p.level, p.current_xp, p.max_xp, p.total_xp
      into v_level, v_current, v_max, v_total
      from public.profiles p
      where p.id = auth.uid();
    return query select v_level, v_current, v_max, v_total;
    return;
  end if;

  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  update public.profiles
    set
      total_xp = total_xp + delta,
      current_xp = current_xp + delta
    where id = auth.uid()
    returning profiles.level, profiles.current_xp, profiles.max_xp, profiles.total_xp
      into v_level, v_current, v_max, v_total;

  if v_level is null then
    raise exception 'profile_not_found';
  end if;

  while v_current >= v_max loop
    v_current := v_current - v_max;
    v_level := v_level + 1;
    v_max := greatest(1, ceil(v_max * 1.2)::int);
  end loop;

  update public.profiles
    set level = v_level, current_xp = v_current, max_xp = v_max
    where id = auth.uid();

  return query select v_level, v_current, v_max, v_total;
end;
$$;

grant execute on function public.grant_xp(int) to authenticated;
