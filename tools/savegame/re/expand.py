import rx, sys
from wtrace import PRIM
SKIP = set(PRIM) | {0x5f2f50, 0x5f2ff0, 0x583c40, 0x5f35b0, 0x5f30d0, 0x618b60, 0x5f50e0}
NAMES = {0x5f50e0: 'count16'}
def show(f, seen, depth, maxdepth):
    if f in seen: print(f'    (see {f:#x})'); return
    seen.add(f)
    print(f'======== {f:#x}  [{len(rx.callers(f))} callers]')
    sub = []
    for i in rx.body(f):
        m, o = i.mnemonic, i.op_str
        if m == 'nop' or (m == 'add' and o.startswith('esp')): continue
        tag = ''
        if m == 'call' and o.startswith('0x'):
            t = int(o, 16)
            if t in PRIM: tag = '   <<< ' + PRIM[t]
            elif t in NAMES: tag = '   <<< ' + NAMES[t]
            elif t not in SKIP: sub.append(t)
        print(f'{i.address:08x}  {m:6} {o}{tag}')
    if depth < maxdepth:
        for t in sub: show(t, seen, depth + 1, maxdepth)
if __name__ == '__main__':
    seen = set(int(x, 16) for x in sys.argv[3:])
    show(int(sys.argv[1], 16), seen, 0, int(sys.argv[2]) if len(sys.argv) > 2 else 3)
