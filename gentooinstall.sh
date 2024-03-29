#!/bin/bash
##Parameters##
disk=sda;
boot=sda1;
lvm=sda2;


##Preparing Disks##

#overriting disks with random numbers to increase security can be commented out
dd bs=4096 if=/dev/urandom iflag=nocache of=/dev/$disk oflag=direct status=progress || true;

#opening manual disk partitioning
fdisk /dev/$disk;

#formatting boot partition
mkfs.vfat -n BOOT -F 32 /dev/$boot;


##LVM SETUP##
#encrypting disk
cryptsetup -v -y -c aes-xts-plain64 -s 512 -h sha512 -i 5000 --use-random luksFormat /dev/$lvm;

#opening disk in order to create lvm
cryptsetup luksOpen /dev/$lvm lvm-system;


#creates physical  volume
pvcreate /dev/mapper/lvm-system;


#creates lvm group of logical volumes
vgcreate lvmSystem /dev/mapper/lvm-system;

#creating logical volumes
lvcreate --contiguous y --size 16G lvmSystem --name volSwap;
lvcreate --contiguous y --size 50G lvmSystem --name volRoot;
lvcreate --contiguous y --extents +100%FREE lvmSystem --name volHome;
lvdisplay;

#scans for available lvms
vgscan;

#activates lvms
vgchange;


##Formatting Partitions##
#edit this part to your liking
fs=btrfs;

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
#sets current time and date
stage=https://distfiles.gentoo.org/releases/amd64/autobuilds/20240303T170409Z/stage3-amd64-hardened-openrc-20240303T170409Z.tar.xz;

#installing stage file
cd /mnt/gentoo;
wget $stage;
tar xpvf stage3-* --xattrs-include='*.*' --numeric-owner;

#change to the directory your file is in
cp /home/mint/gentoo/gentooinstall2.sh /mnt/gentoo/gentooinstall2.sh;

#setting make.conf 
#edit here to your liking
echo 'COMMON_FLAGS="-march=znver2 -O2 -pipe"' > /mnt/gentoo/etc/portage/make.conf;
echo 'CFLAGS="${COMMON_FLAGS}"' >> /mnt/gentoo/etc/portage/make.conf;
echo 'CXXFLAGS="${COMMON_FLAGS}"' >> /mnt/gentoo/etc/portage/make.conf;
echo 'MAKEOPTS="-j8 -l12"' >> /mnt/gentoo/etc/portage/make.conf;
echo 'ACCEPT_LICENSE="*"' >> /mnt/gentoo/etc/portage/make.conf;
echo 'USE="-systemd -gnome -aqua -cdinstall -cdr -css -dvd -dvdr -a52 -cjk -clamav -coreaudio -ios -ipod -iee1395 -telemetry -emacs -xemacs -emboss -3dfx -emboss -altivec -smartcard -cups -ibm colord readline symlink ncurses cryptsetup crypt device-mapper lvm X alsa bash-completion udisks xinerama elogind suid savedconfig zstd"' >> /mnt/gentoo/etc/portage/make.conf;
echo 'VIDEO_CARDS="amdgpu radeonsi"' >> /mnt/gentoo/etc/portage/make.conf;
echo 'ACCEPT_KEYWORDS="~amd64"' >> /mnt/gentoo/etc/portage/make.conf;
echo 'GRUB_PLATFORM="efi-64"' >>  /mnt/gentoo/etc/portage/make.conf;

#chrooting
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
