#!/usr/bin/env python3
# AI-generated (Claude, by Anthropic). Tested on one GPD Win Max 2 G1619-05; review before use. No warranty.
# The G1619-05 firmware pulses the back buttons (F20/F21) at ~25 Hz while they are
# held instead of sending one press. This grabs the GPD keyboard interface, merges
# those pulses into a single hold, and re-emits everything on a virtual keyboard
# that InputPlumber uses as its source instead.
#
# InputPlumber 0.81.0 ignores virtual devices unless their name is on a hardcoded
# whitelist, so the virtual keyboard borrows the whitelisted name "MSI WMI hotkeys".
# The config matches it by that name plus the phys below.
import select, sys, time
import evdev
from evdev import ecodes as e

SOURCE_NAME = "  Mouse for Windows"
OUT_NAME = "MSI WMI hotkeys"
OUT_PHYS = "gpd-debounce/input0"
DEBOUNCE_KEYS = {e.KEY_F20, e.KEY_F21}
# Gap between pulses is ~15-20 ms; release only after this long without a new press.
HOLD_WINDOW = 0.06


def find_source():
    for path in evdev.list_devices():
        dev = evdev.InputDevice(path)
        if dev.name == SOURCE_NAME and e.KEY_F20 in dev.capabilities().get(e.EV_KEY, []):
            return dev
        dev.close()
    return None


def main():
    src = None
    for _ in range(30):
        src = find_source()
        if src:
            break
        time.sleep(1)
    if not src:
        sys.exit(f"no '{SOURCE_NAME}' device with KEY_F20 found")
    src.grab()
    out = evdev.UInput.from_device(src, name=OUT_NAME, phys=OUT_PHYS)
    print(f"grabbed {src.path} ({src.phys}), emitting on {out.device.path}", flush=True)

    held = set()
    pending_up = {}  # key -> release deadline
    while True:
        timeout = max(0.0, min(pending_up.values()) - time.monotonic()) if pending_up else None
        r, _, _ = select.select([src.fd], [], [], timeout)
        if r:
            for ev in src.read():
                if ev.type == e.EV_KEY and ev.code in DEBOUNCE_KEYS:
                    if ev.value == 1:
                        pending_up.pop(ev.code, None)
                        if ev.code not in held:
                            held.add(ev.code)
                            out.write(e.EV_KEY, ev.code, 1)
                            out.syn()
                    elif ev.value == 0:
                        pending_up[ev.code] = time.monotonic() + HOLD_WINDOW
                    continue
                if ev.type == e.EV_SYN and ev.code == e.SYN_REPORT:
                    out.syn()
                else:
                    out.write(ev.type, ev.code, ev.value)
        now = time.monotonic()
        for code in [c for c, t in pending_up.items() if t <= now]:
            del pending_up[code]
            held.discard(code)
            out.write(e.EV_KEY, code, 0)
            out.syn()


if __name__ == "__main__":
    main()
