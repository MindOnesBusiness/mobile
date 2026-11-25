-- =====================================================================
--  MOB Vault database update 16 (all-in-one)
--  Run this once in Supabase: SQL Editor -> New query -> paste -> Run.
--  It holds everything from updates 12 to 15 too, so it is safe to run
--  whether or not you ran 15. Running it again does no harm.
--
--  Part A: profile photos
--  Part B: Shelf rows and descriptions
--  Part C: saved items, Home, Ledger, Focus Room
--  Part D: Formidable Routine
--  Part E: Formidable Routine upgrades: sleep, reading, mood check-in (new)
--  Part F: Weekly Wheel (new)
--  Part G: Sticks School (new)
--  Part I: free vs VIP limits for every tool except Trick Talk (new)
--  Part H: a quick check of the Shelf at the end
-- =====================================================================

begin;

-- =====================  PART A: profile photos  =====================
insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true)
on conflict (id) do update set public = true;

drop policy if exists "people read their own photo" on storage.objects;
create policy "people read their own photo" on storage.objects for select to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "people upload their own photo" on storage.objects;
create policy "people upload their own photo" on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "people change their own photo" on storage.objects;
create policy "people change their own photo" on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "people delete their own photo" on storage.objects;
create policy "people delete their own photo" on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- =====================  PART B: Shelf rows and descriptions  =====================
alter table public.volumes drop constraint if exists volumes_category_chk;
alter table public.volumes add constraint volumes_category_chk
  check (category in ('growth','business','scripture','oldbooks','toolkit','council','misc'));

-- The three Bible items go in Scripture.
update public.volumes set category = 'scripture'
 where title ilike 'red letter words of christ%' or title ilike 'red letters geneva%' or title ilike '%1560 geneva bible%';

-- The Roadside Card and the Accountability File go in Toolkit.
update public.volumes set category = 'toolkit'
 where title ilike '%roadside card%' or title ilike '%accountability file%';

-- Everything else that was in Miscellaneous (the 1890s books) goes in Old Books.
update public.volumes set category = 'oldbooks' where category = 'misc';

-- New items now start in Old Books unless you pick a row.
alter table public.volumes alter column category set default 'oldbooks';

-- ---------- 2. Descriptions ----------
update public.volumes set subtitle = 'Seven short practices to stay steady and on track.' where id = 'destiny-lock' or title ilike 'destiny lock%';
update public.volumes set subtitle = replace(subtitle, 'exact words,.', 'exact words.') where title ilike 'red letter words of christ%';
update public.volumes set subtitle = 'The words of Jesus from the 1560 Geneva Bible.' where title ilike 'red letters geneva%';
update public.volumes set subtitle = 'One of the earliest English Bibles.' where title ilike '%1560 geneva bible%' and subtitle ilike 'one of the earliest english bibles%';
update public.volumes set subtitle = replace(subtitle, 'Set-Up', 'Set Up') where title ilike 'keys to your kingdom%';
update public.volumes set subtitle = 'Simple ways to read faster and remember more.' where title ilike 'read faster%';
update public.volumes set subtitle = replace(subtitle, 'an printable', 'a printable') where title ilike '%roadside card%';

-- Every description: no ",." typo, starts with a capital letter, ends with a period.
update public.volumes set subtitle = regexp_replace(subtitle, ',\s*\.', '.', 'g') where subtitle ~ ',\s*\.';
update public.volumes set subtitle = upper(left(btrim(subtitle), 1)) || substr(btrim(subtitle), 2)
 where coalesce(btrim(subtitle), '') <> '' and left(btrim(subtitle), 1) <> upper(left(btrim(subtitle), 1));
update public.volumes set subtitle = btrim(subtitle) || '.'
 where coalesce(btrim(subtitle), '') <> '' and right(btrim(subtitle), 1) not in ('.', '!', '?');

-- ---------- 3. Be Heard is the free guide at the front of Personal Growth ----------
update public.volumes set category = 'growth',
       sort = (select coalesce(min(sort), 1) - 1 from public.volumes where category = 'growth' and title not ilike 'be heard%')
 where title ilike 'be heard%';
-- Make it Free only if its file is already in the public folder (guests cannot open private files).
-- If the check at the bottom still shows Be Heard as "member" or "vip", re-add it in the app
-- (Admin → Shelf) with "Free (no account needed)", then delete the old one.
update public.volumes v set tier = 'free'
 where v.title ilike 'be heard%'
   and exists (select 1 from public.shelf_files f where f.volume_id = v.id
               and (f.bucket in ('shelf-public', 'site') or f.video_url is not null));
