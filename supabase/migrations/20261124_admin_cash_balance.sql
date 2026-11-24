-- Let class admins correct the accumulated cash balance without rewriting
-- historical payment or expense records.
alter table public.cash_settings
  add column if not exists balance_adjustment bigint not null default 0;

drop policy if exists "Admins adjust accumulated class cash" on public.cash_settings;
create policy "Admins adjust accumulated class cash"
  on public.cash_settings
  for update to authenticated
  using (public.is_class_admin())
  with check (public.is_class_admin());

grant update (balance_adjustment) on public.cash_settings to authenticated;
