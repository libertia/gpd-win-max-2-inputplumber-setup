# Reinstall guide: InputPlumber Steam controller + gyro (GPD Win Max 2, G1619-05)

Tested 2026-10-04 on CachyOS with InputPlumber 0.81.0. This file is self-contained:
the config is embedded below, so you can rebuild the setup from this page alone.

## What this does

InputPlumber merges three parts of the GPD into one virtual **HORIPAD STEAM controller**
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

2. **Create the two config files.** Save the YAML in "The config" and "The back-button map" sections below as
   `/etc/inputplumber/devices.d/50-gpd_winmax2_g1619-05.yaml`:

   ```sh
   sudo mkdir -p /etc/inputplumber/devices.d
   sudo nano /etc/inputplumber/devices.d/50-gpd_winmax2_g1619-05.yaml
   sudo mkdir -p /etc/inputplumber/capability_maps.d
   sudo nano /etc/inputplumber/capability_maps.d/gpd_g1619-05.yaml
   ```

   Steam also needs access to the virtual Horipad's hidraw node, or it gets no gyro:

   ```sh
   echo 'KERNEL=="hidraw*", SUBSYSTEM=="hidraw", KERNELS=="0003:0F0D:01AB.*|0003:0F0D:0196.*", MODE="0660", TAG+="uaccess"' | sudo tee /etc/udev/rules.d/60-inputplumber-horipad-steam.rules
   sudo udevadm control --reload
   ```

   The back buttons pulse while held, so a small debounce service sits in front of
   InputPlumber. It needs the project folder (`gpd-backbutton-debounce.py` and
   `config/gpd-backbutton-debounce.service`); `sudo ./install.sh` installs it.

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
   grep -A1 "Vendor=0f0d Product=01ab" /proc/bus/input/devices
   ```

   You should see `Creating CompositeDevice with config: GPD WinMax2 G1619-05`,
   `Detected IMU: bmi260`, and a `HORI CO.,LTD. HORIPAD STEAM` input device.

5. **Test in Steam:** Settings > Controller > select the HORIPAD STEAM controller >
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
   grep -A1 "Vendor=0f0d Product=01ab" /proc/bus/input/devices
   ```

   Providers should list only `adjustor`, `gpd_win` should be skipped, and the
   HORIPAD STEAM from InputPlumber must still be there. Then re-test gyro in Steam.

5. **Set TDP and fan curve** in the Handheld Daemon app (hhd-ui). Settings are saved
   in `/etc/hhd/state.yml`. hhd caps this model at 28 W.

- **Undo:** `sudo systemctl disable --now hhd && sudo rm -r /etc/systemd/system/hhd.service.d && sudo systemctl daemon-reload`
- **If the controller stops working:** `sudo systemctl stop hhd && sudo systemctl restart inputplumber`,
  then check `systemctl cat hhd` shows the `HHD_PLUGINS=adjustor` line.

## The config

`/etc/inputplumber/devices.d/50-gpd_winmax2_g1619-05.yaml`:

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/ShadowBlip/InputPlumber/main/rootfs/usr/share/inputplumber/schema/composite_device_v1.json
# AI-generated (Claude, by Anthropic). Tested on one GPD Win Max 2 G1619-05; review before use. No warranty.
# Local override for this GPD Win Max 2 (DMI product_name G1619-05).
# Upstream 50-gpd_winmax2.yaml only matches G1619-04 and different USB phys paths,
# so it never claims this unit. This combines the built-in Xbox 360-mode gamepad,
# the "Mouse for Windows" back/mode keys and the BMI260 IMU into one virtual
# HORIPAD STEAM controller, which Steam Input sees with gyro.
#
# Install: copy to /etc/inputplumber/devices.d/ and restart inputplumber.
version: 1
kind: CompositeDevice
name: GPD WinMax2 G1619-05 (Horipad Steam + gyro)

single_source: false

matches:
  - dmi_data:
      product_name: G1619-05
      sys_vendor: GPD

