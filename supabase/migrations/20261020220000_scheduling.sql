-- Was live version 20261023222828_scheduling. Repo timestamp placed after lots_cars for fresh applies.
-- Board/Plan tables that exist on live. Full SECURITY DEFINER RPC bodies already exist on
-- production. This file is for NEW staging projects / schema documentation.
-- See docs/LIVE_MIGRATION_MAP.md.

create table if not exists public.slot_templates (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  instructor_id uuid not null references auth.users (id) on delete cascade,
  car_id uuid references public.cars (id) on delete set null,
  lot_id uuid references public.lots (id) on delete set null,
  name text not null,
  kind text not null default 'btw',
  duration_minutes integer not null default 60,
  travel_before_minutes integer not null default 0,
  travel_after_minutes integer not null default 15,
  days smallint[] not null default '{1,2,3,4,5}',
  window_start time not null default '09:00',
  window_end time not null default '17:00',
  meet text not null default 'lot',
  min_notice_hours integer not null default 24,
  max_advance_days integer not null default 14,
  note text not null default '',
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create index if not exists slot_templates_school_idx on public.slot_templates (school_id);
create index if not exists slot_templates_instructor_idx on public.slot_templates (instructor_id);

create table if not exists public.lessons (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  student_id uuid references public.students (id) on delete set null,
  instructor_id uuid references auth.users (id) on delete set null,
  car_id uuid references public.cars (id) on delete set null,
  lot_id uuid references public.lots (id) on delete set null,
  template_id uuid references public.slot_templates (id) on delete set null,
  start_at timestamptz not null,
  end_at timestamptz not null,
  travel_before_minutes integer not null default 0,
  travel_after_minutes integer not null default 15,
  meet text not null default 'lot',
  kind text not null default 'btw',
  status text not null default 'booked',
  name text not null default '',
  notes text not null default '',
  hours_drawn numeric(6,1) not null default 0,
  drive_id uuid,
  package_id uuid references public.student_packages (id) on delete set null,
  created_by uuid references auth.users (id) on delete set null,
  topic text not null default '',
  pickup text not null default '',
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_at > start_at)
);
create index if not exists lessons_school_start_idx on public.lessons (school_id, start_at);
create index if not exists lessons_instructor_start_idx on public.lessons (instructor_id, start_at);

create table if not exists public.reservations (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  student_id uuid not null references public.students (id) on delete cascade,
  instructor_id uuid not null references auth.users (id) on delete cascade,
  car_id uuid references public.cars (id) on delete set null,
  template_id uuid references public.slot_templates (id) on delete set null,
  lesson_id uuid references public.lessons (id) on delete set null,
  start_at timestamptz not null,
  end_at timestamptz not null,
  travel_before_minutes integer not null default 0,
  travel_after_minutes integer not null default 15,
  meet text not null default 'lot',
  kind text not null default 'btw',
  status text not null default 'requested',
  note text not null default '',
  decline_reason text,
  created_at timestamptz not null default now()
);
create index if not exists reservations_school_idx on public.reservations (school_id, start_at);
create index if not exists reservations_status_idx on public.reservations (school_id, status);

alter table public.slot_templates enable row level security;
alter table public.lessons enable row level security;
alter table public.reservations enable row level security;

-- NOTE: book_lesson, request_slot, accept_reservation, decline_reservation, add_block,
-- add_slot_template, mark_lesson, school_schedule (+ private helpers) already exist on
-- production. Staging that needs full booking should dump those defs from live or wait
-- for a follow-up zip with complete scheduling RPC bodies.
