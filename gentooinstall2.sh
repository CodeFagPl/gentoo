#!/bin/bash
disk=sda
boot=sda1
lvm=sda2

source /etc/profile;
export PS1="(chroot) $PS1";
#preparing boot partition
mkdir /efi;
mount /dev/$boot /efi;
#Updating repository
mkdir --parents /etc/portage/repos.conf;
cp /usr/share/portage/config/repos.conf /etc/portage/repos.conf/gentoo.conf;
echo "sync-git-verify-commit-signature = yes" >> /etc/portage/repos.conf/gentoo.conf;
emerge-webrsync;
#adding mirrors
emerge --verbose --oneshot app-portage/mirrorselect;
mirrorselect -i -o >> /etc/portage/make.conf;
emerge --sync;
#Adding cpu flags
emerge app-portage/cpuid2cpuflags;
echo "*/* $(cpuid2cpuflags)" > /etc/portage/package.use/00cpu-flags;
#updating @world flags
emerge --ask --verbose --update --deep --newuse @world;
#Setting Timezone
echo "Europe/Warsaw" > /etc/timezone;
emerge --config sys-libs/timezone-data;
#updating locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen;
locale-gen;
echo -e 'LANG="de_DE.UTF-8"\nLC_COLLATE="C.UTF-8"' >> /etc/env.d/02locale;
env-update && source /etc/profile && export PS1="(chroot) ${PS1}";
#installing firmware
echo "sys-kernel/linux-firmware compress-zstd redistributable" > /etc/portage/package.use/sys-kernel;
emerge sys-kernel/linux-firmware;
echo "sys-firmware/intel-microcode hostonly" > /etc/portage/package.use/sys-firmware;
emerge sys-firmware/intel-microcode;
#installing genkernel optional can be commented out and done manually
echo "sys-kernel/genkernel firmware" >> /etc/portage/package.use/sys-kernel;
emerge gentoo-sources genkernel cryptsetup lvm2;
#configuring fstab file
echo -e "LABEL=SWAP	none	sw	defaults	0 0\nLABEL=BOOT		/efi	vfat	noatime		0 2\nLABEL=ROOT		/	xfs	defaults	0 1\nLABEL=HOME		/home	xfs	defaults	0 1\nLABEL=NODE		/node	xfs	defaults	0 1" >> /etc/fstab;

#genkernel method#
#enable LUKS AND LVM
nano /etc/genkernel.conf;
genkernel --lvm --luks --no-zfs all;

##installing grub##
echo "sys-boot/grub mount device-mapper" > /etc/portage/package.use/sys-boot;
emerge grub gentoolkit;
echo 'GRUB_CMDLINE_LINUX="crypt_root=/dev/${lvm}  root=/dev/lvmSystem/volRoot rootfstype=xfs dolvm quiet"' >> /etc/default/grub;
nano /etc/default/grub;
grub-install --target=x86_64-efi --efi-directory=/efi /dev/$boot;
grub-mkconfig -o /boot/grub/grub.cfg;


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
echo 'config_${net}="dhcp"' >> /etc/conf.d/net;
cd /etc/init.d;
ln -s net.lo net.$net;
rc-update add net.$net default;


##Installing tools##
emerge syslog-ng cronie mlocate;
rc-update add syslog-ng default;
rc-update add cronie default;
rc-update add sshd default;
rc-update add lvm boot;
