#!/bin/bash

archroot (){
	echo Setting locale information
	ln -sf /usr/share/zoneinfo/Australia/Sydney /etc/localtime
	timedatectl set-timezone Australia/Sydney
	
	echo Updating repolists and downloading new packages
	pacman -Syu --noconfirm
	pacman -S --noconfirm \
	 xorg plasma base-devel \
	 cifs-utils man-db man-pages alsa-utils ark bitwarden dhclient discord dolphin dolphin-plugins ffmpegthumbs firefox \
	 gimp git gwenview kate kcron kdeconnect kdialog kget kgpg kmousetool knotes kompare konsole krdc kruler ksysguard \
	 ksystemlog ktorrent kwalletmanager kvantum libdbusmenu-glib nano neofetch ntfs-3g okular reflector pulseaudio \
	 pulseaudio-alsa pulseaudio-bluetooth sof-firmware spectacle steam sudo sweeper tk ufw usb_modeswitch usbmuxd \
	 usbutils vkd3d vlc wine wine-gecko wine-mono zeroconf-ioslave zsh zsh-syntax highlighting
	
	echo Adding new user
	useradd -mU -s /usr/bin/zsh -G wheel,uucp,video,audio,storage,games,input "$1"
	chsh -s /usr/bin/zsh
	
	echo Installing AUR helper and packages
	su "$1" -c "cd ~; \
	 git clone https://aur.archlinux.org/yay.git; \
	 cd yay; \
	 makepkg -si --noconfirm; \
	 cd ~; \
	 rm -rf yay; \
	 yay -Syu; \
	 yay -S --noconfirm --needed \
	 nerd-fonts-complete ttf-ms-fonts \
	 firefox-extension-bitwarden ocs-url onlyoffice-bin \
	 pamac-all protontricks snapd soundux visual-studio-code-bin \
	 winetricks zsh-autosuggestions-git zsh-theme-powerlevel10k-git"
	
	echo Changing fingerprint information
	chfn -f "${fullname}" "${username}"
	
	echo Installing bootloader
	mount "$part_boot" /boot/efi
	grub-install --target=x86_64-efi --bootloader-id=Arch --efi-directory=/boot/efi
	grub-mkconfig -o /boot/grub/grub.cfg
}

timedatectl set-ntp true
sed -i "93,94s/^#//" /etc/pacman.conf

pacman -Sy
pacman -S --noconfirm dialog
clear

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

dialog --stdout --backtitle "Arch-Linux Installer" \
--title "Pre-Install Config" \
--yesno "Use the same password for root and $username?" 0 0
duplicate_password=$?

if [ "$duplicate_password" -eq 0 ]; then
	while [ 1 ]
	do
		user_password=$(dialog --stdout --backtitle "Arch-Linux Installer" --title "Password Selection" --insecure --passwordbox "Enter your password" 0 0) || exit 1
		clear
		password_confirm=$(dialog --stdout --backtitle "Arch_Linux Installer" --title "Password Selection" --insecure --passwordbox "Confirm your password" 0 0) || exit 1
		clear
		
		if [[ "$user_password" == "$password_confirm" ]]; then
			root_password=${user_password}
			break
		else
			dialog --stdout --backtitle "Arch-Linux Installer" --msgbox "The passwords did not match. Please try again." 0 0
		fi
	done
elif [ "$duplicate_password" -eq 1 ]; then
	while [ 1 ]
	do
		root_password=$(dialog --stdout --backtitle "Arch-Linux Installer" --title "Password Selection: root" --insecure --passwordbox "Enter the root password" 0 0)|| exit 1
		clear
		password_confirm=$(dialog --stdout --backtitle "Arch-Linux Installer" --title "Confirm Password: root" --insecure --passwordbox "Confirm the password" 0 0)|| exit 1
		clear
		
		if [[ "$root_password" == "$password_confirm" ]]; then
			break
		else
			dialog --stdout --backtitle "Arch-Linux Installer" --msgbox "The passwords did not match. Please try again." 0 0
		fi
	done
	while [ 1 ]
	do
		user_password=$(dialog --stdout --backtitle "Arch-Linux Installer" --title "Password Selection: $username" --insecure --passwordbox "Enter the password for $username" 0 0) || exit 1
		clear
		password_confirm=$(dialog --stdout --backtitle "Arch_Linux Installer" --title "Password Selection: $username" --insecure --passwordbox "Confirm the password" 0 0) || exit 1
		clear
		
		if [[ "$user_password" == "$password_confirm" ]]; then
			break
		else
			dialog --stdout --backtitle "Arch-Linux Installer" --msgbox "The passwords did not match. Please try again." 0 0
		fi
	done
else
	exit 3
fi

device=$(dialog --stdout --backtitle "Arch-Linux Installer" --title "Disk Partitioning" --menu "Select installation disk" 0 0 0 $(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop|sr" | tac)) || exit 1
clear

exec 1> >(tee "stdout.log")
exec 2> >(tee "stderr.log")

dialog --stdout --backtitle "Arch-Linux Installer" \
--title "Disk Partitioning" \
--yesno "Will hibernation be used?" 0 0
hibernation=$?
ram=$(free --giga | awk '/Mem:/ {print $2}')
if [ "$hibernation" -eq 0 ]; then
	swap_space=$(python -c "from math import ceil,sqrt; print(ceil(sqrt($ram)))")
elif [ "$hibernation" -eq 1 ]; then
	swap_space=$(python -c "from math import ceil,sqrt; print($ram+(ceil(sqrt($ram))))")
else
	exit 3
fi

swap_end=$((($swap_space*1000)+501))
root_start=$(($swap_end + 1))

dialog --stdout --backtitle "Arch-Linux Installer" \
--title "Disk Partitioning" \
--colors \
--yesno "\Zb\Z5=== WARNING ===\Zn\nProceeding will format ${device} and erase all data on that drive.\n\nPress Yes to continue, or No to back your data up first." 0 0
confirm_format=$?

if [ "$confirm_format" -eq 0 ]; then
	parted -s "${device}" -- mklabel gpt \
	 mkpart ESP fat32 1 500 \
	 mkpart primary linux-swap 501 ${swap_end} \
	 mkpart primary ext4 ${root_start} 100% \
	 set 1 boot on
 
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

pacstrap /mnt base linux linux-firmware grub efibootmgr amd-ucode
arch-chroot /mnt /bin/bash -c "archroot $username"

genfstab -U /mnt >> /mnt/etc/fstab

echo "LANG=en_GB.UTF-8" > /mnt/etc/locale.conf
echo "${hostname}" > /mnt/etc/hostname
echo "127.0.0.1            localhost" > /mnt/etc/hosts
echo "::1                  localhost" >> /mnt/etc/hosts
echo "127.0.1.1            $hostname" >> /mnt/etc/hosts

echo "$username:$user_password" | chpasswd --root /mnt
echo "root:$root_password" | chpasswd --root /mnt

dialog --stdout --backtitle "Arch-Linux Installer" --title "Installation Complete" --msgbox "Installation complete. Please examine the contents of ~/stdout.log and ~/stderr.log to ensure nothing requires your attention, and then run the command: shutdown -r now" 0 0
