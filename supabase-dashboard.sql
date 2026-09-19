-- ============================================================
--  Dashboard extras (run AFTER supabase-setup.sql and supabase-events.sql)
--  Lets approved members see each other in the directory.
--  (Approvals, notices and event management already work under the
--   existing admin/officer policies.)
-- ============================================================
drop policy if exists "read approved directory" on profiles;
create policy "read approved directory"
  on profiles for select
  using (my_rank() >= 1 and approved = true);
