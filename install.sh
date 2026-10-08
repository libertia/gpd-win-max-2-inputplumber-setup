#!/bin/sh
# Install InputPlumber and the GPD Win Max 2 (G1619-05) Steam Deck + gyro config.
# AI-generated (Claude, by Anthropic). Tested on one GPD Win Max 2 G1619-05; review before running. No warranty.
set -e
cd "$(dirname "$0")"
pacman -S --needed --noconfirm inputplumber
install -Dm644 config/50-gpd_winmax2_g1619-05.yaml /etc/inputplumber/devices.d/50-gpd_winmax2_g1619-05.yaml
install -Dm644 config/gpd_g1619-05.yaml /etc/inputplumber/capability_maps.d/gpd_g1619-05.yaml
systemctl enable --now inputplumber
systemctl restart inputplumber
