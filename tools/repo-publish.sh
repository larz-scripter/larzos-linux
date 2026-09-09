#!/bin/sh
# repo-publish.sh - build/refresh the LarzOS apt repo from dist/*.deb
#
# Runs on the repo host. Uses apt-ftparchive + gpg (no reprepro needed).
# Layout produced under $REPO_ROOT:
#
#   dists/stable/Release[.gpg] , InRelease
#   dists/stable/main/binary-<arch>/Packages[.gz]
#   pool/main/*.deb
#   larzos-archive-keyring.gpg   (public key, for apt signed-by=)
#   KEY.asc
#
# Env:
#   REPO_ROOT   default /var/www/larzos/apt
#   DEB_DIR     default ./dist
#   GNUPGHOME   default /root/.larzos-gnupg   (signing keyring lives here)
#   SIGN_UID    default "LarzOS Archive Signing Key <larz@larzos.com>"
#   ORIGIN      default LarzOS
set -eu

REPO_ROOT="${REPO_ROOT:-/var/www/larzos/apt}"
DEB_DIR="${DEB_DIR:-./dist}"
export GNUPGHOME="${GNUPGHOME:-/root/.larzos-gnupg}"
SIGN_UID="${SIGN_UID:-LarzOS Archive Signing Key <larz@larzos.com>}"
ORIGIN="${ORIGIN:-LarzOS}"
SUITE="stable"
COMPONENT="main"

log() { echo "[repo-publish] $*"; }

# --- signing key -----------------------------------------------------------
mkdir -p "$GNUPGHOME"; chmod 700 "$GNUPGHOME"
if ! gpg --list-secret-keys "$SIGN_UID" >/dev/null 2>&1; then
  log "generating signing key: $SIGN_UID"
  cat > "$GNUPGHOME/keygen" <<EOF
%no-protection
Key-Type: eddsa
Key-Curve: ed25519
Key-Usage: sign
Subkey-Type: ecdh
Subkey-Curve: cv25519
Name-Real: LarzOS Archive Signing Key
Name-Email: larz@larzos.com
Expire-Date: 0
%commit
EOF
  gpg --batch --generate-key "$GNUPGHOME/keygen"
  rm -f "$GNUPGHOME/keygen"
fi

# --- pool --------------------------------------------------------------
# New builds land in $DEB_DIR; the pool is cumulative (arch-specific debs
# from other build hosts, e.g. arm64, stay put). Newer versions of the same
# file overwrite by name.
mkdir -p "$REPO_ROOT/pool/$COMPONENT"
if ls "$DEB_DIR"/*.deb >/dev/null 2>&1; then
  cp -f "$DEB_DIR"/*.deb "$REPO_ROOT/pool/$COMPONENT/"
fi

# --- Packages indexes, per architecture --------------------------------
ls "$REPO_ROOT/pool/$COMPONENT"/*.deb >/dev/null 2>&1 || {
  echo "no .deb files in $DEB_DIR or the pool" >&2; exit 1; }
ARCHES=$(for f in "$REPO_ROOT/pool/$COMPONENT"/*.deb; do
           dpkg-deb -f "$f" Architecture
         done | sort -u)
# apt needs binary-all to exist even when packages are arch-specific
echo "$ARCHES" | grep -qx all || ARCHES="$ARCHES
all"

cd "$REPO_ROOT"
for arch in $ARCHES; do
  d="dists/$SUITE/$COMPONENT/binary-$arch"
  mkdir -p "$d"
  apt-ftparchive --arch "$arch" packages "pool/$COMPONENT" > "$d/Packages"
  sed -i "s#^Filename: #Filename: #" "$d/Packages"
  gzip -9c "$d/Packages" > "$d/Packages.gz"
  cat > "$d/Release" <<EOF
Archive: $SUITE
Component: $COMPONENT
Origin: $ORIGIN
Label: $ORIGIN
Architecture: $arch
EOF
done

# --- top-level Release + signatures -----------------------------------
cd "dists/$SUITE"
apt-ftparchive \
  -o "APT::FTPArchive::Release::Origin=$ORIGIN" \
  -o "APT::FTPArchive::Release::Label=$ORIGIN" \
  -o "APT::FTPArchive::Release::Suite=$SUITE" \
  -o "APT::FTPArchive::Release::Codename=$SUITE" \
  -o "APT::FTPArchive::Release::Components=$COMPONENT" \
  -o "APT::FTPArchive::Release::Architectures=$(echo $ARCHES | tr '\n' ' ')" \
  release . > Release
gpg --batch --yes --default-key "$SIGN_UID" -abs -o Release.gpg Release
gpg --batch --yes --default-key "$SIGN_UID" --clearsign -o InRelease Release
cd "$REPO_ROOT"

# --- exported public key ----------------------------------------------
gpg --export "$SIGN_UID" > larzos-archive-keyring.gpg
gpg --armor --export "$SIGN_UID" > KEY.asc

chown -R www-data:www-data "$REPO_ROOT" 2>/dev/null || true
find "$REPO_ROOT" -type d -exec chmod 755 {} + ; find "$REPO_ROOT" -type f -exec chmod 644 {} +

log "published $(ls "$REPO_ROOT/pool/$COMPONENT" | wc -l) package(s) for: $(echo $ARCHES | tr '\n' ' ')"
log "apt line:  deb [signed-by=/usr/share/keyrings/larzos-archive-keyring.gpg] https://larzos.com/apt stable main"
