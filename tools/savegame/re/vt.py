import rx, struct, pickle, os
TV, TS = rx.TEXT[0], rx.TEXT[1]
def is_text(v): return TV <= v < TV + TS
def vtables():
    """runs of >=4 consecutive .text pointers in .rdata, starting where the previous dword is not a text ptr"""
    cache = 'vtables.pkl'
    if os.path.exists(cache): return pickle.load(open(cache, 'rb'))
    out = {}
    for name in ('.rdata',):
        v, vs, r, rs, n = [s for s in rx.SECS if s[4] == name][0]
        words = [struct.unpack_from('<I', rx.DATA, r + i)[0] for i in range(0, rs - 3, 4)]
        i = 0
        while i < len(words):
            if is_text(words[i]):
                j = i
                while j < len(words) and is_text(words[j]): j += 1
                if j - i >= 4: out[v + 4 * i] = words[i:j]
                i = j
            else: i += 1
    pickle.dump(out, open(cache, 'wb'))
    return out
if __name__ == '__main__':
    vts = vtables()
    print(len(vts), 'vtables')
    # callers of 0x53a350 via vtable? find vtables where slot +0x18 is a function that calls WMARK or W32 wrappers
    W = {0x5f4db0, 0x5f4d00, 0x5f4970, 0x5f4df0, 0x5f4c60, 0x5f4e30, 0x5f3590, 0x5f4d70, 0x5f4e70}
    rev = {}
    for p, cs in rx.xrefs().items():
        for c, k in cs: rev.setdefault(rx.func_of(c), set()).add(p)
    n = 0
    for va, slots in sorted(vts.items()):
        if len(slots) > 6:
            s18 = slots[6]
            callees = set(t for t, cs in rx.xrefs().items() if any(s18 <= c < s18 + 0x800 for c, _ in cs))
            if callees & W:
                n += 1
    print(n)
