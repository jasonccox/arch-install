#!/bin/bash

# Script to be run after reboot.

# Keyboard
echo "Setting X11 keyboard layouts"
localectl --no-convert set-x11-keymap us,us microsoft4000, colemak, caps:escape_shifted_capslock,compose:ralt

# Dotfiles
echo "Setting up config files"
git clone https://github.com/jasonccox/dotfiles.git # clone with https since ssh keys aren't on system yet
cd dotfiles
git remote set-url origin git@github.com:jasonccox/dotfiles.git # set to ssh for later use
./setup.sh
