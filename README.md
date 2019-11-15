# arch-install

This is a set of scripts that I use to easily install and setup Arch. I highly recommend doing it yourself with the [Arch wiki](https://wiki.archlinux.org/index.php/Installation_guide) as a guide in order to learn what goes into the install process, but once you figure out how it all works, it's nice to have a script.

## Usage

1. Boot an Arch install USB/CD in UEFI mode.
2. Connect to the internet.
3. Install git: `pacman -Sy git`
4. Clone this repo: `git clone https://gitlab.com/jasonccox/arch-install.git`
5. Change directory to the cloned repo: `cd arch-install`
6. Run the script: `USAGE: ./install.sh DEV_NAME USERNAME [options]`
    - `DEV_NAME` is the name of the disk to which Arch should be installed, such as `sda`. (Use `lsblk` or `fdisk -l` to see available disks.)
    - `USERNAME` is the username of the non-root user to be created.
    - Options:
        - `-e` encrypts the whole disk (except for the `/boot` partition)
7. After the reboot, run the `./first-boot.sh` from the new user's home directory. (In the case of using KDE Plasma with an alternate keyboard layout, I suggest doing this from another tty before you ever log into Plasma for the first time. If you don't, you'll have to manually set your keyboard layout in the System Settings application.)
8. Enjoy using Arch!

## Customization

You probably don't want your Arch install to look exactly like mine. The script already forces you to customize two key parts of the system: the device to which you will install Arch and the username of the non-root user to be created. However, you can customize anything else by editing the scripts. Here are some things you're likely to want to change:

- partition layout (the *create partitions*, *format partitions*, and *mount partitions* sections of `install.sh`) - I setup an EFI partition, a swap partition, a root partition, and a separate partition for `/home`. Of special note is the fact that I made my swap partition about 8GiB to match the RAM in my computer so that hibernate will work. 
- mirror list (the `mirrorlist` file) - I use all the U.S. mirrors. If you're not in the U.S., you probably want to do something else. You can generate your own mirrorlist file on the [Arch Linux website](https://www.archlinux.org/mirrorlist/). 
- timezone (the *set timezone* section of `chroot.sh`)
- locale (the *set locale* section of `chroot.sh`)
- hostname (the *configure network* section of `chroot.sh`)
- keyboard layout (the *save keyboard layout* section of `chroot.sh` and the *Keyboard* section of `first-boot.sh`) - I use the Colemak layout. If you use something else, you'll want to change this or you might have a tough time typing :)
- microcode (the *set up bootloader* section of `chroot.sh`) - Change `intel-ucode` to `amd-ucode` if you have an AMD processor.
- installed software (the *NetworkManager*, *SDDM*, *KDE Plasma*, and *Other Packages* sections of `chroot.sh`, and the *AUR Packages* section of `user.sh`)
