import rx, vt, cg, collections
G = cg.callgraph(); VT = vt.vtables()
W = {0x5f4db0:'W32',0x5f4d00:'W32',0x5f4970:'W32t',0x5f4df0:'W16',0x5f4c60:'W16',0x5f4e30:'W32o',0x5f4c90:'W32o',0x5f3590:'WSTR',0x5f3560:'WSTR',0x5f4d30:'WSTR',0x5f4eb0:'WSTR',0x5f4d70:'WMARK',0x5f4e70:'W8',0x5f4cc0:'W8'}
def writes(f, depth=3, seen=None):
    seen = seen or set()
    if f in seen or f not in G: return False
    seen.add(f)
    for c in G[f]['calls']:
        if isinstance(c, int):
            if c in W: return True
            if depth and writes(c, depth - 1, seen): return True
    return False
def const_ret(f):
    b = rx.body(f, 0x40)
    if len(b) <= 3 and b[0].mnemonic == 'mov' and b[0].op_str.startswith('eax, 0x') and b[-1].mnemonic == 'ret':
        return int(b[0].op_str.split(',')[1], 16)
    if len(b) <= 3 and b[0].mnemonic == 'mov' and b[0].op_str.startswith('eax, ') and b[0].op_str[5:].isdigit():
        return int(b[0].op_str[5:])
    return None
rows = []
for va, s in sorted(VT.items()):
    if len(s) > 7 and writes(s[6]):
        rows.append((va, len(s), const_ret(s[1]), s[6], s[7] if len(s) > 7 else None))
if __name__ == '__main__':
    print(len(rows))
    for va, n, c, s18, s1c in rows:
        print(f'vt {va:#x} n={n:3} +4={c if c is None else hex(c)} save(+18)={s18:#x} +1c={s1c:#x}')
