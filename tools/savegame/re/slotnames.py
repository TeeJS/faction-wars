import rx, re, slot, allsetters, collections, sys
def slot_names(vtab, n=400):
    out = {}
    for k in range(n):
        f = slot.slot(vtab, k)
        if not f: break
        b = rx.body(f, 0x200)
        if len(b) > 60: continue
        strs = []
        for i in b:
            if i.mnemonic == 'push' and re.match(r'0x6[ab][0-9a-f]{4}$', i.op_str):
                s = rx.cstr(int(i.op_str, 16))
                if s and re.match(r'^\(?[A-Za-z][A-Za-z0-9]+\)?$', s): strs.append(s.strip('()'))
        short = [s for s in strs if not s.endswith('Notif')]
        if short: out[k * 4] = short[0]
    return out
S = allsetters.scan()
def fields(vtab, lo=0, hi=1 << 32):
    names = slot_names(vtab)
    res = collections.defaultdict(set)
    for f, stores, slots in S:
        if not (lo <= f < hi): continue
        for s in slots[:1]:
            if s in names:
                for m, w, off in stores[:1]:
                    res[(w, int(off, 16))].add(names[s])
    return names, res
if __name__ == '__main__':
    vtab = int(sys.argv[1], 16)
    names, res = fields(vtab)
    print('slot names:', {hex(k): v for k, v in sorted(names.items())})
    for (w, off), nm in sorted(res.items(), key=lambda x: x[0][1]):
        print(f'  {w:5} +{off:#x}: {sorted(nm)}')
