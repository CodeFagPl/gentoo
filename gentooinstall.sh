#!/bin/sh
##Parameters##
disk=sda; # main drive name
boot=sda1; #boot partition
lvm=sda2; #lvm partition

##Preparing Disks##
#dd bs=4096 if=/dev/urandom iflag=nocache of=/dev/$disk oflag=direct status=progress || true;  #overriting disks with random numbers to increase security can be commented out, as it takes some time
parted -s /dev/$disk mklabel gpt;
parted -s -a optimal /dev/$disk mkpart "primary" "fat32" "0%" "500MiB";
parted -s /dev/$boot set 1 boot on;
parted -s -a optimal /dev/$disk mkpart "primary" "ext4" "500MiB" "100%"
parted -s /dev/$lvm set 2 lvm on;
parted -s /dev/$boot align-check optimal 1;
parted -s /dev/$lvm align-check optimal 2;

##LVM SETUP##
cryptsetup -v -y -c aes-xts-plain64 -s 512 -h sha512 -i 5000 --use-random luksFormat /dev/$lvm;
cryptsetup luksOpen /dev/$lvm lvm-system;
pvcreate /dev/mapper/lvm-system;
vgcreate lvmSystem /dev/mapper/lvm-system; 

lvcreate --contiguous y --size 16G lvmSystem --name volSwap; #creates logical volume for Swap partition
lvcreate --contiguous y --size 50G lvmSystem --name volRoot; #creates logical volume for Root partition  #change this part if you need more or less partitions
lvcreate --contiguous y --extents +100%FREE lvmSystem --name volHome; #creates logical volume for Home partition

##Formatting Partitions##
fs=ext4;
mkfs.vfat -n BOOT -F 32 /dev/$boot;
mkswap -L SWAP /dev/lvmSystem/volSwap;  
mkfs.$fs -L ROOT /dev/lvmSystem/volRoot;
mkfs.$fs -L HOME /dev/lvmSystem/volHome;

##Mounting Partitions##
swapon LABEL=SWAP;
mkdir -p /mnt/gentoo; 
mount LABEL=ROOT /mnt/gentoo;      
mkdir -p /mnt/gentoo/boot;
mount LABEL=BOOT /mnt/gentoo/boot;
mkdir -p /mnt/gentoo/home;
mount LABEL=HOME /mnt/gentoo/home;

##Installing Base System##
stage=https://distfiles.gentoo.org/releases/amd64/autobuilds/20250105T170325Z/stage3-amd64-openrc-20250105T170325Z.tar.xz;
cd /mnt/gentoo;
wget $stage;                                                             
tar xpvf stage3-* --xattrs-include='*.*' --numeric-owner;
cp /gentoo/gentooinstall2.sh /mnt/gentoo/gentooinstall2.sh;  #change to the directory your file is in

##Setting make.conf##
echo 'COMMON_FLAGS="-march=znver2 -O2 -pipe"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
MAKEOPTS="-j8 -l12"
EMERGE_DEFAULT_OPTS="--jobs 8 --load-average 12"
ACCEPT_LICENSE="*"
USE="-webengine -gtk -qt -wayland -systemd -gnome -kde -aqua -cdinstall -cdr -css -dvd -dvdr -a52 -clamav -coreaudio -ios -ipod -iee1395 -telemetry -emacs -xemacs -emboss -3dfx -emboss -altivec -smartcard -cups -ibm cryptsetup crypt device-mapper lvm"
VIDEO_CARDS="amdgpu"
ACCEPT_KEYWORDS="amd64"
GRUB_PLATFORM="efi-64"' > /mnt/gentoo/etc/portage/make.conf;

##Chrooting##
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/;
mount --types proc /proc /mnt/gentoo/proc;
mount --rbind /sys /mnt/gentoo/sys;
mount --make-rslave /mnt/gentoo/sys;
mount --rbind /dev /mnt/gentoo/dev;
mount --make-rslave /mnt/gentoo/dev;
mount --bind /run /mnt/gentoo/run;
mount --make-slave /mnt/gentoo/run;
test -L /dev/shm && rm /dev/shm && mkdir /dev/shm;
mount --types tmpfs --options nosuid,nodev,noexec shm /dev/shm;
chmod 1777 /dev/shm /run/shm;

chroot /mnt/gentoo /bin/bash;
