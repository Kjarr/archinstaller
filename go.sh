#! /bin/bash
# ROOT PERMISSIONS REQUIRED - DUH
# 
# If someone linked you to this script as a way to install Arch - better think twice.
# This script is not extremely user friendly - a relatively easy mistake can format your drive.
# It's also heavily personalized, so it may do something you do not want.

# To use this, simply boot the latest Arch ISO and run 
# wget https://gitlab.com/C0rn3j/C0rn3j/raw/master/Arch-install-script.sh && chmod +x Arch-install-script.sh && ./Arch-install-script.sh

# STRICT MODE
# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
if [[ -e /var/lib/pacman/db.lck ]]; then
	echo "Pacman lockfile detected, make sure nothing is using pacman, exiting."
	exit 1
fi

# File: `curl https://ptpb.pw -F c=@PATH_TO_FILE`. Output: `COMMAND | curl https://ptpb.pw -F c=@-`.
if [[ -z ${1-} ]]; then
	# Set NTP to true so we get correct time and script doesn't fuck up on TLS errors
	timedatectl set-ntp true
	# If previous install fucked up umount the partitions, but first check if they're actually mounted.
	if mountpoint -q "/mnt"; then
		umount -l /mnt
	fi
	if mountpoint -q "/mnt/boot"; then
		umount -l /mnt/boot
	fi
	clear; lsblk
	echo "Select the drive you want to install Linux on e.g. \"sda\" or \"sdb\" without the quotes."
	read drive; clear
	# Check if system is booted via BIOS or UEFI mode
	if [[ -d /sys/firmware/efi/efivars/ ]]; then # Checks if folder exists
		ISEFI=1
	else 
		ISEFI=0
	fi
	if grep Intel /proc/cpuinfo; then # if Intel string was found
		IntelCPU=1
	else
		IntelCPU=0
	fi
	clear
	if [[ $ISEFI = 0 ]]; then
		echo -e "This computer is booted in BIOS mode. You likely have UEFI with Legacy Mode enabled, enable UEFI booting if this is the case.\nIf this is correct press ENTER to continue."
	else
		echo -e "This computer is booted in UEFI mode, this is normal, but make sure your UEFI is up to date. Look up your motherboard vendor page, it's likely going to be incorrectly under \"BIOS\".\nPress ENTER to continue."
	fi
	read; clear

	echo "How would you like to name this computer?"
	read hostname; clear
	echo "What password should the root(administrator) account have?"
	read rootpassword; clear
	echo "What username do you want? Linux only allows lower case letters and numbers by default."
	read username; clear
	echo "What password should your user have? (It is bad practice to use the root account for daily use, and some graphical programs will refuse to work under it or they'll be broken)"
	read userpassword; clear
	timezone=$(tzselect); clear
	echo "Do you want to install a Desktop Environment and GUI tools+apps? This is required if you want a graphical interface(This script uses Cinnamon). You can of course install some other DE later."
	select yn in "Yes" "No"; do
		case $yn in
			Yes ) answerDE="yes"; break;;
			No ) answerDE="no"; break;;
		esac
	done
	clear
	echo "Do you want to set up autologin into your user account and autostart X?"
	select yn in "Yes" "No"; do
		case $yn in
			Yes ) answerGetty="yes"; break;;
			No ) answerGetty="no"; break;;
		esac
	done
	clear
	if lspci | grep NVIDIA >/dev/null; then 
		echo "Do you want to install latest Nvidia proprietary drivers? (You definitely want this if this is a desktop with an Nvidia card that's not ultra-old)"
		select yn in "Yes" "No"; do
			case $yn in
				Yes ) answerNVIDIA="yes"; break;;
				No ) answerNVIDIA="no"; break;;
			esac
		done
		clear
	else
		answerNVIDIA="no"; # No Nvidia card detected, setting no to satisfy strict mode.
	fi
	if lspci | grep Radeon >/dev/null; then 
		echo "Do you want to install the AMDGPU driver? (You definitely want this if this is a desktop with an AMD card that's not ultra-old)"
		select yn in "Yes" "No"; do
			case $yn in
				Yes ) answerAMD="yes"; break;;
				No ) answerAMD="no"; break;;
			esac
		done
		clear
	else
		answerAMD="no"; # No AMD card detected, setting no to satisfy strict mode.
	fi
	if [[ $IntelCPU == 1 ]]; then # No point in asking with an AMD CPU
		echo "Do you want to install the xf86-video-intel driver? This is only useful if you have a laptop/desktop Intel CPU with integrated GPU and you know the modesetting(4) driver is not good for your usage."
		select yn in "Yes" "No"; do
			case $yn in
				Yes ) answerINTEL="yes"; break;;
				No ) answerINTEL="no"; break;;
			esac
		done
		clear
	else
		answerINTEL="no"; # No intel CPU detected, setting no to satisfy strict mode.
	fi

	# BIOS BLOCK
	if [[ $ISEFI = 0 ]]; then
		ESPpartition="none"
		ROOTpartition="none" # So they don't end up missing on the declare line
		echo "Do you want to select an already created partition? If you choose not to do so, the drive $drive will be wiped(drive, NOT partition!!) and used for this Arch installation. If you select no your whole drive WILL BE WIPED!!"
		select yn in "Yes" "No"; do
			case $yn in
				Yes ) answer="yes"; break;;
				No ) answer="no"; break;;
			esac
		done
		clear
		if [[ $answer = "yes" ]]; then
			lsblk
			echo; echo "Which partition should be used? e.g. \"sda3\""
			read partition
			mkfs.ext4 /dev/$partition
			mount /dev/$partition /mnt
		else
			parted -s /dev/$drive mklabel msdos
			parted -s /dev/$drive mkpart primary ext4 1MiB 100%
			parted -s /dev/$drive set 1 boot on
			mkfs.ext4 /dev/${drive}1
			mount /dev/${drive}1 /mnt
		fi
	fi

	# UEFI BLOCK
	if [[ $ISEFI = 1 ]]; then
		clear; echo "Do you want to select already created partitions(ESP+data)? If you choose not to do so, the drive $drive will be wiped(drive, NOT partition!!) and used for this Arch installation. If you select no your whole drive WILL BE WIPED!!"
		select yn in "Yes" "No"; do
			case $yn in
				Yes ) answer="yes"; break;;
				No ) answer="no"; break;;
			esac
		done
		if [[ $answer = "yes" ]]; then
			lsblk
			echo;	echo "Which partition should be used for root(data partition)? e.g. \"sda2\""
			read ROOTpartition; clear
			mkfs.ext4 /dev/${ROOTpartition}
			mount /dev/${ROOTpartition} /mnt
			lsblk
			echo "Which ESP(EFI) partition should be used? e.g. \"sda1\""
			read ESPpartition; clear
			mkdir -p /mnt/boot
			mount /dev/$ESPpartition /mnt/boot
			clear
		else # Wipe drive and create partitions anew
			# If the drive is NVMe the naming scheme differs from traditional sda naming
			if echo $drive | grep "nvme"; then
				Part1Name="p1"
				Part2Name="p2"
			else
				Part1Name="1"
				Part2Name="2"
			fi

			parted -s /dev/$drive mklabel gpt
			parted -s /dev/$drive mkpart ESP fat32 1MiB 513MiB
			parted -s /dev/$drive set 1 boot on
			parted -s /dev/$drive mkpart primary ext4 513MiB 100%
			mkfs.ext4 /dev/${drive}$Part2Name
			mkfs.fat -F32 /dev/${drive}$Part1Name
			mount /dev/${drive}$Part2Name /mnt
			mkdir -p /mnt/boot
			mount /dev/${drive}$Part1Name /mnt/boot
			ESPpartition=${drive}$Part1Name
			ROOTpartition=${drive}$Part2Name
		fi
	fi

	# Delete old vmlinuz files in case there's an install already from a previous time
	if [[ -e /mnt/boot/vmlinuz-linux ]]; then
		rm -f /mnt/boot/vmlinuz-linux
	fi
	if [[ -e /mnt/boot/vmlinuz-linux-hardened ]]; then
		rm -f /mnt/boot/vmlinuz-linux-hardened
	fi

	# MAIN BLOCK
	# Hacky way to get reflector in the ISO
	pacman -Sy reflector --noconfirm
	# Rank mirrors so the install doesn't take 2 hours(unless you live in Australia)
	# Switch to reflector in the future #TODO
	echo "Ranking mirrors... this can take a few minutes"
	reflector --sort rate --save /etc/pacman.d/mirrorlist

	# HEADLESS PACKAGES
	HeadlessPKG="bat bind-tools bmon bridge-utils certbot dmidecode git htop irssi linux-hardened linux-hardened-headers linux-headers lshw mc mlocate ncdu neofetch networkmanager \
openssh p7zip pacman-contrib php python-virtualenv python-pip reflector rsync sane screen strace tcpdump testdisk tmux pwgen unrar unzip vim wget zsh zsh-autosuggestions"
	# WI-FI SUPPORT
	WifiPKG="iw wpa_supplicant dialog"

	# Install base system
	pacstrap /mnt base base-devel $HeadlessPKG $WifiPKG
	# --noconfirm is the default, -i reverts it; - takes input from stdin.
	cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
	genfstab -U /mnt > /mnt/etc/fstab
	cp $BASH_SOURCE /mnt/root

	declare -p hostname rootpassword username userpassword timezone answerGetty ISEFI drive answerDE ESPpartition ROOTpartition answerAMD answerNVIDIA answerINTEL IntelCPU > /mnt/root/answerfile

	arch-chroot /mnt /bin/bash -c "/root/$(basename $BASH_SOURCE) letsgo" # letsgo is there only to make the script know to run the secondary part, it can be any string.
