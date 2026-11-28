-- Private profile avatar uploads. Reads are limited to the owner, admins, and signed-in
-- members whose Discover opt-in allows profile viewing.
alter table public.student_profile_details
  add column if not exists photo_path text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('profile-avatars', 'profile-avatars', false, 5242880, array['image/jpeg','image/png','image/webp']::text[])
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create or replace function private.can_view_profile_avatar(target_profile_id text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select auth.uid() is not null
    and (
      target_profile_id = (select auth.uid()::text)
      or public.is_class_admin()
      or exists (
        select 1 from public.student_profile_details d
        where d.profile_id::text = target_profile_id
          and coalesce(d.discover_opt_in, true) = true
      )
    );
$$;
revoke all on function private.can_view_profile_avatar(text) from public, anon;
grant execute on function private.can_view_profile_avatar(text) to authenticated;

drop policy if exists "Members read visible profile avatars" on storage.objects;
create policy "Members read visible profile avatars"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'profile-avatars'
    and name = split_part(name, '/', 1) || '/avatar'
    and private.can_view_profile_avatar(split_part(name, '/', 1))
  );

drop policy if exists "Students upload own profile avatar" on storage.objects;
create policy "Students upload own profile avatar"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'profile-avatars'
    and auth.uid() is not null
    and name = (select auth.uid()::text) || '/avatar'
  );

drop policy if exists "Students replace own profile avatar" on storage.objects;
create policy "Students replace own profile avatar"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'profile-avatars'
    and auth.uid() is not null
    and name = (select auth.uid()::text) || '/avatar'
  )
  with check (
    bucket_id = 'profile-avatars'
    and auth.uid() is not null
    and name = (select auth.uid()::text) || '/avatar'
  );

drop policy if exists "Students delete own profile avatar" on storage.objects;
create policy "Students delete own profile avatar"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'profile-avatars'
    and auth.uid() is not null
    and name = (select auth.uid()::text) || '/avatar'
  );

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
    'profile_frame', case when auth.uid() = p.id or public.is_class_admin() or coalesce(d.discover_opt_in, true) then sc.profile_frame else null end,
    'photo_path', case when auth.uid() = p.id or public.is_class_admin() or coalesce(d.discover_opt_in, true) then d.photo_path else null end
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
  profile_frame text,
  photo_path text
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
    sc.profile_frame,
    d.photo_path
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
    'profile_frame', sc.profile_frame,
    'photo_path', d.photo_path
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
