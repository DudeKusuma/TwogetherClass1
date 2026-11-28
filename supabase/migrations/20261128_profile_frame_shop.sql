-- Add animated profile frames to the T-Money shop and require ownership before equipping.
alter table public.shop_catalog
  drop constraint if exists shop_catalog_category_check;
alter table public.shop_catalog
  add constraint shop_catalog_category_check
  check (category in ('profile_color', 'name_color', 'title_color', 'profile_frame'));

insert into public.shop_catalog(id, name, description, category, price, preview_color, text_color, preview_label, active) values
  ('frame-blueberry-jam', 'Blueberry Jam', 'Border avatar ungu animasi dengan hiasan blueberry.', 'profile_frame', 8, '#f4eaff', '#6438b5', 'A', true),
  ('frame-strawberry-swirl', 'Strawberry Swirl', 'Border avatar merah muda animasi dengan kilau manis.', 'profile_frame', 8, '#fff0f5', '#b54478', 'A', true),
  ('frame-lemon-glaze', 'Lemon Glaze', 'Border avatar kuning cerah animasi dengan aksen lemon.', 'profile_frame', 8, '#fff9d9', '#9b7716', 'A', true)
on conflict (id) do update set
  name = excluded.name,
  description = excluded.description,
  category = excluded.category,
  price = excluded.price,
  preview_color = excluded.preview_color,
  text_color = excluded.text_color,
  preview_label = excluded.preview_label,
  active = excluded.active;

-- Existing preview-only frames were free; remove them until they are purchased.
update public.student_cosmetics sc
set profile_frame = null, updated_at = now()
where sc.profile_frame is not null
  and not exists (
    select 1 from public.shop_purchases p
    join public.shop_catalog c on c.id = p.item_id
    where p.user_id = sc.profile_id
      and p.item_id = 'frame-' || sc.profile_frame
      and c.category = 'profile_frame'
  );

create or replace function public.purchase_shop_item(p_item_id text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  item_row public.shop_catalog%rowtype;
  balance_now integer;
  purchase_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into item_row from public.shop_catalog where id = p_item_id and active = true;
  if not found then raise exception 'Item tidak tersedia'; end if;
  insert into public.class_wallets(profile_id) values (auth.uid()) on conflict (profile_id) do nothing;
  select t_money into balance_now from public.class_wallets where profile_id = auth.uid() for update;
  if exists(select 1 from public.shop_purchases where user_id = auth.uid() and item_id = p_item_id) then
    raise exception 'Item sudah dimiliki';
  end if;
  if balance_now < item_row.price then raise exception 'T-Money tidak cukup'; end if;
  update public.class_wallets
    set t_money = t_money - item_row.price, updated_at = now()
    where profile_id = auth.uid()
    returning t_money into balance_now;
  insert into public.shop_purchases(user_id, item_id, price_paid)
    values (auth.uid(), p_item_id, item_row.price)
    returning id into purchase_id;
  insert into public.wallet_transactions(profile_id, amount, transaction_type, reason, reference_id)
    values (auth.uid(), item_row.price, 'spend', 'shop:' || p_item_id, purchase_id);
  insert into public.student_cosmetics(profile_id)
    values (auth.uid()) on conflict (profile_id) do nothing;
  return jsonb_build_object(
    'success', true,
    'message', 'Item berhasil dibeli. Pilih di Customize Profile untuk memakainya.',
    'balance', balance_now
  );
end;
$$;
revoke all on function public.purchase_shop_item(text) from public, anon, authenticated;
grant execute on function public.purchase_shop_item(text) to authenticated;

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
  if p_frame_id is not null and not exists (
    select 1
    from public.shop_catalog c
    join public.shop_purchases p on p.item_id = c.id
    where c.id = 'frame-' || p_frame_id
      and c.category = 'profile_frame'
      and c.active = true
      and p.user_id = auth.uid()
  ) then
    raise exception 'Border ini harus dibeli dulu di Shop';
  end if;
  insert into public.student_cosmetics(profile_id, profile_frame)
  values (auth.uid(), p_frame_id)
  on conflict (profile_id) do update
    set profile_frame = excluded.profile_frame, updated_at = now();
end;
$$;
revoke all on function public.equip_profile_frame(text) from public, anon;
grant execute on function public.equip_profile_frame(text) to authenticated;
notify pgrst, 'reload schema';