else # We're in chroot. $1 is only set after chrooting
	# Source answers
	source /root/answerfile

	# Create a hook for reflector triggered on pacman mirror file upgrade
	# Reflector grabs a new list on its own, ignoring the .pacnew, and then just deletes the .pacnew file
	mkdir -p /etc/pacman.d/hooks
	cat > /etc/pacman.d/hooks/mirrorupgrade.hook << EOF
[Trigger]
Operation = Upgrade
Type = Package
Target = pacman-mirrorlist

[Action]
Description = Updating pacman-mirrorlist with reflector and removing pacnew, this can take a few minutes...
When = PostTransaction
Depends = reflector
Exec = /bin/bash -c "reflector --sort rate --save /etc/pacman.d/mirrorlist; rm -f /etc/pacman.d/mirrorlist.pacnew"
EOF

	# Install and enable pacserve. It'll share its cache on LAN and will also make pacman download from cache of LAN devices first
	echo "[xyne-x86_64]" >> /etc/pacman.conf
	echo "Server = https://xyne.archlinux.ca/repos/xyne" >> /etc/pacman.conf
	pacman -Syu pacserve --noconfirm
	pacman.conf-insert_pacserve > /tmp/newpac; cat /tmp/newpac > /etc/pacman.conf
	systemctl enable pacserve

	# Use NetworkManager as a network manager
	systemctl enable NetworkManager

	# Fully enables SysRq
	echo "kernel.sysrq=1" > /etc/sysctl.d/c0rn3j.conf
	# For VSC building
	mkdir /etc/systemd/system.conf.d
	cat > /etc/systemd/system.conf.d/limits.conf << EOF
