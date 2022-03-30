#!/bin/bash

timedatectl set-ntp true
sed -i "93,94s/^#//" /etc/pacman.conf

pacman -Sy
pacman -S --noconfirm dialog
clear

packageServer=$(dialog --stdout --backtitle "Arch-Linux Installer" --title "Pre-Install Config" --inputbox "What is the IP address of the package server?" 0 0) || exit 1
clear
: ${packageServer:?"IP address must be provided."}
echo "$packageServer            package-server.localdomain" >> /etc/hosts

hostname=$(dialog --stdout --backtitle "Arch-Linux Installer" --title "Pre-Install Config" --inputbox "Enter this machine's hostname" 0 0) || exit 1
clear
: ${hostname:?"Hostname cannot be empty."}

fullname=$(dialog --stdout --backtitle "Arch-Linux Installer" --title "Pre-Install Config" --inputbox "What is your full name?" 0 0) || exit 1
clear
: ${fullname:?"Name cannot be empty."}

username=$(dialog --stdout --backtitle "Arch-Linux Installer" --title "Pre-Install Config" --inputbox "Enter your username" 0 0) || exit 1
clear
: ${username:?"Username cannot be empty."}

user_password=""
root_password=""
duplicate_password=$(dialog --stdout --backtitle "Arch-Linux Installer" --title "Pre-Install Config" --yesno "Use the same password for root and $username?" 0 0)
if [$duplicate_password -eq 0]; then
	while [ 1 ]
	do
		user_password=$(dialog --stdout --backtitle "Arch-Linux Installer" --title "Password Selection" --passwordbox "Enter your password" 0 0) || exit 1
		password_confirm=$(dialog --stdout --backtitle "Arch_Linux Installer" --title "Password Selection" --passwordbox "Confirm your password" 0 0) || exit 1
		
		if [[ "$user_password" == "$password_confirm" ]]; then
			root_password=${user_password}
			break
		else
			dialog --stdtout --backtitle "Arch-Linux Installer" --msgbox "The passwords did not match. Please try again." 0 0
		fi
	done
elif [$duplicate_password -eq 1]; then
	while [ 1 ]
	do
		root_password=$(dialog --stdout --backtitle "Arch-Linux Installer" --title "Password Selection: root" --passwordbox "Enter the root password" 0 0)|| exit 1
		password_confirm=$(dialog --stdout --backtitle "Arch-Linux Installer" --title "Confirm Password: root" --passwordbox "Confirm the password" 0 0)|| exit 1

		if [[ "$root_password" == "$password_confirm" ]]; then
			break
		else
			dialog --stdtout --backtitle "Arch-Linux Installer" --msgbox "The passwords did not match. Please try again." 0 0
		fi
	done
	while [ 1 ]
	do
		user_password=$(dialog --stdout --backtitle "Arch-Linux Installer" --title "Password Selection: $username" --passwordbox "Enter the password for $username" 0 0) || exit 1
		password_confirm=$(dialog --stdout --backtitle "Arch_Linux Installer" --title "Password Selection: $username" --passwordbox "Confirm the password" 0 0) || exit 1
		
		if [[ "$user_password" == "$password_confirm" ]]; then
			break
		else
			dialog --stdtout --backtitle "Arch-Linux Installer" --msgbox "The passwords did not match. Please try again." 0 0
		fi
	done
else
	exit 1
fi

device=$(dialog --stdout --backtitle "Arch-Linux Installer" --title "Disk Partitioning" --menu "Select installation disk" 0 0 0 $(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop|sr" | tac)) || exit 1
clear

exec 1> >(tee "stdout.log")
exec 2> >(tee "stderr.log")

ram=$(free --giga | awk '/Mem:/ {print $2}')
hibernation=$(dialog --stdout --backtitle "Arch-Linux Installer" --title "Disk Partitioning" --yesno "Will hibernation be used?" 0 0) || exit 1
if [ $hibernation -eq 0 ]; then
	swap_space=$((int(ceil(sqrt($ram)))))
elif [ $hibernation -eq 1 ]; then
	swap_space=$(($ram + int(ceil(sqrt($ram)))))
else
	exit 1
fi
clear

swap_space=$((int(ceil($swap_space * 953.67431640625))))
swap_end=$(($swap_space+500+1))MiB

confirm_format=$(dialog --stdout --backtitle "Arch-Linux Installer" --title "Disk Partitioning" --yesno "$device will be formatted as GPT\n\nPartition 1:    EFI System    500 MiB\nPartition 2:    Linux swap    $swap_space MiB\nPartition 3:    ext4          Remaining\n\nContinue?\nWARNING: Selecting yes will partition the entire disk, erasing all data on it. Backup your data before proceeding."
clear

if [ $confirm_format -eq 0 ]; then
	gdisk "$device"
	
	parted --script "$device" --mklabel gpt \ 
	mkpart ESP fat32 1Mib 500MiB \
	set 1 boot on \
	mkpart primary linux-swap 500MiB ${swap_end} \
	mkpart primary ext4 ${swap_end} 100%

	part_boot="$(ls ${device}* | grep -E "^${device}p?1$")"
	part_swap="$(ls ${device}* | grep -E "^${device}p?2$")"
	part_root="$(ls ${device}* | grep -E "^${device}p?3$")"
	
	wipefs "$part_boot"
	wipefs "$part_swap"
	wipefs "$part_root"
	
	mkfs.vfat -F32 "$part_boot"
	mkswap "$part_swap"
	swapon "$part_swap"
	mkfs.ext4 "$part_root"
	
	mount "$part_root" /mnt
	mkdir -p /mnt/boot/efi
	mount "$part_boot" /mnt/boot/efi
else
	exit 1
fi

cat >> /etc/pacman.conf <<EOF
[dhester-base]
SigLevel = Optional TrustAll
Server = http://package-server.localdomain/dhester-base/
EOF

pacstrap /mnt dhester-base
genfstab -U /mnt >> /mnt/etc/fstab

echo "LANG=en_GB.UTF-8" > /mnt/etc/locale.conf
echo "${hostname}" > /mnt/etc/hostname
echo "127.0.0.1            localhost" > /mnt/etc/hosts
echo "::1                  localhost" >> /mnt/etc/hosts
echo "127.0.1.1            $hostname" >> /mnt/etc/hosts

arch-chroot /mnt ln -sf /usr/share/zoneinfo/Australia/Sydney /etc/localtime
arch-chroot /mnt timedatectl set-timezone Australia/Sydney
arch-chroot /mnt useradd -mU -s /usr/bin/zsh -G wheel,uucp,video,audio,storage,games,input "$username"
arch-chroot /mnt chsh -s /usr/bin/zsh
arch-chroot /mnt chfn -f "${fullname}" "${username}"
arch-chroot /mnt mount "$part_boot" /boot/efi
arch-chroot /mnt grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

echo "$username:$user_password" | chpasswd --root /mnt
echo "root:$root_password" | chpasswd --root /mnt
