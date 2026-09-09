#!/data/data/com.termux/files/usr/bin/sh
# LarzOS Linux - Termux edition installer
#
#   curl -fsSL https://larzos.com/larzos-linux/termux.sh | sh
#
# Android's seccomp filter kills foreign static binaries (SIGSYS / "Bad system
# call") the moment glibc reaches for a newer syscall, so LarzOS runs inside a
# small Debian arm64 container via proot-distro. You still just type
# `larz-system plan` in Termux - thin launchers hand off to the container.
#
# Works:  larz-system plan/show/modules/status, larz-aid (route/models/serve),
#         a full larzsh shell, apt against the real LarzOS repo.
# Limited: larz-system apply converges packages + files but not systemd
#          services (no init in the container). Use the live ISO / a VM / WSL
#          for a full apply.
set -eu

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
DISTRO="${LARZOS_DISTRO:-debian}"
APT_BASE="https://larzos.com/apt"
CONF_DIR="$HOME/.config/larzos"

say()  { printf '\033[1;36m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

[ -n "${PREFIX:-}" ] && [ -d "$PREFIX/bin" ] || die "run this inside Termux"
case "$(uname -m)" in
  aarch64|arm64) ;;
  *) die "aarch64 only (found $(uname -m))" ;;
esac

# 1. proot-distro + a Debian arm64 rootfs
say "installing proot-distro"
pkg install -y proot-distro >/dev/null 2>&1 || pkg install -y proot-distro

if proot-distro list --installed 2>/dev/null | grep -qw "$DISTRO"; then
  say "$DISTRO container already installed"
else
  say "installing the $DISTRO arm64 container (~150 MB download, one time)"
  proot-distro install "$DISTRO"
fi

pd() { proot-distro login "$DISTRO" --shared-tmp -- "$@"; }

# 2. LarzOS apt repo + packages inside the container
say "adding the LarzOS apt repo and installing the stack (inside $DISTRO)"
pd sh -eu -c '
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq curl gnupg ca-certificates >/dev/null
  curl -fsSL '"$APT_BASE"'/KEY.asc | gpg --dearmor -o /usr/share/keyrings/larzos-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/larzos-archive-keyring.gpg] '"$APT_BASE"' stable main" \
    > /etc/apt/sources.list.d/larzos.list
  apt-get update -qq
  apt-get install -y -qq larzscript larz-system larz-ai larzsh
  larz-system version
'

# 3. share the spec dir: Termux ~/.config/larzos  <->  container /etc/larzos
#    (the bind masks the package's /etc/larzos, so seed both files out first)
mkdir -p "$CONF_DIR"
[ -f "$CONF_DIR/ai.toml" ] || pd sh -c 'cat /etc/larzos/ai.toml 2>/dev/null' > "$CONF_DIR/ai.toml" || true
[ -s "$CONF_DIR/ai.toml" ] || printf 'gateway = "https://gateway.larzpay.com"\n[local]\nmodels = []\n' > "$CONF_DIR/ai.toml"
if [ ! -f "$CONF_DIR/system.lz" ]; then
  pd sh -c 'cat /etc/larzos/system.lz 2>/dev/null' > "$CONF_DIR/system.lz" || true
  [ -s "$CONF_DIR/system.lz" ] || cat > "$CONF_DIR/system.lz" <<'EOF'
# Your machine, in Larzscript.  Edit, then:  larz-system plan
import "larzos" as larzos

larzos.system({
  "hostname": "larzbox",
  "timezone": "UTC",
  "locale":   "en_US.UTF-8",
  "packages": ["git", "curl"],
  "ai": { "gateway": "https://gateway.larzpay.com" },
})
EOF
  say "seeded $CONF_DIR/system.lz"
fi

# 4. Termux launchers -> container
mk() {
  cat > "$PREFIX/bin/$1" <<EOF
#!/data/data/com.termux/files/usr/bin/sh
exec proot-distro login "$DISTRO" --shared-tmp --bind "$CONF_DIR:/etc/larzos" -- $2 "\$@"
EOF
  chmod 0755 "$PREFIX/bin/$1"
}
say "installing launchers: larz-system larz-aid larzos"
mk larz-system larz-system
mk larz-aid    larz-aid
cat > "$PREFIX/bin/larzos" <<EOF
#!/data/data/com.termux/files/usr/bin/sh
# drop into the LarzOS container shell
exec proot-distro login "$DISTRO" --shared-tmp --bind "$CONF_DIR:/etc/larzos" -- "\${@:-larzsh}"
EOF
chmod 0755 "$PREFIX/bin/larzos"

printf '\n\033[1;32mLarzOS (Termux edition) ready.\033[0m\n'
cat <<EOF

  larz-system modules
  larz-system plan            # reads ~/.config/larzos/system.lz
  larz-system show
  larz-aid  route --task coding
  larz-aid  serve &           # AI router on 127.0.0.1:8199 (inside the container)
  larzos                      # a full LarzOS (larzsh) shell

  Edit ~/.config/larzos/system.lz on the phone - it is /etc/larzos/system.lz
  in the container. 'larz-system apply' converges packages and files but not
  systemd services (no init here); use the live ISO / a VM / WSL for that.
EOF
