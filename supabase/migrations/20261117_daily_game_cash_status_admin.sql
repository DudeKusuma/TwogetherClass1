-- Twogether Class: one randomized daily game worth 10 T-Money,
-- plus admin overrides for monthly cash status colors.
-- Run after 20261114_community_games_rewards_pwa.sql and 20261106_tasks_finance.sql.

-- Keep at most one legacy claim per student/day before enforcing the new rule.
delete from public.game_reward_claims older
using public.game_reward_claims newer
where older.profile_id = newer.profile_id
  and older.reward_date = newer.reward_date
  and (older.created_at, older.id) > (newer.created_at, newer.id);

alter table public.game_reward_claims
  alter column amount set default 10;

create unique index if not exists game_reward_claims_one_per_student_day
  on public.game_reward_claims(profile_id, reward_date);

create or replace function public.submit_daily_game_answer(
  p_game_key text,
  p_challenge_index integer,
  p_answer text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  local_day date := (now() at time zone 'Asia/Makassar')::date;
  day_number integer;
  selected_game text;
  expected_index integer;
  claim_id uuid;
  current_balance integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_game_key not in ('trivia','fact','words','wordle') then
    raise exception 'Invalid game';
  end if;

  day_number := local_day - date '1970-01-01';
  selected_game := case
    when mod(floor(abs(sin(day_number::double precision * 12.9898) * 43758.5453))::integer, 4) = 0 then 'trivia'
    when mod(floor(abs(sin(day_number::double precision * 12.9898) * 43758.5453))::integer, 4) = 1 then 'fact'
    when mod(floor(abs(sin(day_number::double precision * 12.9898) * 43758.5453))::integer, 4) = 2 then 'words'
    else 'wordle'
  end;

  if p_game_key <> selected_game then
    raise exception 'Game hari ini berbeda. Muat ulang halaman.';
  end if;

  expected_index := case p_game_key
    when 'trivia' then mod(day_number + 18, 8)
    when 'fact' then mod(day_number + 12, 8)
    when 'words' then mod(day_number + 15, 8)
    when 'wordle' then mod(day_number + 18, 4)
  end;

  if p_challenge_index <> expected_index then
    raise exception 'Challenge sudah berganti';
  end if;

  if not exists (
    select 1
    from public.game_challenge_answers a
    where a.game_key = p_game_key
      and a.challenge_index = p_challenge_index
      and upper(trim(a.correct_answer)) = upper(trim(coalesce(p_answer,'')))
  ) then
    raise exception 'Jawaban belum benar';
  end if;

  insert into public.class_wallets(profile_id)
  values (auth.uid())
  on conflict (profile_id) do nothing;

  insert into public.game_reward_claims(profile_id, game_key, reward_date, amount)
  values (auth.uid(), p_game_key, local_day, 10)
  on conflict (profile_id, reward_date) do nothing
  returning id into claim_id;

  if claim_id is null then
    select t_money into current_balance
    from public.class_wallets
    where profile_id = auth.uid();
    return jsonb_build_object(
      'already_claimed', true,
      'balance', current_balance,
      'amount', 0
    );
  end if;

  update public.class_wallets
  set t_money = t_money + 10, updated_at = now()
  where profile_id = auth.uid()
  returning t_money into current_balance;

  insert into public.wallet_transactions(profile_id, amount, transaction_type, reason, reference_id)
  values (auth.uid(), 10, 'earn', 'daily-game:' || p_game_key, claim_id);

  return jsonb_build_object(
    'already_claimed', false,
    'balance', current_balance,
    'amount', 10
  );
end;
$$;

revoke all on function public.submit_daily_game_answer(text, integer, text) from public;
grant execute on function public.submit_daily_game_answer(text, integer, text) to authenticated;

-- The manual status is visual only; payment allocations and the cash ledger
-- remain the source of truth for amounts actually received.
create table if not exists public.cash_monthly_status_overrides (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles(id) on delete cascade,
  month_start date not null,
  status text not null check (status in ('none','low','half','full')),
  updated_by uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now(),
  unique(student_id, month_start)
);

alter table public.cash_monthly_status_overrides enable row level security;

drop policy if exists "Members read monthly cash status overrides"
  on public.cash_monthly_status_overrides;
create policy "Members read monthly cash status overrides"
  on public.cash_monthly_status_overrides
  for select to authenticated
  using (true);

drop policy if exists "Admins manage monthly cash status overrides"
  on public.cash_monthly_status_overrides;
create policy "Admins manage monthly cash status overrides"
  on public.cash_monthly_status_overrides
  for all to authenticated
  using (public.is_class_admin())
  with check (public.is_class_admin());

grant select on public.cash_monthly_status_overrides to authenticated;
grant insert, update, delete on public.cash_monthly_status_overrides to authenticated;
