# arch-install

This is a set of scripts that I use to easily install and setup Arch. I highly recommend doing it yourself with the [Arch wiki](https://wiki.archlinux.org/index.php/Installation_guide) as a guide in order to learn what goes into the install process, but once you figure out how it all works, it's nice to have a script.

## Usage

1. Boot an Arch install USB/CD in UEFI mode.
2. Connect to the internet. (Sometimes I have had DNS issues here. Telling `systemd-resolved` to use a different DNS server (e.g. `resolvectl dns LINK 1.1.1.1`) and then restarting it (`systemctl restart systemd-resolved`) usually does the trick.)
3. Install git: `pacman -Sy git`
4. Clone this repo: `git clone https://github.com/jasonccox/arch-install.git`
5. Change directory to the cloned repo: `cd arch-install`
6. Run the script: `USAGE: ./install.sh DEVICE HOSTNAME [options]`
    - `DEVICE` is the device to which Arch should be installed, such as `/dev/sda`. (Use `lsblk` or `fdisk -l` to see available disks.)
    - `HOSTNAME` is the hostname of the computer to which Arch is being installed
    - Options:
        - `-s SIZE` sets the size of the swap partition to `SIZE` GiB (default 8)
7. After the reboot, log in as root and run the `/arch-install/first-boot.sh USER`, where `USER` is the username of the non-root user you'd like to create.
8. Once the script is done, log out and log back in as the new user.
8. Enjoy using Arch!

## Customization

You probably don't want your Arch install to look exactly like mine. The script already forces you to customize two key parts of the system: the device to which you will install Arch and the username of the non-root user to be created. However, you can customize anything else by editing the scripts. Here are some things you're likely to want to change:

- partition layout (the *create partitions*, *format partitions*, and *mount partitions* sections of `install.sh`) - I setup an EFI partition and an encrypted BTRFS partition with volumes for root, home, the package cache, snapshots, and a swapfile.
- mirror list (the `mirrorlist` file) - I use all the U.S. mirrors. If you're not in the U.S., you probably want to do something else. You can generate your own mirrorlist file on the [Arch Linux website](https://www.archlinux.org/mirrorlist/). 
- timezone (the *set timezone* section of `chroot.sh`)
- locale (the *set locale* section of `chroot.sh`)
- keyboard layout (the *save keyboard layout* section of `chroot.sh`) - I use the Colemak layout. If you use something else, you'll want to change this or you might have a tough time typing :)
- microcode (the *set up bootloader* section of `chroot.sh`) - Change `intel-ucode` to `amd-ucode` if you have an AMD processor.
- installed software (`packages.list` and `aur-packages.list`)
- config files (the *Dotfiles* section of `user.sh`) - These are some of my personal configs, and I doubt that you want them.
