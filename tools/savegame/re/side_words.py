import rx, re, bisect
st = rx.func_starts()
res = []
for k, f in enumerate(st):
    end = st[k + 1] if k + 1 < len(st) else f + 0x400
    if end - f > 0x3000: end = f + 0x3000
    o = rx.off(f)
    if o is None: continue
    offs = set()
    lines = []
    for ins in rx.md.disasm(rx.DATA[o:o + (end - f)], f):
        m = re.search(r'\[(e[a-z]{2}) \+ 0x(7[048c]|8[04])\]', ins.op_str)
        if m and m.group(1) not in ('esp', 'ebp'):
            offs.add(m.group(2)); lines.append(f'{ins.address:x} {ins.mnemonic} {ins.op_str}')
    if {'7c', '80'} <= offs and len(offs) >= 3:
        res.append((f, sorted(offs), lines[:8]))
for f, offs, lines in res:
    print(hex(f), offs); [print('    ', l) for l in lines]
