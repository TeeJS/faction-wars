import rx, re, pickle, collections
pairs = pickle.load(open('uimsg_factories.pkl', 'rb'))
def vtable_of(factory):
    """the last constant stored to [reg] in the factory or the ctor it calls (one level)"""
    found = None
    for depth, f in enumerate([factory]):
        for i in rx.dis(f, 200, True):
            m = re.match(r'dword ptr \[(e\w\w)\], (0x[0-9a-f]+)$', i.op_str)
            if i.mnemonic == 'mov' and m: found = int(m.group(2), 16)
            if i.mnemonic == 'call' and found is None:
                try:
                    t = int(i.op_str, 16)
                except ValueError:
                    continue
                for j in rx.dis(t, 200, True):
                    m2 = re.match(r'dword ptr \[(e\w\w)\], (0x[0-9a-f]+)$', j.op_str)
                    if j.mnemonic == 'mov' and m2: found = int(m2.group(2), 16)
    return found
rows = []
for mid, fac in pairs:
    vt = vtable_of(fac)
    slots = [rx.u32(vt + 4 * k) for k in range(6)] if vt and rx.off(vt) else []
    rows.append((mid, fac, vt, slots))
pickle.dump(rows, open('uimsg_rows.pkl', 'wb'))
by = collections.defaultdict(list)
for mid, fac, vt, slots in rows:
    by[slots[2] if len(slots) > 2 else None].append(hex(mid))
for save, ids in sorted(by.items(), key=lambda x: -len(x[1])):
    print(hex(save) if save else None, len(ids), ids[:12])
