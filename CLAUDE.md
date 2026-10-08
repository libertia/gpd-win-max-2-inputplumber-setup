# CLAUDE.md

InputPlumber composite device config that turns the built-in controls of a
**GPD Win Max 2 (DMI `G1619-05`)** into one virtual **HORIPAD STEAM controller** with gyro,
for Steam Input. Published at github.com/libertia/gpd-win-max-2-inputplumber-setup.

## Hardware (this machine)

- Gamepad: evdev `Microsoft X-Box 360 pad` (`xpad`, USB `045e:028e`), phys `usb-0000:*:00.0-3/input0`
- Back buttons / mode keys: evdev `  Mouse for Windows` (two leading spaces, USB `2f24:0135`), phys `usb-0000:*:00.0-4/input{0,1}`
- IMU: IIO `bmi260` (`i2c-BMI0260:00`), `/sys/bus/iio/devices/iio:device0`, no kernel mount matrix
- Not part of this setup: Flydigi Vader 4 (`04b4:2412`), Steam's own virtual pads (`28de:11ff`)

The USB controller's PCI bus number changes between boots (`ca` vs `c7`), so `phys_path` uses `*` for it.

Upstream `50-gpd_winmax2.yaml` matches only `G1619-04` and `0000:{74,65,73}:00.3` USB paths,
which is why this local config exists.

## Files

- `config/50-gpd_winmax2_g1619-05.yaml`: the composite device config (targets `hori-steam`, `mouse`, `keyboard`; capability map `gpd_g1619_05`). Validate against upstream `schema/composite_device_v1.json`.
- `config/gpd_g1619-05.yaml`: capability map `gpd_g1619_05`. Back buttons send F20 (left) / F21 (right), mapped to LeftPaddle1 / RightPaddle1. Upstream `gpd2` expects 0/9 and doesn't fit this unit.
- `gpd-backbutton-debounce.py` + `config/gpd-backbutton-debounce.service`: firmware pulses back buttons ~25 Hz while held. Service grabs the `input1` keyboard, merges pulses (60 ms window), re-emits as uinput `MSI WMI hotkeys` / phys `gpd-debounce/input0` (name borrowed: InputPlumber skips virtual devices not on its name whitelist).
- `config/60-inputplumber-horipad-steam.rules`: uaccess on the virtual Horipad hidraw; without it Steam has no gyro.
- `capture-keys.py`: run with sudo to see which keys reach the InputPlumber virtual keyboard (unmapped keys pass through there).
- `install.sh`: installs the package, copies the config to `/etc/inputplumber/devices.d/` and the map to `/etc/inputplumber/capability_maps.d/`, enables and restarts the service. Run with sudo.
- `README.md`: public GitHub readme, keeps the AI-generated disclaimer near the top.
- `REINSTALL.md`: self-contained rebuild guide with the config embedded. Keep its embedded YAML in sync when the config changes.
- `devices.md`: hardware discovery notes.
- `raw/`: raw command output and upstream reference files. Contains the hostname and controller serial, so it should not be published.

## Install and verify

```sh
sudo ./install.sh
journalctl -u inputplumber -b | grep -E "Creating CompositeDevice|Detected IMU"
grep -A1 "Vendor=0f0d Product=01ab" /proc/bus/input/devices
busctl get-property org.shadowblip.InputPlumber /org/shadowblip/InputPlumber/CompositeDevice0 org.shadowblip.Input.CompositeDevice SourceDevicePaths
```

Healthy state: `CompositeDevice0` holds the pad (`event13`–`event17`, number varies), `event4` (GPD mouse) plus the debounced `MSI WMI hotkeys` keyboard and
`/dev/iio:device0`, and a `HORI CO.,LTD. HORIPAD STEAM` (`0f0d:01ab`) exists.
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
