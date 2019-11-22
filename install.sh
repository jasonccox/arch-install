#!/bin/bash

# First script to run to install Arch.
#
# Prerequisites:
#   - be booted in UEFI mose
#   - be connected to the internet

print_usage () {
    echo "USAGE: ./install.sh DEVICE USERNAME HOSTNAME [options]"
    echo "OPTIONS:"
    echo "  -e        encrypt the whole disk (except for the /boot partition)"
    echo "  -r SIZE   set the size of the root partition to SIZE GiB (default 32)"
    echo "  -s SIZE   set the size of the swap partition to SIZE GiB (default 8)"
}

# set default variable values
ENCRYPTED="false"
ROOT_SIZE=32
SWAP_SIZE=8

# read command line arguments into variables
if [ $# -lt 3 ]; then
    print_usage
    exit 1
fi

DEV="$1"
USER="$2"
HOSTNAME="$3"

while [ ! -z "$4" ]; do
    case "$4" in
        -e )    ENCRYPTED="true"
                ;;
        -r )    shift
                if [ -z "$4" ]; then
                    print_usage
                    exit 1
                fi
                ROOT_SIZE="$4"
                ;;
        -s )    shift
                if [ -z "$4" ]; then
                    print_usage
                    exit 1
                fi
                SWAP_SIZE="$4"
                ;;
        * )     print_usage
                exit 1
    esac

    shift
done

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
echo "Creating partitions on $DEV"
parted "$DEV" mklabel gpt
parted "$DEV" mkpart primary fat32 1MiB 513MiB # /efi or /boot
parted "$DEV" set 1 esp on # sets partition 1 as EFI partition
if [ "$ENCRYPTED" = "true" ]; then
    parted "$DEV" mkpart primary ext4 513MiB 100% # encrypted with LUKS

    # encrypt second partition
    echo "Encrypting $DEV"2
    cryptsetup luksFormat "$DEV"2

    # open encrypted partition
    echo "Password successfully set"
    echo "Please enter the drive encryption password to open it"
    cryptsetup open "$DEV"2 cryptlvm

    # create LVM volumes on encrypted partition
    pvcreate /dev/mapper/cryptlvm
    vgcreate vols /dev/mapper/cryptlvm
    lvcreate -L "$ROOT_SIZE"g vols -n root
    lvcreate -L "$SWAP_SIZE"g vols -n swap
    lvcreate -l 100%FREE vols -n home
else
    let ROOT_END=513+1024*"$ROOT_SIZE"
    let SWAP_END="$ROOT_END"+1024*"$SWAP_SIZE"
    parted "$DEV" mkpart primary ext4 513MiB "$ROOT_END"MiB # /
    parted "$DEV" mkpart primary ext4 "$ROOT_END"MiB "$SWAP_END"MiB # swap
    parted "$DEV" mkpart primary ext4 "$SWAP_END"MiB 100% # /home
fi

# format partitions
echo "Formatting partitions"
mkfs.fat -F32 "$DEV"1
if [ "$ENCRYPTED" = "true" ]; then
    mkfs.ext4 /dev/vols/root
    mkswap /dev/vols/swap
    mkfs.ext4 /dev/vols/home
else
    mkfs.ext4 "$DEV"2 # /
    mkswap "$DEV"3
    mkfs.ext4 "$DEV"4 # /home
fi

# mount partitions
echo "Mounting partitions"
if [ "$ENCRYPTED" = "true" ]; then
    mount /dev/vols/root /mnt
    mkdir /mnt/boot /mnt/home
    mount "$DEV"1 /mnt/boot
    mount /dev/vols/home /mnt/home
    swapon /dev/vols/swap
else
    mount "$DEV"2 /mnt
    mkdir /mnt/efi /mnt/home
    mount "$DEV"1 /mnt/efi
    mount "$DEV"4 /mnt/home
    swapon "$DEV"3
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

# copy chroot and user scripts
echo "Copying scripts to run on new root"
cp chroot.sh /mnt/chroot.sh
cp user.sh /mnt/user.sh

# run chroot.sh from new root
echo "chroot-ing to new root"
if [ "$ENCRYPTED" = "true" ]; then
    arch-chroot /mnt ./chroot.sh /boot "$USER" "$HOSTNAME" "$DEV"2 /dev/vols/root
else
    arch-chroot /mnt ./chroot.sh /efi "$USER" "$HOSTNAME"
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
