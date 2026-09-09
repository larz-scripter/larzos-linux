#!/data/data/com.termux/files/usr/bin/sh
# LarzOS Linux - Termux edition installer
#
#   curl -fsSL https://larzos.com/larzos-linux/termux.sh | sh
#
# Installs the LarzOS control plane (larz-system / larz-pkg / larz-aid) on an
# unrooted Android phone via Termux. Larzscript is a fully static aarch64 ELF,
# so it runs natively on Android - no proot, no chroot.
#
# What works here:  larz-system plan/show/modules/version, larz-pkg, larz-aid
#                   (route/models/serve/health) - the whole config + package +
#                   AI-router engine, exactly as on a real LarzOS box.
# What does NOT:     larz-system apply  (needs root + apt + systemd).
#                    Use a VM / the live ISO / the WSL rootfs for a full apply.
set -eu

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
REPO_DIR="${LARZOS_DIR:-$HOME/larzos-linux}"
BRANCH="${LARZOS_BRANCH:-main}"
LZS_URL="https://larzos.com/apt/pool/main/larzscript_1.40.0_arm64.deb"
GIT_URL="https://github.com/larz-scripter/larzos-linux"

say() { printf '\033[1;36m::\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

case "$(uname -m)" in
  aarch64|arm64) ;;
  *) die "this build is aarch64-only (found $(uname -m))" ;;
esac

# 1. deps
if command -v pkg >/dev/null 2>&1; then
  say "installing git, curl, tar, xz, dpkg"
  pkg install -y git curl tar xz-utils dpkg >/dev/null 2>&1 || \
    pkg install -y git curl tar xz-utils dpkg
else
  command -v git curl >/dev/null 2>&1 || die "need git and curl on PATH"
fi

# 2. static larzscript
if ! command -v larzscript >/dev/null 2>&1; then
  say "fetching static larzscript (aarch64) -> \$PREFIX/bin"
  tmp="$(mktemp -d)"
  curl -fsSL "$LZS_URL" -o "$tmp/l.deb"
  mkdir "$tmp/x"
  if command -v dpkg-deb >/dev/null 2>&1; then
    dpkg-deb -x "$tmp/l.deb" "$tmp/x"
  elif command -v ar >/dev/null 2>&1; then
    ( cd "$tmp" && ar x l.deb && tar -C x -xf data.tar.* )
  else
    die "need dpkg or binutils to unpack the larzscript package (pkg install dpkg)"
  fi
  install -m 0755 "$(find "$tmp/x" -name larzscript -type f | head -1)" "$PREFIX/bin/larzscript"
  rm -rf "$tmp"
fi
say "larzscript $(larzscript --version 2>&1 | sed 's/.*native) //')"

# 3. repo
if [ -d "$REPO_DIR/.git" ]; then
  say "updating $REPO_DIR"
  git -C "$REPO_DIR" pull --ff-only --quiet || true
else
  say "cloning $GIT_URL -> $REPO_DIR"
  git clone --depth 1 --branch "$BRANCH" "$GIT_URL" "$REPO_DIR"
fi

# 4. config seeds (user-writable, no /etc on Android)
CONF_DIR="$HOME/.config/larzos"
mkdir -p "$CONF_DIR"
if [ ! -f "$CONF_DIR/system.lz" ]; then
  cp "$REPO_DIR/examples/system.lz" "$CONF_DIR/system.lz"
  say "seeded $CONF_DIR/system.lz  (edit it, then: larz-system plan)"
fi
if [ ! -f "$CONF_DIR/ai.toml" ]; then
  cat > "$CONF_DIR/ai.toml" <<'EOF'
gateway = "https://gateway.larzpay.com"
[local]
models = []
EOF
fi

# 5. wrappers
mk_wrap() {
  bin="$1"; target="$2"
  cat > "$PREFIX/bin/$bin" <<EOF
#!/data/data/com.termux/files/usr/bin/sh
export LARZSCRIPT_PATH="$REPO_DIR/lib"
export LARZOS_AI_CONF="\${LARZOS_AI_CONF:-$CONF_DIR/ai.toml}"
cd "$REPO_DIR"
exec larzscript "$REPO_DIR/$target" "\$@"
EOF
  chmod 0755 "$PREFIX/bin/$bin"
}
say "installing wrappers: larz-system larz-pkg larz-aid"
mk_wrap larz-pkg    bin/larz-pkg
mk_wrap larz-aid    packages/larz-ai/files/larz-aid.lz

# larz-system: default the spec path to the user config when the sub-command
# takes one (plan/show/apply) and the caller didn't give one.
cat > "$PREFIX/bin/larz-system" <<EOF
#!/data/data/com.termux/files/usr/bin/sh
export LARZSCRIPT_PATH="$REPO_DIR/lib"
export LARZOS_AI_CONF="\${LARZOS_AI_CONF:-$CONF_DIR/ai.toml}"
SPEC="$CONF_DIR/system.lz"
case "\${1:-}" in
  plan|show|apply) [ -n "\${2:-}" ] || set -- "\$1" "\$SPEC" ;;
esac
exec larzscript "$REPO_DIR/bin/larz-system" "\$@"
EOF
chmod 0755 "$PREFIX/bin/larz-system"

cat <<EOF

  \033[1;32mLarzOS (Termux edition) ready.\033[0m

    larz-system modules            list realization modules
    larz-system plan  ~/.config/larzos/system.lz
    larz-system show  ~/.config/larzos/system.lz
    larz-pkg  list
    larz-aid  route --task coding
    larz-aid  serve &              # local AI router on 127.0.0.1:8199
    curl 127.0.0.1:8199/health

  Edit ~/.config/larzos/system.lz to describe your machine in Larzscript.
  'larz-system apply' is intentionally disabled here (needs root+apt+systemd) -
  test a full apply on the live ISO, a VM, or the WSL rootfs.
EOF
