-- ============================================================
--  The Provincial Officers roll
--  Run AFTER supabase-schema.sql (it needs my_rank() and lodges)
--
--  One row per office per year. The public site reads the current
--  year; officers edit the roll from the members' area and roll it
--  forward each installation.
-- ============================================================
set search_path = public, extensions;

create table if not exists officers (
  id          bigint generated always as identity primary key,
  year        int  not null default extract(year from now())::int,
  office      text not null,                  -- e.g. 'Provincial Grand Secretary'
  short       text,                           -- e.g. 'Prov. G. Sec.' for tight layouts
  sort        int  not null default 100,      -- seniority, ascending
  full_name   text,                           -- null = the office is vacant
  honorific   text,                           -- 'Rt. W. Bro.', 'W. Bro.', 'Bro.'
  lodge_id    int  references lodges(id),
  lodge_label text,                           -- free text where no lodge row fits
  email       text,
  photo_url   text,
  notes       text,
  active      boolean not null default true,
  updated_at  timestamptz not null default now(),
  unique (year, office)
);

create index if not exists officers_year_idx on officers(year, sort);

alter table officers enable row level security;

drop policy if exists "officers public read"   on officers;
drop policy if exists "officers manage roll"   on officers;

-- the roll is public: it is the page visitors and candidates look for
create policy "officers public read" on officers
  for select using (active = true);

create policy "officers manage roll" on officers
  for all to authenticated
  using (my_rank() >= 2) with check (my_rank() >= 2);

-- keep updated_at honest
create or replace function officers_touch() returns trigger as $$
begin new.updated_at = now(); return new; end;
$$ language plpgsql;

drop trigger if exists officers_touch_trg on officers;
create trigger officers_touch_trg before update on officers
  for each row execute function officers_touch();

-- ============================================================
--  Seed: the office ladder for the current year.
--
--  Only the two offices published on the old site are named here.
--  Every other office is seeded VACANT on purpose — fill them in
--  from the members' area rather than guessing.
--
--  Check the titles and the seniority order against the Province's
--  own returns before this goes live: Irish usage differs from
--  English in places, and a Province may not work every office.
-- ============================================================
insert into officers (year, office, short, sort, honorific, full_name, email) values
  (extract(year from now())::int, 'Provincial Grand Master',                'Prov. G.M.',      10, 'Rt. W. Bro.', 'Ian Devonport', null),
  (extract(year from now())::int, 'Deputy Provincial Grand Master',         'Dep. Prov. G.M.', 20, 'V. W. Bro.',  null, null),
  (extract(year from now())::int, 'Provincial Senior Grand Warden',         'Prov. S.G.W.',    30, 'W. Bro.',     null, null),
  (extract(year from now())::int, 'Provincial Junior Grand Warden',         'Prov. J.G.W.',    40, 'W. Bro.',     null, null),
  (extract(year from now())::int, 'Provincial Grand Treasurer',             'Prov. G. Treas.', 50, 'W. Bro.',     null, null),
  (extract(year from now())::int, 'Provincial Grand Secretary',             'Prov. G. Sec.',   60, 'W. Bro.',     'Marcus Notley', 'marcusnotley@gmail.com'),
  (extract(year from now())::int, 'Provincial Grand Director of Ceremonies','Prov. G.D.C.',    70, 'W. Bro.',     null, null),
  (extract(year from now())::int, 'Provincial Senior Grand Deacon',         'Prov. S.G.D.',    80, 'Bro.',        null, null),
  (extract(year from now())::int, 'Provincial Junior Grand Deacon',         'Prov. J.G.D.',    90, 'Bro.',        null, null),
  (extract(year from now())::int, 'Provincial Grand Almoner',               'Prov. G. Alm.',  100, 'W. Bro.',     null, null),
  (extract(year from now())::int, 'Provincial Grand Superintendent of Works','Prov. G. Supt.',110, 'W. Bro.',     null, null),
  (extract(year from now())::int, 'Provincial Grand Organist',              'Prov. G. Org.',  120, 'Bro.',        null, null),
  (extract(year from now())::int, 'Provincial Grand Inner Guard',           'Prov. G.I.G.',   130, 'Bro.',        null, null),
  (extract(year from now())::int, 'Provincial Grand Tyler',                 'Prov. G. Tyler', 140, 'Bro.',        null, null)
on conflict (year, office) do nothing;

-- ============================================================
--  Roll the whole roll forward to a new year, names and all,
--  so next year's returns start from this year's sheet.
--    select officers_roll_forward(2027);
-- ============================================================
create or replace function officers_roll_forward(new_year int)
returns int as $$
declare n int;
begin
  if my_rank() < 2 then
    raise exception 'Only an officer may roll the roll forward.';
  end if;
  insert into officers (year, office, short, sort, full_name, honorific, lodge_id, lodge_label, email)
  select new_year, office, short, sort, full_name, honorific, lodge_id, lodge_label, email
  from officers
  where year = (select max(year) from officers where year < new_year)
  on conflict (year, office) do nothing;
  get diagnostics n = row_count;
  return n;
end;
$$ language plpgsql security invoker;
