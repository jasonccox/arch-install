#!/bin/bash

# Setup to be run on new root as new user.

# Yay (AUR helper)
echo "Installing AUR helper"
cd /tmp
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd ..
rm -rf yay

echo "Done with setup as new user"
