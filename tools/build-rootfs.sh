#!/bin/sh
# build-rootfs.sh - a minimal LarzOS root filesystem: Ubuntu 24.04 base +
# the LarzOS apt repo + the config engine, preconfigured. This is the shared
# base for the WSL image (below), and later the Docker image and live ISO.
#
# Run on an Ubuntu host as root.
#
#   OUT=dist/larzos-rootfs.tar.gz sh tools/build-rootfs.sh
#
# Then, on Windows:
#   wsl --import LarzOS C:\LarzOS larzos-rootfs.tar.gz
#   wsl -d LarzOS
set -eu

SUITE="${SUITE:-noble}"
ARCH="${ARCH:-amd64}"
OUT="${OUT:-dist/larzos-rootfs-$ARCH.tar.gz}"
ROOT="${ROOT:-/tmp/larzos-rootfs}"
APT_BASE="${LARZOS_APT_BASE:-https://larzos.com/apt}"
MIRROR="${MIRROR:-http://archive.ubuntu.com/ubuntu}"

command -v debootstrap >/dev/null || { apt-get update && apt-get install -y debootstrap; }

cleanup() {
  for m in dev/pts dev proc sys; do umount -l "$ROOT/$m" 2>/dev/null || true; done
}
trap cleanup EXIT

rm -rf "$ROOT"
debootstrap --arch="$ARCH" --variant=minbase \
  --include=ca-certificates,curl,gnupg,systemd,systemd-sysv,dbus,sudo,less,vim-tiny,iproute2 \
  "$SUITE" "$ROOT" "$MIRROR"

cat > "$ROOT/etc/apt/sources.list" <<EOF
deb $MIRROR $SUITE main universe
deb $MIRROR $SUITE-updates main universe
deb http://security.ubuntu.com/ubuntu $SUITE-security main universe
EOF

curl -fsSL "$APT_BASE/KEY.asc" | gpg --dearmor > "$ROOT/usr/share/keyrings/larzos-archive-keyring.gpg"
echo "deb [signed-by=/usr/share/keyrings/larzos-archive-keyring.gpg] $APT_BASE stable main" \
  > "$ROOT/etc/apt/sources.list.d/larzos.list"

# WSL settings (harmless elsewhere)
cat > "$ROOT/etc/wsl.conf" <<'EOF'
[boot]
systemd=true
[user]
default=larz
[network]
generateHosts=true
generateResolvConf=true
EOF

# the machine spec the image ships with
mkdir -p "$ROOT/etc/larzos"
cat > "$ROOT/etc/larzos/system.lz" <<'EOF'
# The machine this image becomes. Edit, then: sudo larz-system apply
import "larzos" as larzos

larzos.system({
  "hostname": "larzos",
  "users":    [ { "name": "larz", "groups": ["sudo"], "shell": "/usr/bin/larzsh" } ],
  "packages": ["larz-system", "larz-ai", "larzsh", "git", "curl"],
  "services": { "larz-ai": "enabled" },
  "audio":    { "profile": "off" },
  "ai":       { "local_models": [], "gateway": "https://gateway.larzpay.com" },
})
EOF

for m in proc sys dev dev/pts; do mount --bind "/$m" "$ROOT/$m"; done

chroot "$ROOT" /bin/sh -eux <<'CHROOT'
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends larz-system larz-ai larzsh
useradd -m -s /usr/bin/larzsh -G sudo larz
echo 'larz ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/larz
chmod 440 /etc/sudoers.d/larz
printf 'Welcome to LarzOS.\nYour machine is /etc/larzos/system.lz  -  edit it, then: sudo larz-system apply\n' > /etc/motd
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/*
CHROOT

cleanup
trap - EXIT

mkdir -p "$(dirname "$OUT")"
tar --numeric-owner -C "$ROOT" -czf "$OUT" .
echo "built $OUT  ($(du -h "$OUT" | cut -f1))"
