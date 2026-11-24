-- Include wallet balances in student detail RPCs.
-- Discover only returns a balance for a profile that opted into Discover.

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
    't_money', coalesce(w.t_money, 0)
  ) into profile_data
  from public.class_roster r
  join public.profiles p on p.id = r.profile_id
  left join public.student_profile_details d on d.profile_id = p.id
  left join public.class_wallets w on w.profile_id = p.id
  where p.id = target_profile_id
    and coalesce(d.discover_opt_in, true) = true;
  return profile_data;
end;
$$;
revoke all on function public.get_discover_student_profile(uuid) from public;
revoke all on function public.get_discover_student_profile(uuid) from anon;
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
    't_money', case when auth.uid() = p.id or public.is_class_admin() then coalesce(w.t_money, 0) else null end
  ) into profile_data
  from public.class_roster r
  join public.profiles p on p.id = r.profile_id
  left join public.student_profile_details d on d.profile_id = p.id
  left join public.class_wallets w on w.profile_id = p.id
  where p.id = target_profile_id;
  return profile_data;
end;
$$;
revoke all on function public.get_student_profile(uuid) from public;
grant execute on function public.get_student_profile(uuid) to authenticated;
