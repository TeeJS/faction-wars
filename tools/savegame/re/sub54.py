import rx, vt2, classes, re
V = vt2.split()
VS = set(V)
def vt_imms(f, depth=2, seen=None):
    """vtable addresses written as immediates in f and callees"""
    seen = seen if seen is not None else set()
    if f in seen: return []
    seen.add(f); out = []
    for i in rx.body(f, 0x800):
        for m in re.findall(r'0x[0-9a-f]+', i.op_str):
            v = int(m, 16)
            if v in VS and i.mnemonic == 'mov' and i.op_str.startswith('dword ptr ['): out.append((i.address, v))
        if depth and i.mnemonic == 'call' and i.op_str.startswith('0x'):
            out += vt_imms(int(i.op_str, 16), depth - 1, seen)
    return out
if __name__ == '__main__':
    import classes2
    for c, va, n, s18, s1c in sorted(classes2.rows):
        s = V[va]
        fac = s[0xe8 // 4] if len(s) > 0xe8 // 4 else None
        res = vt_imms(fac) if fac else []
        last = res[-1][1] if res else None
        sv = V[last][2] if last and len(V[last]) > 2 else None
        print(f'class {c:#04x} factory={fac and hex(fac)} vtables={[hex(v) for a,v in res]} -> sub vt {last and hex(last)} save(+8)={sv and hex(sv)}')
