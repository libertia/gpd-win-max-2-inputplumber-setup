#!/bin/sh
# Install InputPlumber and the GPD Win Max 2 (G1619-05) Steam Deck + gyro config.
set -e
cd "$(dirname "$0")"
pacman -S --needed --noconfirm inputplumber
install -Dm644 config/50-gpd_winmax2_g1619-05.yaml /etc/inputplumber/devices.d/50-gpd_winmax2_g1619-05.yaml
systemctl enable --now inputplumber
systemctl restart inputplumber
