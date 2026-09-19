-- ============================================================
--  Members' chat  (run AFTER supabase-setup.sql)
--  Rank-gated realtime chat. Secure = HTTPS transport + RLS
--  (members only). Not end-to-end encrypted.
-- ============================================================
set search_path = public, extensions;

create table if not exists messages (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users,
  author_name text,
  author_avatar text,
  body text not null,
  min_level int not null default 1,          -- 1 = members and above
  created_at timestamptz default now()
);
alter table messages enable row level security;
drop policy if exists "messages read"        on messages;
drop policy if exists "messages insert own"  on messages;
drop policy if exists "admins manage messages" on messages;
create policy "messages read"        on messages for select using (my_rank() >= min_level);
create policy "messages insert own"  on messages for insert with check (user_id = auth.uid() and my_rank() >= 1);
create policy "admins manage messages" on messages for all using (my_rank() >= 3) with check (my_rank() >= 3);

-- enable Realtime for this table (safe if already added)
do $$
begin
  if not exists (select 1 from pg_publication_tables
                 where pubname='supabase_realtime' and schemaname='public' and tablename='messages') then
    alter publication supabase_realtime add table messages;
  end if;
end $$;
