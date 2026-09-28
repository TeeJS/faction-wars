import rx, slot, re, sys
def vt_accessors(vt, n=200):
    out = []
    for k in range(n):
        f = slot.slot(vt, k)
        if not f: break
        b = rx.body(f, 0x80)
        if len(b) > 12: continue
        txt = '; '.join(f'{i.mnemonic} {i.op_str}' for i in b)
        if re.search(r'\[ecx \+ 0x', txt) or re.search(r'\[e[a-d]x \+ 0x', txt):
            out.append((k, f, txt))
    return out
if __name__ == '__main__':
    for k, f, t in vt_accessors(int(sys.argv[1], 16)):
        print(f'slot {k:3} (+{k*4:#05x}) {f:#x}: {t}')
