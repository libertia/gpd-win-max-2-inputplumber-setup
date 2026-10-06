# CLAUDE.md

InputPlumber composite device config that turns the built-in controls of a
**GPD Win Max 2 (DMI `G1619-05`)** into one virtual **Steam Deck controller** with gyro,
for Steam Input. Published at github.com/libertia/gpd-win-max-2-inputplumber-setup.

## Hardware (this machine)

- Gamepad: evdev `Microsoft X-Box 360 pad` (`xpad`, USB `045e:028e`), phys `usb-0000:ca:00.0-3/input0`
- Back buttons / mode keys: evdev `  Mouse for Windows` (two leading spaces, USB `2f24:0135`), phys `usb-0000:ca:00.0-4/input{0,1}`
- IMU: IIO `bmi260` (`i2c-BMI0260:00`), `/sys/bus/iio/devices/iio:device0`, no kernel mount matrix
- Not part of this setup: Flydigi Vader 4 (`04b4:2412`), Steam's own virtual pads (`28de:11ff`)

Upstream `50-gpd_winmax2.yaml` matches only `G1619-04` and `0000:{74,65,73}:00.3` USB paths,
which is why this local config exists.

## Files

- `config/50-gpd_winmax2_g1619-05.yaml`: the composite device config (targets `deck`, `mouse`, `keyboard`; capability map `gpd2`). Validate against upstream `schema/composite_device_v1.json`.
- `install.sh`: installs the package, copies the config to `/etc/inputplumber/devices.d/`, enables and restarts the service. Run with sudo.
- `README.md`: public GitHub readme, keeps the AI-generated disclaimer near the top.
- `REINSTALL.md`: self-contained rebuild guide with the config embedded. Keep its embedded YAML in sync when the config changes.
- `devices.md`: hardware discovery notes.
- `raw/`: raw command output and upstream reference files. Contains the hostname and controller serial, so it should not be published.

## Install and verify

```sh
sudo ./install.sh
journalctl -u inputplumber -b | grep -E "Creating CompositeDevice|Detected IMU"
grep -A1 "Vendor=28de Product=1205" /proc/bus/input/devices
busctl get-property org.shadowblip.InputPlumber /org/shadowblip/InputPlumber/CompositeDevice0 org.shadowblip.Input.CompositeDevice SourceDevicePaths
```

Healthy state: `CompositeDevice0` holds `event17` (pad), `event4`/`event5` (keys) and
`/dev/iio:device0`, and a `Valve Corporation Steam Controller` (`28de:1205`) exists.
Gyro is checked in Steam > Settings > Controller > gyro calibration.

## Conventions

- **The user runs sudo.** Claude has no passwordless sudo here. Put privileged steps in a
  script or a single command for the user to run, then verify afterwards without root.
- Don't change system config (`/etc`, packages, services) without asking first.
- After editing the config, the user reinstalls it (`sudo ./install.sh`) and Claude re-checks the journal.
- If gyro is mirrored, swap `mount_matrix` for the commented GPD Win 4 orientation in the config.
- Keep the AI-generated disclaimer in `README.md`, `install.sh` and the config header.
- Keep `raw/` and anything with the hostname or device serial out of git.
- The `inputplumber` CLI in 0.81.0 has no `device list`; use `busctl tree org.shadowblip.InputPlumber`.
