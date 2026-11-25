-- Keep a class contribution active until every roster member has an approved
-- payment covering the per-student target amount.
create or replace function public.prevent_closing_unpaid_contribution()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.status <> 'closed' and new.status = 'closed' then
    if exists (
      select 1
      from public.class_roster r
      cross join lateral (
        select coalesce(sum(p.amount), 0)::bigint as total_paid
        from public.contribution_payments p
        where p.contribution_id = new.id
          and p.student_id = r.profile_id
          and p.status = 'approved'
      ) paid
      where r.profile_id is null
         or paid.total_paid < new.target_amount
    ) then
      raise exception using
        errcode = '23514',
        message = 'Iuran belum bisa ditutup sebelum semua siswa melunasi pembayaran.';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists prevent_closing_unpaid_contribution on public.class_contributions;
create trigger prevent_closing_unpaid_contribution
  before update of status on public.class_contributions
  for each row execute function public.prevent_closing_unpaid_contribution();
