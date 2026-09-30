"""Save function -> field list. W32/W16/W8/WSTR on [this+off]; calls with ecx=this+off;
virtual calls; fixed loops (mov reg, N ... dec reg; jne back); conditional jumps shown."""
import rx, re, sys
from wtrace import PRIM
def gram(f, n=2000):
    ins = rx.body(f)
    out = []
    regoff = {}      # reg -> this offset held (lea reg,[this+off])
    this = {'ecx'}
    loopn = {}
    for k, i in enumerate(ins):
        m, o = i.mnemonic, i.op_str
        mm = re.match(r'(e\w\w), ecx$', o)
        if m == 'mov' and mm and k < 12: this.add(mm.group(1))
        mm = re.match(r'(e\w\w), dword ptr \[esp \+ 0x[0-9a-f]+\]$', o)
        ml = re.match(r'(e\w\w), \[(e\w\w) \+ (0x[0-9a-f]+)\]$', o)
        if m == 'lea' and ml and ml.group(2) in this: regoff[ml.group(1)] = int(ml.group(3), 16)
        if m == 'add' and re.match(r'(e\w\w), (0x[0-9a-f]+)$', o):
            r, v = o.split(', ')
            if r in this: regoff[r] = int(v, 16)
        mn = re.match(r'(e\w\w), (0x[0-9a-f]+)$', o)
        if m == 'mov' and mn and int(mn.group(2), 16) < 0x400: loopn[mn.group(1)] = int(mn.group(2), 16)
        if m == 'call':
            if o.startswith('0x'):
                t = int(o, 16)
                # which offset: the most recent lea whose reg was pushed / ecx
                off = None
                for j in range(k - 1, max(0, k - 6), -1):
                    pj = ins[j]
                    if pj.mnemonic == 'push' and pj.op_str in regoff: off = regoff[pj.op_str]; break
                    if pj.mnemonic == 'lea' and pj.op_str.startswith('ecx,'):
                        ml2 = re.match(r'ecx, \[(e\w\w) \+ (0x[0-9a-f]+)\]$', pj.op_str)
                        if ml2: off = int(ml2.group(2), 16); break
                    if pj.mnemonic == 'push' and pj.op_str in this: off = 0; break
                out.append((i.address, PRIM.get(t, hex(t)), off))
            else:
                out.append((i.address, 'VCALL ' + o, None))
        if m in ('je', 'jne', 'jl', 'jle', 'jg', 'jge', 'jb', 'ja', 'jae', 'jbe'):
            tgt = int(o, 16)
            if tgt < i.address:
                prev = ins[k - 1]
                cnt = loopn.get(prev.op_str.split(',')[0], '?') if prev.mnemonic == 'dec' else '?'
                out.append((i.address, f'LOOP back to {tgt:#x} x{cnt}', None))
            else:
                out.append((i.address, f'{m} -> {tgt:#x}', None))
        if m == 'ret': out.append((i.address, 'RET', None)); break
    return out
if __name__ == '__main__':
    for a in sys.argv[1:]:
        print('=====', a)
        for addr, what, off in gram(int(a, 16)):
            print(f'  {addr:08x} {what}' + (f' @+{off:#x}' if off is not None else ''))
