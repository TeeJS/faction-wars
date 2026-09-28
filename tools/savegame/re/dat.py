import struct, os
GD = r'C:\Program Files (x86)\GOG Galaxy\Games\Star Wars - Rebellion\GData'
SIZES = {'CAPSHPSD':200,'FIGHTSD':168,'TROOPSD':68,'SPECFCSD':116,'MJCHARSD':148,'MNCHARSD':148,
 'SYSTEMSD':44,'SECTORSD':36,'DEFFACSD':60,'MANFACSD':56,'PROFACSD':56,'MISSNSD':112,'FLEETSD':24,
 'ALLFACSD':52,'UNIQUESD':24,'ABODESD':24,'BASICSD':24,'MANMGRSD':24}
def load():
    out = {}
    for n, sz in SIZES.items():
        b = open(os.path.join(GD, n + '.DAT'), 'rb').read()
        f1, cnt, fam, f4 = struct.unpack_from('<4I', b, 0)
        recs = []
        for i in range(cnt):
            o = 16 + i * sz
            rid, f2, pf, npf, rfam, txt, f7 = struct.unpack_from('<5I2H', b, o)
            recs.append(dict(id=rid, fam=rfam, txt=txt, raw=b[o:o+sz]))
        out[n] = dict(fam=fam, f4=f4, recs=recs, total=len(b), expect=16+cnt*sz)
    return out
if __name__ == '__main__':
    d = load()
    for n, v in d.items():
        fams = sorted(set(r['fam'] for r in v['recs']))
        ids = [r['id'] for r in v['recs']]
        print(f"{n:9} hdrfam={v['fam']:#x} n={len(ids):3} size_ok={v['total']==v['expect']} fams={[hex(x) for x in fams]} ids={min(ids):#x}..{max(ids):#x}")
