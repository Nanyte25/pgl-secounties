#!/usr/bin/env bash
# ============================================================
#  PGL South Eastern Counties — interactive setup
#  Targets: macOS (Homebrew) and Fedora (dnf). Uses gum for UI.
#  Run:  cd scripts && ./setup.sh
# ============================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=lib.sh
source "$HERE/lib.sh"
detect_os
cd "$ROOT"

[ "$OS" = unknown ] && die "Unsupported OS. This script targets macOS and Fedora."
ensure_gum

banner "Provincial Grand Lodge" "South Eastern Counties" "— site setup —"
md "Detected OS: **$OS**   ·   Project root: \`$ROOT\`"

# ---------- 1. prerequisites ----------
step_prereqs(){
  h "1 · Prerequisites"
  ensure_gum
  have git || { info "Installing git…"; pkg_install git; }
  have gh  || { info "Installing GitHub CLI…"; pkg_install gh; }
  if [ "$OS" != mac ] && ! have wl-copy && ! have xclip && ! have xsel; then
    if gum confirm "Install a clipboard helper (wl-clipboard)?"; then pkg_install wl-clipboard || warn "Skipped."; fi
  fi
  ok "git $(git --version | awk '{print $3}') · gh $(gh --version | head -1 | awk '{print $3}') · gum ready."
}

# ---------- 2. git ----------
step_git(){
  h "2 · Git repository"
  have git || pkg_install git
  if [ -d .git ]; then ok "Already a git repository."
  else git init -b main >/dev/null; ok "Initialised repo on branch 'main'."; fi
  git add -A
  if git diff --cached --quiet; then info "Nothing new to commit."
  else
    local msg; msg=$(gum input --header "Commit message" --value "Initial commit: PGL South Eastern Counties site" --width 60)
    git commit -m "$msg" >/dev/null && ok "Committed."
  fi
}

# ---------- 3. github ----------
step_github(){
  h "3 · GitHub repository"
  have gh || pkg_install gh
  gh auth status >/dev/null 2>&1 || { info "Log in to GitHub in your browser…"; gh auth login; }
  git rev-parse HEAD >/dev/null 2>&1 || { warn "No commit yet — doing that first."; step_git; }
  if git remote get-url origin >/dev/null 2>&1; then
    ok "Remote 'origin' → $(git remote get-url origin)"
    if gum confirm "Push 'main' to origin now?"; then gum spin --title "Pushing…" -- git push -u origin main && ok "Pushed."; fi
    return
  fi
  local name vis; name=$(gum input --header "Repository name" --value "pgl-secounties" --width 40)
  vis=$(gum choose --header "Visibility" "public" "private")
  [ "$vis" = private ] && md "> Note: GitHub Pages on a **private** repo requires a paid GitHub plan."
  gum spin --title "Creating $name on GitHub…" -- gh repo create "$name" --"$vis" --source=. --remote=origin --push
  ok "Repository created and pushed."
}

# ---------- 4. pages ----------
step_pages(){
  h "4 · GitHub Pages"
  have gh || die "Run step 1 first (installs gh)."
  local slug; slug=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null) || die "No GitHub repo yet — run step 3."
  info "Enabling Pages for $slug (branch main, root)…"
  if gh api -X POST "repos/$slug/pages" -H "Accept: application/vnd.github+json" \
        -f "source[branch]=main" -f "source[path]=/" >/dev/null 2>&1; then
    ok "Pages enabled."
  else
    warn "Pages is likely already enabled (or GitHub needs a minute)."
  fi
  local owner=${slug%%/*} repo=${slug##*/}
  md "Your site will be live at:  **https://$owner.github.io/$repo/**  (first build ~1 min)"
}

