-- ============================================================
--  Stage 1: profiles + avatars + additional lodges + change requests
--  Run AFTER supabase-setup.sql (and the other feature files).
--  No security model change here — that's Stage 2 (RBAC).
-- ============================================================
set search_path = public, extensions;

-- avatar url on the member profile
alter table profiles add column if not exists avatar_url text;

-- a brother's additional lodges (one row per lodge; is_primary marks the main one)
create table if not exists profile_lodges (
  id bigint generated always as identity primary key,
  profile_id uuid references profiles(id) on delete cascade,
  lodge_id int references lodges(id),
  is_primary boolean default false,
  unique (profile_id, lodge_id)
);
alter table profile_lodges enable row level security;
drop policy if exists "own lodges read"   on profile_lodges;
drop policy if exists "own lodges write"  on profile_lodges;
drop policy if exists "admin lodges read" on profile_lodges;
-- a brother manages his own lodge list; approved members can read others (directory); admins read all
create policy "own lodges write"  on profile_lodges for all
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy "read lodges"        on profile_lodges for select
  using (profile_id = auth.uid() or my_rank() >= 1);

-- change requests (rank / office / other) -> admin queue
create table if not exists change_requests (
  id bigint generated always as identity primary key,
  profile_id uuid references profiles(id) on delete cascade,
  kind text not null,            -- 'rank' | 'office' | 'lodge' | 'note'
  requested text not null,       -- what they're asking for (free text / value)
  reason text,
  status text not null default 'pending',   -- pending | approved | declined
  created_at timestamptz default now(),
  decided_at timestamptz,
  decided_by uuid references auth.users
);
alter table change_requests enable row level security;
drop policy if exists "own requests"     on change_requests;
drop policy if exists "own insert"       on change_requests;
drop policy if exists "admins requests"  on change_requests;
-- a brother sees & creates his own; admins (rank 3) see & manage all
create policy "own requests"    on change_requests for select using (profile_id = auth.uid() or my_rank() >= 3);
create policy "own insert"      on change_requests for insert with check (profile_id = auth.uid());
create policy "admins requests" on change_requests for all    using (my_rank() >= 3) with check (my_rank() >= 3);

-- avatars storage bucket (public images)
insert into storage.buckets (id, name, public) values ('avatars','avatars', true) on conflict (id) do nothing;
drop policy if exists "avatars public read" on storage.objects;
drop policy if exists "avatars self write"  on storage.objects;
create policy "avatars public read" on storage.objects for select using (bucket_id='avatars');
-- a brother can write only into his own folder: avatars/<uid>/...
create policy "avatars self write" on storage.objects for all to authenticated
  using (bucket_id='avatars' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id='avatars' and (storage.foldername(name))[1] = auth.uid()::text);
