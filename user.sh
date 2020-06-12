#!/bin/bash

# Setup to be run on new root as new user.

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
yay -S --noconfirm tutanota-desktop-bin tmuxinator

echo "Done with setup as new user"