[Manager]
DefaultLimitNOFILE=32768
DefaultTasksMax=32768
EOF
	if [[ $IntelCPU -eq 1 ]]; then # Install Intel microcode if Intel CPU was detected. AMD does not need any special treatment as it has microcode in linux-firmware.
		pacman -Syu intel-ucode --noconfirm --force # Force in case ucode was previously already installed
	fi
	echo "Assuming you want English language..."
	echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
	locale-gen
	echo "LANG=en_US.UTF-8" > /etc/locale.conf; clear
	ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
	hwclock --systohc --utc
	echo $hostname > /etc/hostname
	echo "root:$rootpassword" | chpasswd

	# Add regular user. uucp and lock are there for arduino development.
	useradd -m -G wheel,uucp,lock,wireshark -s /bin/zsh $username
	echo "$username:$userpassword" | chpasswd
	echo "$username ALL=(ALL) ALL" >> /etc/sudoers
	# No need to enter password when using sudo pacman/trizen/paccache
	echo "$username ALL = NOPASSWD: /usr/bin/trizen, /usr/bin/pacman, /usr/bin/paccache" >> /etc/sudoers

	# Enable multilib #TODO oneliner
	cp /etc/pacman.conf /etc/pacman.confbackup
	perl -0pe 's/#\[multilib]\n#/[multilib]\n/' /etc/pacman.confbackup > /etc/pacman.conf
	rm /etc/pacman.confbackup
	#sed -i s/"#\[multilib\]\\n#"/"\[multilib\]\n"/g /etc/pacman.conf

	# Make pacman/trizen output better - colorize, show verbose package lists and show total amount downloaded instead of per package
	# Also add pacman-game-like progress bar
	sed -i s/#Color/Color/g /etc/pacman.conf
	sed -i s/#TotalDownload/TotalDownload/g /etc/pacman.conf
	sed -i s/#VerbosePkgLists/VerbosePkgLists\\nILoveCandy/g /etc/pacman.conf

	# UEFI BLOCK
	if [[ $ISEFI = 1 ]]; then
		# Using systemd-boot
		bootctl install
		echo "default arch" > /boot/loader/loader.conf
		echo "timeout 5" >> /boot/loader/loader.conf
		echo "editor 0" >> /boot/loader/loader.conf

		echo "title Arch Linux" > /boot/loader/entries/arch.conf
		echo "linux /vmlinuz-linux" >> /boot/loader/entries/arch.conf
		if [[ $IntelCPU -eq 1 ]]; then
			echo "initrd /intel-ucode.img" >> /boot/loader/entries/arch.conf
		fi
		echo "initrd /initramfs-linux.img" >> /boot/loader/entries/arch.conf
		echo "options root=PARTUUID=$(blkid -s PARTUUID -o value /dev/${ROOTpartition}) rw" >> /boot/loader/entries/arch.conf

		echo "title Arch Linux Hardened" > /boot/loader/entries/arch-hardened.conf
		echo "linux /vmlinuz-linux-hardened" >> /boot/loader/entries/arch-hardened.conf
		if [[ $IntelCPU -eq 1 ]]; then
			echo "initrd /intel-ucode.img" >> /boot/loader/entries/arch-hardened.conf
		fi
		echo "initrd /initramfs-linux-hardened.img" >> /boot/loader/entries/arch-hardened.conf
		echo "options root=PARTUUID=$(blkid -s PARTUUID -o value /dev/${ROOTpartition}) rw" >> /boot/loader/entries/arch-hardened.conf
	fi

	# BIOS BLOCK
	if [[ $ISEFI = 0 ]]; then
		pacman -Syu grub os-prober --noconfirm
		grub-install --target=i386-pc /dev/$drive
		grub-mkconfig -o /boot/grub/grub.cfg
	fi

	# Set makeflags to number of threads - speeds up compiling PKGBUILDs
	sed -i s/"\#MAKEFLAGS=\"-j2\""/"MAKEFLAGS=\"-j\$(nproc)\""/g /etc/makepkg.conf

	# Set journal size to max 200M, prevents having up to 4GiB journal
	# sudo journalctl --disk-usage # Get current usage
	mkdir -p /etc/systemd/journald.conf.d/
	echo "[Journal]" > /etc/systemd/journald.conf.d/00-journal-size.conf
	echo "SystemMaxUse=200M" >> /etc/systemd/journald.conf.d/00-journal-size.conf

	# Install trizen (AUR helper)
	cd /tmp
	pacman -Syu pacutils perl-libwww perl-term-ui perl-json perl-data-dump perl-lwp-protocol-https perl-term-readline-gnu --noconfirm
	wget https://aur.archlinux.org/cgit/aur.git/snapshot/trizen.tar.gz
	gunzip trizen.tar.gz; tar xvf trizen.tar; cd trizen
	chown $username:$username ./ -R
	sudo -u $username makepkg
	pacman -U *.tar.xz --noconfirm
	
	# Setup Oh-my-zsh
	wget https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -O - | zsh #Install for root
	# Set theme to mortalscumbag
	sed -i s/robbyrussell/"mortalscumbag"/g /root/.zshrc
	# Install Oh-my-zsh for the regular user
	cp -r /root/.oh-my-zsh /home/$username/.oh-my-zsh
	echo "source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" >> /root/.zshrc
	cp /root/.zshrc /home/$username/.zshrc
	chown $username:$username -R /home/$username/.oh-my-zsh
	chown $username:$username /home/$username/.zshrc
	sed -i s/root/"home\/$username"/g /home/$username/.zshrc
	# Enable automatic updates of oh-my-zsh
	sed -i 's/source\ \$ZSH/DISABLE_UPDATE_PROMPT=true\nsource \$ZSH/' /root/.zshrc
	sed -i 's/source\ \$ZSH/DISABLE_UPDATE_PROMPT=true\nsource \$ZSH/' /home/$username/.zshrc

	if [[ $username == "c0rn3j" ]]; then # If it's my own install enable my SSH key and bunch of other stuff
		systemctl enable sshd
		mkdir -p /home/c0rn3j/.ssh
		mkdir -p /root/.ssh
		echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN0UrYQJE+udiy4LldhUIzfuaKM6F3wBUV/CjQwMaksF c0rn3j@c0rn3jDesktop" > /home/c0rn3j/.ssh/authorized_keys
		echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN0UrYQJE+udiy4LldhUIzfuaKM6F3wBUV/CjQwMaksF c0rn3j@c0rn3jDesktop" > /root/.ssh/authorized_keys
		sed -i 's/#PasswordAuthentication yes/PasswordAuthentication\ no/g' /etc/ssh/sshd_config # Turn off insecure SSH login via passwords
		chown -R c0rn3j:c0rn3j /home/c0rn3j/.ssh
		sudo -u c0rn3j git config --global user.email "spleefer90@gmail.com"
		sudo -u c0rn3j git config --global user.name "C0rn3j"
		echo "export GOPATH=/home/c0rn3j/Golang" >> /home/c0rn3j/.zshrc
	fi

	# Add some aliases and set some variables
	echo "alias nano=\"nano -wSPc\"" >> /home/$username/.zshrc # -w disable retarded line breaks that break config files, ;-S scroll one line at a time; -P open files at last edited position; -c Constantly display the cursor position
	echo "alias clearcaches=\"sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches\"" >> /home/$username/.zshrc
	echo "alias htop=\"htop -d3\"" >> /home/$username/.zshrc # I prefer faster refreshing
	echo "alias trizen='sudo paccache -rk 2 && trizen'" >> /home/$username/.zshrc # Only keep last two versions of a package on update
	# set default g++ flags to be strict
	echo "alias g++='g++ -pedantic -Wall -Wextra -Wcast-align -Wcast-qual -Wctor-dtor-privacy -Wdisabled-optimization -Wformat=2 -Winit-self -Wlogical-op -Wmissing-declarations -Wmissing-include-dirs -Wnoexcept -Wold-style-cast -Woverloaded-virtual -Wredundant-decls -Wshadow -Wsign-conversion -Wsign-promo -Wstrict-null-sentinel -Wstrict-overflow=5 -Wswitch-default -Wundef -Werror -Wno-unused -Og'" >> /home/$username/.zshrc

	echo "export EDITOR=nano" >> /home/$username/.zshrc
	echo "export VISUAL=nano" >> /home/$username/.zshrc
	# Bat is a prettier cat with syntax highlighting and more
	echo "alias cat='bat'" >> /home/$username/.zshrc


	if [[ $answerGetty == "yes" ]]; then
		# Enable autologin on tty1
		mkdir -p /etc/systemd/system/getty@tty1.service.d
		echo "[Service]" > /etc/systemd/system/getty@tty1.service.d/override.conf
		echo "ExecStart=" >> /etc/systemd/system/getty@tty1.service.d/override.conf
		echo "ExecStart=-/usr/bin/agetty --autologin $username -s %I 115200,38400,9600 vt102" >> /etc/systemd/system/getty@tty1.service.d/override.conf
		# Autostart X
		echo 'if [ -z "$DISPLAY" ] && [ -n "$XDG_VTNR" ] && [ "$XDG_VTNR" -eq 1 ]; then' >> /home/$username/.zshrc
		echo '	exec startx' >> /home/$username/.zshrc
		echo 'fi' >> /home/$username/.zshrc
	fi

	# Install Nvidia proprietary drivers
	if [[ $answerNVIDIA = "yes" ]]; then
		pacman -Syu nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings opencl-nvidia --noconfirm
	fi

	# Install AMDGPU driver
	if [[ $answerAMD = "yes" ]]; then
		pacman -Syu mesa lib32-mesa xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon libva-mesa-driver lib32-libva-mesa-driver libva-vdpau-driver mesa-vdpau lib32-mesa-vdpau --noconfirm
	fi

	# Install xf86 Intel drivers
	if [[ $answerINTEL = "yes" ]]; then
		pacman -Syu xf86-video-intel --noconfirm
	fi

	# Set up clipboard sharing if this is a KVM VM
	if [[ $(systemd-detect-virt) == "kvm" ]]; then
		pacman -Syu spice-vdagent --noconfirm
		systemctl enable spice-vdagentd
	fi

	# Create archfinish.sh - script meant to be executed on first boot
	echo "#!/bin/bash" > /home/$username/archfinish.sh
	# Enable NTP time syncing
	echo "sudo timedatectl set-ntp true" >> /home/$username/archfinish.sh
	chown $username:$username /home/$username/archfinish.sh
	chmod +x /home/$username/archfinish.sh

	if [[ $answerDE = "yes" ]]; then
		pacman -Syu xorg xorg-xinit cinnamon --noconfirm
		echo "exec cinnamon-session" > /home/$username/.xinitrc

		# Download my favorite Cinnamon theme
		mkdir /home/$username/.themes
		chown $username:$username /home/$username/.themes
		cd /home/$username/.themes
		wget https://cinnamon-spices.linuxmint.com/files/themes/New-Minty.zip
		unzip New-Minty.zip
		rm -f New-Minty.zip

		# PERSONAL BLOAT SETUP
		pacman -Syu aircrack-ng android-tools android-udev arch-install-scripts btrfs-progs calibre code chromium deadbeef dnsmasq dosfstools fcron \
			fdupes file-roller firefox flameshot flite gedit gimp glances gnome-calculator gnome-disk-utility libgnome-keyring gnome-keyring gnome-terminal go gparted icedtea-web iotop iptables jre8-openjdk kdeconnect \
			keepassxc krita lib32-mpg123 libreoffice-fresh macchanger nautilus nfs-utils nmon nomacs ntfs-3g obs-studio ovmf pavucontrol python2-nautilus \
			lib32-wavpack qbittorrent qemu pysolfc redshift rfkill riot-desktop shellcheck smartmontools smplayer sshfs steam steam-native-runtime telegram-desktop ttf-dejavu ttf-liberation \
			virt-manager wine_gecko wine-mono wine-staging winetricks wireshark-qt wol x11-ssh-askpass xclip xterm youtube-dl \
			nmap noto-fonts noto-fonts-cjk noto-fonts-emoji --noconfirm --needed
		systemctl enable fcron
		# Setup virtualization
		usermod -G libvirt $username
		systemctl enable libvirtd
		# Setup UEFI virtualization
		echo "nvram = [" >> /etc/libvirt/qemu.conf
		echo "\"/usr/share/ovmf/x64/OVMF_CODE.fd:/usr/share/ovmf/x64/OVMF_VARS.fd\"" >> /etc/libvirt/qemu.conf
		echo "]" >> /etc/libvirt/qemu.conf
		# Add the C bit to VM images folder because btrfs is a Copy-On-Write filesystem
		#chattr +C /var/lib/libvirt/images

		# espeak is a mumble TTS dependency, needs to be installed before building
		echo "trizen -Syu espeak --noconfirm --noedit --needed" >> /home/$username/archfinish.sh
		# Mumble migrated to jack2 which breaks on --noconfirm
		echo "trizen -Syu mumble-git --noedit --needed" >> /home/$username/archfinish.sh
		echo "trizen -Syu angrysearch nextcloud-client pamac-aur qdirstat peek reaver-wps-fork-t6x-git sc-controller --noconfirm --noedit --needed" >> /home/$username/archfinish.sh
		# Set my favorite Cinnamon theme
		echo "gsettings set org.cinnamon.theme name \"New-Minty\"" >> /home/$username/archfinish.sh
	fi
	exit
fi
clear
echo "Looks like the first part of the installation was a success! Now you should reboot with 'reboot'."
echo "After you login, there's a script - /home/$username/archfinish.sh - that you should run after the reboot to finish the installation."