-- Destiny Lock is no longer the free sample: guests now see it as "Free account".
-- (Its free sample file stays in your folder. Nothing is deleted.)
delete from public.shelf_versions where volume_id = 'destiny-lock' and tier = 'free';
update public.volumes set tier = 'member' where id = 'destiny-lock' and tier = 'free';


-- =====================  PART C: saved items, Home, Ledger, Focus Room  =====================
create table if not exists public.saved_items (
  user_id   uuid not null references auth.users(id) on delete cascade,
  volume_id text not null references public.volumes(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, volume_id)
);
alter table public.saved_items enable row level security;
drop policy if exists "own saved items" on public.saved_items;
create policy "own saved items" on public.saved_items for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create table if not exists public.recent_opens (
  user_id   uuid not null references auth.users(id) on delete cascade,
  volume_id text not null references public.volumes(id) on delete cascade,
  opened_at timestamptz not null default now(),
  primary key (user_id, volume_id)
);
alter table public.recent_opens enable row level security;
drop policy if exists "own recent opens" on public.recent_opens;
create policy "own recent opens" on public.recent_opens for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- When each Shelf item was added. Items already on the Shelf count as added on launch day, so they don't all show as "new".
alter table public.volumes add column if not exists created_at timestamptz;
update public.volumes set created_at = '2026-10-10T00:00:00-05:00' where created_at is null;
alter table public.volumes alter column created_at set default now();
alter table public.volumes alter column created_at set not null;
alter table public.profiles add column if not exists last_seen_at timestamptz;

-- Marks this visit and gives back the one before it (for "New since your last visit").
-- A new visit only counts after 30 minutes away, so moving around the app doesn't reset it.
create or replace function public.touch_last_seen() returns timestamptz
language plpgsql volatile security definer set search_path = public as $$
declare prev timestamptz;
begin
  if auth.uid() is null then return null; end if;
  select last_seen_at into prev from public.profiles where id = auth.uid();
  if prev is null or prev < now() - interval '30 minutes' then
    update public.profiles set last_seen_at = now() where id = auth.uid();
  end if;
  return prev;
end $$;
revoke all on function public.touch_last_seen() from public, anon;
grant execute on function public.touch_last_seen() to authenticated;

-- ---------- 2. Cash & Hours Ledger ----------
create table if not exists public.ledgers (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name        text not null default 'My ledger' check (char_length(name) between 1 and 60),
  rate        numeric(10,2) not null default 25 check (rate > 0),
  worker      text not null default 'Me' check (char_length(worker) <= 40),
  payer       text not null default 'Client' check (char_length(payer) <= 40),
  share_token text unique,
  created_at  timestamptz not null default now()
);
create table if not exists public.ledger_entries (
  id           uuid primary key default gen_random_uuid(),
  ledger_id    uuid not null references public.ledgers(id) on delete cascade,
  receipt_no   text not null,
  kind         text not null check (kind in ('work','cash')),
  entry_date   date not null,
  hours        numeric(10,2) check (hours is null or hours > 0),
  amount       numeric(10,2) check (amount is null or amount > 0),
  rate         numeric(10,2) not null check (rate > 0),     -- the rate when it was logged; never changes later
  note         text check (char_length(note) <= 120),
  voided       boolean not null default false,
  voided_at    timestamptz,
  confirmed_at timestamptz,
  created_at   timestamptz not null default now(),
  unique (ledger_id, receipt_no),
  check ((kind = 'work' and hours is not null) or (kind = 'cash' and amount is not null))
);
alter table public.ledgers enable row level security;
alter table public.ledger_entries enable row level security;

drop policy if exists "own ledgers read" on public.ledgers;
drop policy if exists "own ledgers add" on public.ledgers;
drop policy if exists "own ledgers change" on public.ledgers;
create policy "own ledgers read"   on public.ledgers for select to authenticated using (owner_id = auth.uid());
create policy "own ledgers add"    on public.ledgers for insert to authenticated with check (owner_id = auth.uid());
create policy "own ledgers change" on public.ledgers for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
-- No delete policy: ledgers and entries are never deleted.

