-- Store an equipped animated profile frame and expose it through profile RPCs.
alter table public.student_cosmetics
  add column if not exists profile_frame text;

alter table public.student_cosmetics
  drop constraint if exists student_cosmetics_profile_frame_check;
alter table public.student_cosmetics
  add constraint student_cosmetics_profile_frame_check
  check (profile_frame is null or profile_frame in ('blueberry-jam', 'strawberry-swirl', 'lemon-glaze'));

create or replace function public.equip_profile_frame(p_frame_id text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_frame_id is not null and p_frame_id not in ('blueberry-jam', 'strawberry-swirl', 'lemon-glaze') then
    raise exception 'Unknown profile frame';
  end if;
  insert into public.student_cosmetics(profile_id, profile_frame)
  values (auth.uid(), p_frame_id)
  on conflict (profile_id) do update
    set profile_frame = excluded.profile_frame, updated_at = now();
end;
$$;
revoke all on function public.equip_profile_frame(text) from public, anon;
grant execute on function public.equip_profile_frame(text) to authenticated;

drop function if exists public.get_discover_students();
create function public.get_discover_students()
returns table(
  profile_id uuid,
  display_name text,
  hobbies text[],
  about_me text[],
  profile_color text,
  role text,
  job_title text,
  profile_frame text
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p.id,
    coalesce(nullif(trim(d.short_name), ''), nullif(trim(p.display_name), ''), r.full_name),
    coalesce(d.hobbies, '{}'::text[]),
    coalesce(d.about_me, '{}'::text[]),
    sc.profile_color,
    p.role,
    p.job_title,
    sc.profile_frame
  from public.profiles p
  join public.class_roster r on r.profile_id = p.id
  left join public.student_profile_details d on d.profile_id = p.id
  left join public.student_cosmetics sc on sc.profile_id = p.id
  where auth.uid() is not null
    and coalesce(d.discover_opt_in, true) = true
  order by coalesce(nullif(trim(d.short_name), ''), nullif(trim(p.display_name), ''), r.full_name);
$$;
revoke all on function public.get_discover_students() from public, anon;
grant execute on function public.get_discover_students() to authenticated;

create or replace function public.get_discover_student_profile(target_profile_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare profile_data jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select jsonb_build_object(
    'profile_id', p.id,
    'role', p.role,
    'job_title', p.job_title,
    'full_name', r.full_name,
    'short_name', coalesce(nullif(d.short_name, ''), nullif(p.display_name, ''), r.full_name),
    'attendance_number', r.attendance_number,
    'student_number', case when coalesce(d.show_student_number, false) then r.student_number else null end,
    'show_student_number', coalesce(d.show_student_number, false),
    'birth_place', coalesce(d.birth_place, ''),
    'birth_date', d.birth_date,
    'gender', coalesce(d.gender, r.gender),
    'address', coalesce(d.address, ''),
    'description', coalesce(d.description, ''),
    'hobbies', coalesce(d.hobbies, '{}'::text[]),
    'about_me', coalesce(d.about_me, '{}'::text[]),
    't_money', coalesce(w.t_money, 0),
    'profile_color', sc.profile_color,
    'profile_frame', sc.profile_frame
  ) into profile_data
  from public.class_roster r
  join public.profiles p on p.id = r.profile_id
  left join public.student_profile_details d on d.profile_id = p.id
  left join public.class_wallets w on w.profile_id = p.id
  left join public.student_cosmetics sc on sc.profile_id = p.id
  where p.id = target_profile_id
    and coalesce(d.discover_opt_in, true) = true;
  return profile_data;
end;
$$;
revoke all on function public.get_discover_student_profile(uuid) from public, anon;
grant execute on function public.get_discover_student_profile(uuid) to authenticated;

create or replace function public.get_student_profile(target_profile_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare profile_data jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select jsonb_build_object(
    'profile_id', p.id,
    'full_name', r.full_name,
    'short_name', case when auth.uid() = p.id or public.is_class_admin() or coalesce(d.discover_opt_in, true)
      then coalesce(nullif(d.short_name, ''), nullif(p.display_name, ''), r.full_name) else null end,
    'attendance_number', r.attendance_number,
    'student_number', case when auth.uid() = p.id or public.is_class_admin() or (coalesce(d.discover_opt_in, true) and coalesce(d.show_student_number, false)) then r.student_number else null end,
    'birth_place', case when auth.uid() = p.id or public.is_class_admin() or coalesce(d.discover_opt_in, true) then coalesce(d.birth_place, '') else null end,
    'birth_date', case when auth.uid() = p.id or public.is_class_admin() or coalesce(d.discover_opt_in, true) then d.birth_date else null end,
    'gender', case when auth.uid() = p.id or public.is_class_admin() or coalesce(d.discover_opt_in, true) then coalesce(d.gender, r.gender) else null end,
    'address', case when auth.uid() = p.id or public.is_class_admin() or coalesce(d.discover_opt_in, true) then coalesce(d.address, '') else null end,
    'description', case when auth.uid() = p.id or public.is_class_admin() or coalesce(d.discover_opt_in, true) then coalesce(d.description, '') else null end,
    'hobbies', case when auth.uid() = p.id or public.is_class_admin() or coalesce(d.discover_opt_in, true) then coalesce(d.hobbies, '{}'::text[]) else null end,
    'about_me', case when auth.uid() = p.id or public.is_class_admin() or coalesce(d.discover_opt_in, true) then coalesce(d.about_me, '{}'::text[]) else null end,
    'show_student_number', case when auth.uid() = p.id or public.is_class_admin() then coalesce(d.show_student_number, false) else null end,
    'discover_opt_in', case when auth.uid() = p.id or public.is_class_admin() then coalesce(d.discover_opt_in, true) else null end,
    't_money', case when auth.uid() = p.id or public.is_class_admin() then coalesce(w.t_money, 0) else null end,
    'profile_color', case when auth.uid() = p.id or public.is_class_admin() or coalesce(d.discover_opt_in, true) then sc.profile_color else null end,
    'profile_frame', case when auth.uid() = p.id or public.is_class_admin() or coalesce(d.discover_opt_in, true) then sc.profile_frame else null end
  ) into profile_data
  from public.class_roster r
  join public.profiles p on p.id = r.profile_id
  left join public.student_profile_details d on d.profile_id = p.id
  left join public.class_wallets w on w.profile_id = p.id
  left join public.student_cosmetics sc on sc.profile_id = p.id
  where p.id = target_profile_id;
  return profile_data;
end;
$$;
revoke all on function public.get_student_profile(uuid) from public, anon;
grant execute on function public.get_student_profile(uuid) to authenticated;

notify pgrst, 'reload schema';
