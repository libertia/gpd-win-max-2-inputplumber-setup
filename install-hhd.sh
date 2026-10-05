#!/bin/sh
# Install Handheld Daemon (hhd) for TDP and fan curve only, next to InputPlumber.
# AI-generated (Claude, by Anthropic). Review before running. No warranty.
set -e
cd "$(dirname "$0")"

# hhd (includes adjustor), hhd-ui (desktop app for TDP/fan settings),
# acpi_call-dkms (TDP is set through /proc/acpi/call; DKMS builds it for
# both linux-cachyos and linux-cachyos-lts).
pacman -S --needed --noconfirm hhd hhd-ui acpi_call-dkms
modprobe acpi_call

# Only load the TDP/fan plugin, never controller emulation.
install -Dm644 config/hhd/10-tdp-fan-only.conf /etc/systemd/system/hhd.service.d/10-tdp-fan-only.conf

# Use the system service only; the legacy per-user one would bypass the drop-in.
for u in $(systemctl list-units --all --plain --no-legend 'hhd@*' | awk '{print $1}'); do
    systemctl disable --now "$u" || true
done
systemctl disable --now "hhd@${SUDO_USER:-liber}" 2>/dev/null || true

# power-profiles-daemon would fight hhd over the platform profile.
systemctl disable --now power-profiles-daemon 2>/dev/null || true

systemctl daemon-reload
systemctl enable hhd
systemctl restart hhd
# Restart InputPlumber afterwards so it re-claims the pad if anything grabbed it.
sleep 3
systemctl restart inputplumber
echo "Done. Now run ./verify-hhd.sh (no sudo needed)."
