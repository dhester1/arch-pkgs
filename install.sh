#!/bin/bash

archroot (){
	username="$1"
	fullname="$2 $3"
	boot_dir="$4"
	
	echo Setting locale information
	timedatectl set-timezone Australia/Sydney
	echo "LANG=en_AU.UTF-8
	LANGUAGE=en_AU:en_GB:en_US" > locale.conf
	sed -i "/en_AU.UTF-8/s/^#//" /etc/locale.gen
	locale-gen
	
	echo Updating repolists and downloading new packages
	sed -i "93,94s/^#//" /etc/pacman.conf
	pacman -Syu --noconfirm
	pacman -S --noconfirm \
	 bluedevil breeze-gtk drkonqi kactivitymanagerd kde-cli-tools kde-gtk-config kdecoration kdeplasma-addons kgamma5 khotkeys \
	 kinfocenter kmenuedit kscreen kscreenlocker ksshaskpass kwallet-pam kwin kwrited libkscreen libksysguard milou \
	 plasma-browser-integration plasma-desktop plasma-disks plasma-firewall plasma-integration plasma-nm plasma-pa \
	 plasma-sdk plasma-systemmonitor plasma-vault plasma-workspace polkit-kde-agent powerdevil sddm-kcm systemsettings \
	 xdg-desktop-portal-kde xorg \
	 base-devel cifs-utils man-db man-pages alsa-utils ark bitwarden dhclient discord dolphin dolphin-plugins ffmpegthumbs firefox \
	 gimp git gwenview kate kcron kdeconnect kdialog kget kgpg kmousetool knotes kompare konsole krdc kruler ksysguard \
	 ksystemlog ktorrent kwalletmanager kvantum libdbusmenu-glib nano neofetch ntfs-3g okular pulseaudio \
	 pulseaudio-alsa pulseaudio-bluetooth sof-firmware spectacle steam sudo sweeper tk ufw usb_modeswitch usbmuxd \
	 usbutils vkd3d vlc wine wine-gecko wine-mono zeroconf-ioslave zsh	
	
	echo Adding new user
	useradd -mU -s /usr/bin/zsh -G wheel,uucp,video,audio,storage,games,input "$username"
	chsh -s /usr/bin/zsh
	echo "$username ALL=(ALL:ALL) NOPASSWD: ALL" | EDITOR="tee -a" visudo
	
	echo Enabling KDE
	systemctl enable sddm
	systemctl enable NetworkManager
	
	echo Installing AUR helper and packages
	su "$username" -c "cd ~; \
	 git clone https://aur.archlinux.org/yay.git; \
	 cd yay; \
	 makepkg -si --noconfirm; \
	 cd ~; \
	 rm -rf yay; \
	 yay -Syu; \
	 yay -S --noconfirm \
	 nerd-fonts-complete ttf-ms-fonts \
	 authy bottles firefox-extension-bitwarden ocs-url onlyoffice-bin \
	 pamac-aur protontricks soundux visual-studio-code-bin winetricks; \
	 (curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh) | sh; \
	 git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions; \
	 git clone https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting; \
	 git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k; "
	 
	curl -o skel.tar.gz https://filedn.com/lQ8zQmQjsI6Xso40sDFKgff/skel.tar.gz
	tar -xf skel.tar.gz -C /home/${username}/
	
	echo Changing fingerprint information
	chfn -f "$fullname" "$username"
	
	echo Installing bootloader
	mount "$boot_dir" /boot/efi
	grub-install --target=x86_64-efi --bootloader-id=Arch --efi-directory=/boot/efi
	grub-mkconfig -o /boot/grub/grub.cfg
}

timedatectl set-ntp true
sed -i "93,94s/^#//" /etc/pacman.conf

pacman -Sy
pacman -S --noconfirm dialog
clear

while [ 1 ]
do
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
	clear
	
	if [ "$duplicate_password" -eq 0 ]; then
		password_type="root and $username have the same password."
	else
		password_type="root and $username have different passwords."
	fi
	
	dialog --stdout --backtitle "Arch-Linux Installer"\
	--title "Confirm Choices" \
	--yesno "Are the following details correct?\nComputer Name: ${hostname}\nFull Name: ${fullname}\nUsername: ${username}\nPasswords: ${password_type}" 0 0
	valid_choices=$?
	clear
	
	if [ "$valid_choices" -eq 0 ]; then
		break
	fi
done

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
			clear
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
			clear
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
			clear
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
clear

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
--yesno "\Zb\Z1=== WARNING ===\Zn\nProceeding will format ${device} and erase all data on that drive.\n\nPress Yes to continue, or No to back your data up first." 0 0
confirm_format=$?
clear

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
	clear
