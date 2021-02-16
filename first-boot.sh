#!/bin/bash
#
# first-boot.sh - Script to be run after reboot.

### SETUP

if [ -z "$1" ]; then
    echo "USAGE: ./first-boot.sh USER"
    exit 1
fi

USER="$1"

set -e

### SETUP SNAPSHOTS
# See https://wiki.archlinux.org/index.php/Snapper#Configuration_of_snapper_and_mount_point

echo "Setting up snapshots"

# snapper - automated snapshot utility for btrfs
# snap-pac - adds pacman hooks to take pre and post snapshots
# grub-btrfs - automatically adds new snapshots to grub menu
# rsync - used to copy /boot to /.bootbackup
pacman -S --noconfirm \
    snapper \
    snap-pac \
    grub-btrfs \
    rsync

# Unmount existing snapshots subvolume and remove its mount directory since
# creating the snapper config will recreate them.
umount /.snapshots
rm -r /.snapshots

# Create a snapper config for the root subvolume.
snapper -c root create-config /

# Turn off hourly snapshots.
sed -i 's/^TIMELINE_CREATE=.*$/TIMELINE_CREATE="no"/' /etc/snapper/configs/root

# Get rid of the extra snapshot subvolume that snapper created.
btrfs subvolume delete /.snapshots

# Remake the snapshot mount directory, mount the snapshot subvolume there, and
# update its permissions. We've essentially gotten snapper to use our previously
# created snapshot subvolume.
mkdir /.snapshots
chmod 750 /.snapshots

# Add a snap-pac config to take snapshots based on the `root` snapper config.
cp /etc/snap-pac/root.conf{.example,}

# Automatically create grub entries when new snapshots are stored at /.snapshots.
systemctl enable grub-btrfs.path

# Add grub-btrfs-overlryfs initcpio hook to use overlayfs when booting into
# read-only snapshots (see
# https://github.com/Antynea/grub-btrfs/blob/master/initramfs/readme.md)
sed -i '/^HOOKS=/s/)/ grub-btrfs-overlayfs)/' /etc/mkinitcpio.conf
mkinitcpio -P

# Add pacman hook to copy /boot to /.bootbackup since it's on a separate
# partition. (See
# https://wiki.archlinux.org/index.php/Snapper#Backup_non-Btrfs_boot_partition_on_pacman_transactions)
mkdir -p /etc/pacman.d/hooks
cat > /etc/pacman.d/hooks/50-bootbackup.hook <<< '
[Trigger]
Operation = Upgrade
Operation = Install
Operation = Remove
Type = Path
Target = usr/lib/modules/*/vmlinuz

[Action]
Depends = rsync
Description = Backing up /boot...
When = PreTransaction
Exec = /usr/bin/rsync -a --delete /boot /.bootbackup
'

### INSTALL AND SETUP SOFTWARE

echo "Installing software"
pacman -S --noconfirm --needed $(cat /arch-install/packages.list | grep -v '^#')

# Enable bluetooth.
systemctl enable bluetooth.service

### SETUP NEW USER

# Create a new user with sudo privileges.
echo "Creating user $USER"
useradd -m "$USER"
echo "$USER ALL=(ALL) ALL" > "/etc/sudoers.d/01_$USER"
echo "Please set the password for user $USER"
passwd "$USER"

# Add new user to video group to be able to use brightnessctl.
usermod -aG video "$USER"

# Run setup as new user.
echo "Running additional setup as $USER. You may be promped to enter the password for $USER for some of the commands."
su --login "$USER" /arch-install/user.sh

# ### FINISH

echo "Cleaning up"
rm -r /arch-install

echo "All done! Log out, log back in as $USER, and enjoy!"