drop policy if exists "own entries read" on public.ledger_entries;
drop policy if exists "own entries add" on public.ledger_entries;
drop policy if exists "own entries change" on public.ledger_entries;
create policy "own entries read" on public.ledger_entries for select to authenticated
  using (exists (select 1 from public.ledgers l where l.id = ledger_id and l.owner_id = auth.uid()));
create policy "own entries add" on public.ledger_entries for insert to authenticated
  with check (exists (select 1 from public.ledgers l where l.id = ledger_id and l.owner_id = auth.uid()));
create policy "own entries change" on public.ledger_entries for update to authenticated
  using (exists (select 1 from public.ledgers l where l.id = ledger_id and l.owner_id = auth.uid()));

-- Free members get 1 ledger. VIPs get as many as they want. Only VIPs can turn on a share link.
create or replace function public.ledger_rules() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' and not (public.is_vip() or public.is_admin())
     and exists (select 1 from public.ledgers where owner_id = new.owner_id) then
    raise exception 'Free members get 1 ledger. VIP gets one for every job.';
  end if;
  if new.share_token is not null and (tg_op = 'INSERT' or new.share_token is distinct from old.share_token)
     and not (public.is_vip() or public.is_admin()) then
    raise exception 'Share links are for VIPs.';
  end if;
  return new;
end $$;
drop trigger if exists ledger_rules on public.ledgers;
create trigger ledger_rules before insert or update on public.ledgers for each row execute function public.ledger_rules();

-- Entries: only voided / confirmed can change after they are saved. The numbers and dates stay as logged.
create or replace function public.ledger_entry_lock() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.receipt_no is distinct from old.receipt_no or new.kind is distinct from old.kind
     or new.entry_date is distinct from old.entry_date or new.hours is distinct from old.hours
     or new.amount is distinct from old.amount or new.rate is distinct from old.rate
     or new.note is distinct from old.note or new.created_at is distinct from old.created_at
     or new.ledger_id is distinct from old.ledger_id then
    raise exception 'Saved entries cannot be changed. Void it and add a new one.';
  end if;
  if new.voided and not old.voided then new.voided_at := now(); end if;
  if not new.voided then new.voided_at := null; end if;
  if new.confirmed_at is not null and old.confirmed_at is not null then new.confirmed_at := old.confirmed_at; end if;
  return new;
end $$;
drop trigger if exists ledger_entry_lock on public.ledger_entries;
create trigger ledger_entry_lock before update on public.ledger_entries for each row execute function public.ledger_entry_lock();

-- View-only share page: anyone with the link sees that one ledger, no account needed.
create or replace function public.ledger_shared(p_token text) returns json
language sql stable security definer set search_path = public as $$
  select json_build_object(
    'name', l.name, 'rate', l.rate, 'worker', l.worker, 'payer', l.payer,
    'entries', coalesce((select json_agg(json_build_object(
        'receipt_no', e.receipt_no, 'kind', e.kind, 'entry_date', e.entry_date, 'hours', e.hours, 'amount', e.amount,
        'rate', e.rate, 'note', e.note, 'voided', e.voided, 'confirmed_at', e.confirmed_at, 'created_at', e.created_at)
        order by e.entry_date, e.created_at) from public.ledger_entries e where e.ledger_id = l.id), '[]'::json))
  from public.ledgers l
  where p_token is not null and length(p_token) >= 20 and l.share_token = p_token;
$$;
grant execute on function public.ledger_shared(text) to anon, authenticated;

-- ---------- 3. Focus Room ----------
create table if not exists public.focus_sessions (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null default auth.uid() references auth.users(id) on delete cascade,
  task           text not null check (char_length(task) between 1 and 120),
  tag            text check (char_length(tag) <= 30),
  mode           text not null check (mode in ('sprint','deep','flow','custom')),
  planned_min    int check (planned_min between 1 and 240),
  started_at     timestamptz not null default now(),
  ends_at        timestamptz,
  ended_at       timestamptz,
  focus_seconds  int not null default 0 check (focus_seconds >= 0),
  drifts         int not null default 0 check (drifts >= 0),
  parked         text check (char_length(parked) <= 1000),
  finished       text check (finished in ('yes','part','no')),
  rating         int check (rating between 1 and 5),
  share_live     boolean not null default false
);
create index if not exists focus_sessions_user_started on public.focus_sessions (user_id, started_at desc);
alter table public.focus_sessions enable row level security;
drop policy if exists "own focus sessions" on public.focus_sessions;
create policy "own focus sessions" on public.focus_sessions for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- "Focusing now": who is in a session right now and chose to show it. Only the name and the task.
create or replace function public.focusing_now() returns table(display_name text, username text, avatar_url text, task text, ends_at timestamptz)
language sql stable security definer set search_path = public as $$
  select p.display_name, p.username, p.avatar_url, f.task, f.ends_at
    from public.focus_sessions f join public.profiles p on p.id = f.user_id
   where f.share_live and f.ended_at is null and f.started_at > now() - interval '4 hours'
     and auth.uid() is not null
   order by f.started_at desc limit 20;
