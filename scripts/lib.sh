#!/usr/bin/env bash
# Shared helpers for the PGL setup script. Sourced by setup.sh.

# ---- plain output (used before gum is available) ----
_g=$'\033[38;5;178m'; _r=$'\033[31m'; _grn=$'\033[32m'; _z=$'\033[0m'
info(){ printf '%s»%s %s\n' "$_g" "$_z" "$*"; }
ok(){   printf '%s✓%s %s\n' "$_grn" "$_z" "$*"; }
warn(){ printf '%s!%s %s\n' "$_g" "$_z" "$*"; }
err(){  printf '%s✗%s %s\n' "$_r" "$_z" "$*" >&2; }
die(){  err "$*"; exit 1; }
have(){ command -v "$1" >/dev/null 2>&1; }

detect_os(){
  case "$(uname -s)" in
    Darwin) OS=mac ;;
    Linux)  if have dnf; then OS=fedora
            elif have apt-get; then OS=debian
            else OS=linux; fi ;;
    *)      OS=unknown ;;
  esac
  export OS
}

pkg_install(){ # pkg_install <pkg...>
  case "$OS" in
    mac)    brew install "$@" ;;
    fedora) sudo dnf install -y "$@" ;;
    debian) sudo apt-get update -qq && sudo apt-get install -y "$@" ;;
    *)      die "Unsupported OS — please install manually: $*" ;;
  esac
}

ensure_brew(){
  [ "$OS" = mac ] || return 0
  have brew && return 0
  warn "Homebrew is required on macOS but was not found."
  printf 'Install Homebrew now? [y/N] '; read -r a
  case "$a" in
    y|Y) /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" ;;
    *)   die "Install Homebrew from https://brew.sh then re-run." ;;
  esac
  have brew || die "Homebrew is installed but not on PATH — open a new terminal and re-run."
}

# ---- bootstrap gum (the interactive UI) using plain prompts ----
ensure_gum(){
  have gum && return 0
  info "Installing gum (interactive UI)…"
  case "$OS" in
    mac) ensure_brew; brew install gum ;;
    fedora)
      if ! sudo dnf install -y gum 2>/dev/null; then
        info "Adding the Charm package repository…"
        sudo tee /etc/yum.repos.d/charm.repo >/dev/null <<'REPO'
[charm]
name=Charm
baseurl=https://repo.charm.sh/yum/
enabled=1
gpgcheck=1
gpgkey=https://repo.charm.sh/yum/gpg.key
REPO
        sudo rpm --import https://repo.charm.sh/yum/gpg.key || true
        sudo dnf install -y gum
      fi ;;
    debian)
      sudo mkdir -p /etc/apt/keyrings
      curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
      echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list >/dev/null
      sudo apt-get update -qq && sudo apt-get install -y gum ;;
    *) die "Install gum manually: https://github.com/charmbracelet/gum" ;;
  esac
  have gum || die "gum installation failed."
}

# ---- gum wrappers (colours: 178 gold) ----
GOLD=178
banner(){ gum style --border double --border-foreground $GOLD --foreground $GOLD --align center --width 54 --padding "1 3" -- "$@"; }
h(){  gum style --foreground $GOLD --bold -- "$*"; }
md(){ printf '%s\n' "$*" | gum format; }

# ---- clipboard + open ----
clip(){ # reads stdin
  case "$OS" in
    mac) pbcopy ;;
    *)   if   have wl-copy; then wl-copy
         elif have xclip;   then xclip -selection clipboard
         elif have xsel;    then xsel --clipboard --input
         else cat >/dev/null; return 1; fi ;;
  esac
}
openurl(){ case "$OS" in mac) open "$1" >/dev/null 2>&1 || true ;; *) have xdg-open && xdg-open "$1" >/dev/null 2>&1 || true ;; esac; }
