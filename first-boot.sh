#!/bin/bash

# Script to be run after reboot.

# Keyboard
echo "Setting X11 keyboard layouts"
localectl --no-convert set-x11-keymap us,us microsoft4000, colemak, caps:escape_shifted_capslock,compose:ralt
