#!/bin/sh
# Install InputPlumber and the GPD Win Max 2 (G1619-05) Horipad Steam + gyro config.
# AI-generated (Claude, by Anthropic). Tested on one GPD Win Max 2 G1619-05; review before running. No warranty.
set -e
cd "$(dirname "$0")"
pacman -S --needed --noconfirm inputplumber python-evdev
install -Dm644 config/50-gpd_winmax2_g1619-05.yaml /etc/inputplumber/devices.d/50-gpd_winmax2_g1619-05.yaml
install -Dm644 config/gpd_g1619-05.yaml /etc/inputplumber/capability_maps.d/gpd_g1619-05.yaml
install -Dm644 config/60-inputplumber-horipad-steam.rules /etc/udev/rules.d/60-inputplumber-horipad-steam.rules
udevadm control --reload
install -Dm755 gpd-backbutton-debounce.py /usr/local/bin/gpd-backbutton-debounce.py
install -Dm644 config/gpd-backbutton-debounce.service /etc/systemd/system/gpd-backbutton-debounce.service
systemctl daemon-reload
systemctl enable gpd-backbutton-debounce
systemctl stop inputplumber
systemctl restart gpd-backbutton-debounce
systemctl enable --now inputplumber
systemctl restart inputplumber
