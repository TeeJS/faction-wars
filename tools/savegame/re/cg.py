import rx, pickle, os
def callgraph():
    cache = 'cg.pkl'
    if os.path.exists(cache): return pickle.load(open(cache, 'rb'))
    starts = set(t for t, cs in rx.xrefs().items() if any(k == 'call' for _, k in cs))
    import vt
    for va, slots in vt.vtables().items(): starts.update(slots)
    G = {}
    for f in sorted(starts):
        try: b = rx.body(f, 0x6000)
        except Exception: continue
        calls = []
        for i in b:
            if i.mnemonic == 'call':
                calls.append(int(i.op_str, 16) if i.op_str.startswith('0x') else i.op_str)
        G[f] = dict(end=b[-1].address + b[-1].size if b else f, calls=calls)
    pickle.dump(G, open(cache, 'wb'))
    return G
if __name__ == '__main__':
    G = callgraph(); print(len(G))
