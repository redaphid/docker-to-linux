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

rm $DISK
truncate -s 4G $DISK

echo_blue "[Make partitions]"
parted --script $DISK \
    mklabel gpt \
    mkpart "EFI" fat32 1Mi $EFI_SIZE \
    set 1 esp on \
    mkpart "rootfs" ext4 ${EFI_OFFSET_HUMAN} 100%

fdisk -l $DISK

losetup -D

#root partition
ROOT_LOOP=$(losetup -f)
ROOT_DIR=/os/mnt/root

echo_blue "[Mounting Root]"
echo -e "\n[Using ${ROOT_LOOP} loop device for root]"
losetup -o ${EFI_OFFSET} ${ROOT_LOOP} $DISK
mkfs.ext4 ${ROOT_LOOP}
mkdir -p $ROOT_DIR
mount -t ext4 ${ROOT_LOOP} $ROOT_DIR

echo_blue "[chroot]"
echo -e "\n[copying host os to chroot]"
rsync -ax / $ROOT_DIR

echo -e "\n[setting up pseudo devices for chroot]"
mount --rbind /sys $ROOT_DIR/sys && mount --make-rslave $ROOT_DIR/sys
mount --rbind /dev $ROOT_DIR/dev && mount --make-rslave $ROOT_DIR/dev
mount --rbind /proc $ROOT_DIR/proc && mount --make-rslave $ROOT_DIR/proc
cp /etc/resolv.conf $ROOT_DIR/etc/


#EFI partition
echo_blue "\n[Format EFI partition]"
EFI_LOOP=$(losetup -f)
EFI_DIR=$ROOT_DIR/boot/
echo -e "\n[Using ${EFI_LOOP} loop device for EFI]"
losetup -o 1Mi ${EFI_LOOP} $DISK
mkfs.fat32 ${EFI_LOOP}
exit 1

mkdir -p $EFI_DIR
mount -t auto ${EFI_LOOP} $EFI_DIR
mkdir $EFI_DIR/EFI

ls -alh $ROOT_DIR
ls -alh $EFI_DIR

PS1='(chroot) # ' chroot $ROOT_DIR /bin/bash -c 'grub-install --no-nvram --efi-directory=/boot && exit'
echo "checking efi dir"
ls -alh $EFI_DIR/EFI/debian

umount -lf $EFI_DIR
umount -lf $ROOT_DIR/sys
umount -lf $ROOT_DIR/dev
umount -lf $ROOT_DIR/proc
umount $ROOT_DIR


echo "formatting root (again)"
yes | mkfs.ext4 ${ROOT_LOOP}

echo "re-mounting root"
mount -t auto ${ROOT_LOOP} $ROOT_DIR
ls -alh $ROOT_DIR

echo_blue "[Copy ${DISTR} directory structure to partition]"



cp -R /os/${DISTR}.dir/. $ROOT_DIR


echo_blue "[Unmount root (yes, again)]"
umount $ROOT_DIR

losetup -D

# echo_blue "[Write syslinux MBR]"
# dd if=/usr/lib/syslinux/mbr/mbr.bin of=$DISK bs=440 count=1 conv=notrunc

# echo_blue "[Convert to qcow2]"
# qemu-img convert -c $DISK -O qcow2 /os/${DISTR}.qcow2
