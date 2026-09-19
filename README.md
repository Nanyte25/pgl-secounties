# Provincial Grand Lodge of the South Eastern Counties — website

A modern, static site for **GitHub Pages** with an optional **Supabase** backend
for rank-based member login. No build step, no server, effectively no cost.

## What's here
```
index.html            The whole site (self-contained: HTML/CSS/JS)
supabase-schema.sql   Postgres schema + rank-based Row-Level Security
js/config.example.js  Template for your Supabase keys → copy to js/config.js
img/                  Drop lodge photos / brethren portraits here
DEPLOY.md             Manual walkthrough (if you'd rather not use the script)
scripts/setup.sh      Interactive installer (macOS + Fedora), powered by gum
scripts/lib.sh        Helper functions
```

## Quick start (one command)
```bash
cd scripts
chmod +x setup.sh
./setup.sh
```
The script (using **gum** for a nice interactive UI) will, step by step:

1. Install prerequisites — `git`, `gh` (GitHub CLI), `gum`
2. Initialise the git repo and make the first commit
3. Create the GitHub repository and push
4. Enable GitHub Pages and print your live URL
5. Set up Supabase — save your keys to `js/config.js`, copy the schema to your
   clipboard, and open the SQL editor to paste it (or apply it over `psql`)
6. Optionally set a custom domain (writes `CNAME`)
7. Deploy — commit and push any later changes

Pick a single step from the menu, or **“9 · Run everything.”**

It works on **macOS** (via Homebrew) and **Fedora** (via dnf / the Charm repo).
The very first run installs `gum` itself before the menu appears.

## Activating real member login
The site ships with a **demo** login (`bro@demo` / `officer@demo` / `admin@demo`,
any password) so you can see the rank-gated area immediately. To make it real,
run step 5, then paste the Supabase wiring snippet from **DEPLOY.md** — it reads
your keys from `js/config.js`. The anon key is public and safe to commit; access
control lives in the database (RLS), not the browser.

## Photos & portraits
Drop images into `img/` and swap the placeholder tiles / monogram medallions in
`index.html` for `<img src="img/…">`. Public-domain portraits of the notable
brethren are on Wikimedia Commons.
