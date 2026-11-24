-- Include account role and class officer title in Discover student cards.
drop function if exists public.get_discover_students();
create function public.get_discover_students()
returns table(
  profile_id uuid,
  display_name text,
  hobbies text[],
  about_me text[],
  profile_color text,
  role text,
  job_title text
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
    p.job_title
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
    'profile_color', sc.profile_color
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

notify pgrst, 'reload schema';