$$;
revoke all on function public.focusing_now() from public, anon;
grant execute on function public.focusing_now() to authenticated;

-- =====================  PART D: Formidable Routine  =====================
create table if not exists public.routine_settings (
  user_id     uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  leave_time  time not null default '07:30',
  started_on  date not null default current_date,          -- week 1 of the plan and the exercise ladder
  rough_steps text[] not null default array['wake','exercise','prayer','dog'],
  plan_done   text[] not null default '{}',                 -- Enterprise Hour tasks checked off
  plan_notes  jsonb not null default '{}'::jsonb,           -- notes for each plan week (niche, offer, ...)
  updated_at  timestamptz not null default now()
);
-- Each person's own changes to the lists: steps they added, and default steps they removed.
alter table public.routine_settings add column if not exists custom jsonb not null default '{"morning":[],"evening":[],"prep":[]}'::jsonb;
alter table public.routine_settings add column if not exists hidden text[] not null default '{}';
alter table public.routine_settings enable row level security;
drop policy if exists "own routine settings" on public.routine_settings;
create policy "own routine settings" on public.routine_settings for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- One row per person per day: what they checked off and their business numbers.
create table if not exists public.routine_days (
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  day        date not null,
  checks     text[] not null default '{}',
  rough      boolean not null default false,
  morning_done boolean not null default false,
  evening_done boolean not null default false,
  leads      int not null default 0 check (leads between 0 and 10000),
  calls      int not null default 0 check (calls between 0 and 10000),
  convos     int not null default 0 check (convos between 0 and 10000),
  booked     int not null default 0 check (booked between 0 and 10000),
  closed     int not null default 0 check (closed between 0 and 10000),
  updated_at timestamptz not null default now(),
  primary key (user_id, day)
);
alter table public.routine_days enable row level security;
drop policy if exists "own routine days" on public.routine_days;
drop policy if exists "own routine days read" on public.routine_days;
drop policy if exists "own routine days write" on public.routine_days;
drop policy if exists "own routine days change" on public.routine_days;
-- Reading: everyone sees the last few days. Only VIPs (and admins) see older days, for history and streaks.
create policy "own routine days read" on public.routine_days for select to authenticated
  using (user_id = auth.uid() and (day >= current_date - 2 or public.is_vip() or public.is_admin()));
create policy "own routine days write" on public.routine_days for insert to authenticated
  with check (user_id = auth.uid() and day between current_date - 2 and current_date + 1);
create policy "own routine days change" on public.routine_days for update to authenticated
  using (user_id = auth.uid() and day >= current_date - 2) with check (user_id = auth.uid());


-- =====================  PART E: Formidable Routine upgrades (new in 16)  =====================
alter table public.routine_settings add column if not exists sleep_hours numeric(3,1) not null default 6.5;
alter table public.routine_settings drop constraint if exists routine_sleep_chk;
alter table public.routine_settings add constraint routine_sleep_chk check (sleep_hours between 6 and 8);
alter table public.routine_settings add column if not exists reading jsonb not null default '{"on":false,"per_day":3,"deadline":0}'::jsonb;
alter table public.routine_settings add column if not exists mood_morning boolean not null default false;

alter table public.routine_days add column if not exists chapters_am int not null default 0;
alter table public.routine_days add column if not exists chapters_pm int not null default 0;
alter table public.routine_days add column if not exists mood int;
alter table public.routine_days add column if not exists mood_am int;
alter table public.routine_days add column if not exists feelings text[] not null default '{}';
alter table public.routine_days add column if not exists mood_note text;
alter table public.routine_days drop constraint if exists routine_days_new_chk;
alter table public.routine_days add constraint routine_days_new_chk check (
  chapters_am between 0 and 200 and chapters_pm between 0 and 200
  and (mood is null or mood between 1 and 5) and (mood_am is null or mood_am between 1 and 5)
  and coalesce(array_length(feelings, 1), 0) <= 15 and (mood_note is null or char_length(mood_note) <= 280));


