# Deploying the PGL South Eastern Counties site

The easiest path is the interactive installer:
```bash
cd scripts && chmod +x setup.sh && ./setup.sh
```
This document is the manual equivalent, and the reference for the Supabase wiring.

## Stack (chosen for low cost + low maintenance)
| Layer            | Choice                | Cost                   |
|------------------|-----------------------|------------------------|
| Hosting (public) | GitHub Pages          | Free                   |
| Auth + database  | Supabase              | Free tier (ample here) |
| File storage     | Supabase Storage      | Free tier (1 GB)       |
| Calendar         | Google Calendar embed | Free                   |

Everything is a **managed service** — nothing to patch or pay for at this scale.
Supabase only costs (~€25/mo Pro) if you exceed 500 MB DB / 50k monthly users.

## 1. GitHub Pages
1. Create a repo, add these files at the root, push to `main`.
2. **Settings → Pages → Source: `main` / `/root`.**
3. Live at `https://<user>.github.io/<repo>/`.
4. Custom domain: put the domain in a `CNAME` file, point DNS at GitHub Pages.

## 2. Supabase
1. Create a free project at supabase.com.
2. **SQL Editor → paste `supabase-schema.sql` → Run** (lodges, member profiles,
   rank-based Row-Level Security, storage-ready).
3. **Authentication → Providers → enable Email.**
4. **Storage →** create buckets `gallery` (public) and `documents` (private).
5. Copy `js/config.example.js` to `js/config.js` and fill in **Project URL** and
   **anon public key** (Settings → API). The setup script does this for you.

Then add this before `</body>` in `index.html` to replace the demo login with
real, rank-aware auth (it reads the keys from `js/config.js`):

```html
<script src="js/config.js"></script>
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
<script>
  const sb = supabase.createClient(PGL_CONFIG.SUPABASE_URL, PGL_CONFIG.SUPABASE_ANON_KEY);

  async function doLogin(e){
    e.preventDefault();
    const email = document.getElementById('li-email').value;
    const password = document.getElementById('li-pass').value;
    const { error } = await sb.auth.signInWithPassword({ email, password });
    if (error) { alert(error.message); return false; }
    await loadMember(); closeModal(); return false;
  }
  async function loadMember(){
    const { data:{ user } } = await sb.auth.getUser();
    if (!user) return;
    const { data:p } = await sb.from('profiles').select('*').eq('id', user.id).single();
    if (!p || !p.approved) { alert('Your access is awaiting approval.'); return; }
    renderMembers({ name:p.full_name, rank:p.masonic_rank, tier:p.rank_level });
    // notices are gated by RLS — only rows this rank may see come back:
    const { data:notices } = await sb.from('notices').select('*').order('event_date');
  }
  async function signOut(){ await sb.auth.signOut(); location.reload(); }
  sb.auth.onAuthStateChange((_e,s)=>{ if(s) loadMember(); });
</script>
```

**Rank model:** `rank_level` 1 = member, 2 = officer, 3 = admin. Each content row
carries a `min_level`; RLS compares them. Promote someone by editing one cell in
the Supabase table editor. New registrations arrive as `approved = false`; the
Webmaster flips them on. No deploy needed for day-to-day changes.

## 3. Google Calendar
Keep one shared calendar; embed it in the Calendar section:
```html
<iframe src="https://calendar.google.com/calendar/embed?src=YOUR_CAL_ID&mode=MONTH&ctz=Europe/Dublin"
        style="border:0;width:100%;height:520px" loading="lazy"></iframe>
```
The "Upcoming meetings" list is generated automatically from the meeting rules.

## Handover in one line
Public content = edit `index.html` and push (`./setup.sh` → step 7).
Members, events, summonses, photos = edit rows in the Supabase table editor.
