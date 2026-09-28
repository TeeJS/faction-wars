import rx, re, slot, allsetters, sys
def strs(f):
    out = []
    for i in rx.body(f, 0x200):
        if i.mnemonic == 'push' and re.match(r'0x6[ab][0-9a-f]{4}$', i.op_str):
            try: out.append(rx.cstr(int(i.op_str, 16)))
            except Exception: pass
    return out
def named_slots(vtab, lo_slot=0x1bc, n=400):
    res = {}
    for k in range(lo_slot // 4, n):
        f = slot.slot(vtab, k)
        if not f: break
        b = rx.body(f, 0x200)
        if len(b) > 60: continue
        s = [x for x in strs(f) if re.match(r'^\(?[A-Za-z][A-Za-z0-9]+\)?$', x)]
        if s: res[k * 4] = s
    return res
if __name__ == '__main__':
    vtab = int(sys.argv[1], 16); lo, hi = int(sys.argv[2], 16), int(sys.argv[3], 16)
    for k, s in sorted(named_slots(vtab).items()): print(f'  notif {k:#x}: {s}')
    for f, st, sl in allsetters.scan():
        if lo <= f < hi: print(f'  setter {f:#x} fires {[hex(x) for x in sl[:2]]} stores {st[:2]}')
