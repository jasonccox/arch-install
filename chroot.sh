#!/bin/bash

# Script run on the new root.

# variables
if [ -z "$1" ]; then
    echo "USAGE: ./chroot.sh [default username]"
    exit 1
fi
USER="$1"

# exit on errors
set -e

# set timezone
echo "Setting timezone"
ln -sf /usr/share/zoneinfo/America/Denver /etc/localtime
hwclock --systohc

# set locale
echo "Setting locale"
vim +/#en_US\.UFT-8 -c "normal! x" -c wq
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# save keyboard layout
echo "Saving keyboard layout"
echo "KEYMAP=colemak" > /etc/vconsole.conf

# configure network
echo "Configuring network"
echo "jason-desktop" > /etc/hostname
echo "127.0.0.1        localhost" >> /etc/hosts
echo "::1              localhost" >> /etc/hosts
echo "127.0.1.1        jason-desktop.localdomain" >> /etc/hosts

# set up bootloader
echo "Installing bootloader"
pacman -S grub efibootmgr intel-ucode
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# install NetworkManager to connect to Internet after reboot
echo "Installing NetworkManager"
pacman -S networkmanager
systemctl enable NetworkManager.service

# SDDM
echo "Installing SDDM"
pacman -S --no-confirm xorg sddm
systemctl enable sddm.service

# KDE Plasma
echo "Installing KDE Plasma desktop environment"
pacman -S --no-confirm phonon-qt5-vlc plasma-meta plasma-nm sddm-kcm kde-gtk-config libdbusmenu-glib libdbusmenu-gtk2 libdbusmenu-gtk3 kdeconnect

# Other Packages
echo "Installing additional software"
pacman -S --no-confirm base-devel git konsole firefox gvim zip unzip openssh code hunspell-en_US hunspell-es_any nextcloud-client yakuake pulseaudio-alsa pulseaudio-bluetooth

# Yay (AUR helper)
cd /tmp
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd ..
rm -rf yay

# AUR Packages
yay -S --no-confirm tutanota-desktop-linux

# Keyboard
echo "Setting X11 keyboard layouts"
localectl --no-convert set-x11-keymap us,us microsoft4000, colemak, caps:escape_shifted_capslock compose:ralt

# set the root password
echo "Please set the root password"
passwd

# create a new user with sudo privileges
echo "Creating user $USER"
useradd -m "$USER"
pacman -S sudo
echo "$USER ALL=(ALL) ALL" > "/etc/sudoers.d/01_$USER"
echo "Please set the password for user $USER"
passwd "$USER"

echo "Exiting chroot"
