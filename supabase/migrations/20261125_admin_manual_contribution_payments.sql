-- Let class administrators record a paid contribution directly when payment
-- was handled outside the student payment request flow.
drop policy if exists "Admins record paid contribution payments" on public.contribution_payments;
create policy "Admins record paid contribution payments"
  on public.contribution_payments
  for insert
  to authenticated
  with check (public.is_class_admin() and status = 'approved');

grant insert on public.contribution_payments to authenticated;
