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
#   LARZOS_CLAUDE=0 ...                    # skip the ~450MB node + Claude Code layer
#
# Then, on Windows (WSL 2.4.4+):
#   wsl --install --from-file larzos-<ver>.wsl      # branded: icon, OOBE, terminal profile
# or the classic way:
#   wsl --import LarzOS C:\LarzOS larzos-rootfs-amd64.tar.gz && wsl -d LarzOS
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

# --- LarzOS as a first-class WSL distribution -------------------------------
# /etc/wsl-distribution.conf makes `wsl --install --from-file larzos-<ver>.wsl`
# register this as "LarzOS" with the LarzOS icon, a branded first-run, a Start
# menu shortcut and a Windows Terminal profile. (WSL 2.4.4+.)
mkdir -p "$ROOT/usr/lib/larzos"

cat > "$ROOT/etc/wsl-distribution.conf" <<'EOF'
[oobe]
command = /usr/lib/larzos/wsl-oobe.sh
defaultUid = 1000
defaultName = LarzOS

[shortcut]
enabled = true
icon = /usr/lib/larzos/larzos.ico

[windowsterminal]
enabled = true
profileTemplate = /usr/lib/larzos/terminal-profile.json
EOF

cat > "$ROOT/usr/lib/larzos/wsl-oobe.sh" <<'EOF'
#!/bin/sh
# LarzOS — WSL first run. Runs once, as root; must exit 0.
set -e
C='\033[1;36m'; R='\033[0m'
printf '\n'
[ -x /etc/update-motd.d/00-larzos ] && /etc/update-motd.d/00-larzos 2>/dev/null || printf "  ${C}λ  LarzOS${R}\n"
printf '\n'
printf "  You are the ${C}larz${R} user — passwordless sudo, ${C}larzsh${R} as your shell.\n"
printf "  One command runs the machine:  ${C}larz${R}   (try ${C}larz doctor${R}, ${C}larz code${R})\n"
printf "  Your whole system is ${C}/etc/larzos/system.lz${R} — edit it, then ${C}sudo larz apply${R}.\n"
printf '\n'
exit 0
EOF
chmod 0755 "$ROOT/usr/lib/larzos/wsl-oobe.sh"

cat > "$ROOT/usr/lib/larzos/terminal-profile.json" <<'EOF'
{
  "profiles": [
    {
      "name": "LarzOS",
      "colorScheme": "LarzOS",
      "font": { "face": "Cascadia Mono" },
      "cursorShape": "bar"
    }
  ],
  "schemes": [
    {
      "name": "LarzOS",
      "background": "#0B1020", "foreground": "#E8EEF7",
      "cursorColor": "#22D3EE", "selectionBackground": "#22D3EE",
      "black": "#131A2E", "brightBlack": "#3A4661",
      "red": "#F87171", "brightRed": "#FCA5A5",
      "green": "#5CB37A", "brightGreen": "#86EFAC",
      "yellow": "#FFB020", "brightYellow": "#FCD34D",
      "blue": "#60A5FA", "brightBlue": "#93C5FD",
      "purple": "#B587D6", "brightPurple": "#D8B4FE",
      "cyan": "#22D3EE", "brightCyan": "#67E8F9",
      "white": "#E8EEF7", "brightWhite": "#FFFFFF"
    }
  ]
}
EOF

# the icon: prefer the packaged branding .ico, else make one from the png
if [ -f "$ROOT/usr/share/larzos/branding/larzos.ico" ]; then
  cp "$ROOT/usr/share/larzos/branding/larzos.ico" "$ROOT/usr/lib/larzos/larzos.ico"
elif command -v convert >/dev/null && [ -f "$HERE/packages/larz-branding/files/art/larzos.png" ]; then
  convert "$HERE/packages/larz-branding/files/art/larzos.png" -define icon:auto-resize=256,128,64,48,32,16 \
    "$ROOT/usr/lib/larzos/larzos.ico" || true
fi
[ -f "$HERE/packages/larz-branding/files/art/larzos.ico" ] && \
  cp "$HERE/packages/larz-branding/files/art/larzos.ico" "$ROOT/usr/lib/larzos/larzos.ico"

for m in proc sys dev dev/pts; do mount --bind "/$m" "$ROOT/$m"; done

# apt's download/extract sandbox (the _apt user) can't drop privileges inside a
# proot userland (the phone app), so apt-get fails there. Run it as root - a
# small trade-off that makes `apt install` work everywhere this rootfs runs.
mkdir -p "$ROOT/etc/apt/apt.conf.d"
echo 'APT::Sandbox::User "root";' > "$ROOT/etc/apt/apt.conf.d/99larzos-no-sandbox"

