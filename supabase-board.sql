-- ============================================================
--  Bulletin board (threaded) + members-only photograph gallery
--  Run AFTER supabase-schema.sql, supabase-events.sql,
--  supabase-dashboard.sql and supabase-features.sql
-- ============================================================
set search_path = public, extensions;

-- ============================================================
--  1. BULLETIN BOARD
--     Any approved member may post; replies hang off a parent
--     post. Officers (rank 2) may pin and remove any post;
--     every Brother may edit or remove his own.
-- ============================================================
create table if not exists board_posts (
  id            bigint generated always as identity primary key,
  parent_id     bigint references board_posts(id) on delete cascade,
  user_id       uuid   not null references auth.users default auth.uid(),
  author_name   text,
  author_avatar text,
  title         text,
  body          text not null,
  category      text not null default 'general',   -- general | notice | question | forsale | travel
  min_level     int  not null default 1,           -- 1 members · 2 officers
  pinned        boolean not null default false,
  edited_at     timestamptz,
  created_at    timestamptz not null default now()
);

create index if not exists board_posts_parent_idx  on board_posts(parent_id);
create index if not exists board_posts_recent_idx  on board_posts(pinned desc, created_at desc);

alter table board_posts enable row level security;

drop policy if exists "board read by rank"      on board_posts;
drop policy if exists "board members post"      on board_posts;
drop policy if exists "board author or officer edits"   on board_posts;
drop policy if exists "board author or officer deletes" on board_posts;

-- read: anything at or below your rank
create policy "board read by rank" on board_posts
  for select to authenticated
  using (my_rank() >= min_level);

-- write: approved members only, and only as yourself
create policy "board members post" on board_posts
  for insert to authenticated
  with check (my_rank() >= 1 and user_id = auth.uid() and my_rank() >= min_level);

-- edit: your own post, or any post if you are an officer (this is what allows pinning)
create policy "board author or officer edits" on board_posts
  for update to authenticated
  using (user_id = auth.uid() or my_rank() >= 2)
  with check (user_id = auth.uid() or my_rank() >= 2);

-- remove: your own post, or any post if you are an officer
create policy "board author or officer deletes" on board_posts
  for delete to authenticated
  using (user_id = auth.uid() or my_rank() >= 2);

-- reply counts without a second round trip
create or replace view board_threads as
  select p.*,
         (select count(*) from board_posts r where r.parent_id = p.id) as reply_count,
         (select max(r.created_at) from board_posts r where r.parent_id = p.id) as last_reply_at
  from board_posts p
  where p.parent_id is null;

-- ============================================================
--  2. MEMBERS-ONLY GALLERY
--     Private bucket: nothing is publicly readable. The browser
--     asks for a short-lived signed URL per image after sign-in.
-- ============================================================
insert into storage.buckets (id, name, public)
values ('gallery','gallery', false)
on conflict (id) do nothing;

drop policy if exists "gallery members read"   on storage.objects;
drop policy if exists "gallery members upload" on storage.objects;
drop policy if exists "gallery owner or officer deletes" on storage.objects;

create policy "gallery members read" on storage.objects
  for select to authenticated
  using (bucket_id = 'gallery' and my_rank() >= 1);

create policy "gallery members upload" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'gallery' and my_rank() >= 1);

create policy "gallery owner or officer deletes" on storage.objects
  for delete to authenticated
  using (bucket_id = 'gallery' and (owner = auth.uid() or my_rank() >= 2));

create table if not exists gallery_items (
  id          bigint generated always as identity primary key,
  path        text not null unique,            -- object path inside the 'gallery' bucket
  caption     text,
  album       text not null default 'Province',-- Province | Lodge V | Installations | Events | Regalia …
  taken_on    date,
  min_level   int  not null default 1,
  sort        int  not null default 0,
  uploaded_by uuid references auth.users default auth.uid(),
  created_at  timestamptz not null default now()
);

create index if not exists gallery_album_idx on gallery_items(album, created_at desc);

alter table gallery_items enable row level security;

drop policy if exists "gallery read by rank"   on gallery_items;
drop policy if exists "gallery members add"    on gallery_items;
drop policy if exists "gallery owner or officer manages" on gallery_items;

create policy "gallery read by rank" on gallery_items
  for select to authenticated
  using (my_rank() >= min_level);

create policy "gallery members add" on gallery_items
  for insert to authenticated
  with check (my_rank() >= 1 and uploaded_by = auth.uid());

create policy "gallery owner or officer manages" on gallery_items
  for all to authenticated
  using (uploaded_by = auth.uid() or my_rank() >= 2)
  with check (uploaded_by = auth.uid() or my_rank() >= 2);

-- ============================================================
--  3. Realtime (optional) — lets the board update live
-- ============================================================
do $$
begin
  execute 'alter publication supabase_realtime add table board_posts';
exception when others then null;
end $$;
