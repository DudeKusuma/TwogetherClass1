-- Buying a color unlocks it. The student must equip it separately.
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
    'message', 'Warna berhasil dibuka. Pilih di Customize Profile untuk memakainya.',
    'balance', balance_now
  );
end;
$$;
revoke all on function public.purchase_shop_item(text) from public, anon, authenticated;
grant execute on function public.purchase_shop_item(text) to authenticated;

create or replace function public.set_default_profile_background()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  insert into public.student_cosmetics(profile_id, profile_color)
    values (auth.uid(), null)
    on conflict (profile_id) do update
      set profile_color = null, updated_at = now();
  return jsonb_build_object('success', true, 'message', 'Background putih digunakan.');
end;
$$;
revoke all on function public.set_default_profile_background() from public, anon, authenticated;
grant execute on function public.set_default_profile_background() to authenticated;
