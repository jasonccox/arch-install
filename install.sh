#!/bin/bash

# First script to run to install Arch.
#
# Prerequisites:
#   - be booted in UEFI mose
#   - be connected to the internet

# variables
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "USAGE: ./install.sh DEV_NAME USERNAME [options]"
    echo "OPTIONS:"
    echo "  -e        encrypt the whole disk (except for the /boot partition)"
    exit 1
fi
DEV="$1"
USER="$2"
if [ "$3" = "-e" ]; then
    ENCRYPTED="true"
fi

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
if [ "$ENCRYPTED" = "true" ]; then
    parted /dev/"$DEV" mkpart primary fat32 1MiB 513MiB
    parted /dev/"$DEV" mkpart primary ext4 513MiB 100%
    echo "Please choose a password for you drive encryption"
    cryptsetup luksFormat /dev/"$DEV"2
    echo "Please enter the drive encryption password"
    cryptsetup open /dev/"$DEV"2 cryptlvm
    pvcreate /dev/mapper/cryptlvm
    vgcreate vols /dev/mapper/cryptlvm
    lvcreate -L 32g vols -n root
    lvcreate -L 8g vols -n swap
    lvcreate -l 100%FREE vols -n home
else
    parted /dev/"$DEV" mkpart primary fat32 1MiB 261MiB
    parted /dev/"$DEV" mkpart primary ext4 261MiB 33029MiB
    parted /dev/"$DEV" mkpart primary ext4 33029MiB 41221MiB
    parted /dev/"$DEV" mkpart primary ext4 41221MiB 100%
fi
parted /dev/"$DEV" set 1 esp on

# format partitions
echo "Formatting partitions"
mkfs.fat -F32 /dev/"$DEV"1
if [ "$ENCRYPTED" = "true" ]; then
    mkfs.ext4 /dev/vols/root
    mkswap /dev/vols/swap
    mkfs.ext4 /dev/vols/home
else
    mkfs.ext4 /dev/"$DEV"2
    mkswap /dev/"$DEV"3
    mkfs.ext4 /dev/"$DEV"4
fi

# mount partitions
echo "Mounting partitions"
if [ "$ENCRYPTED" = "true" ]; then
    mount /dev/vols/root /mnt
    mkdir /mnt/boot /mnt/home
    mount /dev/"$DEV"1 /mnt/boot
    mount /dev/vols/home /mnt/home
    swapon /dev/vols/swap
else
    mount /dev/"$DEV"2 /mnt
    mkdir /mnt/efi /mnt/home
    mount /dev/"$DEV"1 /mnt/efi
    mount /dev/"$DEV"4 /mnt/home
    swapon /dev/"$DEV"3
fi

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
if [ "$ENCRYPTED" = "true" ]; then
    arch-chroot /mnt ./chroot.sh /boot "$USER" /dev/"$DEV"2 /dev/vols/root
else
    arch-chroot /mnt ./chroot.sh /efi "$USER"
fi

# copy first-boot.sh
echo "Copying first-boot.sh to $USER's home directory"
cp first-boot.sh /mnt/home/$USER/first-boot.sh

# clean up
echo "Cleaning up"
rm /mnt/chroot.sh /mnt/user.sh

# reboot
echo "All done! Your system will now reboot. After rebooting, run the first-boot.sh script in $USER's home directory."
read -p "Press enter to continue..."
reboot
