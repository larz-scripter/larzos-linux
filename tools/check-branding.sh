#!/bin/sh
# check-branding.sh <rootfs> - fail the build if a root filesystem still
# presents as the base distro instead of LarzOS. Run after the larz-branding
# package (or `larz-rebrand apply`) in build-rootfs.sh / build-iso.sh.
set -eu

R="${1:?usage: check-branding.sh <rootfs-dir>}"
[ -d "$R" ] || { echo "check-branding: no such dir: $R" >&2; exit 2; }

rc=0
bad() { echo "  FAIL  $*"; rc=1; }
ok()  { echo "  ok    $*"; }

f="$R/usr/lib/os-release"
if [ -r "$f" ] && grep -q '^ID=larzos$' "$f" && ! grep -qiE '^(ID|NAME|PRETTY_NAME)=.*(debian|ubuntu)' "$f"; then
  ok "os-release -> $(sed -n 's/^PRETTY_NAME=//p' "$f" | tr -d '\"')"
else
  bad "os-release still names the base distro (or ID!=larzos)"
fi

f="$R/etc/issue"
if [ -r "$f" ] && grep -q 'LarzOS' "$f" && ! grep -qiE 'debian|ubuntu' "$f"; then
  ok "/etc/issue branded"
else
  bad "/etc/issue not branded"
fi

[ -x "$R/etc/update-motd.d/00-larzos" ] && ok "motd hook present" || bad "missing /etc/update-motd.d/00-larzos"

h=$(cat "$R/etc/hostname" 2>/dev/null || echo "")
case "$h" in
  larzos|larzbox|larz*) ok "hostname -> $h" ;;
  "") echo "  note  /etc/hostname unset (live-config will name it)" ;;
  *) bad "/etc/hostname is '$h' - a leaked build-host name" ;;
esac

for leak in 10-help-text 50-motd-news 80-esm 90-updates-available 91-release-upgrade 95-hwe-eol 10-uname; do
  [ -e "$R/etc/update-motd.d/$leak" ] && bad "base motd script left behind: $leak"
done

link=$(readlink "$R/etc/dpkg/origins/default" 2>/dev/null || echo "")
[ "$link" = "larzos" ] && ok "dpkg vendor -> larzos" || bad "dpkg origins/default -> ${link:-unset}, not larzos"

[ -r "$R/etc/default/grub.d/99-larzos.cfg" ] && ok "grub distributor set" || echo "  note  no grub.d/99-larzos.cfg (ok if this image has no grub)"

grep -rIl --exclude-dir=doc --exclude-dir=locale -iE 'welcome to (debian|ubuntu)' "$R/etc" 2>/dev/null \
  | while read -r hit; do echo "  note  '$hit' still says welcome to Debian/Ubuntu"; done || true

echo
if [ "$rc" -eq 0 ]; then echo "check-branding: PASS ($R)"; else echo "check-branding: FAIL ($R)"; fi
exit "$rc"
