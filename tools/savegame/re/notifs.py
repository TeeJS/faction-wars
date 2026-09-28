import rx, re, vt
d = rx.DATA
v, vs, r, rs, n = [s for s in rx.SECS if s[4] == '.data'][0]
notif = [(v + m.start(), m.group().decode()) for m in re.finditer(rb'[A-Za-z0-9]+Notif(?=\x00)', d[r:r+rs])]
RUNS = vt.vtables()
where = {}
for va, s in RUNS.items():
    for k, f in enumerate(s): where.setdefault(f, []).append(va + 4 * k)
rows = []
for a, s in notif:
    for ref in rx.imm_refs(a):
        f = rx.func_of(ref)
        # event id pushed near the reference
        b = rx.body(f, 0x200)
        ids = [i.op_str for i in b if i.mnemonic == 'push' and re.match(r'0x[0-9a-f]{2,3}$', i.op_str)]
        rows.append((s, f, ids[:3], len(rx.callers(f)), where.get(f, [])[:3]))
if __name__ == '__main__':
    for s, f, ids, nc, w in rows:
        print(f'{s:48} fn {f:#x} ids {ids} callers {nc} in-vtable {[hex(x) for x in w]}')