# ---------- 5. supabase ----------
step_supabase(){
  h "5 · Supabase backend (optional — enables member login)"
  md "Supabase provides **auth + Postgres + storage** on a free tier. We will: capture your keys into \`js/config.js\`, copy the schema to your clipboard, and open the SQL editor to paste it."
  gum confirm "Set up Supabase now?" || { info "Skipped."; return; }

  if ! gum confirm "Do you already have a Supabase project?"; then
    info "Opening supabase.com to create a free project…"; openurl "https://supabase.com/dashboard/projects"
    gum input --header "Create the project, then press Enter to continue" --placeholder "…" >/dev/null || true
  fi

  local url key; url=$(gum input --header "Supabase Project URL" --placeholder "https://xxxx.supabase.co" --width 50)
  key=$(gum input --header "Supabase anon public key" --placeholder "eyJhbGciOi…" --width 50)
  mkdir -p js
  cat > js/config.js <<CFG
// Public Supabase settings — safe to commit. Security is enforced by RLS.
window.PGL_CONFIG = {
  SUPABASE_URL: "${url}",
  SUPABASE_ANON_KEY: "${key}"
};
CFG
  ok "Wrote js/config.js"

  if clip < supabase-schema.sql; then ok "Schema copied to clipboard — ready to paste."
  else warn "Clipboard unavailable; open supabase-schema.sql and copy it manually."; fi

  if [ -n "$url" ]; then local proj=${url#https://}; proj=${proj%%.*}; openurl "https://supabase.com/dashboard/project/$proj/sql/new"; fi
  md "In the SQL editor: **paste** (⌘/Ctrl-V) and press **Run**. Then enable **Email** under Authentication → Providers."

  if gum confirm "Advanced: apply the schema right now over psql instead?"; then
    have psql || { info "Installing psql…"; if [ "$OS" = mac ]; then brew install libpq && brew link --force libpq; else pkg_install postgresql; fi; }
    local conn; conn=$(gum input --password --header "Postgres connection string (Settings → Database → Connection string → URI)" --width 60)
    if [ -n "$conn" ] && psql "$conn" -f supabase-schema.sql; then ok "Schema applied via psql."; else warn "psql apply skipped or failed — use the dashboard paste instead."; fi
  fi
}

# ---------- 6. custom domain ----------
step_cname(){
  h "6 · Custom domain (optional)"
  gum confirm "Point a custom domain at this site?" || { info "Skipped."; return; }
  local dom; dom=$(gum input --header "Domain" --value "pgl-secounties.com" --width 40)
  printf '%s\n' "$dom" > CNAME
  ok "Wrote CNAME → $dom"
  md "At your DNS provider, add either an **A record** for the apex to \`185.199.108.153\` … \`185.199.111.153\`, or a **CNAME** to \`<owner>.github.io\`. GitHub issues HTTPS automatically once DNS resolves."
}

# ---------- 7. deploy ----------
step_deploy(){
  h "7 · Deploy (commit & push)"
  git add -A
  if git diff --cached --quiet; then info "Working tree clean — nothing to deploy."; return; fi
  local msg; msg=$(gum input --header "Commit message" --value "Update site" --width 50)
  git commit -m "$msg" >/dev/null
  git remote get-url origin >/dev/null 2>&1 || { warn "No 'origin' remote — run step 3 first."; return; }
  gum spin --title "Pushing to GitHub…" -- git push origin main
  ok "Deployed. GitHub Pages rebuilds in ~30–60 seconds."
}

run_all(){ step_prereqs; step_git; step_github; step_pages; step_supabase; step_cname; step_deploy; banner "Setup complete"; }

# ---------- menu loop ----------
while true; do
  choice=$(gum choose --header "Choose a step (↑/↓, Enter — Esc to quit):" \
    "1 · Install prerequisites (git, gh, gum)" \
    "2 · Initialise git repo & first commit" \
    "3 · Create GitHub repo & push" \
    "4 · Enable GitHub Pages" \
    "5 · Set up Supabase (schema + keys)" \
    "6 · Custom domain (CNAME)" \
    "7 · Deploy (commit & push changes)" \
    "9 · Run everything, in order" \
    "Quit") || exit 0
  case "$choice" in
    1*) step_prereqs ;;
    2*) step_git ;;
    3*) step_github ;;
    4*) step_pages ;;
    5*) step_supabase ;;
    6*) step_cname ;;
    7*) step_deploy ;;
    9*) run_all ;;
    Quit) exit 0 ;;
  esac
  echo
done
