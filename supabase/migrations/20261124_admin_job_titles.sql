alter table public.profiles
  add column if not exists job_title text;

comment on column public.profiles.job_title is
  'Class officer title shown for admin accounts in the app.';
