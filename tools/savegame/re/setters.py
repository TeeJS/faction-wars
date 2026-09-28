import rx, re
d = rx.DATA
v, vs, r, rs, n = [s for s in rx.SECS if s[4] == '.data'][0]
inv = [(v + m.start(), m.group().decode()) for m in re.finditer(rb'Invalid [A-Za-z0-9 ]+? value!?', d[r:r+rs])]
def setter_info(f):
    """offset written after the compare in a validating setter; and the vcall slot fired"""
    b = rx.body(f, 0x300)
    offs = []; vc = []
    for i in b:
        mm = re.match(r'dword ptr \[e(si|cx|bx|di) \+ (0x[0-9a-f]+)\], e\w\w$', i.op_str)
        if i.mnemonic == 'mov' and mm: offs.append(mm.group(2))
        mw = re.match(r'word ptr \[e(si|cx|bx|di) \+ (0x[0-9a-f]+)\], \w\w$', i.op_str)
        if i.mnemonic == 'mov' and mw: offs.append('w' + mw.group(2))
        if i.mnemonic == 'call' and i.op_str.startswith('dword ptr [eax +') or (i.mnemonic == 'call' and 'dword ptr [edx +' in i.op_str):
            vc.append(i.op_str.split('+ ')[1].rstrip(']'))
    return offs, vc
rows = []
for a, s in inv:
    for ref in rx.imm_refs(a):
        f = rx.func_of(ref)
        offs, vc = setter_info(f)
        rows.append((s, f, offs, vc, len(rx.callers(f))))
if __name__ == '__main__':
    for s, f, offs, vc, nc in sorted(rows, key=lambda x: x[1]):
        print(f'{f:#x} [{nc:3}c] {s:45} writes {offs}  fires {vc}')
