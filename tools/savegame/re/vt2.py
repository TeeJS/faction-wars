import rx, vt, struct, re, pickle, os
def vt_starts():
    cache = 'vtstarts.pkl'
    if os.path.exists(cache): return pickle.load(open(cache, 'rb'))
    runs = vt.vtables()
    lo = min(runs); addrs = set()
    for va, s in runs.items():
        for k in range(len(s)): addrs.add(va + 4 * k)
    # scan .text for 'mov dword ptr [reg(+disp)], imm32' encodings: C7 /0 imm32 ; just scan all imm32 equal to a run address
    v, vs, r, rs, n = rx.TEXT
    starts = {}
    D = rx.DATA
    for i in range(r, r + rs - 4):
        x = struct.unpack_from('<I', D, i)[0]
        if x in addrs:
            starts.setdefault(x, []).append(v + (i - r))
    pickle.dump(starts, open(cache, 'wb'))
    return starts
def split():
    runs = vt.vtables(); st = vt_starts()
    out = {}
    for va, s in runs.items():
        cuts = sorted(a for a in st if va <= a < va + 4 * len(s))
        if not cuts or cuts[0] != va: cuts = [va] + cuts
        for k, c in enumerate(cuts):
            e = cuts[k + 1] if k + 1 < len(cuts) else va + 4 * len(s)
            out[c] = s[(c - va) // 4:(e - va) // 4]
    return out
if __name__ == '__main__':
    V = split(); print(len(V))
