#!/bin/sh
# build-rootfs.sh - a minimal LarzOS root filesystem: Debian stable base +
# the LarzOS apt repo + the config engine + the LarzOS identity, all
# preconfigured. Shared base for the WSL image, the Docker image and the
# live ISO.
#
# Debian is the executor; nothing the user sees says "Debian" - larz-branding
# rewrites os-release / issue / motd / grub / dpkg-vendor, and
# tools/check-branding.sh fails the build if anything leaks through.
#
# Run on a Debian/Ubuntu host as root.
#
#   OUT=dist/larzos-rootfs-amd64.tar.gz sh tools/build-rootfs.sh
#
# Then, on Windows:
#   wsl --import LarzOS C:\LarzOS larzos-rootfs-amd64.tar.gz
#   wsl -d LarzOS
set -eu

SUITE="${SUITE:-trixie}"
ARCH="${ARCH:-amd64}"
OUT="${OUT:-dist/larzos-rootfs-$ARCH.tar.gz}"
ROOT="${ROOT:-/tmp/larzos-rootfs}"
APT_BASE="${LARZOS_APT_BASE:-https://larzos.com/apt}"
MIRROR="${MIRROR:-http://deb.debian.org/debian}"
SECMIRROR="${SECMIRROR:-http://deb.debian.org/debian-security}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"

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
deb $MIRROR $SUITE main contrib non-free-firmware
deb $MIRROR $SUITE-updates main contrib non-free-firmware
deb $SECMIRROR $SUITE-security main contrib non-free-firmware
EOF

# name the machine LarzOS (debootstrap leaves whatever the host had)
echo larzos > "$ROOT/etc/hostname"
printf '127.0.0.1\tlocalhost\n127.0.1.1\tlarzos\n' > "$ROOT/etc/hosts"

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

for m in proc sys dev dev/pts; do mount --bind "/$m" "$ROOT/$m"; done

chroot "$ROOT" /bin/sh -eux <<'CHROOT'
export DEBIAN_FRONTEND=noninteractive
apt-get update
# larz-branding's postinst runs `larz-rebrand apply`, so the image presents as
# LarzOS the moment the package lands.
apt-get install -y --no-install-recommends larz-branding larz larz-system larz-ai larzsh
useradd -m -s /usr/bin/larzsh -G sudo larz
echo 'larz ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/larz
chmod 440 /etc/sudoers.d/larz
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/*
CHROOT

cleanup
trap - EXIT

# The machine this image ships as - written after the package install so it
# is not clobbered by larz-system's packaged default conffile.
cat > "$ROOT/etc/larzos/system.lz" <<'EOF'
# The machine this image becomes. Edit, then: sudo larz-system apply
import "larzos" as larzos

larzos.system({
  "hostname": "larzos",
  "users":    [ { "name": "larz", "groups": ["sudo"], "shell": "/usr/bin/larzsh" } ],
  "packages": ["larz-branding", "larz", "larz-system", "larz-ai", "larzsh", "git", "curl"],
  "services": { "larz-ai": "enabled" },
  "audio":    { "profile": "off" },
  "ai":       { "local_models": [], "gateway": "https://gateway.larzpay.com" },
})
EOF

# Identity gate: the image must not present as the base distro.
sh "$HERE/tools/check-branding.sh" "$ROOT"

mkdir -p "$(dirname "$OUT")"
tar --numeric-owner -C "$ROOT" -czf "$OUT" .
echo "built $OUT  ($(du -h "$OUT" | cut -f1))"
