#!/bin/bash

# Setup to be run on new root as new user.

### FISH SHELL
echo "Setting default shell to fish"
chsh -s "$(which fish)"

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

### SETUP DOTFILES
echo "Setting up dotfiles"
cd ~
git clone https://github.com/jasonccox/dotfiles.git # clone with https since ssh keys aren't on system yet
cd dotfiles
git remote set-url origin git@github.com:jasonccox/dotfiles.git # set to ssh for later use
./setup.sh shell vim git tmux ssh sway alacritty kmonad

echo "Done with setup as new user"
