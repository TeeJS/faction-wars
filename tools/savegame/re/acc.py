"""find tiny accessor functions: read/write [ecx+OFF] and return"""
import rx, re, sys
def accessors(lo, hi):
    out = []
    for f in sorted(rx.xrefs()):
        if not (lo <= f < hi): continue
        b = rx.body(f, 0x40)
        if len(b) > 6: continue
        ops = [(i.mnemonic, i.op_str) for i in b]
        txt = '; '.join(f'{m} {o}' for m, o in ops)
        m = re.findall(r'\[ecx \+ (0x[0-9a-f]+)\]', txt)
        if m and ops[-1][0] == 'ret':
            out.append((f, txt, len(rx.callers(f))))
    return out
if __name__ == '__main__':
    lo, hi = int(sys.argv[1], 16), int(sys.argv[2], 16)
    for f, t, n in accessors(lo, hi): print(f'{f:#x} [{n:3}] {t}')
