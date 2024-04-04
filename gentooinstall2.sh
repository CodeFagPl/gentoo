#!/bin/bash
##Parameters##
disk=sda;
boot=sda1;
lvm=sda2;

#continuation from previous file
env-update && source /etc/profile;


##Updating Repository##
mkdir --parents /etc/portage/repos.conf;
cp /usr/share/portage/config/repos.conf /etc/portage/repos.conf/gentoo.conf;
echo "sync-git-verify-commit-signature = yes" >> /etc/portage/repos.conf/gentoo.conf;
emerge-webrsync;

##Adding Mirrors##
echo 'GENTOO_MIRRORS="http://ftp.vectranet.pl/gentoo/"' >> /etc/portage/make.conf;
emerge --sync;

##Adding cpu flags##
emerge app-portage/cpuid2cpuflags;
echo "*/* $(cpuid2cpuflags)" > /etc/portage/package.use/00cpu-flags;

##Updating @world flags##
emerge --verbose --update --deep --newuse @world;

##Setting Timezone##
#edit according to your settings
echo "Europe/Warsaw" > /etc/timezone;
emerge --config sys-libs/timezone-data;

#updating locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen;
locale-gen;
echo -e 'LANG="en_US.UTF-8"\nLC_COLLATE="C.UTF-8"' >> /etc/env.d/02locale;
env-update && source /etc/profile;


##Kernel configuration##
#installing firmware
echo "sys-kernel/linux-firmware compress-zstd" > /etc/portage/package.use/sys-kernel;
emerge sys-kernel/linux-firmware;
emerge sys-firmware/sof-firmware;
emerge sys-firmware/alsa-firmware;
#echo "sys-firmware/intel-microcode hostonly" > /etc/portage/package.use/sys-firmware;
#emerge sys-firmware/intel-microcode;

#installing genkernel optional can be commented out and done manually
#echo "sys-kernel/genkernel firmware" >> /etc/portage/package.use/sys-kernel;
echo "sys-kernel/gentoo-sources experimental" >> /etc/portage/package.use/sys-kernel;
emerge gentoo-sources cryptsetup lvm2;

#configuring fstab file
echo -e "UUID=	  /boot	  vfat	  noatime		0 2\nUUID=	  none	  sw	  defaults	0 0\nUUID=	  /	  btrfs	  defaults	0 1\nUUID=	  /home	  btrfs	  defaults	0 1" >> /etc/fstab;
nano /etc/fstab;
#genkernel method#
cd /usr/src/linux;
#enable LUKS AND LVM
echo "sys-kernel/installkernel uki" >> /etc/portage/package.use/sys-kernel;
emerge sys-kernel/installkernel;
#manual method#
make menuconfig;
make -j3 && make -j3 modules_install;
make install;
emerge sys-kernel/dracut;
echo -e 'compress="zstd"\nadd_dracutmodules+=" crypt lvm dm rootfs-block udev-rules base fs-lib uefi-lib"\nfilesystems+=" btrfs vfat "\nkernel_cmdline+=""' >> /etc/dracut.conf;
dracut --kver 6.8.3-gentoo; 
##installing grub##
echo "sys-boot/grub mount device-mapper" > /etc/portage/package.use/sys-boot;
emerge grub gentoolkit;

grubconfig='GRUB_CMDLINE_LINUX_DEFAULT="cryptdevice=UUID=encrypted_uuid:lvm-system:allowdiscards root=UUID=root_uuid rootfstype=btrfs dolvm quiet resume=UUID=swap_uuid rootdelay=3 net.ifnames=0"';

echo "$grubconfig" >> /etc/default/grub;
echo 'GRUB_ENABLE_CRYPTODISK=y' >> /etc/default/grub;
nano /etc/lvm/lvm.conf;
    #Set: 
    #    allow-discards = 1
    #    devices {
    #    multipath_component_detection = 0
    #    md_component_detection = 0
    #    }
 
    #    activation {
    #    udev_sync = 0
    #    udev_rules = 0
    #    }
nano /etc/default/grub;
grub-install --efi-directory=/boot --bootloader-id=GRUB --recheck;
grub-mkconfig -o /boot/grub/grub.cfg;
nano /boot/grub/grub.cfg;


##Finalization##
#setting password for root
passwd;

#set hostname edit however you want :3
echo Gentoo > /etc/hostname;

#configuring the net
emerge net-misc/dhcpcd;
rc-update add dhcpcd default;
rc-service dhcpcd start;

#here insert the name of your net controller
net=enp4s0;
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
