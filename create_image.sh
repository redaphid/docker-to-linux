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

losetup -D

#EFI partition
echo_blue "\n[Format EFI partition]"
EFI_LOOP=$(losetup -f)
echo -e "\n[Using ${EFI_LOOP} loop device for EFI]"
losetup -o $(numfmt --from iec-i 1Mi) ${EFI_LOOP} $DISK
mkfs.vfat ${EFI_LOOP}

mkdir -p /os/mnt/efi
mount -t auto ${EFI_LOOP} /os/mnt/efi
mkdir /os/mnt/efi/EFI



#root partition
ROOT_LOOP=$(losetup -f)
echo -e "\n[Using ${ROOT_LOOP} loop device for root]"
losetup -o $EFI_OFFSET ${ROOT_LOOP} $DISK
mkdir -p /os/mnt/root
mount -t auto ${ROOT_LOOP} /os/mnt/root
ls -alh /os/mnt/root
exit 1

echo_blue "[Copy ${DISTR} directory structure to partition]"



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
