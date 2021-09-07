FROM amd64/debian:bullseye
LABEL com.iximiuz-project="docker-to-linux"
RUN apt-get -y update
RUN apt-get -y install \
    dosfstools \
    extlinux \
    fdisk \
    qemu-utils \
    parted \
    pv \
    uuid \
    tree \
    grub-efi-amd64 \
    linux-image-amd64 \
    rsync \    
    xorriso \    
    mtools \
    refind \