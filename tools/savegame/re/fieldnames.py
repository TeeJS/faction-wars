"""Name object fields: setter (store [this+OFF], fire vtable slot) -> slot chain -> notification name."""
import rx, re, slot, notifs, cg, functools
G = cg.callgraph()
NOTIF = {a: s for a, s in notifs.notif}
# short names pushed next to the Notif string
def names_in(f):
    out = []
    for i in rx.body(f, 0x300):
        if i.mnemonic == 'push' and i.op_str.startswith('0x'):
            v = int(i.op_str, 16)
            if v in NOTIF: out.append(NOTIF[v])
    return out
@functools.lru_cache(None)
def reach(vtab, f, depth=4):
    """notification names reachable from function f, following this-vcalls through vtab"""
    got = names_in(f)
    if got or depth == 0: return tuple(got)
    b = rx.body(f, 0x400)
    res = []
    for i in b:
        if i.mnemonic == 'call':
            m = re.match(r'dword ptr \[e[a-d]x \+ (0x[0-9a-f]+)\]$', i.op_str)
            if m:
                g = slot.slot(vtab, int(m.group(1), 16) // 4)
                if g: res += reach(vtab, g, depth - 1)
            elif i.op_str.startswith('0x'):
                t = int(i.op_str, 16)
                if t not in (0x53fcf0, 0x4f8980): res += reach(vtab, t, depth - 1)
        if len(res) > 6: break
    return tuple(res)
SETTER = re.compile(r'(?:dword|word|byte) ptr \[e(?:si|di|bx|cx) \+ (0x[0-9a-f]+)\], ')
def setters(lo, hi):
    """functions in [lo,hi) that store [this+OFF] and then call a vtable slot"""
    out = []
    for f in sorted(G):
        if not (lo <= f < hi): continue
        b = rx.body(f, 0x200)
        if len(b) > 90: continue
        store = None; slots = []
        for i in b:
            m = SETTER.match(i.op_str) if i.mnemonic == 'mov' else None
            if m and store is None: store = (m.group(1), i.op_str.split(' ptr')[0])
            mv = re.match(r'dword ptr \[e[a-d]x \+ (0x[0-9a-f]{3})\]$', i.op_str) if i.mnemonic == 'call' else None
            if mv and store: slots.append(int(mv.group(1), 16))
        if store and slots: out.append((f, store, slots))
    return out
if __name__ == '__main__':
    import sys
    vtab = int(sys.argv[1], 16); lo = int(sys.argv[2], 16); hi = int(sys.argv[3], 16)
    for f, (off, width), slots in setters(lo, hi):
        names = []
        for s in slots:
            g = slot.slot(vtab, s // 4)
            if g: names += reach(vtab, g)
        print(f'{f:#x} {width:5} +{off:6} slots {[hex(s) for s in slots]} -> {sorted(set(names))}')
