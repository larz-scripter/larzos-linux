#!/bin/sh
# build-iso.sh - a hybrid BIOS/UEFI live ISO from the LarzOS rootfs.
#
# Boots (casper live layer) to an autologin larzsh console. `larz-install
# <disk>` then writes LarzOS to a real disk. No persistence in the live
# session itself.
#
# Run on an Ubuntu host as root, after tools/build-rootfs.sh.
#
#   ROOTFS=dist/larzos-rootfs-amd64.tar.gz OUT=dist/larzos-live-amd64.iso \
#     sh tools/build-iso.sh
set -eu

ROOTFS="${ROOTFS:-dist/larzos-rootfs-amd64.tar.gz}"
OUT="${OUT:-dist/larzos-live-amd64.iso}"
WORK="${WORK:-/tmp/larzos-iso}"
ROOT="$WORK/rootfs"
ISO="$WORK/iso"

for t in xorriso grub-mkrescue mksquashfs; do
  command -v "$t" >/dev/null || { echo "need $t (apt install xorriso grub-common mtools grub-efi-amd64-bin squashfs-tools)"; exit 1; }
done
[ -f "$ROOTFS" ] || { echo "rootfs not found: $ROOTFS - run tools/build-rootfs.sh first"; exit 1; }

cleanup() { for m in dev/pts dev proc sys run; do umount -l "$ROOT/$m" 2>/dev/null || true; done; }
trap cleanup EXIT

rm -rf "$WORK"
mkdir -p "$ROOT" "$ISO/casper" "$ISO/boot/grub" "$ISO/.disk"
tar -C "$ROOT" -xzf "$ROOTFS"

for m in proc sys dev dev/pts run; do mount --bind "/$m" "$ROOT/$m"; done

KERNEL_PKG="${KERNEL_PKG:-linux-image-virtual}"

chroot "$ROOT" /bin/sh -eux <<CHROOT
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends $KERNEL_PKG casper
CHROOT

chroot "$ROOT" /bin/sh -eux <<'CHROOT'
export DEBIAN_FRONTEND=noninteractive

# casper's live overlay needs these in the initramfs or it drops to a
# busybox shell ("cow format specified as 'overlay' and no support found").
sed -i 's/^MODULES=.*/MODULES=most/' /etc/initramfs-tools/initramfs.conf
printf '\noverlay\nsquashfs\nisofs\nloop\nsr_mod\ncdrom\nvfat\n' >> /etc/initramfs-tools/modules
# live autologin as the larz user, into larzsh
printf 'export USERNAME="larz"\nexport HOST="larzos"\nexport BUILD_SYSTEM="LarzOS"\nexport FLAVOUR="LarzOS"\n' > /etc/casper.conf
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<E
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin larz --noclear %I \$TERM
E
cat > /etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf <<E 2>/dev/null || mkdir -p /etc/systemd/system/serial-getty@ttyS0.service.d
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin larz --keep-baud 115200,38400,9600 %I \$TERM
E
update-initramfs -c -k all

# slim the live filesystem
apt-get autoremove --purge -y
apt-get clean
rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*.deb \
       /usr/share/doc/* /usr/share/man/* /usr/share/info/* \
       /usr/share/lintian/* /usr/share/locale/* /var/log/* /var/cache/*
CHROOT

cleanup
trap - EXIT

# kernel + initrd for the boot loader
cp "$ROOT"/boot/vmlinuz-*   "$ISO/casper/vmlinuz"
cp "$ROOT"/boot/initrd.img-* "$ISO/casper/initrd"

# the live filesystem
mksquashfs "$ROOT" "$ISO/casper/filesystem.squashfs" \
  -noappend -comp xz -Xbcj x86 -b 1M -wildcards \
  -e "proc/*" "sys/*" "dev/*" "run/*" "tmp/*" "boot/*" \
     "var/cache/*" "var/lib/apt/lists/*" \
     "usr/share/doc/*" "usr/share/man/*" "usr/share/locale/*"
du -sx --block-size=1 "$ROOT" | cut -f1 > "$ISO/casper/filesystem.size"
printf 'LarzOS live amd64\n' > "$ISO/.disk/info"

cat > "$ISO/boot/grub/grub.cfg" <<'G'
set timeout=10
set default=0
insmod all_video
menuentry "LarzOS (live)" {
    linux  /casper/vmlinuz boot=casper quiet splash console=tty0 console=ttyS0,115200 ---
    initrd /casper/initrd
}
menuentry "LarzOS (live, safe graphics)" {
    linux  /casper/vmlinuz boot=casper nomodeset console=tty0 console=ttyS0,115200 ---
    initrd /casper/initrd
}
G

grub-mkrescue --compress=xz -o "$OUT" "$ISO" -- -volid LARZOS
echo "built $OUT  ($(du -h "$OUT" | cut -f1))"