source_devices:
  # Built-in gamepad, xpad 045e:028e. The PCI bus number of the USB controller
  # changes between boots (seen ca:00.0 and c7:00.0), so it is wildcarded.
  - group: gamepad
    evdev:
      name: "Microsoft X-Box 360 pad"
      phys_path: "usb-0000:*:00.0-3/input0"
      handler: event*
  # Built-in keyboard/mouse interface (back buttons, mode keys), 2f24:0135
  - group: keyboard
    evdev:
      name: "  Mouse for Windows"
      phys_path: "usb-0000:*:00.0-4/input0"
      handler: event*
  # The keyboard interface (input1) is not read directly: its back buttons pulse
  # while held, so gpd-backbutton-debounce.py grabs it and re-emits it as this
  # virtual keyboard. The name is borrowed because InputPlumber only accepts
  # whitelisted virtual devices; phys_path keeps it specific to the debouncer.
  - group: keyboard
    evdev:
      name: "MSI WMI hotkeys"
      phys_path: "gpd-debounce/input0"
      handler: event*
  # BMI260 IMU at /sys/bus/iio/devices/iio:device0
  - group: imu
    iio:
      name: "{i2c-BMI0260:00,bmi260}"
      # Kernel exposes no mount matrix. Upstream Win Max 2 uses identity. The GPD
      # Win 4 orientation is another option if axes come out inverted:
      #   x: [-1, 0, 0]
      #   y: [0, -1, 0]
      #   z: [0, 0, 1]
      # With the hori-steam target, identity gave correct pitch but roll and
      # yaw swapped, so the y and z rows are exchanged, and yaw (y) is negated
      # because it turned the wrong way after the swap.
      mount_matrix:
        x: [1, 0, 0]
        y: [0, 0, -1]
        z: [0, 1, 0]

options:
  auto_manage: true

# Horipad Steam target carries gyro/accel to Steam Input; keyboard + mouse keep
# the GPD mouse-mode keys working.
target_devices:
  - hori-steam
  - mouse
  - keyboard

# Back buttons send F20/F21 on this model; map them to the Horipad's M1/M2 back paddles
# (see gpd_g1619-05.yaml, installed to /etc/inputplumber/capability_maps.d/).
capability_map_id: gpd_g1619_05
```

## The back-button map

`/etc/inputplumber/capability_maps.d/gpd_g1619-05.yaml` (left back button sends F20, right sends F21):

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/ShadowBlip/InputPlumber/main/rootfs/usr/share/inputplumber/schema/capability_map_v1.json
# AI-generated (Claude, by Anthropic). Tested on one GPD Win Max 2 G1619-05; review before use. No warranty.
# Back buttons on the G1619-05 send F20 (left) and F21 (right) by default, not the
# 0/9 that upstream gpd2 expects. Desktops treat F20/F21 as mic mute and touchpad
# toggle, so map them to the Horipad Steam back paddles (M1/M2) instead.
#
# Install: copy to /etc/inputplumber/capability_maps.d/ and restart inputplumber.
version: 1
kind: CapabilityMap
name: GPD WinMax2 G1619-05
id: gpd_g1619_05

mapping:
  - name: Left Paddle
    source_events:
      - keyboard: KeyF20
    target_event:
      gamepad:
        button: LeftPaddle1
  - name: Right Paddle
    source_events:
      - keyboard: KeyF21
    target_event:
      gamepad:
        button: RightPaddle1

filtered_events: []
```

## Troubleshooting

- **No composite device created:** check the model with
  `cat /sys/class/dmi/id/product_name` (must be `G1619-05`) and the pad's USB path with
  `grep -A4 'X-Box 360 pad"' /proc/bus/input/devices` (the `P: Phys=` line must be
  `usb-0000:<bus>:00.0-3/input0`; the bus number varies between boots and is wildcarded). A BIOS update or a different kernel can change the rest;
  edit `matches` / `phys_path` in the config to the new values, then restart the service.
- **Gyro moves the wrong way:** replace the `mount_matrix` values with the commented
  alternative in the config, then `sudo systemctl restart inputplumber`.
- **Undo everything:**
  `sudo systemctl disable --now inputplumber && sudo rm /etc/inputplumber/devices.d/50-gpd_winmax2_g1619-05.yaml /etc/inputplumber/capability_maps.d/gpd_g1619-05.yaml`
