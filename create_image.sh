#!/bin/bash

set -e

echo_blue() {
    local font_blue="\033[94m"
    local font_bold="\033[1m"
    local font_end="\033[0m"

    echo -e "\n${font_blue}${font_bold}${1}${font_end}"
}

echo_blue "[Create disk image]"
DISK=/os/${DISTR}.img

EFI_SIZE=512Mi
EFI_OFFSET=`expr $(numfmt --from iec-i 1Mi) \+ $(numfmt --from iec-i $EFI_SIZE)`
EFI_OFFSET_HUMAN=`expr $(numfmt --to iec-i $EFI_OFFSET)`
echo $EFI_OFFSET
echo $EFI_OFFSET_HUMAN

truncate -s 4G $DISK

echo_blue "[Make partition]"
parted --script $DISK \
    mklabel gpt \
    mkpart "EFI" fat32 1Mi $EFI_SIZE \
    set 1 esp on \
    mkpart "rootfs" ext4 $EFI_OFFSET_HUMAN 100%

fdisk -l $DISK

echo_blue "\n[Format partition with ext4]"
losetup -D
LOOPDEVICE=$(losetup -f)
echo -e "\n[Using ${LOOPDEVICE} loop device]"
losetup -o $(expr 512 \* 2048) ${LOOPDEVICE} $DISK
mkfs.vfat ${LOOPDEVICE}

echo_blue "[Copy ${DISTR} directory structure to partition]"
mkdir -p /os/mnt
mount -t auto ${LOOPDEVICE} /os/mnt/
cp -R /os/${DISTR}.dir/. /os/mnt/

echo_blue "[Setup extlinux]"
extlinux --install /os/mnt/boot/
cp /os/${DISTR}/syslinux.cfg /os/mnt/boot/syslinux.cfg

echo_blue "[Unmount]"
umount /os/mnt
losetup -D

echo_blue "[Write syslinux MBR]"
dd if=/usr/lib/syslinux/mbr/mbr.bin of=$DISK bs=440 count=1 conv=notrunc

echo_blue "[Convert to qcow2]"
qemu-img convert -c $DISK -O qcow2 /os/${DISTR}.qcow2
