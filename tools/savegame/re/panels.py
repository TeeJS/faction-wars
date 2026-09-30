import rx, re, pickle
VTS = [0x65bc40,0x65bc08,0x65bbd0,0x65bb88,0x65bb40,0x65baf8,0x65bab0,0x65ba68,0x65ba20,0x65b9d8,0x65b990,0x65b948,0x65b900,0x65b8b8,0x65b870,0x65b828,0x65b7e0,0x65b798,0x65b758,0x65b710,0x65b6c8,0x65b680,0x65b638,0x65b5f0,0x65b5a8,0x65b568,0x65b520,0x65b4d8,0x65b490,0x65b450,0x65b408,0x65b3c8,0x65b380,0x65b338,0x65b2f0,0x65b2a8,0x65b260,0x65b218,0x65b1d0,0x65b188,0x65b140,0x65b0f8,0x65b0b0]
def const_ret(f):
    b = rx.body(f)
    for i in b[:4]:
        m = re.match(r'eax, (0x[0-9a-f]+|\d+)$', i.op_str)
        if i.mnemonic == 'mov' and m: return int(m.group(1), 0)
    return None
rows = []
for vt in VTS:
    t = const_ret(rx.u32(vt + 0xc))
    rows.append((t, vt, rx.u32(vt + 8), rx.u32(vt + 4)))
rows.sort(key=lambda r: (r[0] is None, r[0]))
for t, vt, sv, ld in rows:
    print(hex(t) if t is not None else None, hex(vt), 'save', hex(sv), 'load', hex(ld))
pickle.dump(rows, open('panels.pkl', 'wb'))
