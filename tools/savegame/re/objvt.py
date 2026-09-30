import rx, re, pickle, collections
def vt_chain(f, depth=0, seen=None):
    """vtable constants stored to [reg] in the factory, its ctor and the ctor's callees (2 levels), in order"""
    seen = seen or set(); out = []
    if f in seen or depth > 2: return out
    seen.add(f)
    for i in rx.body(f):
        m = re.match(r'dword ptr \[(e\w\w)\], (0x[0-9a-f]+)$', i.op_str)
        if i.mnemonic == 'mov' and m and 0x650000 <= int(m.group(2), 16) < 0x6a0000: out.append(int(m.group(2), 16))
        if i.mnemonic == 'call' and i.op_str.startswith('0x'):
            t = int(i.op_str, 16)
            if t not in (0x618b70, 0x619730): out += vt_chain(t, depth + 1, seen)
    return out
def save_of(fac):
    vts = vt_chain(fac)
    if not vts: return None, None
    vt = vts[-1]
    return vt, rx.u32(vt + 8)
if __name__ == '__main__':
    pairs = pickle.load(open('obj_factories.pkl', 'rb'))
    rows = []
    for mid, fac in pairs:
        vt, sv = save_of(fac)
        rows.append((mid, fac, vt, sv))
        print(hex(mid), hex(fac), hex(vt) if vt else None, hex(sv) if sv else None)
    pickle.dump(rows, open('obj_rows.pkl', 'wb'))
