#!/usr/bin/env python3
# Print key events from InputPlumber's virtual keyboard for 15 s.
# Run with sudo, then press each GPD back button a few times.
import os, select, struct, time, glob
FMT = 'llHHi'; SZ = struct.calcsize(FMT)
names = {}
for p in glob.glob('/sys/class/input/event*/device/name'):
    n = open(p).read().strip()
    if n in ('InputPlumber Keyboard', 'HORI CO.,LTD. HORIPAD STEAM'):
        names[os.open('/dev/input/' + p.split('/')[4], os.O_RDONLY | os.O_NONBLOCK)] = n
codes = {}
try:
    import re
    src = open('/usr/include/linux/input-event-codes.h').read()
    for m in re.finditer(r'#define\s+(KEY_\w+|BTN_\w+)\s+(0x[0-9a-fA-F]+|\d+)', src):
        codes.setdefault(int(m.group(2), 0), m.group(1))
except OSError:
    pass
print('Listening on:', sorted(set(names.values())), '- press the back buttons now (15 s)')
end = time.time() + 15
while time.time() < end:
    r, _, _ = select.select(list(names), [], [], 0.5)
    for fd in r:
        data = os.read(fd, SZ * 64)
        for i in range(0, len(data), SZ):
            sec, usec, typ, code, val = struct.unpack(FMT, data[i:i + SZ])
            if typ == 1:
                state = {0: 'up', 1: 'down', 2: 'repeat'}.get(val, val)
                print(f"{sec % 1000 + usec / 1e6:8.3f} {names[fd]}: {codes.get(code, code)} {state}", flush=True)