-- =====================  PART F: Weekly Wheel (new)  =====================
create table if not exists public.wheel_weeks (
  user_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  week_start   date not null check (extract(isodow from week_start) = 1),   -- always a Monday
  scores       jsonb not null default '{}'::jsonb,      -- Wheel of Life, 1 to 10 for each area
  inner_wheel  jsonb not null default '{}'::jsonb,      -- Inner Wheel, 0 to 4 for each theme
  inner_auto   jsonb,                                   -- what the daily check-ins filled in
  checkin_days int not null default 0 check (checkin_days between 0 and 7),
  priorities   jsonb not null default '[]'::jsonb,
  goals        jsonb not null default '{}'::jsonb,
  goals_done   jsonb not null default '{}'::jsonb,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  primary key (user_id, week_start)
);
alter table public.wheel_weeks enable row level security;
drop policy if exists "own wheel read" on public.wheel_weeks;
drop policy if exists "own wheel write" on public.wheel_weeks;
drop policy if exists "own wheel change" on public.wheel_weeks;
-- Free: this week and last week. VIP: every week. Only the member ever sees their own.
create policy "own wheel read" on public.wheel_weeks for select to authenticated
  using (user_id = auth.uid() and (week_start >= date_trunc('week', current_date)::date - 7 or public.is_vip()));
create policy "own wheel write" on public.wheel_weeks for insert to authenticated
  with check (user_id = auth.uid() and week_start between date_trunc('week', current_date)::date - 7 and date_trunc('week', current_date)::date + 7);
create policy "own wheel change" on public.wheel_weeks for update to authenticated
  using (user_id = auth.uid() and week_start >= date_trunc('week', current_date)::date - 7) with check (user_id = auth.uid());

-- =====================  PART G: Sticks School (new)  =====================
create table if not exists public.school_courses (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name        text not null check (char_length(btrim(name)) between 1 and 60),
  start_date  date not null default current_date,
  session_min int not null default 15 check (session_min between 5 and 120),
  sort        int not null default 0,
  created_at  timestamptz not null default now()
);
create index if not exists school_courses_user on public.school_courses(user_id);
alter table public.school_courses enable row level security;
drop policy if exists "own school courses" on public.school_courses;
create policy "own school courses" on public.school_courses for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Free members get 1 course. VIPs get 3.
create or replace function public.school_course_rules() returns trigger language plpgsql as $$
declare n int;
begin
  select count(*) into n from public.school_courses where user_id = new.user_id;
  if n >= 3 then raise exception 'You can study up to 3 courses at once.'; end if;
  if n >= 1 and not (public.is_vip() or public.is_admin()) then raise exception 'Free members get 1 course. VIPs get 3.'; end if;
  return new;
end $$;
drop trigger if exists school_course_rules on public.school_courses;
create trigger school_course_rules before insert on public.school_courses for each row execute function public.school_course_rules();

create table if not exists public.school_curriculum (
  course_id   uuid not null references public.school_courses(id) on delete cascade,
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  stick       int not null check (stick between 1 and 10),
  resource    text check (char_length(resource) <= 500),
  objective   text check (char_length(objective) <= 500),
  task1       text check (char_length(task1) <= 500),
  task2       text check (char_length(task2) <= 500),
  task3       text check (char_length(task3) <= 500),
  application text check (char_length(application) <= 500),
  done_when   text check (char_length(done_when) <= 500),
  updated_at  timestamptz not null default now(),
  primary key (course_id, stick)
);
alter table public.school_curriculum enable row level security;
drop policy if exists "own school curriculum" on public.school_curriculum;
create policy "own school curriculum" on public.school_curriculum for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid() and exists (select 1 from public.school_courses c where c.id = course_id and c.user_id = auth.uid()));

