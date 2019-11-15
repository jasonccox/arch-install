#!/bin/bash

# Script run on the new root as the root user.

# variables
if [ $# -ne 2 ] && [ $# -ne 4 ]; then
    echo "USAGE: ./chroot.sh BOOT_MOUNT USERNAME [encrypted_device root_device]"
    exit 1
fi
BOOTMNT="$1"
USER="$2"
ENCDEV="$3"
ROOTDEV="$4"

# exit on errors
set -e

# install dependencies
echo "Installing dependencies"
pacman -S --noconfirm vim git sudo

# set timezone
echo "Setting timezone"
ln -sf /usr/share/zoneinfo/America/Denver /etc/localtime
hwclock --systohc

# set locale
echo "Setting locale"
vim +/#en_US\.UTF-8 -c "normal! x" -c wq /etc/locale.gen
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

# configure mkinitcpio (encrypted only)
if [ ! -z "$ENCDEV" ]; then
    vim +/^HOOKS= -c "normal! ccHOOKS=(base udev autodetect keyboard keymap modconf block encrypt lvm2 filesystems fsck)" -c wq /etc/mkinitcpio.conf
    pacman -S --noconfirm lvm2 # required for lvm2 mkinitcpio hook and runs mkinitcpio after install
fi

# set up bootloader
echo "Installing bootloader"
pacman -S --noconfirm grub efibootmgr intel-ucode $FSPKGS
grub-install --target=x86_64-efi --efi-directory="$BOOTMNT" --bootloader-id=GRUB
if [ ! -z "$ENCDEV" ]; then
    vim +/^GRUB_CMDLINE_LINUX= -c 'normal! $' -c "normal! icryptdevice=UUID=$(lsblk -dno UUID /dev/$ENCDEV):cryptlvm root=$ROOTDEV" -c wq /etc/default/grub
fi
grub-mkconfig -o /boot/grub/grub.cfg

# install NetworkManager to connect to Internet after reboot
echo "Installing NetworkManager"
pacman -S --noconfirm networkmanager
systemctl enable NetworkManager.service

# SDDM
echo "Installing SDDM"
pacman -S --noconfirm xorg sddm
systemctl enable sddm.service

# KDE Plasma
echo "Installing KDE Plasma desktop environment"
pacman -S --noconfirm phonon-qt5-vlc plasma-meta plasma-nm sddm-kcm kde-gtk-config libdbusmenu-glib libdbusmenu-gtk2 libdbusmenu-gtk3 kdeconnect

# Other Packages
echo "Installing additional software"
pacman -Rs --noconfirm vim
pacman -S --noconfirm base-devel konsole firefox gvim zip unzip openssh code hunspell-en_US hunspell-es_any nextcloud-client yakuake pulseaudio-alsa pulseaudio-bluetooth dosfstools e2fsprogs

# set the root password
echo "Please set the root password"
passwd

# create a new user with sudo privileges
echo "Creating user $USER"
useradd -m "$USER"
echo "$USER ALL=(ALL) ALL" > "/etc/sudoers.d/01_$USER"
echo "Please set the password for user $USER"
passwd "$USER"

# run setup as new user
echo "Running additional setup as $USER. You may be promped to enter the password for $USER for some of the commands."
su "$USER" ./user.sh

echo "Exiting chroot"
