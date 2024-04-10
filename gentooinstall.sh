#!/bin/bash
##Parameters##
disk=sda; #disk name
disk2=sda;
boot=sda1; #boot partition
lvm=sda2; #lvm partition


##Preparing Disks##

#overriting disks with random numbers to increase security can be commented out
dd bs=4096 if=/dev/urandom iflag=nocache of=/dev/$disk oflag=direct status=progress || true;
dd bs=4096 if=/dev/urandom iflag=nocache of=/dev/$disk2 oflag=direct status=progress || true;

fdisk /dev/$disk; #opening manual disk partitioning

##LVM SETUP##
cryptsetup -v -y -c aes-xts-plain64 -s 512 -h sha512 -i 5000 --use-random luksFormat /dev/$lvm; #encrypting disk
cryptsetup luksOpen /dev/$lvm lvm-system; #opening disk in order to create lvm
pvcreate /dev/mapper/lvm-system; #creates physical  volume
vgcreate lvmSystem /dev/mapper/lvm-system; #creates lvm group of logical volumes

#can be changed according to your needs
lvcreate --contiguous y --size 16G lvmSystem --name volSwap; #creates logical volume for Swap partition
lvcreate --contiguous y --size 50G lvmSystem --name volRoot; #creates logical volume for Root partition
lvcreate --contiguous y --extents +100%FREE lvmSystem --name volHome; #creates logical volume for Home partition

vgscan; #scans for available lvms
vgchange;#activates lvms


##Formatting Partitions##
#edit this part to your liking
fs=btrfs;
#fs_format  params  path
mkfs.vfat -n BOOT -F 32 /dev/$boot;
mkswap -L SWAP /dev/lvmSystem/volSwap; 
mkfs.$fs -L ROOT /dev/lvmSystem/volRoot;
mkfs.$fs -L HOME /dev/lvmSystem/volHome;


##Mounting Partitions##

#before mounting you always need to create a mountpoint
swapon LABEL=SWAP; #exception is swap
mkdir -p /mnt/gentoo; #mountpoint for root
mount LABEL=ROOT /mnt/gentoo; #mounting root
mkdir -p /mnt/gentoo/boot;
mount LABEL=BOOT /mnt/gentoo/boot;
mkdir -p /mnt/gentoo/home;
mount LABEL=HOME /mnt/gentoo/home;



##Installing Base System##
stage=https://distfiles.gentoo.org/releases/amd64/autobuilds/20240407T165048Z/stage3-amd64-openrc-20240407T165048Z.tar.xz; #insert a link for your desired stage file

#installing stage file
cd /mnt/gentoo;
wget $stage; #downloads the stage file
tar xpvf stage3-* --xattrs-include='*.*' --numeric-owner; #untars it

#change to the directory your file is in
cp /home/mint/gentoo/gentooinstall2.sh /mnt/gentoo/gentooinstall2.sh;

#setting make.conf 
echo 'COMMON_FLAGS="-march=znver2 -O2 -pipe"' > /mnt/gentoo/etc/portage/make.conf; # edit -march to =native for default setting or to your specific cpu, look up the wiki
echo 'CFLAGS="${COMMON_FLAGS}"' >> /mnt/gentoo/etc/portage/make.conf;
echo 'CXXFLAGS="${COMMON_FLAGS}"' >> /mnt/gentoo/etc/portage/make.conf;
echo 'MAKEOPTS="-j8 -l12"' >> /mnt/gentoo/etc/portage/make.conf; #use rule -j[RAM/2GB] -l[thread count]
echo 'EMERGE_DEFAULT_OPTS="--jobs 8 --load-average 12"' >> /mnt/gentoo/etc/portage/make.conf; #same here
echo 'ACCEPT_LICENSE="*"' >> /mnt/gentoo/etc/portage/make.conf; #you can accept or decline licenses here
echo 'USE="-systemd -gnome -aqua -cdinstall -cdr -css -dvd -dvdr -a52 -cjk -clamav -coreaudio -ios -ipod -iee1395 -telemetry -emacs -xemacs -emboss -3dfx -emboss -altivec -smartcard -cups -ibm bash-completion alsa symlink cryptsetup crypt device-mapper lvm savedconfig X udev udisks elogind dbus"' >> /mnt/gentoo/etc/portage/make.conf; #better left alone unless you know what to do 
echo 'VIDEO_CARDS="amdgpu radeonsi"' >> /mnt/gentoo/etc/portage/make.conf; #change to whatever gpu you use, look up the wiki
echo 'ACCEPT_KEYWORDS="~amd64"' >> /mnt/gentoo/etc/portage/make.conf; 
echo 'GRUB_PLATFORM="efi-64"' >>  /mnt/gentoo/etc/portage/make.conf; #if you don't have uefi boot delete or comment the line

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