create table if not exists public.school_sessions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  course_id   uuid not null references public.school_courses(id) on delete cascade,
  day         date not null,                     -- the day it was done
  stick       int not null check (stick between 1 and 10),
  td          int not null check (td between 1 and 3),
  minutes     int not null default 15 check (minutes between 0 and 240),
  done        boolean not null default true,
  note        text check (char_length(note) <= 500),
  makeup_for  date,                              -- for a make-up: the missed day it covers
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  check (makeup_for is null or makeup_for < day)
);
-- One session per course per planned day.
create unique index if not exists school_sessions_one_per_day on public.school_sessions (course_id, (coalesce(makeup_for, day)));
create index if not exists school_sessions_user_day on public.school_sessions (user_id, day);
alter table public.school_sessions enable row level security;
drop policy if exists "own school sessions read" on public.school_sessions;
drop policy if exists "own school sessions write" on public.school_sessions;
drop policy if exists "own school sessions change" on public.school_sessions;
drop policy if exists "own school sessions delete" on public.school_sessions;
create policy "own school sessions read" on public.school_sessions for select to authenticated
  using (user_id = auth.uid());
-- Sessions are logged on the day you do them. Missed days never fill in on their own.
create policy "own school sessions write" on public.school_sessions for insert to authenticated
  with check (user_id = auth.uid() and day between current_date - 2 and current_date + 1
    and exists (select 1 from public.school_courses c where c.id = course_id and c.user_id = auth.uid()));
create policy "own school sessions change" on public.school_sessions for update to authenticated
  using (user_id = auth.uid() and day >= current_date - 2) with check (user_id = auth.uid());
create policy "own school sessions delete" on public.school_sessions for delete to authenticated
  using (user_id = auth.uid());

grant select, insert, update, delete on public.wheel_weeks, public.school_courses, public.school_curriculum, public.school_sessions to authenticated;

-- =====================  PART I: free vs VIP limits for the tools (new)  =====================
-- Free members get a taste of each tool. VIP ($7 a month) opens everything.
-- These rules only apply to members using the app. They never touch what you run here in the SQL Editor.
create or replace function public.vip_or_admin() returns boolean language sql stable as $$
  select auth.uid() is null or public.is_vip() or public.is_admin();
$$;

-- Ledger: free = 1 ledger and 10 receipts.
create or replace function public.ledger_entry_limit() returns trigger language plpgsql as $$
declare n int;
begin
  if public.vip_or_admin() then return new; end if;
  select count(*) into n from public.ledger_entries e join public.ledgers l on l.id = e.ledger_id where l.owner_id = auth.uid();
  if n >= 10 then raise exception 'Free members get 10 receipts. VIP gets unlimited receipts.'; end if;
  return new;
end $$;
drop trigger if exists ledger_entry_limit on public.ledger_entries;
create trigger ledger_entry_limit before insert on public.ledger_entries for each row execute function public.ledger_entry_limit();

-- Focus Room: free = 1 Sprint every 24 hours.
create or replace function public.focus_limit() returns trigger language plpgsql as $$
begin
  if public.vip_or_admin() then return new; end if;
  if new.mode <> 'sprint' then raise exception 'Free members get Sprint mode. VIP opens every mode.'; end if;
  if exists (select 1 from public.focus_sessions where user_id = new.user_id and started_at > now() - interval '24 hours') then
    raise exception 'Free members get 1 Sprint every 24 hours. VIP has no limit.'; end if;
  return new;
end $$;
drop trigger if exists focus_limit on public.focus_sessions;
create trigger focus_limit before insert on public.focus_sessions for each row execute function public.focus_limit();

-- Formidable Routine: free = the basic morning and evening checklists.
-- Free members cannot change their own steps, rough morning, reading or mood settings, or the business plan.
create or replace function public.routine_settings_limit() returns trigger language plpgsql as $$
begin
  if public.vip_or_admin() then return new; end if;
  if tg_op = 'UPDATE' then
    new.custom := old.custom; new.hidden := old.hidden; new.rough_steps := old.rough_steps;
    new.reading := old.reading; new.mood_morning := old.mood_morning; new.plan_done := old.plan_done; new.plan_notes := old.plan_notes;
  else
    new.custom := '{"morning":[],"evening":[],"prep":[]}'::jsonb; new.hidden := '{}'; new.rough_steps := array['wake','exercise','prayer','dog'];
    new.reading := '{"on":false,"per_day":3,"deadline":0}'::jsonb; new.mood_morning := false; new.plan_done := '{}'; new.plan_notes := '{}'::jsonb;
  end if;
  return new;
end $$;
drop trigger if exists routine_settings_limit on public.routine_settings;
create trigger routine_settings_limit before insert or update on public.routine_settings for each row execute function public.routine_settings_limit();

