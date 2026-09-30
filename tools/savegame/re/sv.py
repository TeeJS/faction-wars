import rx, sys
NAMES={0x5f4db0:'W32',0x5f4d00:'W32',0x5f4df0:'W16',0x5f3590:'WSTR',0x5f4d70:'WMARK',0x5f4e70:'W8',0x5f4c60:'W16',0x5f4970:'W32t',0x5f4e30:'W32o',0x5f4eb0:'WSTR',0x5f4d30:'WSTR',0x5f3560:'WSTR',0x5f4cc0:'W8',0x5f4c90:'W32o'}
def show(f, n=160):
    print('=====', hex(f))
    for i in rx.dis(f, n, True):
        t=i.op_str
        if i.mnemonic=='call':
            try: tgt=int(t,16); t=t+('  <'+NAMES[tgt]+'>' if tgt in NAMES else '')
            except: pass
        if i.mnemonic in ('call','lea','ret','jmp','je','jne','jle','jl','jge','jg','cmp','test','inc','dec') or ('+ 0x' in t and i.mnemonic=='mov'):
            print(f'  {i.address:08x}  {i.mnemonic:5} {t}')
for a in sys.argv[1:]: show(int(a,16))
