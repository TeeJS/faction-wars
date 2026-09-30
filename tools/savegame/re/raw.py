import rx, sys
SKIP = ('push', 'pop')
for a in sys.argv[1:]:
    f = int(a, 16)
    print('=====', hex(f))
    for i in rx.body(f):
        if i.mnemonic in SKIP and i.op_str in ('esi', 'edi', 'ebx', 'ebp', 'ecx'): continue
        if i.mnemonic == 'add' and i.op_str.startswith('esp'): continue
        print(f'  {i.address:08x}  {i.mnemonic:6} {i.op_str}')
