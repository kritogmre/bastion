#!/usr/bin/env bash
#
# Bastion — one-line installer (Linux)
#
#   curl -fsSL https://raw.githubusercontent.com/kritogmre/bastion/main/install.sh | bash
#
# Downloads the latest release (native backend + signed extension), verifies
# integrity (sha256), installs into ~/.local/share/bastion, then runs the
# configurator (CLI + backend service + browser extension).
# No dependencies. Authorized use only.
set -euo pipefail

OWNER="kritogmre"
REPO="bastion"
INSTALL_DIR="$HOME/.local/share/bastion"
API="https://api.github.com/repos/$OWNER/$REPO/releases/latest"

if [ -t 1 ]; then
  B="\033[1m"; R="\033[0m"; G="\033[92m"; Y="\033[93m"; C="\033[96m"; M="\033[95m"; E="\033[91m"
else B=""; R=""; G=""; Y=""; C=""; M=""; E=""; fi
ok()   { printf "  ${G}✓${R} %b\n" "$*"; }
info() { printf "  ${C}•${R} %b\n" "$*"; }
warn() { printf "  ${Y}!${R} %b\n" "$*"; }
err()  { printf "  ${E}✗ %b${R}\n" "$*" >&2; }
step() { printf "\n${B}${M}▎%b${R}\n" "$*"; }
die()  { err "$*"; exit 1; }

printf "${M}${B}\n   🛡  Bastion — installer${R}\n"

# ---------- pré-requis ----------
# No Python needed here: the backend ships as a native binary.
step "1/4 · Prerequisites"
command -v curl >/dev/null 2>&1 || die "curl is required (sudo apt install -y curl)."
command -v tar  >/dev/null 2>&1 || die "tar is required."
command -v sha256sum >/dev/null 2>&1 || die "sha256sum is required (coreutils)."
ok "curl + tar + sha256sum"
[ "${OWNER:0:2}" = "__" ] && die "Installer not published (OWNER/REPO not set)."

# ---------- résoudre la dernière release ----------
step "2/4 · Finding the latest version"
META="$(curl -fsSL "$API")" || die "Cannot reach the GitHub API ($API)."
# Parse without Python (grep/sed) → works on any Linux.
TAG="$(printf '%s' "$META" | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')"
TARBALL_URL="$(printf '%s' "$META" | grep -oE '"browser_download_url": *"[^"]*-linux\.tar\.gz"' | head -1 | sed -E 's/.*"(https[^"]+)".*/\1/')"
SHA_URL="$(printf '%s' "$META" | grep -oE '"browser_download_url": *"[^"]*-linux\.tar\.gz\.sha256"' | head -1 | sed -E 's/.*"(https[^"]+)".*/\1/')"
[ -n "$TARBALL_URL" ] || die "No Linux package in the latest release."
ok "version ${B}$TAG${R}"

# ---------- télécharger + vérifier ----------
step "3/4 · Download & verify"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
curl -fL# "$TARBALL_URL" -o "$TMP/bastion.tar.gz" || die "Download failed."
if [ -n "$SHA_URL" ] && curl -fsSL "$SHA_URL" -o "$TMP/bastion.sha256"; then
  EXPECT="$(cut -d' ' -f1 "$TMP/bastion.sha256")"
  GOT="$(sha256sum "$TMP/bastion.tar.gz" | cut -d' ' -f1)"
  [ "$EXPECT" = "$GOT" ] || die "Invalid checksum! (corrupted/tampered download)"
  ok "sha256 verified"
else
  warn "no sha256 published — integrity not verified"
fi

# ---------- installer ----------
step "4/4 · Installation"
# stop a running backend (update) — otherwise the binary is busy (ETXTBSY)
command -v systemctl >/dev/null 2>&1 && systemctl --user stop bastion.service 2>/dev/null || true
mkdir -p "$INSTALL_DIR"
# clean the old version (user config in ~/.config/bastion is kept)
rm -rf "$INSTALL_DIR.old"
[ -e "$INSTALL_DIR/app" ] || [ -e "$INSTALL_DIR/backend" ] && mv "$INSTALL_DIR" "$INSTALL_DIR.old" && mkdir -p "$INSTALL_DIR"
tar -xzf "$TMP/bastion.tar.gz" -C "$TMP"
# the tarball contains a bastion/ folder
cp -r "$TMP/bastion/." "$INSTALL_DIR/"
rm -rf "$INSTALL_DIR.old"
ok "installed in ${B}$INSTALL_DIR${R}"

if [ -x "$INSTALL_DIR/setup.sh" ]; then
  # --update (triggered by the in-app updater): only refresh files + restart the
  # backend. Skip the browser policy (sudo) and the local AI install (Ollama).
  case " $* " in
    *" --update "*) SETUP_ARGS="--yes --no-browser --no-ai"; info "update: refreshing & restarting…\n" ;;
    *)              SETUP_ARGS="$*";                          info "starting the configurator…\n" ;;
  esac
  exec "$INSTALL_DIR/setup.sh" $SETUP_ARGS
else
  warn "setup.sh not found in the package — manual setup required."
  info "Backend: $INSTALL_DIR/app/bastion.bin serve"
fi
