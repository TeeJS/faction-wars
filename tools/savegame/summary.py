"""Summarise a parsed save: objects per class in each of the three copies."""
import sys, collections, rebsave
NAMES = {0x08:'fleet',0x10:'troop',0x14:'capital ship',0x18:'death star',0x1c:'fighter',0x20:'HQ',0x22:'ion cannon',0x23:'turbolaser',
 0x24:'shield',0x25:'DS shield',0x28:'shipyard',0x29:'training fac',0x2a:'construction yd',0x2c:'mine',0x2d:'refinery',
 0x30:'major char',0x31:'major char',0x32:'major char',0x33:'major char',0x34:'major char',0x35:'major char',0x38:'minor char',
 0x3c:'special force',0x80:'sector',0x90:'system core',0x92:'system rim',0x98:'abode',0xa0:'manager a0',0xa2:'manager a2',0xa4:'manager a4',
 0xf1:'galaxy',0xf2:'uniq f2',0xf3:'side',0xf8:'uniq f8',0xf9:'uniq f9',0xfa:'uniq fa'}
def walk(o, c):
    c[o['class']] += 1
    for k in o['children']: walk(k, c)
r, g = rebsave.parse(open(sys.argv[1], 'rb').read())
print(f"{g['name']!r}: header {g['header']}  day {g['settings'][3]}  events {len(g['events'])}")
cs = []
for v in g['views']:
    c = collections.Counter(); walk(v, c); cs.append(c)
print(f"{'class':22} master alliance empire")
for k in sorted(set().union(*cs)):
    n = NAMES.get(k, 'mission' if 0x41 <= k <= 0x73 else '?')
    print(f'{k:#04x} {n:16} {cs[0][k]:6} {cs[1][k]:8} {cs[2][k]:6}')
