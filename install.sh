#!/bin/bash

# First script to run to install Arch.
#
# Prerequisites:
#   - be booted in UEFI mose
#   - be connected to the internet

print_usage () {
    echo "USAGE: ./install.sh DEVICE HOSTNAME [options]"
    echo "OPTIONS:"
    echo "  -s SIZE       set the size of the swapfile to SIZE GiB (default $SWAP_SIZE)"
}

### SETUP

# Set default variable values.
SWAP_SIZE=8

# Read command line arguments into variables.
if [ $# -lt 2 ] || [[ "$1" == -* ]] || [[ "$2" == -* ]]; then
    print_usage
    exit 1
fi

DEV="$1"
HOSTNAME="$2"

while [ "$3" ]; do
    case "$3" in
        -s )    shift
                if [ -z "$3" ]; then
                    print_usage
                    exit 1
                fi
                SWAP_SIZE="$3"
                ;;
        * )     print_usage
                exit 1
    esac

    shift
done

# Make sure you're booted in UEFI mode.
echo "Verifying UEFI mode"
if ! ls /sys/firmware/efi/efivars; then
    echo "You are not booted in UEFI mode. Aborting."
    exit 2
fi

# Verify Internet connection.
echo "Verifying Internet connection"
if ! ping -c 5 archlinux.org; then
    echo "You are not connected to the Internet. Aborting."
    exit 3
fi

# Exit on errors.
set -e

### UPDATE SYSTEM CLOCK
echo "Updating system clock"
timedatectl set-ntp true

### SETUP DISKS/PARTITIONS

# Create partitions.
echo "Creating partitions on $DEV"

# Format disk with GPT table.
parted "$DEV" mklabel gpt

# Create unencrypted partition for /boot.
parted "$DEV" mkpart primary fat32 1MiB 513MiB
parted "$DEV" set 1 esp on # set it as EFI partition

# Create encrypted partition for everything else.
parted "$DEV" mkpart primary btrfs 513MiB 100%

# Encrypt second partition.
echo "Encrypting $DEV"2
cryptsetup luksFormat "$DEV"2
echo "Password successfully set"

# Open encrypted partition.
ENC_NAME=cryptroot
echo "Please enter the drive encryption password to open it"
cryptsetup open "$DEV"2 $ENC_NAME

# Format partitions.
echo "Formatting partitions"

# Format first partition as fat32.
mkfs.fat -F32 -n EFI "$DEV"1

# Format second partition as btrfs.
mkfs.btrfs -L ROOT /dev/mapper/$ENC_NAME

# Create various btrfs subvolumes.
mount /dev/mapper/$ENC_NAME /mnt
btrfs subvolume create /mnt/@root # /
btrfs subvolume create /mnt/@home # /home
btrfs subvolume create /mnt/@pkg # /var/cache/pacman/pkg
btrfs subvolume create /mnt/@snapshots # btrfs snapshots
btrfs subvolume create /mnt/@swap # for a swapfile
btrfs subvolume create /mnt/@btrfs # btrfs root
umount /mnt

# Mount partitions.
echo "Mounting partitions"

# First mount the root subvolume.
mount -o subvol=@root /dev/mapper/$ENC_NAME /mnt

# Make mount dirs for everything else.
mkdir -p /mnt/{boot,home,var/cache/pacman/pkg,swap,.snapshots,btrfs}

# Mount the rest. See `man 8 mount` and `man 5 btrfs` for details about flags.
FLAGS="discard=async,compress=zstd,noatime"
mount -o "$FLAGS,subvol=@home" /dev/mapper/$ENC_NAME /mnt/home
mount -o "$FLAGS,subvol=@pkg" /dev/mapper/$ENC_NAME /mnt/var/cache/pacman/pkg
mount -o "$FLAGS,subvol=@snapshots" /dev/mapper/$ENC_NAME /mnt/.snapshots
mount -o subvol=@swap /dev/mapper/$ENC_NAME /mnt/swap
mount -o "$FLAGS,subvol=@btrfs" /dev/mapper/$ENC_NAME /mnt/btrfs
mount "$DEV"1 /mnt/boot

### INSTALL BASE SYSTEM

# TODO: figure out new way to get mirrors without redirect - use reflector?
# Adjust mirrors.
echo "Setting desired mirrors"
curl -s -L 'https://www.archlinux.org/mirrorlist/?country=US&protocol=https&ip_version=4&use_mirror_status=on' | sed 's/^#Server/Server/' > /etc/pacman.d/mirrorlist

# Install base system. Add btrfs-progs because root is on btrfs.
echo "Installing base system"
pacstrap /mnt base linux linux-firmware btrfs-progs

### GENERATE FSTAB
echo "Generating fstab"
genfstab -U /mnt >> /mnt/etc/fstab

### CHROOT

# Copy chroot and user scripts to be run from new root.
echo "Copying scripts to run on new root"
mkdir /mnt/arch-install
cp chroot.sh first-boot.sh user.sh packages.list aur-packages.list /mnt/arch-install

# Run chroot.sh from new root.
echo "chroot-ing to new root"
arch-chroot /mnt /arch-install/chroot.sh /boot /swap "$SWAP_SIZE" "$HOSTNAME" "$DEV"2 "$ENC_NAME"

### REBOOT
echo "Your system will now reboot. After rebooting, log in as root and run the first-boot.sh script found in /arch-install/"
read -p "Press enter to continue..."
reboot
