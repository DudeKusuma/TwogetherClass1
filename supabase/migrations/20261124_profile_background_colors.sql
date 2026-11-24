-- Profile color cosmetics are used as student-card backgrounds.
update public.shop_catalog
set name = 'Mint',
    description = 'Background mint lembut untuk kartu profil.',
    preview_color = '#DFF7ED',
    text_color = '#245B48',
    preview_label = ' ',
    active = true
where id = 'profile-mint';

update public.shop_catalog
set name = 'Lavender',
    description = 'Background lavender untuk kartu profil.',
    preview_color = '#EEE8FF',
    text_color = '#514078',
    preview_label = ' ',
    active = true
where id = 'profile-lavender';

update public.shop_catalog
set active = false
where category <> 'profile_color';

insert into public.shop_catalog(id, name, description, category, price, preview_color, text_color, preview_label, active)
values
  ('profile-peach', 'Peach', 'Background peach hangat untuk kartu profil.', 'profile_color', 8, '#FFE8D6', '#704A32', ' ', true),
  ('profile-sky', 'Sky', 'Background biru langit untuk kartu profil.', 'profile_color', 8, '#DFEFFA', '#35566B', ' ', true),
  ('profile-lemon', 'Lemon', 'Background kuning lembut untuk kartu profil.', 'profile_color', 8, '#FFF5CC', '#665626', ' ', true)
on conflict (id) do update set
  name = excluded.name,
  description = excluded.description,
  category = excluded.category,
  price = excluded.price,
  preview_color = excluded.preview_color,
  text_color = excluded.text_color,
  preview_label = excluded.preview_label,
  active = excluded.active;

drop function if exists public.get_discover_students();
create function public.get_discover_students()
returns table(profile_id uuid, display_name text, hobbies text[], about_me text[], profile_color text)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p.id,
    coalesce(nullif(trim(d.short_name), ''), nullif(trim(p.display_name), ''), r.full_name),
    coalesce(d.hobbies, '{}'::text[]),
    coalesce(d.about_me, '{}'::text[]),
    sc.profile_color
  from public.profiles p
  join public.class_roster r on r.profile_id = p.id
  left join public.student_profile_details d on d.profile_id = p.id
  left join public.student_cosmetics sc on sc.profile_id = p.id
  where auth.uid() is not null
    and coalesce(d.discover_opt_in, true) = true
  order by coalesce(nullif(trim(d.short_name), ''), nullif(trim(p.display_name), ''), r.full_name);
$$;
revoke all on function public.get_discover_students() from public;
revoke all on function public.get_discover_students() from anon;
grant execute on function public.get_discover_students() to authenticated;
notify pgrst, 'reload schema';
