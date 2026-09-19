-- ============================================================
--  Calendar events + manager  (run AFTER supabase-setup.sql)
--  Adds the events table with rank-aware Row-Level Security.
--    min_level: 0 = public · 1 = members · 2 = officers
--  Read: anyone sees rows at/above their rank. Write: officers+ (>=2).
-- ============================================================
set search_path = public, extensions;

create table if not exists events (
  id          bigint generated always as identity primary key,
  title       text not null,
  starts_at   timestamptz not null,
  ends_at     timestamptz,
  location    text,
  body        text,
  lodge_id    int references lodges(id),
  min_level   int not null default 0,
  created_by  uuid references auth.users,
  created_at  timestamptz default now()
);

alter table events enable row level security;
drop policy if exists "events by rank"       on events;
drop policy if exists "officers manage events" on events;
create policy "events by rank"        on events for select using (my_rank() >= min_level);
create policy "officers manage events" on events for all    using (my_rank() >= 2) with check (my_rank() >= 2);

-- a couple of sample events (safe to delete later)
insert into events (title, starts_at, location, body, min_level) values
  ('Waterford Masonic Summer BBQ', (now() + interval '20 days')::date + time '18:00',
   'The Lodge Rooms, 1 Waterside, Waterford', 'Live music, raffle, all welcome.', 0),
  ('Officers'' Installation Rehearsal', (now() + interval '9 days')::date + time '19:00',
   '1 Waterside, Waterford', 'For Provincial officers and above.', 2);
