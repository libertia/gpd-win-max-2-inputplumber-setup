#!/bin/sh
# Check hhd runs TDP/fan only and InputPlumber still owns the controller. No root needed.
echo "== services =="
systemctl is-active hhd inputplumber
echo "== hhd plugins (expect only adjustor loaded, gpd_win skipped) =="
journalctl -u hhd -b --no-pager | grep -E "Found plugin providers|Skipping provider 'gpd_win'|acpi_call|TDP|fan" | tail -n 15
echo "== hhd must not have grabbed input devices (expect nothing) =="
journalctl -u hhd -b --no-pager | grep -iE "gpdw|controller|hidraw|uinput" | tail -n 5
echo "== InputPlumber composite device and IMU =="
journalctl -u inputplumber -b --no-pager | grep -E "Creating CompositeDevice|Detected IMU" | tail -n 2
echo "== virtual Steam Deck controller (expect a Valve Corporation line) =="
grep -A1 "Vendor=28de Product=1205" /proc/bus/input/devices | grep Name | sort -u
echo "== fan =="
cat /sys/class/hwmon/hwmon*/fan1_input 2>/dev/null
