#!/bin/bash
##Parameters##
disk=sda;
boot=sda1;
lvm=sda2;


##Preparing Disks##

#overriting disks with random numbers to increase security can be commented out
#dd bs=4096 if=/dev/urandom iflag=nocache of=/dev/$disk oflag=direct status=progress || true;

#opening manual disk partitioning
fdisk /dev/$disk;

#formatting boot partition
mkfs.vfat -n BOOT -F 32 /dev/$boot;


##LVM SETUP##
#encrypting disk
cryptsetup -v -y -c aes-xts-plain64 -s 512 -h sha512 -i 5000 --use-random luksFormat /dev/$lvm;

#verifying
cryptsetup luksDump /dev/$lvm;

#opening disk in order to create lvm
cryptsetup luksOpen /dev/$lvm lvm-system;

#searches for lvm disks
lvmdiskscan;

#creates physical  volume
pvcreate /dev/mapper/lvm-system;

#displays lvm volumes
pvdisplay;

#creates lvm group of logical volumes
vgcreate lvmSystem /dev/mapper/lvm-system;

#creating logical volumes
lvcreate --contiguous y --size 16G lvmSystem --name volSwap;
lvcreate --contiguous y --size 50G lvmSystem --name volRoot;
lvcreate --contiguous y --size 100G lvmSystem --name volHome;
lvcreate --contiguous y --extents +100%FREE lvmSystem --name volNode;
lvdisplay;

#scans for available lvms
vgscan;

#activates lvms
vgchange;


##Formatting Partitions##
#edit this part to your liking
fs=xfs;

mkswap -L SWAP /dev/lvmSystem/volSwap;
mkfs.$fs -L ROOT /dev/lvmSystem/volRoot;
mkfs.$fs -L HOME /dev/lvmSystem/volHome;
mkfs.$fs -L NODE /dev/lvmSystem/volNode;


##Mounting Partitions##

swapon LABEL=SWAP;
mkdir -p /mnt/gentoo;
mount LABEL=ROOT /mnt/gentoo;
mkdir -p /mnt/gentoo/home;
mount LABEL=HOME /mnt/gentoo/home;
mkdir -p /mnt/gentoo/node;
mount LABEL=NODE /mnt/gentoo/node;


##Installing Base System##
#sets current time and date
stage=https://distfiles.gentoo.org/releases/amd64/autobuilds/20240303T170409Z/stage3-amd64-hardened-openrc-20240303T170409Z.tar.xz;
ntpd -q -g;

#installing stage file
cd /mnt/gentoo;
wget $stage;
tar xpvf stage3-* --xattrs-include='*.*' --numeric-owner;

#change to the directory your file is in
cp /home/mint/gentoo/gentooinstall2.sh /mnt/gentoo/gentooinstall2.sh;

#setting make.conf 
#edit here to your liking
echo 'COMMON_FLAGS="-march=skylake -O2 -pipe"' > /mnt/gentoo/etc/portage/make.conf;
echo 'CFLAGS="${COMMON_FLAGS}"' >> /mnt/gentoo/etc/portage/make.conf;
echo 'CXXFLAGS="${COMMON_FLAGS}"' >> /mnt/gentoo/etc/portage/make.conf;
echo 'MAKEOPTS="-j8 -l8"' >> /mnt/gentoo/etc/portage/make.conf;
echo 'ACCEPT_LICENSE="*"' >> /mnt/gentoo/etc/portage/make.conf;
echo 'USE="-kde -systemd -gnome -aqua -cdinstall -cdr -css -dvd -dvdr -a52 -cjk -clamav -coreaudio -ios -ipod -iee1395 -emacs -xemacs -emboss -3dfx -emboss -altivec -smartcard -cups -ibm minimal readline symlink ncurses cryptsetup crypt device-mapper lvm"' >> /mnt/gentoo/etc/portage/make.conf;
echo 'VIDEO_CARDS="intel nvidia"' >> /mnt/gentoo/etc/portage/make.conf;
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
