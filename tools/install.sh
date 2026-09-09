#!/bin/sh
# LarzOS installer - add the apt repo and install a LarzOS component.
#
#   curl -fsSL https://larzos.com/larzos-linux/install.sh | sudo sh
#   curl -fsSL https://larzos.com/larzos-linux/install.sh | sudo sh -s -- larz-system
#
# Default target is larz-desktop (shell + low-latency audio + AI manager).
set -eu

TARGET="${1:-larz-desktop}"
KEYRING=/usr/share/keyrings/larzos-archive-keyring.gpg
LIST=/etc/apt/sources.list.d/larzos.list
BASE="${LARZOS_APT_BASE:-https://larzos.com/apt}"

if [ "$(id -u)" != 0 ]; then
  echo "run as root, e.g.:  curl -fsSL https://larzos.com/larzos-linux/install.sh | sudo sh" >&2
  exit 1
fi

. /etc/os-release 2>/dev/null || true
case " ${ID:-} ${ID_LIKE:-} " in
  *" debian "*|*" ubuntu "*) : ;;
  *) echo "LarzOS packages target Debian/Ubuntu; found ${PRETTY_NAME:-unknown}" >&2; exit 1 ;;
esac

command -v curl >/dev/null || { apt-get update && apt-get install -y curl; }
command -v gpg  >/dev/null || { apt-get update && apt-get install -y gnupg; }

echo "==> fetching LarzOS archive key"
tmpkey=$(mktemp)
curl -fsSL "$BASE/KEY.asc" -o "$tmpkey"
gpg --dearmor < "$tmpkey" > "$KEYRING"
chmod 644 "$KEYRING"
rm -f "$tmpkey"

echo "==> adding apt source -> $LIST"
echo "deb [signed-by=$KEYRING] $BASE stable main" > "$LIST"

echo "==> apt-get update"
apt-get update

echo "==> installing $TARGET"
DEBIAN_FRONTEND=noninteractive apt-get install -y "$TARGET"

cat <<'EOF'

LarzOS is installed.

Next:
  sudo -e /etc/larzos/system.lz     # describe your machine, in Larzscript
  larz-system plan                   # preview the changes
  sudo larz-system apply             # converge the machine

Docs and roadmap: https://larzos.com/larzos-linux/
EOF