else
	exit 1
fi

pacstrap /mnt base linux linux-firmware grub efibootmgr amd-ucode reflector
systemctl start reflector
clear

export -f archroot
arch-chroot /mnt /bin/bash -c "archroot $username ${fullname} $part_boot"
clear

genfstab -U /mnt >> /mnt/etc/fstab

echo "${hostname}" > /mnt/etc/hostname
echo "127.0.0.1            localhost" > /mnt/etc/hosts
echo "::1                  localhost" >> /mnt/etc/hosts
echo "127.0.1.1            $hostname" >> /mnt/etc/hosts

mkdir -p /mnt/usr/share/wallpapers/Custom/SDDM
mkdir -p /mnt/usr/local/share/fonts

curl https://raw.githubusercontent.com/dhester1/arch-pkgs/main/fonts/MesloLGS%20NF%20Bold%20Italic.ttf -o /mnt/usr/local/share/fonts/MesloLGS\ NF\ Bold\ Italic.ttf
curl https://raw.githubusercontent.com/dhester1/arch-pkgs/main/fonts/MesloLGS%20NF%20Bold.ttf -o /mnt/usr/local/share/fonts/MesloLGS\ NF\ Bold.ttf
curl https://raw.githubusercontent.com/dhester1/arch-pkgs/main/fonts/MesloLGS%20NF%20Italic.ttf -o /mnt/usr/local/share/fonts/MesloLGS\ NF\ Italic.ttf
curl https://raw.githubusercontent.com/dhester1/arch-pkgs/main/fonts/MesloLGS%20NF%20Regular.ttf -o /mnt/usr/local/share/fonts/MesloLGS\ NF\ Regular.ttf

curl https://raw.githubusercontent.com/dhester1/arch-pkgs/main/wallpapers/sddm/sddm1.png -o /mnt/usr/share/wallpapers/Custom/SDDM/sddm1.png
curl https://raw.githubusercontent.com/dhester1/arch-pkgs/main/wallpapers/sddm/sddm2.png -o /mnt/usr/share/wallpapers/Custom/SDDM/sddm2.png
curl https://raw.githubusercontent.com/dhester1/arch-pkgs/main/wallpapers/wall1.jpg -o /mnt/usr/share/wallpapers/Custom/wall1.jpg
curl https://raw.githubusercontent.com/dhester1/arch-pkgs/main/wallpapers/wall2.jpg -o /mnt/usr/share/wallpapers/Custom/wall2.jpg
curl https://raw.githubusercontent.com/dhester1/arch-pkgs/main/wallpapers/wall3.jpg -o /mnt/usr/share/wallpapers/Custom/wall3.png
curl https://raw.githubusercontent.com/dhester1/arch-pkgs/main/wallpapers/wall4.jpg -o /mnt/usr/share/wallpapers/Custom/wall4.jpg
curl https://raw.githubusercontent.com/dhester1/arch-pkgs/main/wallpapers/wall5.jpg -o /mnt/usr/share/wallpapers/Custom/wall5.png
curl https://raw.githubusercontent.com/dhester1/arch-pkgs/main/wallpapers/wall6.jpg -o /mnt/usr/share/wallpapers/Custom/wall6.png
curl https://raw.githubusercontent.com/dhester1/arch-pkgs/main/wallpapers/wall7.jpg -o /mnt/usr/share/wallpapers/Custom/wall7.jpg
curl https://raw.githubusercontent.com/dhester1/arch-pkgs/main/wallpapers/wall8.jpg -o /mnt/usr/share/wallpapers/Custom/wall8.jpg
curl https://raw.githubusercontent.com/dhester1/arch-pkgs/main/wallpapers/wall9.jpg -o /mnt/usr/share/wallpapers/Custom/wall9.jpg
curl https://raw.githubusercontent.com/dhester1/arch-pkgs/main/wallpapers/wall10.jpg -o /mnt/usr/share/wallpapers/Custom/wall10.jpg
curl https://raw.githubusercontent.com/dhester1/arch-pkgs/main/wallpapers/wall11.jpg -o /mnt/usr/share/wallpapers/Custom/wall11.png

echo "$username:$user_password" | chpasswd --root /mnt
echo "root:$root_password" | chpasswd --root /mnt

dialog --stdout --backtitle "Arch-Linux Installer" --title "Installation Complete" --msgbox "Installation complete.\nPlease examine the contents of stdout.log and stderr.log to ensure nothing requires your attention\n\nPlease run the command: \"shutdown -r now\" to boot into your new system." 0 0
clear
