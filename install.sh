#!/usr/bin/env bash
#
# Bastion — installeur en une ligne (Linux)
#
#   curl -fsSL https://raw.githubusercontent.com/kritogmre/bastion/main/install.sh | bash
#
# Télécharge la dernière release (backend obfusqué + extension signée), vérifie
# l'intégrité (sha256), installe dans ~/.local/share/bastion, puis lance le
# configurateur (CLI + service backend + extension navigateur).
# Aucune dépendance pip. Usage strictement autorisé.
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

printf "${M}${B}\n   🛡  Bastion — installeur${R}\n"

# ---------- pré-requis ----------
# Aucune dépendance Python ici : le backend embarque son propre Python 3.13.
step "1/4 · Pré-requis"
command -v curl >/dev/null 2>&1 || die "curl est requis (sudo apt install -y curl)."
command -v tar  >/dev/null 2>&1 || die "tar est requis."
command -v sha256sum >/dev/null 2>&1 || die "sha256sum est requis (coreutils)."
ok "curl + tar + sha256sum"
[ "${OWNER:0:2}" = "__" ] && die "Installeur non publié (OWNER/REPO non renseignés)."

# ---------- résoudre la dernière release ----------
step "2/4 · Recherche de la dernière version"
META="$(curl -fsSL "$API")" || die "Impossible de joindre l'API GitHub ($API)."
# Parsing sans Python (grep/sed) → marche sur n'importe quel Linux.
TAG="$(printf '%s' "$META" | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')"
TARBALL_URL="$(printf '%s' "$META" | grep -oE '"browser_download_url": *"[^"]*-linux\.tar\.gz"' | head -1 | sed -E 's/.*"(https[^"]+)".*/\1/')"
SHA_URL="$(printf '%s' "$META" | grep -oE '"browser_download_url": *"[^"]*-linux\.tar\.gz\.sha256"' | head -1 | sed -E 's/.*"(https[^"]+)".*/\1/')"
[ -n "$TARBALL_URL" ] || die "Aucun paquet Linux dans la dernière release."
ok "version ${B}$TAG${R}"

# ---------- télécharger + vérifier ----------
step "3/4 · Téléchargement & vérification"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
curl -fL# "$TARBALL_URL" -o "$TMP/bastion.tar.gz" || die "Échec du téléchargement."
if [ -n "$SHA_URL" ] && curl -fsSL "$SHA_URL" -o "$TMP/bastion.sha256"; then
  EXPECT="$(cut -d' ' -f1 "$TMP/bastion.sha256")"
  GOT="$(sha256sum "$TMP/bastion.tar.gz" | cut -d' ' -f1)"
  [ "$EXPECT" = "$GOT" ] || die "Somme de contrôle invalide ! (téléchargement corrompu/altéré)"
  ok "sha256 vérifié"
else
  warn "pas de sha256 publié — intégrité non vérifiée"
fi

# ---------- installer ----------
step "4/4 · Installation"
mkdir -p "$INSTALL_DIR"
# nettoyage de l'ancienne version (on garde la config utilisateur ~/.config/bastion)
rm -rf "$INSTALL_DIR.old"
[ -d "$INSTALL_DIR/backend" ] && mv "$INSTALL_DIR" "$INSTALL_DIR.old" && mkdir -p "$INSTALL_DIR"
tar -xzf "$TMP/bastion.tar.gz" -C "$TMP"
# le tarball contient un dossier bastion/
cp -r "$TMP/bastion/." "$INSTALL_DIR/"
rm -rf "$INSTALL_DIR.old"
ok "installé dans ${B}$INSTALL_DIR${R}"

if [ -x "$INSTALL_DIR/setup.sh" ]; then
  info "lancement du configurateur…\n"
  # transmet les éventuels arguments (ex: --yes) à setup.sh
  exec "$INSTALL_DIR/setup.sh" "$@"
else
  warn "setup.sh introuvable dans le paquet — configuration manuelle requise."
  info "Backend : python3 $INSTALL_DIR/backend/bastion.py serve"
fi
