#!/bin/bash
##Parameters##
disk=sda; #disk name
boot=sda1; #boot partition
lvm=sda2; #lvm partition

#continuation from previous file
env-update && source /etc/profile;


##Updating Repository##
mkdir --parents /etc/portage/repos.conf;
cp /usr/share/portage/config/repos.conf /etc/portage/repos.conf/gentoo.conf;
echo "sync-git-verify-commit-signature = yes" >> /etc/portage/repos.conf/gentoo.conf;
emerge-webrsync;

#adding mirrors
echo 'GENTOO_MIRRORS="http://ftp.vectranet.pl/gentoo/"' >> /etc/portage/make.conf;
emerge --sync;

#adding cpu flags
emerge app-portage/cpuid2cpuflags;
echo "*/* $(cpuid2cpuflags)" > /etc/portage/package.use/00cpu-flags;

#updating @world flags
emerge --verbose --update --deep --newuse @world;


##Setting Timezone##
#edit according to your settings
echo "Europe/Warsaw" > /etc/timezone; #change to match your timezone
emerge --config sys-libs/timezone-data;

#updating locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen; #change locale to your preffered
locale-gen;
echo -e 'LANG="en_US.UTF-8"\nLC_COLLATE="C.UTF-8"' >> /etc/env.d/02locale;
env-update && source /etc/profile;


##Kernel configuration##
#installing firmware
echo "sys-kernel/linux-firmware compress-zstd" > /etc/portage/package.use/sys-kernel;
emerge sys-kernel/linux-firmware;
emerge sys-firmware/sof-firmware;
emerge sys-firmware/alsa-firmware;

#uncomment if you use intel cpu
#echo "sys-firmware/intel-microcode hostonly" > /etc/portage/package.use/sys-firmware;
#emerge sys-firmware/intel-microcode; 

#installing kernel source
echo "sys-kernel/gentoo-sources experimental" >> /etc/portage/package.use/sys-kernel;
emerge gentoo-sources cryptsetup lvm2;

#configuring fstab file
echo -e "UUID=	  /boot	  vfat	  noatime		0 2\nUUID=	  none	  swap	  defaults	0 0\nUUID=	  /	  btrfs	  defaults	0 1\nUUID=	  /home	  btrfs	  defaults	0 1" >> /etc/fstab; #insert your disks UUIDs here
nano /etc/fstab;

#configuring the kernel itself
cd /usr/src/linux;
echo "sys-kernel/installkernel uki" >> /etc/portage/package.use/sys-kernel;
emerge sys-kernel/installkernel;
make menuconfig;
make -j8 && make -j8 modules_install; #change jobs to match your make.conf setting
make install;

#generating initramfs
emerge sys-kernel/dracut;
echo -e 'compress="zstd"\nadd_dracutmodules+="crypt lvm dm rootfs-block "\nfilesystems+="btrfs vfat"\nkernel_cmdline="root=UUID= resume=UUID= rd.luks.uuid= rd.luks.allow-discards rootfstype=btrfs rootflags=ro,relatime"' >> /etc/dracut.conf;
echo 'early_microcode="yes"' > /etc/dracut.conf.d/microcode.conf;
dracut --kver 6.8.4-gentoo; #change to match kernel version you will download


##Configuring the bootloader##
echo "sys-boot/grub mount device-mapper" > /etc/portage/package.use/sys-boot;
emerge grub gentoolkit;

grubconfig='GRUB_CMDLINE_LINUX="quiet net.ifnames=0"'; #you can change your cmdline arguments according to your needs

echo "$grubconfig" >> /etc/default/grub;
echo 'GRUB_ENABLE_CRYPTODISK=y' >> /etc/default/grub;

nano /etc/lvm/lvm.conf; #Set: allow-discards = 1    
nano /etc/default/grub; #check if everything is alright

grub-install --efi-directory=/boot --bootloader-id=GRUB --recheck;
grub-mkconfig -o /boot/grub/grub.cfg;
nano /boot/grub/grub.cfg;


##Finalization##
passwd; #setting password for root

echo Gentoo > /etc/hostname; #set hostname edit however you want :3

#configuring the net
emerge net-misc/dhcpcd;
rc-update add dhcpcd default;
rc-service dhcpcd start;

net=enp4s0; #here insert the name of your net controller
beg='config_'"$net";
end='="dhcp"';
netconfig="$beg""$end";
echo "$netconfig" >> /etc/conf.d/net;
cd /etc/init.d;
ln -s net.lo net.$net;
rc-update add net.$net default;


##Installing tools##
emerge syslog-ng cronie;
echo 'app-shells/bash-completion eselect' > /etc/portage/package.use/app-shells;
emerge app-shells/bash-completion;
emerge net-misc/chrony;
emerge sys-block/io-scheduler-udev-rules sys-fs/dosfstools sys-fs/btrfs-progs;
rc-update add chronyd default;
rc-update add syslog-ng default;
rc-update add cronie default;
rc-update add lvm boot;
rc-update add device-mapper boot;
rc-update add dmcrypt boot;
env-update && source /etc/profile;
