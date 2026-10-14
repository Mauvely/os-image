#!/usr/bin/env python3
"""qmp-type.py <socket> <text>   type lowercase letters, digits and '-' on the VM console, then Enter."""
import json, socket, sys, time
s = socket.socket(socket.AF_UNIX); s.connect(sys.argv[1])
f = s.makefile("rw"); f.readline()
def call(cmd, args=None):
    f.write(json.dumps({"execute": cmd, **({"arguments": args} if args else {})}) + "\n"); f.flush()
    while True:
        r = json.loads(f.readline())
        if "return" in r or "error" in r: return r
call("qmp_capabilities")
for ch in sys.argv[2] + "\n":
    q = "ret" if ch == "\n" else "minus" if ch == "-" else ch
    call("send-key", {"keys": [{"type": "qcode", "data": q}]}); time.sleep(0.05)
