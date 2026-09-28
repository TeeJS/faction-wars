import rx, sys, classes
from wtrace import PRIM
SKIP = set(PRIM) | {0x5f2f50, 0x5f2ff0, 0x583c40, 0x5f35b0, 0x5f30d0, 0x618b60}
def show(f, seen, depth, maxdepth, out):
    if f in seen: out.append(f'    (see {f:#x})'); return
    seen.add(f)
    out.append(f'======== {f:#x}  [{len(rx.callers(f))} callers]')
    sub = []
    for i in rx.body(f):
        m, o = i.mnemonic, i.op_str
        if m == 'nop' or (m == 'add' and o.startswith('esp')): continue
        tag = ''
        if m == 'call' and o.startswith('0x'):
            t = int(o, 16)
            if t in PRIM: tag = '   <<< ' + PRIM[t]
            elif t not in SKIP:
                if classes.writes(t, 4): sub.append(t); tag = '   <<< (writes)'
                else: tag = '   (no-write)'
        out.append(f'{i.address:08x}  {m:6} {o}{tag}')
    if depth < maxdepth:
        for t in sub: show(t, seen, depth + 1, maxdepth, out)
if __name__ == '__main__':
    out = []; seen = set(int(x, 16) for x in sys.argv[3:])
    show(int(sys.argv[1], 16), seen, 0, int(sys.argv[2]), out); print('\n'.join(out))
