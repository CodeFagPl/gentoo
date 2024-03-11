#!/bin/bash
##Parameters##
disk=sda;
boot=sda1;
lvm=sda2;

#continuation from previous file
source /etc/profile;

##Preparing boot partition##
mount /dev/$boot /boot;

##Updating Repository##
mkdir --parents /etc/portage/repos.conf;
cp /usr/share/portage/config/repos.conf /etc/portage/repos.conf/gentoo.conf;
echo "sync-git-verify-commit-signature = yes" >> /etc/portage/repos.conf/gentoo.conf;
emerge-webrsync;

##Adding Mirrors##
emerge --verbose --oneshot app-portage/mirrorselect;
mirrorselect -i -o >> /etc/portage/make.conf;
emerge --sync;

##Adding cpu flags##
emerge app-portage/cpuid2cpuflags;
echo "*/* $(cpuid2cpuflags)" > /etc/portage/package.use/00cpu-flags;

##Updating @world flags##
emerge --ask --verbose --update --deep --newuse @world;

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
echo "sys-kernel/linux-firmware compress-zstd redistributable" > /etc/portage/package.use/sys-kernel;
emerge sys-kernel/linux-firmware;
#echo "sys-firmware/intel-microcode hostonly" > /etc/portage/package.use/sys-firmware;
#emerge sys-firmware/intel-microcode;

#installing genkernel optional can be commented out and done manually
echo "sys-kernel/genkernel firmware" >> /etc/portage/package.use/sys-kernel;
emerge gentoo-sources genkernel cryptsetup lvm2;

#configuring fstab file
echo -e "UUID=	  none	  sw	  defaults	0 0\nUUID=	  /boot	  vfat	  noatime		0 2\nUUID=	  /	  xfs	  defaults	0 1\nUUID=	  /home	  xfs	  defaults	0 1\nUUID=	  /node	  xfs	  defaults	0 1" >> /etc/fstab;

#genkernel method#
cd /usr/src/linux;
#enable LUKS AND LVM
genkernel --install --lvm --luks --microcode all;

#manual method#
#make menuconfig;
#make && make modules_install;
#make install;

##installing grub##
echo "sys-boot/grub mount device-mapper" > /etc/portage/package.use/sys-boot;
emerge grub gentoolkit;

#beg='GRUB_CMDLINE_LINUX="crypt_root=/dev/'"$lvm";
#end=' root=LABEL=ROOT rootfstype=xfs dolvm quiet"';
grubconfig='GRUB_CMDLINE_LINUX_DEFAULT="crypt_root=UUID=uuid dolvm"';

echo "$grubconfig" >> /etc/default/grub;
echo 'GRUB_ENABLE_CRYPTODISK=y' >> /etc/default/grub;

nano /etc/default/grub;
grub-install --efi-directory=/boot --bootloader-id=GRUB --recheck;
grub-mkconfig -o /boot/grub/grub.cfg;
nano /boot/grub/grub.cfg;


##Finalization##
#setting password for root
passwd;

#set hostname edit however you want :3
echo MoneroChan > /etc/hostname;

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
emerge syslog-ng cronie mlocate;
rc-update add syslog-ng default;
rc-update add cronie default;
rc-update add sshd default;
rc-update add lvm boot;
env-update && source /etc/profile;
