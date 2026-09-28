import rx, vt2, classes
V = vt2.split()
rows = []
for va, s in sorted(V.items()):
    if len(s) > 7:
        c = classes.const_ret(s[1])
        if c is not None and classes.writes(s[6]):
            rows.append((c, va, len(s), s[6], s[7]))
if __name__ == '__main__':
    for c, va, n, s18, s1c in sorted(rows):
        print(f'code {c:#04x}  vt {va:#x} n={n:3}  save={s18:#x}  load?={s1c:#x}')
