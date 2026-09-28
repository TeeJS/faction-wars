"""Compact listing of a serializer function: primitive writes/reads, calls, vcalls, branches."""
import rx, sys, re
PRIM = {0x5f4d00:'W32',0x5f4db0:'W32',0x5f4970:'W32t',0x5f4c60:'W16',0x5f4df0:'W16',0x5f4cc0:'W8',0x5f4e70:'W8',
        0x5f4c90:'W32o',0x5f4e30:'W32o',0x5f3560:'WSTRt',0x5f3590:'WSTRt',0x5f4d30:'WSTR',0x5f4eb0:'WSTR',0x5f4d70:'WMARK',
        0x5f4ce0:'R32',0x5f4d90:'R32',0x4fcdb0:'R32t',0x5f4c40:'R16',0x5f4dd0:'R16',0x5f4ca0:'R8',0x5f4e50:'R8',
        0x5f4c80:'R32o',0x5f4e10:'R32o',0x5f3530:'RSTRt',0x5f3580:'RSTRt',0x5f4d20:'RSTR',0x5f4e90:'RSTR',0x5f4d40:'RMARK',
        0x617430:'OSWRITE',0x6173b0:'ISREAD'}
def trace(f, maxlen=0x3000, show_all=False):
    ins = rx.body(f, maxlen)
    out = []
    window = []
    for i in ins:
        m, o = i.mnemonic, i.op_str
        window.append(i)
        if m == 'call':
            if o.startswith('0x'):
                t = int(o, 16)
                # find the most recent lea/push describing the field argument
                arg = ''
                for w in reversed(window[-8:-1]):
                    if w.mnemonic == 'lea' : arg = w.op_str.split(',',1)[1].strip(); break
                    if w.mnemonic == 'push' and not w.op_str.startswith('e') : arg = 'imm ' + w.op_str; break
                if t in PRIM: out.append((i.address, PRIM[t], arg))
                else: out.append((i.address, f'call {t:#x}', f'[{len(rx.callers(t))}c] ' + arg))
            else:
                out.append((i.address, 'vcall', o))
            window = []
        elif m.startswith('j') and m != 'jmp':
            out.append((i.address, m, o))
        elif m == 'jmp':
            out.append((i.address, 'jmp', o))
        elif m in ('ret',):
            out.append((i.address, 'ret', o))
        elif show_all:
            out.append((i.address, m, o))
    return out
if __name__ == '__main__':
    f = int(sys.argv[1], 16)
    for a, k, v in trace(f, show_all=len(sys.argv) > 2):
        print(f'{a:08x}  {k:10} {v}')