chroot "$ROOT" env LARZOS_CLAUDE="${LARZOS_CLAUDE:-1}" ARCH="$ARCH" /bin/sh -eux <<'CHROOT'
export DEBIAN_FRONTEND=noninteractive
apt-get update
# larz-branding's postinst runs `larz-rebrand apply`, so the image presents as
# LarzOS the moment the package lands.
apt-get install -y --no-install-recommends larz-branding larz larz-system larz-ai larzsh
# The command-line tools people expect on a Linux box out of the box.
apt-get install -y --no-install-recommends \
  openssh-client openssh-server git wget ca-certificates \
  nano procps iproute2 iputils-ping dnsutils net-tools \
  bash-completion ncurses-bin xz-utils unzip zip file tar gzip bzip2 \
  htop tree jq
# Claude Code, preinstalled (LARZOS_CLAUDE=0 skips this ~150MB node layer).
# Claude Code 2.x needs Node >= 22 and a per-arch native binary; Debian stable
# ships Node 20, so bring our own Node into /opt and do the global install with
# it, on the same arch as this rootfs. Then apt-install larz-claude-code (its
# postinst sees `claude` already present and skips its own npm run).
if [ "${LARZOS_CLAUDE:-1}" = 1 ]; then
  case "${ARCH:-amd64}" in
    amd64) NODE_ARCH=x64 ;;
    arm64) NODE_ARCH=arm64 ;;
    armhf) NODE_ARCH=armv7l ;;
    *)     NODE_ARCH=x64 ;;
  esac
  NODE_VER="$(curl -fsSL https://nodejs.org/dist/index.json \
    | jq -r 'map(select(.version|startswith("v22.")))|.[0].version')"
  : "${NODE_VER:?could not resolve a Node 22 release}"
  echo "build-rootfs: Node $NODE_VER ($NODE_ARCH) for Claude Code"
  curl -fsSL "https://nodejs.org/dist/${NODE_VER}/node-${NODE_VER}-linux-${NODE_ARCH}.tar.xz" \
    -o /tmp/node.tar.xz
  mkdir -p /opt/node
  tar -xJf /tmp/node.tar.xz -C /opt/node --strip-components=1
  rm -f /tmp/node.tar.xz
  # our Node wins on PATH (guest PATH starts /usr/local/bin)
  for b in node npm npx; do ln -sf "/opt/node/bin/$b" "/usr/local/bin/$b"; done

  /opt/node/bin/npm install -g --no-fund --no-audit @anthropic-ai/claude-code \
    || echo "build-rootfs: claude-code npm install had a problem (continuing)"

  # claude-code ships as a ~200MB self-contained native ELF, delivered as a
  # hardlink (bin/claude.exe  <->  the per-arch package). The phone app unpacks
  # the rootfs tar and can't always reproduce hardlinks, which leaves `claude`
  # a dangling symlink. Move the real binary to a plain file on PATH and drop
  # the hardlinked copies so it survives any unpack.
  CCDIR=/opt/node/lib/node_modules/@anthropic-ai/claude-code
  if [ -s "$CCDIR/bin/claude.exe" ]; then
    rm -f /usr/local/bin/claude /opt/node/bin/claude
    mv "$CCDIR/bin/claude.exe" /usr/local/bin/claude
    chmod 0755 /usr/local/bin/claude
    ln -sf /usr/local/bin/claude /opt/node/bin/claude
    rm -rf "$CCDIR"/node_modules/@anthropic-ai/claude-code-linux-* 2>/dev/null || true
  fi

  apt-get install -y --no-install-recommends larz-claude-code || \
    echo "build-rootfs: larz-claude-code install had a problem (continuing)"

  test -x /usr/local/bin/claude && /usr/local/bin/claude --version \
    || { echo "build-rootfs: FATAL - claude not runnable"; exit 1; }
fi
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
  "packages": ["larz-branding", "larz", "larz-system", "larz-ai", "larzsh", "larz-claude-code", "git", "curl"],
  "services": { "larz-ai": "enabled" },
  "audio":    { "profile": "off" },
  "ai":       { "local_models": [], "gateway": "https://gateway.larzos.com" },
})
EOF

# Identity gate: the image must not present as the base distro.
sh "$HERE/tools/check-branding.sh" "$ROOT"

mkdir -p "$(dirname "$OUT")"
tar --numeric-owner -C "$ROOT" -czf "$OUT" .
echo "built $OUT  ($(du -h "$OUT" | cut -f1))"
