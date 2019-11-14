#!/bin/bash

# First script to run to install Arch.
#
# Prerequisites:
#   - be booted in UEFI mose
#   - be connected to the internet

# variables
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "USAGE: ./install.sh [device name] [default username]"
    exit 1
fi
DEV="$1"
USER="$2"

# make sure you're booted in UEFI mode
echo "Verifying UEFI mode"
if ! ls /sys/firmware/efi/efivars; then
    echo "You are not booted in UEFI mode. Aborting."
    exit 2
fi

# verify Internet connection
echo "Verifying Internet connection"
if ! ping -c 5 archlinux.org; then
    echo "You are not connected to the Internet. Aborting."
    exit 3
fi

# exit on errors
set -e

# update system clock
echo "Updating system clock"
timedatectl set-ntp true

# create partitions
echo "Creating partitions on /dev/$DEV"
parted /dev/"$DEV" mklabel gpt
parted /dev/"$DEV" mkpart primary fat32 1MiB 261MiB
parted /dev/"$DEV" set 1 esp on
parted /dev/"$DEV" mkpart primary ext4 261MiB 33029MiB
parted /dev/"$DEV" mkpart primary ext4 33029MiB 41221MiB
parted /dev/"$DEV" mkpart primary ext4 41221MiB 100%

# format partitions
echo "Formatting partitions"
mkfs.fat -F32 /dev/"$DEV"1
mkfs.ext4 /dev/"$DEV"2
mkswap /dev/"$DEV"3
mkfs.ext4 /dev/"$DEV"4

# mount partitions
echo "Mounting partitions"
mount /dev/"$DEV"2 /mnt
mkdir /mnt/efi /mnt/home
mount /dev/"$DEV"1 /mnt/efi
mount /dev/"$DEV"4 /mnt/home
swapon /dev/"$DEV"3

# adjust mirrors
echo "Setting desired mirrors"
cp mirrorlist /etc/pacman.d/mirrorlist

# install base system
echo "Installing base system"
pacstrap /mnt base linux linux-firmware

# generate fstab
echo "Generating fstab"
genfstab -U /mnt >> /mnt/etc/fstab

# copy chroot script
echo "Copying script to run on new root"
cp chroot.sh /mnt/chroot.sh
cp user.sh /mnt/user.sh

# run chroot.sh from new root
echo "chroot-ing to new root"
arch-chroot /mnt ./chroot.sh "$USER"

# clean up
echo "Cleaning up"
rm /mnt/chroot.sh /mnt/user.sh

# reboot
echo "All done! Your system will now reboot."
read -p "Press enter to continue..."
reboot
