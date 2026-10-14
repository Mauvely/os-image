#!/usr/bin/env python3
"""qmp-type.py <socket> <text>   type text on the VM console (US layout), then Enter."""
import json, socket, sys, time
s = socket.socket(socket.AF_UNIX); s.connect(sys.argv[1])
f = s.makefile("rw"); f.readline()
def call(cmd, args=None):
    f.write(json.dumps({"execute": cmd, **({"arguments": args} if args else {})}) + "\n"); f.flush()
    while True:
        r = json.loads(f.readline())
        if "return" in r or "error" in r: return r
call("qmp_capabilities")
PLAIN = {" ": "spc", "-": "minus", "=": "equal", "/": "slash", ".": "dot", ",": "comma", ";": "semicolon",
         "\\": "backslash", "'": "apostrophe", "[": "bracket_left", "]": "bracket_right", "\n": "ret"}
SHIFT = {"_": "minus", "+": "equal", ">": "dot", "<": "comma", ":": "semicolon", "|": "backslash", "*": "8",
         "(": "9", ")": "0", "&": "7", "$": "4", "\"": "apostrophe", "{": "bracket_left", "}": "bracket_right",
         "!": "1", "@": "2", "#": "3", "%": "5", "^": "6", "?": "slash"}
for ch in sys.argv[2] + "\n":
    keys = []
    if ch in PLAIN: keys = [PLAIN[ch]]
    elif ch in SHIFT: keys = ["shift", SHIFT[ch]]
    elif ch.isupper(): keys = ["shift", ch.lower()]
    else: keys = [ch]
    call("send-key", {"keys": [{"type": "qcode", "data": k} for k in keys]}); time.sleep(0.04)
