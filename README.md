# InputPlumber config: GPD Win Max 2 (G1619-05) as a Steam Deck controller with gyro

An [InputPlumber](https://github.com/ShadowBlip/InputPlumber) composite device config
that turns the built-in controls of the **GPD Win Max 2 (DMI model `G1619-05`)** into a
single virtual **Steam Deck controller**, so Steam Input gets buttons, sticks, back
buttons **and gyro** from one device.

> [!WARNING]
> **AI-generated.** The config, install script and documentation in this repository
> were written with the help of an AI assistant (Claude, by Anthropic). They have been
> tested on one GPD Win Max 2 (G1619-05) and work there, but have not been reviewed by
> the InputPlumber maintainers. Read `install.sh` and the config before running anything
> with `sudo`, and use at your own risk. No warranty is provided.

## Why this exists

InputPlumber ships `50-gpd_winmax2.yaml`, but it only matches model `G1619-04` and
that unit's USB paths. On `G1619-05` it never activates, so the built-in pad shows up
as a plain Xbox 360 controller with no gyro. This config fixes the match.

## What gets combined

| Part | Kernel device | ID |
|---|---|---|
| Built-in gamepad | evdev `Microsoft X-Box 360 pad` (`xpad`), phys `usb-0000:*:00.0-3/input0` | USB `045e:028e` |
| Back buttons / mode keys | evdev `  Mouse for Windows`, phys `usb-0000:*:00.0-4/input{0,1}` | USB `2f24:0135` |
| IMU | IIO `bmi260` (`i2c-BMI0260:00`) | Bosch BMI260 |

Output: a virtual `Valve Corporation Steam Controller` (`28de:1205`, Steam Deck),
plus InputPlumber keyboard and mouse devices. The two back buttons (which send F20/F21) become the Steam Deck's left and right back paddles.

## Requirements

- GPD Win Max 2 with `cat /sys/class/dmi/id/product_name` = `G1619-05`
- InputPlumber 0.81.0 or newer (tested on CachyOS, kernel 7.2)

## Install

```sh
sudo ./install.sh
```

or by hand:

```sh
sudo pacman -S inputplumber
sudo install -Dm644 config/50-gpd_winmax2_g1619-05.yaml /etc/inputplumber/devices.d/50-gpd_winmax2_g1619-05.yaml
sudo install -Dm644 config/gpd_g1619-05.yaml /etc/inputplumber/capability_maps.d/gpd_g1619-05.yaml
sudo systemctl enable --now inputplumber
sudo systemctl restart inputplumber
```

## Verify

```sh
journalctl -u inputplumber -b | grep -E "Creating CompositeDevice|Detected IMU"
grep -A1 "Vendor=28de Product=1205" /proc/bus/input/devices
```

Expect `Creating CompositeDevice with config: GPD WinMax2 G1619-05`,
`Detected IMU: bmi260`, and a `Valve Corporation Steam Controller` input device.
Then test the gyro in Steam: Settings > Controller > Steam Deck controller > gyro calibration.

## Troubleshooting

- **Nothing happens:** your USB paths may differ. Check
  `grep -A4 'X-Box 360 pad"' /proc/bus/input/devices` and update `phys_path` in the
  config to the `P: Phys=` value, then restart the service.
- **Gyro is inverted:** swap `mount_matrix` for the commented alternative in the config.
- **Uninstall:**
  `sudo systemctl disable --now inputplumber && sudo rm /etc/inputplumber/devices.d/50-gpd_winmax2_g1619-05.yaml /etc/inputplumber/capability_maps.d/gpd_g1619-05.yaml`

## Files

- `config/50-gpd_winmax2_g1619-05.yaml`: the composite device config
- `config/gpd_g1619-05.yaml`: capability map turning the F20/F21 back buttons into Steam back paddles
- `capture-keys.py`: prints which keys reach InputPlumber's virtual keyboard (run with sudo)
- `install.sh`: installs the package and config, starts the service
- `REINSTALL.md`: step-by-step rebuild guide with the config embedded
- `devices.md`: hardware discovery notes
- `install-hhd.sh`, `verify-hhd.sh`, `config/hhd/10-tdp-fan-only.conf`: optional Handheld Daemon for TDP and fan curve only (see `hhd.md`)
- `hhd.md`: why and how hhd runs next to InputPlumber

## Credits

Based on the upstream GPD Win Max 2 config from
[ShadowBlip/InputPlumber](https://github.com/ShadowBlip/InputPlumber).