-- Free members save their checkmarks only. Mood, reading, rough mornings and the scoreboard are VIP.
create or replace function public.routine_days_limit() returns trigger language plpgsql as $$
begin
  if public.vip_or_admin() then return new; end if;
  if tg_op = 'UPDATE' then
    new.rough := old.rough; new.leads := old.leads; new.calls := old.calls; new.convos := old.convos; new.booked := old.booked; new.closed := old.closed;
    new.chapters_am := old.chapters_am; new.chapters_pm := old.chapters_pm; new.mood := old.mood; new.mood_am := old.mood_am;
    new.feelings := old.feelings; new.mood_note := old.mood_note;
  else
    new.rough := false; new.leads := 0; new.calls := 0; new.convos := 0; new.booked := 0; new.closed := 0;
    new.chapters_am := 0; new.chapters_pm := 0; new.mood := null; new.mood_am := null; new.feelings := '{}'; new.mood_note := null;
  end if;
  return new;
end $$;
drop trigger if exists routine_days_limit on public.routine_days;
create trigger routine_days_limit before insert or update on public.routine_days for each row execute function public.routine_days_limit();

-- Free members see the last 3 days. VIPs see everything.
drop policy if exists "own routine days read" on public.routine_days;
create policy "own routine days read" on public.routine_days for select to authenticated
  using (user_id = auth.uid() and (day >= current_date - 2 or public.is_vip() or public.is_admin()));

-- Weekly Wheel: free = the Wheel of Life for this week only.
create or replace function public.wheel_limit() returns trigger language plpgsql as $$
begin
  if public.vip_or_admin() then return new; end if;
  if tg_op = 'UPDATE' then
    new.inner_wheel := old.inner_wheel; new.inner_auto := old.inner_auto; new.priorities := old.priorities; new.goals := old.goals; new.goals_done := old.goals_done;
  else
    new.inner_wheel := '{}'::jsonb; new.inner_auto := null; new.priorities := '[]'::jsonb; new.goals := '{}'::jsonb; new.goals_done := '{}'::jsonb;
  end if;
  return new;
end $$;
drop trigger if exists wheel_limit on public.wheel_weeks;
create trigger wheel_limit before insert or update on public.wheel_weeks for each row execute function public.wheel_limit();
drop policy if exists "own wheel read" on public.wheel_weeks;
drop policy if exists "own wheel write" on public.wheel_weeks;
drop policy if exists "own wheel change" on public.wheel_weeks;
create policy "own wheel read" on public.wheel_weeks for select to authenticated
  using (user_id = auth.uid() and (week_start >= date_trunc('week', current_date)::date or public.is_vip() or public.is_admin()));
create policy "own wheel write" on public.wheel_weeks for insert to authenticated
  with check (user_id = auth.uid() and week_start <= date_trunc('week', current_date)::date + 7
    and week_start >= date_trunc('week', current_date)::date - case when public.is_vip() or public.is_admin() then 7 else 0 end);
create policy "own wheel change" on public.wheel_weeks for update to authenticated
  using (user_id = auth.uid() and week_start >= date_trunc('week', current_date)::date - case when public.is_vip() or public.is_admin() then 7 else 0 end)
  with check (user_id = auth.uid());

-- Sticks School: free = 1 course, plan the first stick, no make-ups.
create or replace function public.school_curriculum_limit() returns trigger language plpgsql as $$
begin
  if new.stick > 1 and not public.vip_or_admin() then raise exception 'Free members plan the first stick. VIP plans all 10.'; end if;
  return new;
end $$;
drop trigger if exists school_curriculum_limit on public.school_curriculum;
create trigger school_curriculum_limit before insert or update on public.school_curriculum for each row execute function public.school_curriculum_limit();
create or replace function public.school_makeup_limit() returns trigger language plpgsql as $$
begin
  if new.makeup_for is not null and not public.vip_or_admin() then raise exception 'Make-up days are for VIPs.'; end if;
  return new;
end $$;
drop trigger if exists school_makeup_limit on public.school_sessions;
create trigger school_makeup_limit before insert or update on public.school_sessions for each row execute function public.school_makeup_limit();

commit;

-- =====================  PART H: check the Shelf  =====================
select title, category as row, tier as access, subtitle as description, sort
  from public.volumes where status <> 'hidden'
 order by array_position(array['growth','business','scripture','oldbooks','toolkit','council','misc'], category), sort;
