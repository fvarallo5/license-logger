-- LicenseLogger 006: state hour rules as data (not code).
-- Only rows with verified = true may be shown as "the state requirement".
-- Everything else is labelled "example / unverified" in the apps.
-- Sources come from licenselogger-research/data.py.

create table if not exists public.state_rule_sets (
  id uuid primary key default gen_random_uuid(),
  state_code text not null check (char_length(state_code) = 2 and state_code = upper(state_code)),
  version int not null default 1 check (version >= 1),
  effective_from date not null default date '2000-01-01',
  label text not null,
  total_minutes int not null check (total_minutes > 0),
  night_minutes int not null default 0 check (night_minutes >= 0),
  daily_cap_minutes int check (daily_cap_minutes is null or daily_cap_minutes > 0),
  lessons_count boolean not null default false,          -- do instructor lessons count toward the log?
  night_rule text not null default 'sunset_sunrise'
    check (night_rule in ('sunset_sunrise', 'clock_window')),
  night_start time,                                      -- only for clock_window
  night_end time,
  form_code text not null default '',
  form_url text not null default '',
  source_url text not null default '',
  verified boolean not null default false,
  verified_on date,
  notes text not null default '',
  created_at timestamptz not null default now(),
  unique (state_code, version),
  check (night_minutes <= total_minutes),
  check (night_rule <> 'clock_window' or (night_start is not null and night_end is not null)),
  check (not verified or verified_on is not null)
);
create index if not exists state_rule_sets_lookup_idx
  on public.state_rule_sets (state_code, effective_from desc);

alter table public.state_rule_sets enable row level security;
alter table public.state_rule_sets force row level security;
drop policy if exists state_rule_sets_read on public.state_rule_sets;
create policy state_rule_sets_read on public.state_rule_sets
  for select to authenticated using (true);
revoke all on table public.state_rule_sets from public, anon, authenticated;
grant select on table public.state_rule_sets to authenticated;
grant select, insert, update on table public.state_rule_sets to service_role;

-- Optional per-student override (e.g. a school pins an older rule version).
alter table public.students
  add column if not exists rule_set_id uuid references public.state_rule_sets (id) on delete set null;
create index if not exists students_rule_set_id_idx on public.students (rule_set_id);

-- Reference data. Texas is the only verified rule (TDLR DES150N).
insert into public.state_rule_sets
  (state_code, version, label, total_minutes, night_minutes, daily_cap_minutes, form_code, form_url, source_url, verified, verified_on, notes)
values
  ('TX', 1, 'Texas 30-hour behind-the-wheel log', 30 * 60, 10 * 60, 120, 'TDLR DES150N',
   'https://www.tdlr.texas.gov/driver/files/DES150N-Texas-30-Hour-Behind-the-Wheel-Log.pdf',
   'https://www.tdlr.texas.gov/driver/files/DES150N-Texas-30-Hour-Behind-the-Wheel-Log.pdf',
   true, date '2026-10-19',
   'Max 2 hours per day count. Night definition on the form still to confirm; app uses sunset to sunrise.'),
  ('MI', 1, 'Michigan supervised driving (example)', 50 * 60, 10 * 60, null, 'Michigan Supervised Driving Log', '',
   'https://www.michigan.gov/-/media/Project/Websites/sos/License-and-ID/New-drivers/Michigan-Supervised-Driving-Log.pdf',
   false, null, 'UNVERIFIED example: 30 h before Segment 2; 50 (10 night) before skills test.'),
  ('CO', 1, 'Colorado DR 2324 (example)', 50 * 60, 10 * 60, null, 'DR 2324', '', 'https://dmv.colorado.gov/minor-license',
   false, null, 'UNVERIFIED example.'),
  ('NY', 1, 'New York MV-262 (example)', 50 * 60, 15 * 60, null, 'MV-262', 'https://dmv.ny.gov/forms/mv262.pdf',
   'https://dmv.ny.gov/forms/mv262.pdf', false, null, 'UNVERIFIED example: 15 h after sunset; certification-based.'),
  ('CA', 1, 'California DL 44 certification (example)', 50 * 60, 10 * 60, null, 'DL 44', '',
   'https://www.dmv.ca.gov/portal/file/supervised-driving-log-pdf', false, null, 'UNVERIFIED example.'),
  ('PA', 1, 'Pennsylvania DL-180C (example)', 65 * 60, 0, null, 'DL-180C', '',
   'https://www.pa.gov/content/dam/copapwp-pagov/en/penndot/documents/public/dvspubsforms/bdl/bdl-form/dl-180c.pdf',
   false, null, 'UNVERIFIED example: night/weather split not modelled.')
on conflict (state_code, version) do nothing;

-- Which rule applies to a student: their override, else the newest effective
-- version for their state. NULL when the state has no row yet.
create or replace function private.rule_for_student(p_student_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    s.rule_set_id,
    (select r.id from public.state_rule_sets r
      where r.state_code = s.state_code and r.effective_from <= current_date
      order by r.effective_from desc, r.version desc
      limit 1)
  )
  from public.students s
  where s.id = p_student_id;
$$;
revoke all on function private.rule_for_student(uuid) from public, anon;
grant execute on function private.rule_for_student(uuid) to authenticated;
