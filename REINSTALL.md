# Reinstall guide: InputPlumber Steam controller + gyro (GPD Win Max 2, G1619-05)

Tested 2026-10-04 on CachyOS with InputPlumber 0.81.0. This file is self-contained:
the config is embedded below, so you can rebuild the setup from this page alone.

## What this does

InputPlumber merges three parts of the GPD into one virtual **Steam Deck controller**
that Steam Input sees with gyro:

- built-in gamepad ("Microsoft X-Box 360 pad", USB 045e:028e)
- back-button / mode keys ("  Mouse for Windows", USB 2f24:0135)
- BMI260 motion sensor (IIO `bmi260`)

The config shipped with InputPlumber only covers model G1619-04, so this custom config
is required.

## Steps after a fresh OS install

1. **Install InputPlumber** (CachyOS / Arch):

   ```sh
   sudo pacman -S inputplumber
   ```

2. **Create the config.** Save the YAML in the next section as
   `/etc/inputplumber/devices.d/50-gpd_winmax2_g1619-05.yaml`:

   ```sh
   sudo mkdir -p /etc/inputplumber/devices.d
   sudo nano /etc/inputplumber/devices.d/50-gpd_winmax2_g1619-05.yaml
   ```

   (Or, if you backed up this project folder, run `sudo ./install.sh` from it,
   which does steps 1 to 3 at once.)

3. **Enable and start the service:**

   ```sh
   sudo systemctl enable --now inputplumber
   sudo systemctl restart inputplumber
   ```

4. **Check it worked:**

   ```sh
   journalctl -u inputplumber -b | grep -E "Creating CompositeDevice|Detected IMU"
   grep -A1 "Vendor=28de Product=1205" /proc/bus/input/devices
   ```

   You should see `Creating CompositeDevice with config: GPD WinMax2 G1619-05`,
   `Detected IMU: bmi260`, and a `Valve Corporation Steam Controller` input device.

5. **Test in Steam:** Settings > Controller > select the Steam Deck controller >
   gyro calibration/test. Tilt the device and confirm the gyro follows.

## TDP and fan curve with Handheld Daemon (hhd)

hhd handles TDP and the fan curve; InputPlumber keeps the controller. hhd is limited to
its `adjustor` plugin with a systemd drop-in, so its GPD controller emulation never
loads. Do this after the InputPlumber steps above.

1. **Install** hhd, its desktop app and the `acpi_call` module that TDP needs:

   ```sh
   sudo pacman -S --needed hhd hhd-ui acpi_call-dkms
   sudo modprobe acpi_call
   ```

2. **Limit hhd to TDP/fan.** Create
   `/etc/systemd/system/hhd.service.d/10-tdp-fan-only.conf`:

   ```ini
   [Service]
   Environment=HHD_PLUGINS=adjustor
   ```

3. **Start it, then restart InputPlumber:**

   ```sh
   sudo systemctl disable --now power-profiles-daemon
   sudo systemctl daemon-reload
   sudo systemctl enable --now hhd
   sudo systemctl restart inputplumber
   ```

   Use `hhd.service` only, not `hhd@<user>.service` (the drop-in does not cover it).
   With the project folder, `sudo ./install-hhd.sh` does steps 1 to 3.

4. **Check** with `./verify-hhd.sh`, or by hand:

   ```sh
   journalctl -u hhd -b | grep -E "Found plugin providers|Skipping provider 'gpd_win'"
   grep -A1 "Vendor=28de Product=1205" /proc/bus/input/devices
   ```

   Providers should list only `adjustor`, `gpd_win` should be skipped, and the
   Valve Steam Controller from InputPlumber must still be there. Then re-test gyro in Steam.

5. **Set TDP and fan curve** in the Handheld Daemon app (hhd-ui). Settings are saved
   in `/etc/hhd/state.yml`. hhd caps this model at 28 W.

- **Undo:** `sudo systemctl disable --now hhd && sudo rm -r /etc/systemd/system/hhd.service.d && sudo systemctl daemon-reload`
- **If the controller stops working:** `sudo systemctl stop hhd && sudo systemctl restart inputplumber`,
  then check `systemctl cat hhd` shows the `HHD_PLUGINS=adjustor` line.

## The config

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/ShadowBlip/InputPlumber/main/rootfs/usr/share/inputplumber/schema/composite_device_v1.json
# Local override for this GPD Win Max 2 (DMI product_name G1619-05).
# Upstream 50-gpd_winmax2.yaml only matches G1619-04 and different USB phys paths,
# so it never claims this unit. This combines the built-in Xbox 360-mode gamepad,
# the "Mouse for Windows" back/mode keys and the BMI260 IMU into one virtual
# Steam Deck controller, which Steam Input sees with gyro.
#
# Install: copy to /etc/inputplumber/devices.d/ and restart inputplumber.
version: 1
kind: CompositeDevice
name: GPD WinMax2 G1619-05 (Steam Deck + gyro)

single_source: false

matches:
  - dmi_data:
      product_name: G1619-05
      sys_vendor: GPD

source_devices:
  # Built-in gamepad, xpad 045e:028e, currently /dev/input/event17
  - group: gamepad
    evdev:
      name: "Microsoft X-Box 360 pad"
      phys_path: usb-0000:ca:00.0-3/input0
      handler: event*
  # Built-in keyboard/mouse interface (back buttons, mode keys), 2f24:0135
  - group: keyboard
    evdev:
      name: "  Mouse for Windows"
      phys_path: usb-0000:ca:00.0-4/input0
      handler: event*
  - group: keyboard
    evdev:
      name: "  Mouse for Windows"
      phys_path: usb-0000:ca:00.0-4/input1
      handler: event*
  # BMI260 IMU at /sys/bus/iio/devices/iio:device0
  - group: imu
    iio:
      name: "{i2c-BMI0260:00,bmi260}"
      # Kernel exposes no mount matrix. Start with identity (same as upstream
      # Win Max 2). If gyro yaw/pitch come out inverted in Steam's gyro test,
      # try the GPD Win 4 orientation instead:
      #   x: [-1, 0, 0]
      #   y: [0, -1, 0]
      #   z: [0, 0, 1]
      mount_matrix:
        x: [1, 0, 0]
        y: [0, 1, 0]
        z: [0, 0, 1]

options:
  auto_manage: true

# Steam Deck target carries gyro/accel to Steam Input; keyboard + mouse keep
# the GPD mouse-mode keys working.
target_devices:
  - deck
  - mouse
  - keyboard

# Same button mapping as upstream Win Max 2 (back buttons, Xbox/menu combos).
capability_map_id: gpd2
```

## Troubleshooting

- **No composite device created:** check the model with
  `cat /sys/class/dmi/id/product_name` (must be `G1619-05`) and the pad's USB path with
  `grep -A4 'X-Box 360 pad"' /proc/bus/input/devices` (the `P: Phys=` line must be
  `usb-0000:ca:00.0-3/input0`). A BIOS update or a different kernel can change these;
  edit `matches` / `phys_path` in the config to the new values, then restart the service.
- **Gyro moves the wrong way:** replace the `mount_matrix` values with the commented
  alternative in the config, then `sudo systemctl restart inputplumber`.
- **Undo everything:**
  `sudo systemctl disable --now inputplumber && sudo rm /etc/inputplumber/devices.d/50-gpd_winmax2_g1619-05.yaml`
