#!/bin/sh
##Parameters##
disk=sda; # main drive name
boot=sda1; #boot partition
lvm=sda2; #lvm partition


##Preparing Disks##
dd bs=4096 if=/dev/urandom iflag=nocache of=/dev/$disk oflag=direct status=progress || true;  #overriting disks with random numbers to increase security can be commented out, as it takes some time
dd bs=4096 if=/dev/urandom iflag=nocache of=/dev/$disk2 oflag=direct status=progress || true;
fdisk /dev/$disk;

##LVM SETUP##
cryptsetup -v -y -c aes-xts-plain64 -s 512 -h sha512 -i 5000 --use-random luksFormat /dev/$lvm;  #encryption is set up only for one disk, so if you need to encrypt both just do it after installing gentoo
cryptsetup luksOpen /dev/$lvm lvm-system; #opening disk in order to create lvm
pvcreate /dev/mapper/lvm-system;
vgcreate lvmSystem /dev/mapper/lvm-system; 

lvcreate --contiguous y --size 16G lvmSystem --name volSwap; #creates logical volume for Swap partition
lvcreate --contiguous y --size 100G lvmSystem --name volRoot; #creates logical volume for Root partition  #change this part if you need more or less partitions
lvcreate --contiguous y --extents +100%FREE lvmSystem --name volHome; #creates logical volume for Home partition


##Formatting Partitions##
fs=ext4;
#fs_format  params  path
mkfs.vfat -n BOOT -F 32 /dev/$boot;
mkswap -L SWAP /dev/lvmSystem/volSwap;  #edit this part according to your partition settings
mkfs.$fs -L ROOT /dev/lvmSystem/volRoot;
mkfs.$fs -L HOME /dev/lvmSystem/volHome;


##Mounting Partitions##
swapon LABEL=SWAP;  #mounting by label work will only work if you applied labels to your partitions
mkdir -p /mnt/gentoo; 
mount LABEL=ROOT /mnt/gentoo;      
mkdir -p /mnt/gentoo/boot;
mount LABEL=BOOT /mnt/gentoo/boot;
mkdir -p /mnt/gentoo/home;
mount LABEL=HOME /mnt/gentoo/home;



##Installing Base System##
stage=https://distfiles.gentoo.org/releases/amd64/autobuilds/20241027T164832Z/stage3-amd64-openrc-20241027T164832Z.tar.xz; #insert a link for your desired stage file
cd /mnt/gentoo;
wget $stage;                                                             
tar xpvf stage3-* --xattrs-include='*.*' --numeric-owner;
cp /home/mint/gentoo/gentooinstall2.sh /mnt/gentoo/gentooinstall2.sh;  #change to the directory your file is in

##Setting make.conf##
echo 'COMMON_FLAGS="-march=znver2 -O2 -pipe"' > /mnt/gentoo/etc/portage/make.conf;  #edit -march to =native for default setting or to your specific cpu, look up the wiki
echo 'CFLAGS="${COMMON_FLAGS}"' >> /mnt/gentoo/etc/portage/make.conf;
echo 'CXXFLAGS="${COMMON_FLAGS}"' >> /mnt/gentoo/etc/portage/make.conf;
echo 'MAKEOPTS="-j8 -l12"' >> /mnt/gentoo/etc/portage/make.conf;  #rule of thumb is -j[RAM/2GB] -l[thread count]
echo 'EMERGE_DEFAULT_OPTS="--jobs 8 --load-average 8"' >> /mnt/gentoo/etc/portage/make.conf; #same here
echo 'ACCEPT_LICENSE="*"' >> /mnt/gentoo/etc/portage/make.conf; #you can accept or decline licenses here
echo 'USE="-wayland -systemd -gnome -aqua -cdinstall -cdr -css -dvd -dvdr -a52 -clamav -coreaudio -ios -ipod -iee1395 -telemetry -emacs -xemacs -emboss -3dfx -emboss -altivec -smartcard -cups -ibm cryptsetup crypt device-mapper lvm"' >> /mnt/gentoo/etc/portage/make.conf;  #better left alone unless you know what to do 
echo 'VIDEO_CARDS="amdgpu radeonsi"' >> /mnt/gentoo/etc/portage/make.conf;  #change to whatever gpu you use, look up the wiki
echo 'ACCEPT_KEYWORDS="~amd64"' >> /mnt/gentoo/etc/portage/make.conf; 
echo 'GRUB_PLATFORM="efi-64"' >>  /mnt/gentoo/etc/portage/make.conf;  #if you don't have uefi boot delete or comment the line

##Chrooting##
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/; #this whole block is unnecessary if you use dedicated gentoo install system
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
