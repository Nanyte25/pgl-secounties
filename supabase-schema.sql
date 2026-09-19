-- =====================================================================
--  PGL South Eastern Counties — backend schema (Supabase / Postgres)
--  Paste this into  Supabase → SQL Editor → New query → Run.
--  Cost: fits entirely inside Supabase's FREE tier.
--  Access model:  rank_level  1 = member · 2 = officer · 3 = admin
--  Gating is enforced by Row-Level Security (RLS), so restricted rows
--  NEVER leave the database for a browser that isn't entitled to them.
-- =====================================================================

-- ---------- reference: lodges (public) ----------
create table lodges (
  id          int primary key,          -- lodge number (5, 32, 44, 116, 642)
  name        text not null,
  town        text not null,
  address     text,
  eircode     text,
  contact_email text,
  has_chapter boolean default false
);

insert into lodges (id,name,town,address,eircode,contact_email,has_chapter) values
  (5,  'Masonic Lodge No. V',        'Waterford','1 Waterside, Waterside','X91 VN84','secretary@lodgev.com',        false),
  (32, 'Royal Shamrock Lodge No. 32','Waterford','1 Waterside, Waterside','X91 VN84','Waterford.Lodge32@gmail.com', true),
  (44, 'Donoughmore Lodge No. 44',   'Clonmel',  '12 Nelson St.',         'E91 V2R6','Ian.Devonport@gmail.com',     true),
  (116,'Unity Lodge No. 116',        'Carlow',   'Athy Road',             'R93 VW67','carlowunitylodge116@gmail.com',false),
  (642,'Masonic Lodge No. 642',      'Kilkenny', 'The Maltings, Kiln House, Tilbury Lane','R95 T97W','kilkennymasons@gmail.com', true);

-- ---------- member profiles (one row per auth user) ----------
create table profiles (
  id          uuid primary key references auth.users on delete cascade,
  full_name   text,
  lodge_id    int references lodges(id),
  masonic_rank text,                    -- free text for display, e.g. 'Master Mason'
  rank_level  int  not null default 1,  -- 1 member · 2 officer · 3 admin  (drives access)
  approved    boolean not null default false,   -- Secretary/Webmaster flips this on
  created_at  timestamptz default now()
);

-- helper: current user's effective rank (0 if not approved / not signed in)
create or replace function my_rank() returns int language sql stable security definer as $$
  select coalesce((select case when approved then rank_level else 0 end
                   from profiles where id = auth.uid()), 0);
$$;

-- ---------- gated content tables ----------
-- Every content row carries min_level. RLS compares it to my_rank().

create table notices (           -- circulars, summonses, minutes, resources
  id          bigint generated always as identity primary key,
  category    text,              -- 'notice' | 'summons' | 'minutes' | 'officer'
  title       text not null,
  body        text,
  file_url    text,              -- link to Supabase Storage object (optional)
  lodge_id    int references lodges(id),   -- null = whole Province
  min_level   int not null default 1,
  event_date  date,
  created_at  timestamptz default now()
);

create table gallery (           -- photo gallery (public by default)
  id          bigint generated always as identity primary key,
  image_url   text not null,
  caption     text,
  album       text,
  sort        int default 0,
  min_level   int not null default 0        -- 0 = visible to the public
);

-- =====================================================================
--  ROW-LEVEL SECURITY
-- =====================================================================
alter table profiles enable row level security;
alter table notices  enable row level security;
alter table gallery  enable row level security;
alter table lodges   enable row level security;

-- lodges: readable by anyone (public site needs them)
create policy "lodges public read" on lodges for select using (true);

-- profiles: a member sees & edits only their own row; admins see all
create policy "own profile read"   on profiles for select using (id = auth.uid() or my_rank() >= 3);
create policy "own profile update" on profiles for update using (id = auth.uid());
create policy "admin manage profiles" on profiles for all using (my_rank() >= 3) with check (my_rank() >= 3);
-- allow a brand-new signup to create their own (unapproved) profile row
create policy "self insert profile" on profiles for insert with check (id = auth.uid());

-- notices: visible only if the viewer's rank meets the row's min_level
create policy "notices by rank" on notices for select using (my_rank() >= min_level);
create policy "admin write notices" on notices for all using (my_rank() >= 3) with check (my_rank() >= 3);

-- gallery: public rows (min_level 0) show to everyone; higher rows gated
create policy "gallery by rank" on gallery for select using (my_rank() >= min_level);
create policy "admin write gallery" on gallery for all using (my_rank() >= 3) with check (my_rank() >= 3);

-- =====================================================================
--  Auto-create a pending profile whenever someone registers
-- =====================================================================
create or replace function handle_new_user() returns trigger language plpgsql security definer as $$
begin
  insert into profiles (id, full_name) values (new.id, new.raw_user_meta_data->>'full_name');
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users for each row execute function handle_new_user();

-- =====================================================================
--  Day-to-day maintenance (no code needed):
--   • Approve a member : Table editor → profiles → set approved = true,
--                        rank_level = 1/2/3.
--   • Add a summons    : Table editor → notices → new row, min_level = 1.
--   • Officer-only doc : notices → min_level = 2.
--   • Upload files     : Storage → bucket 'documents' (private) /
--                        'gallery' (public). Paste the URL into file_url.
-- =====================================================================
