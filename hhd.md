# Plan: Handheld Daemon for TDP and fan only

Goal: hhd sets TDP and the fan curve; InputPlumber keeps the controller and gyro.

## Findings (2026-10-05, CachyOS, hhd 4.1.12 source)

- hhd is not installed yet. CachyOS repo has `hhd` 4.1.12 (adjustor is bundled in it;
  the separate `adjustor` 4.0.1 package is not needed) and `hhd-ui` 3.4.2.
- hhd knows this model: `G1619-05` is in its GPD controller list (`hhd/device/gpd/win`)
  and is **not** marked untested, so its controller emulation would start by default
  and fight InputPlumber for the pad, back buttons and IMU.
- TDP: adjustor maps `G1619-05` to its SMU driver (28 W max), which writes through
  `/proc/acpi/call`. The `acpi_call` module is not installed; `acpi_call-dkms` builds
  it for both installed kernels (the repo's `acpi_call` targets Arch's `linux` only).
- Fan: the `gpd_fan` module is loaded and exposes hwmon `gpdfan` with `pwm1`, which
  adjustor's fan curve supports.
- `power-profiles-daemon` is installed but disabled; keep it off so it doesn't fight hhd.

## How controller handling is disabled

hhd reads `HHD_PLUGINS`, a comma-separated whitelist of plugin providers. Setting it to
`adjustor` skips every other provider: `gpd_win` (controllers), `generic`, `overlay`,
`powerbuttond`, `rgb` and the rest. The `plugins.yml` blacklist is not used because in
4.1.x it only logs and does not skip.

Drop-in: `config/hhd/10-tdp-fan-only.conf` -> `/etc/systemd/system/hhd.service.d/`.

Trade-off: no hhd gamescope overlay (that lives in the `overlay` plugin, which also reads
controllers). TDP and fan are set from the hhd-ui desktop app instead.

## Steps

1. `sudo ./install-hhd.sh`
2. `./verify-hhd.sh`
3. Re-test gyro in Steam, then set TDP/fan in hhd-ui.

Full manual steps are in REINSTALL.md.

## Verified 2026-10-05

After `install-hhd.sh`: hhd log shows `Skipping provider 'gpd_win' due to whitelist` and
`Found plugin providers: adjustor` (smu, smu_qam, battery, ppd loaded). `acpi_call` is loaded,
`hhdctl get` shows `tdp.qam.tdp=15` and the `tdp.qam.fan` curve (mode `disabled` = firmware
fan control until changed). InputPlumber still creates the G1619-05 composite device with
IMU `bmi260` and the virtual Valve Steam Controller.
