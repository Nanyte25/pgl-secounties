# Provincial Grand Lodge of the South Eastern Counties — website

A modern, static site for **GitHub Pages** with an optional **Supabase** backend
for rank-based member login. No build step, no server, effectively no cost.

## What's here
```
index.html            The public site (self-contained: HTML/CSS/JS)
app.html              The members' area (login, dashboard, board, gallery)
supabase-schema.sql   Postgres schema + rank-based Row-Level Security
supabase-board.sql    Bulletin board + members-only gallery
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

## The Orders and their symbols
The five Irish Orders each carry their grand symbol as inline SVG, defined once
in a `<defs>` block near the top of `index.html` and mirrored into `app.html`:

| id        | Order                        |
|-----------|------------------------------|
| `#sc`     | The Craft — square & compasses with G |
| `#tau`    | Mark & Royal Arch — the triple tau    |
| `#swords` | Knight Masonry — crossed swords       |
| `#eagle`  | Ancient & Accepted Rite — double-headed eagle |
| `#cross`  | Knights Templar & Malta — cross patée |

Use one anywhere with `<svg viewBox="0 0 100 100"><use href="#tau"/></svg>`;
it inherits `color`, so it takes the gold from its surroundings. They appear in
the Orders section, the homepage slider, the gallery gate and the footer. Edit a
symbol in one place and it changes everywhere. If official badge artwork is ever
supplied, drop it in as `img/order-*.png` — the Orders markup already prefers
those files and falls back to the SVG when they are absent.

## The gallery (members only)
The photograph album lives behind the login, in `app.html` → **Gallery**. Images
go into a **private** Supabase bucket (`gallery`); the browser asks for a
one-hour signed URL per image after sign-in, so nothing is readable from the
open web. Any approved member may upload; officers may remove anything. The
public page shows only a locked gate linking to the login.

## The bulletin board
`app.html` → **Bulletin board**. Members start threads and reply to them;
officers may pin a thread to the top or remove any post; every Brother may
remove his own. Threads carry a category (general, notice, question, visiting,
regalia & sales) and a visibility level — officers can post officer-only
threads. Run `supabase-board.sql` once to create the tables, the policies, the
private bucket and the `board_threads` view.

## Photos & portraits
Public-domain portraits of the notable brethren are on Wikimedia Commons; the
medallions in `index.html` already point at Commons file paths and fall back to
a monogram when a portrait is missing.
