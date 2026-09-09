#!/bin/sh
# build-iso.sh - a hybrid BIOS/UEFI live ISO from the LarzOS rootfs, on the
# Debian live stack (live-boot + live-config). No casper.
#
# Boots to an autologin larzsh console. `larz-install <disk>` then writes
# LarzOS to a real disk. No persistence in the live session.
#
# Run on a Debian/Ubuntu host as root, after tools/build-rootfs.sh.
#
#   ROOTFS=dist/larzos-rootfs-amd64.tar.gz OUT=dist/larzos-live-amd64.iso \
#     sh tools/build-iso.sh
set -eu

ROOTFS="${ROOTFS:-dist/larzos-rootfs-amd64.tar.gz}"
OUT="${OUT:-dist/larzos-live-amd64.iso}"
WORK="${WORK:-/tmp/larzos-iso}"
KERNEL_PKG="${KERNEL_PKG:-linux-image-amd64}"
ROOT="$WORK/rootfs"
ISO="$WORK/iso"
HERE="$(cd "$(dirname "$0")/.." && pwd)"

for t in xorriso grub-mkrescue mksquashfs; do
  command -v "$t" >/dev/null || { echo "need $t (apt install xorriso grub-common mtools grub-efi-amd64-bin squashfs-tools)"; exit 1; }
done
[ -f "$ROOTFS" ] || { echo "rootfs not found: $ROOTFS - run tools/build-rootfs.sh first"; exit 1; }

cleanup() { for m in dev/pts dev proc sys run; do umount -l "$ROOT/$m" 2>/dev/null || true; done; }
trap cleanup EXIT

rm -rf "$WORK"
mkdir -p "$ROOT" "$ISO/live" "$ISO/boot/grub" "$ISO/.disk"
tar -C "$ROOT" -xzf "$ROOTFS"

for m in proc sys dev dev/pts run; do mount --bind "/$m" "$ROOT/$m"; done

chroot "$ROOT" /bin/sh -eux <<CHROOT
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  $KERNEL_PKG live-boot live-config live-config-systemd \
  gdisk parted dosfstools rsync e2fsprogs \
  grub-pc-bin grub-efi-amd64-bin grub2-common
CHROOT

chroot "$ROOT" /bin/sh -eux <<'CHROOT'
export DEBIAN_FRONTEND=noninteractive

# live-boot's overlay root needs these in the initramfs.
sed -i 's/^MODULES=.*/MODULES=most/' /etc/initramfs-tools/initramfs.conf
printf '\noverlay\nsquashfs\nisofs\nloop\nsr_mod\ncdrom\nvfat\n' >> /etc/initramfs-tools/modules
cat > /etc/initramfs-tools/hooks/larzos-live <<'H'
#!/bin/sh
[ "$1" = prereqs ] && { echo; exit 0; }
. /usr/share/initramfs-tools/hook-functions
for m in overlay squashfs isofs loop; do manual_add_modules "$m"; done
H
chmod +x /etc/initramfs-tools/hooks/larzos-live

# live-config: name the machine, reuse the packaged larz user, skip prompts.
mkdir -p /etc/live
cat > /etc/live/config.conf <<'L'
LIVE_HOSTNAME="larzos"
LIVE_USERNAME="larz"
LIVE_USER_DEFAULT_GROUPS="audio cdrom dip floppy video plugdev netdev sudo"
L

# autologin to larzsh on console + serial, independent of any display manager
mkdir -p /etc/systemd/system/getty@tty1.service.d \
         /etc/systemd/system/serial-getty@ttyS0.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<E
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin larz --noclear %I \$TERM
E
cat > /etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf <<E
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin larz --keep-baud 115200,38400,9600 %I \$TERM
E

depmod $(ls /lib/modules) || true
update-initramfs -c -k all
lsinitramfs /boot/initrd.img-* | grep -q 'overlay' || { echo "FATAL: overlay not in initramfs"; exit 1; }

apt-get autoremove --purge -y
apt-get clean
rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*.deb \
       /usr/share/doc/* /usr/share/man/* /usr/share/info/* \
       /usr/share/lintian/* /usr/share/locale/* /var/log/* /var/cache/*
CHROOT

cleanup
trap - EXIT

# identity gate
sh "$HERE/tools/check-branding.sh" "$ROOT"

cp "$ROOT"/boot/vmlinuz-*    "$ISO/live/vmlinuz"
cp "$ROOT"/boot/initrd.img-* "$ISO/live/initrd.img"

mksquashfs "$ROOT" "$ISO/live/filesystem.squashfs" \
  -noappend -comp xz -Xbcj x86 -b 1M -wildcards \
  -e "proc/*" "sys/*" "dev/*" "run/*" "tmp/*" "boot/*" \
     "var/cache/*" "var/lib/apt/lists/*" \
     "usr/share/doc/*" "usr/share/man/*" "usr/share/locale/*"
printf 'LarzOS live %s\n' "$(basename "$OUT" .iso | sed 's/larzos-live-//')" > "$ISO/.disk/info"

CMDLINE="boot=live components live-media-path=/live quiet splash vt.global_cursor_default=0 console=tty0 console=ttyS0,115200"
cat > "$ISO/boot/grub/grub.cfg" <<G
set timeout=5
set default=0
insmod all_video
menuentry "LarzOS (live)" {
    linux  /live/vmlinuz $CMDLINE ---
    initrd /live/initrd.img
}
menuentry "LarzOS (live, safe graphics)" {
    linux  /live/vmlinuz $CMDLINE nomodeset ---
    initrd /live/initrd.img
}
G

grub-mkrescue --compress=xz -o "$OUT" "$ISO" -- -volid LARZOS
echo "built $OUT  ($(du -h "$OUT" | cut -f1))"
