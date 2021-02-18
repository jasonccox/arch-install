#!/bin/bash

# Setup to be run on new root as new user.

### SETUP DOTFILES
echo "Setting up dotfiles"
git clone https://github.com/jasonccox/dotfiles.git # clone with https since ssh keys aren't on system yet
cd dotfiles
git remote set-url origin git@github.com:jasonccox/dotfiles.git # set to ssh for later use
./setup.sh shell vim git tmux ssh sway alacritty

### INSTALL AUR PACKAGES

# Yay (AUR helper)
echo "Installing AUR helper"
cd /tmp
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
cd ..
rm -rf yay

# AUR Packages
echo "Installing additional software from AUR"
yay -S --noconfirm $(cat /arch-install/aur-packages.list | grep -v '^#')

echo "Done with setup as new user"
