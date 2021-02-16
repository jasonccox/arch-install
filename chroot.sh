#!/bin/bash

# Script run on the new root as the root user.

### SETUP

# Set variables from args.
if [ $# -ne 6 ]; then
    echo "USAGE: ./chroot.sh BOOT_MNT SWAP_DIR SWAP_SIZE HOSTNAME ENC_DEV ENC_NAME"
    exit 1
fi
BOOT_MNT="$1"
SWAP_DIR="$2"
SWAP_SIZE="$3"
HOSTNAME="$4"
ENC_DEV="$5"
ENC_NAME="$6"

# Exit on errors.
set -e

### SET TIMEZONE
echo "Setting timezone"
ln -sf /usr/share/zoneinfo/America/Denver /etc/localtime
hwclock --systohc

### SET LOCALE
echo "Setting locale"
sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

### SET KEYBOARD LAYOUT
echo "Saving keyboard layout"
echo "KEYMAP=colemak" > /etc/vconsole.conf

### SETUP NETWORK

# Set hostname.
echo "Configuring network"
echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1        localhost" >> /etc/hosts
echo "::1              localhost" >> /etc/hosts
echo "127.0.1.1        $HOSTNAME.localdomain" >> /etc/hosts

# Install NetworkManager to connect to Internet after reboot.
echo "Installing NetworkManager"
pacman -S --noconfirm networkmanager
systemctl enable NetworkManager.service

### SETUP BOOT

# Install boot-related packages.
echo "Installing boot-related packages"

# grub - boot loader
# efibootmgr - needed for grub-install to add grub to boot loader
# intel-ucode - microcode for Intel processor
pacman -S --noconfirm \
    grub \
    efibootmgr \
    intel-ucode

# Configure mkinitcpio.
echo "Configuring mkinitcpio"

# Most of these are the hooks that were already there by default, except...
#  - encrypt - add support for encrypted root
#  - btrfs - add support for btrfs root
#  - keymap - support using alternate keyboard layout when entering encryption password
sed -i 's/^HOOKS=.*$/HOOKS=(base udev autodetect keyboard keymap modconf block encrypt btrfs filesystems fsck)/' /etc/mkinitcpio.conf

# Add the btrfs binary in order to do maintenence on system without mounting it.
sed -i 's#^BINARIES=.*$#BINARIES=(/usr/bin/btrfs)#' /etc/mkinitcpio.conf

# Regenerate initcpio.
mkinitcpio -P

# Set up bootloader.
echo "Installing bootloader"

# Install grub to EFI.
grub-install --target=x86_64-efi --efi-directory="$BOOT_MNT" --bootloader-id=GRUB

# Enable grub to boot into encrypted partition.
sed -i "s/^GRUB_CMDLINE_LINUX=.*$/GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=$(lsblk -dno UUID $ENC_DEV):$ENC_NAME\"/" /etc/default/grub

# Generate grub config.
grub-mkconfig -o /boot/grub/grub.cfg

### SETUP SWAPFILE

echo "Setting up swapfile"
cd $SWAP_DIR

# Create a zero-length file.
truncate -s 0 main

# Turn off copy-on-write on the file.
chattr +C main

# Turn off compression on the file.
btrfs property set main compression none

# Grow the file to the desired swap size.
fallocate -l ${SWAP_SIZE}G main

# Only let root write/read the swap file.
chmod 600 main

# Make the file be used as swap.
mkswap main

# Update fstab to automatically mount and use the swapfile.
echo "$SWAP_DIR/main none swap sw 0 0" >> /etc/fstab

# TODO: get hibernate working

### SET ROOT PASSWORD
echo "Please set the root password"
passwd

echo "Exiting chroot"
