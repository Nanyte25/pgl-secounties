-- ============================================================
--  Documents, Dues tracker, and Homepage slider
--  Run AFTER supabase-setup.sql, supabase-events.sql, supabase-dashboard.sql
-- ============================================================
set search_path = public, extensions;

-- ---------- storage buckets ----------
insert into storage.buckets (id, name, public) values ('documents','documents', false) on conflict (id) do nothing;
insert into storage.buckets (id, name, public) values ('media','media', true)          on conflict (id) do nothing;

-- storage policies (officers write; documents read = signed-in, media = public)
drop policy if exists "docs officers write" on storage.objects;
drop policy if exists "docs read signed in" on storage.objects;
drop policy if exists "media officers write" on storage.objects;
drop policy if exists "media public read"   on storage.objects;
create policy "docs officers write" on storage.objects for all to authenticated
  using (bucket_id='documents' and public.my_rank()>=2) with check (bucket_id='documents' and public.my_rank()>=2);
create policy "docs read signed in" on storage.objects for select to authenticated
  using (bucket_id='documents' and public.my_rank()>=1);
create policy "media officers write" on storage.objects for all to authenticated
  using (bucket_id='media' and public.my_rank()>=2) with check (bucket_id='media' and public.my_rank()>=2);
create policy "media public read" on storage.objects for select using (bucket_id='media');

-- ---------- documents (metadata; file lives in the 'documents' bucket) ----------
create table if not exists documents (
  id bigint generated always as identity primary key,
  title text not null,
  path text not null,
  min_level int not null default 1,
  lodge_id int references lodges(id),
  uploaded_by uuid references auth.users,
  created_at timestamptz default now()
);
alter table documents enable row level security;
drop policy if exists "documents by rank" on documents;
drop policy if exists "officers manage documents" on documents;
create policy "documents by rank" on documents for select using (my_rank() >= min_level);
create policy "officers manage documents" on documents for all using (my_rank()>=2) with check (my_rank()>=2);

-- ---------- membership & dues ----------
create table if not exists dues_members (
  id bigint generated always as identity primary key,
  full_name text not null,
  lodge_id int references lodges(id),
  active boolean default true,
  created_at timestamptz default now()
);
create table if not exists dues (
  id bigint generated always as identity primary key,
  member_id bigint references dues_members(id) on delete cascade,
  year int not null,
  amount numeric(8,2) default 0,
  paid boolean default false,
  paid_on date,
  note text,
  unique (member_id, year)
);
alter table dues_members enable row level security;
alter table dues enable row level security;
drop policy if exists "dues_members officers" on dues_members;
drop policy if exists "dues officers" on dues;
create policy "dues_members officers" on dues_members for all using (my_rank()>=2) with check (my_rank()>=2);
create policy "dues officers" on dues for all using (my_rank()>=2) with check (my_rank()>=2);

-- ---------- homepage slider ----------
create table if not exists slides (
  id bigint generated always as identity primary key,
  image_url text not null,
  caption text,
  sort int default 0,
  active boolean default true,
  created_at timestamptz default now()
);
alter table slides enable row level security;
drop policy if exists "slides public read" on slides;
drop policy if exists "officers manage slides" on slides;
create policy "slides public read" on slides for select using (active = true);
create policy "officers manage slides" on slides for all using (my_rank()>=2) with check (my_rank()>=2);

-- a few seed members for the dues demo (safe to delete)
insert into dues_members (full_name, lodge_id) values
  ('Bro. Michael Power', 5), ('Bro. James Ryan', 32), ('Bro. Test Member', 5)
on conflict do nothing;
