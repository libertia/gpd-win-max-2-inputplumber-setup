# InputPlumber device discovery (2026-10-04)

Goal: have InputPlumber combine the Xbox-style gamepad and the IMU into one
virtual controller that Steam Input sees with gyro.

## TL;DR

- **InputPlumber is not installed.** No binary, no `inputplumber.service`, so no
  DBus tree to inspect. Package is available: `cachyos-extra-znver4/inputplumber 0.81.0-1.1`
  (also `extra/inputplumber 0.81.0-1`).
- **Machine:** GPD, `product_name=G1619-05` (GPD Win Max 2, newer revision).
- **Gamepad:** the built-in GPD controller, which presents as an Xbox 360 pad
  (`045e:028e`, driver `xpad`) on `/dev/input/event17`.
- **IMU:** Bosch BMI260 on I2C (`i2c-BMI0260:00`) at `/sys/bus/iio/devices/iio:device0`.
- **Upstream config will NOT auto-match this machine.** InputPlumber ships
  `50-gpd_winmax2.yaml`, but it matches only `product_name: G1619-04`, and its
  gamepad/keyboard `phys_path`s are `usb-0000:{74,65,73}:00.3-*`, while this unit
  uses `usb-0000:ca:00.0-*`. The IMU match (`bmi260` / `i2c-BMI0260:00`) would work.
  A local override in `/etc/inputplumber/devices.d/` with `G1619-05` and the
  `ca:00.0` phys paths will be needed (not done; nothing changed on the system).

## Devices as the kernel sees them

### Built-in gamepad (Xbox 360 mode)

| Field | Value |
|---|---|
| evdev name | `Microsoft X-Box 360 pad` |
| evdev node | `/dev/input/event17` (also `js0`) |
| phys_path | `usb-0000:ca:00.0-3/input0` |
| USB ID | `045e:028e`, iProduct "Game for windows", serial `7592665E` |
| USB location | bus 3, port 3 (`3-3:1.0`), PCI `0000:ca:00.0` (AMD 151f xHCI) |
| driver | `xpad` |
| ID_PATH | `pci-0000:ca:00.0-usb-0:3:1.0` |

### Built-in keyboard/mouse (back buttons / mode keys)

| Field | Value |
|---|---|
| evdev name | `  Mouse for Windows` (two leading spaces) |
| nodes | `event4` (mouse, `usb-0000:ca:00.0-4/input0`), `event5` (kbd, `usb-0000:ca:00.0-4/input1`) |
| USB ID | `2f24:0135` |
| hidraw | `hidraw0`, `hidraw1`, `hidraw2` |

### IMU

| Field | Value |
|---|---|
| IIO device | `/sys/bus/iio/devices/iio:device0` → `/dev/iio:device0` (root-only, 0600) |
| name | `bmi260` |
| sysfs path | `/sys/devices/platform/AMDI0010:02/i2c-2/i2c-BMI0260:00/iio:device0` |
| drivers loaded | `bmi260_i2c`, `bmi260_core` (also `bmi270_*` loaded, unused) |
| accel | 100 Hz, scale 0.002394 m/s² per LSB |
| gyro (anglvel) | 200 Hz, scale 0.001065 rad/s per LSB |
| mount matrix | none exposed in sysfs or hwdb |
| sample at rest | accel x=69 y=-973 z=-3981 (≈ -9.5 m/s² on Z, device lying flat); gyro ≈ 0 |

No mount matrix means axis orientation will have to come from InputPlumber's own
handling for this device (upstream GPD configs don't set one either) and should
be checked once running.

## Other controllers present

- **Flydigi VADER4** (`04b4:2412`, USB via hub, `event261`/`js2`, mouse `event262`,
  `hidraw11`–`14`). External controller, not part of the built-in pad. Ignore unless
  you meant this one.
- **Steam virtual pads**: `Microsoft X-Box 360 pad 0/1` (`28de:11ff`, `event268`,
  `event269`). These are created by the running Steam client, not real hardware.
- Keychron K10 HE and Keychron Link also expose joystick nodes (`js1`, `js3`); irrelevant.

## Upstream config reference

`raw/upstream-50-gpd_winmax2.yaml` is the current upstream Win Max 2 config.
It groups the Xbox pad + "Mouse for Windows" keyboard + `bmi260` IIO into one
composite device, targets `xbox-elite`, `mouse`, `keyboard`, and uses capability map
`gpd2`. For Steam Input with gyro the target would normally be switched to a
Steam Deck / DualSense style target (e.g. `deck` or `ds5`) since `xbox-elite`
carries no motion.

## Raw output (in `raw/`)

- `pkg.txt`, `systemctl-status.txt`: install / service check
- `lsusb.txt`, `proc-input-devices.txt`, `hidraw.txt`, `iio.txt`, `modules.txt`
- `details.txt`: DMI, `lsusb -v` for the pads, USB tree, udev properties, IIO values
- `upstream-50-gpd_winmax2.yaml`, `upstream-50-gpd_win4.yaml`: upstream configs for comparison

## Composite config for Steam controller + gyro

`config/50-gpd_winmax2_g1619-05.yaml` matches DMI `G1619-05`, groups the Xbox 360 pad
(`usb-0000:ca:00.0-3/input0`), both "Mouse for Windows" interfaces and the `bmi260` IIO
into one composite device, and emulates a **Steam Deck controller** (`deck`) plus
mouse and keyboard. It reuses upstream capability map `gpd2`.

Not installed yet. To install (needs root, changes the system):

    sudo pacman -S inputplumber
    sudo install -Dm644 config/50-gpd_winmax2_g1619-05.yaml /etc/inputplumber/devices.d/50-gpd_winmax2_g1619-05.yaml
    sudo systemctl enable --now inputplumber

Then check `busctl tree org.shadowblip.InputPlumber` shows a CompositeDevice with the
pad and IIO sources, and use Steam > Settings > Controller > Calibration to test gyro.
If gyro axes are mirrored, swap in the commented mount matrix in the config.

## Installed and verified (2026-10-04)

InputPlumber v0.81.0 is running with the local config. `CompositeDevice0` holds
`/dev/input/event17` (pad), `event4`/`event5` (GPD keys) and `/dev/iio:device0` (BMI260,
sampled at 200 Hz), and exposes a virtual "Valve Corporation Steam Controller"
(`28de:1205`, Steam Deck). Log excerpt in `raw/after-install.txt`.
