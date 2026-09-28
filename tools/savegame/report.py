"""Readable report of a parsed save, using the Star Wars pack for names.

    python report.py SAVEGAME.001
"""
import sys, json, os, collections
import rebsave

PACK = os.path.join(os.path.dirname(__file__), '..', '..', 'packs', 'star-wars-rebellion')
def load(name): return json.load(open(os.path.join(PACK, name), encoding='utf-8'))

planets = {p['source_id']: p for p in load('map.json')['planets']}
chars = {c['source_id']: c for c in load('characters.json')['characters']}
units = {}
for u in load('units.json')['units']:
    if 'source_family_id' in u: units[(u['source_family_id'], u['source_id'])] = u
facils = {}
for f in load('facilities.json')['facilities']:
    if 'source_family_id' in f: facils[(f['source_family_id'], f['source_id'])] = f

def walk(o, parent=None, out=None):
    out = [] if out is None else out
    o['parent'] = parent; out.append(o)
    for k in o['children']: walk(k, o, out)
    return out

def system_of(o):
    while o and o['class'] not in (0x90, 0x92): o = o['parent']
    return o

def sysname(o):
    s = system_of(o)
    return planets.get(s['template'], {}).get('display_name', s['template']) if s else '-'

def label(o):
    c = o['class']
    if (c, o['template']) in units: return units[(c, o['template'])]['id']
    if (c, o['template']) in facils: return facils[(c, o['template'])]['id']
    if o['template'] in chars and 0x30 <= c <= 0x38: return chars[o['template']]['id']
    return o.get('name', f'{c:#x}/{o["template"]}')

def main(path):
    r, g = rebsave.parse(open(path, 'rb').read())
    objs = walk(g['views'][0])
    side = {1: 'Alliance', 2: 'Empire'}.get(g['header']['side'], '?')
    print(f"{g['name']!r}  player {side}  day {g['game']['day']}  sub-tick {g['game']['sub_tick']}")

    print('\n== Systems: ownership and loyalty')
    by = collections.defaultdict(list)
    for o in objs:
        if o['class'] in (0x90, 0x92): by[rebsave.owner(o['control_kind'])].append(o['loyalty'])
    for k, v in sorted(by.items()):
        print(f'  {k:8} {len(v):3} systems, loyalty min {min(v)} avg {sum(v) / len(v):.0f} max {max(v)}')
    pop = [(o, 'populated' in rebsave.bits(o['system_flags'], rebsave.SYSTEM_FLAGS)) for o in objs if o['class'] in (0x90, 0x92)]
    agree = sum(1 for o, p in pop if p == planets.get(o['template'], {}).get('starts_inhabited'))
    print(f'  "populated" flag matches pack starts_inhabited on {agree} of {len(pop)} systems')
    bad = [o for o in objs if o['class'] in (0x90, 0x92) and (o['energy_allocated'] > o['energy'] or o['raw_material_allocated'] > o['raw_material'])]
    print(f'  systems with allocated > total: {len(bad)}')

    print('\n== Fleets (real ones)')
    for o in objs:
        if o['class'] == 0x08 and 'name' in o:
            ships = collections.Counter(label(k) for k in o['children'])
            st = rebsave.bits(o['status'], rebsave.BASE_STATUS)
            move = f"enroute, eta {o['eta']}" if 'enroute' in st else 'at'
            print(f"  {o['name']:10} {rebsave.owner(o['control_kind']):8} {move} {sysname(o):14} flags {rebsave.bits(o['fleet_flags'], rebsave.FLEET_FLAGS)} {dict(ships)}")

    print('\n== Characters')
    for o in objs:
        if 0x30 <= o['class'] <= 0x38:
            f = rebsave.bits(o['character_flags'], rebsave.CHARACTER_FLAGS) + rebsave.bits(o['role_flags'], rebsave.ROLE_FLAGS)
            print(f"  {label(o):22} {rebsave.owner(o['control_kind']):8} at {sysname(o):14} dip {o['base_diplomacy']:3}/{o['enhanced_diplomacy']:3} "
                  f"esp {o['base_espionage']:3} com {o['base_combat']:3}/{o['enhanced_combat']:3} lead {o['base_leadership']:3} "
                  f"loy {o['base_loyalty']:3} force {o['force']:3} inj {o['injury']} {f}")

    print('\n== Production (non-empty managers)')
    for o in objs:
        if o['class'] in (0xa0, 0xa2, 0xa4) and o['remaining_count']:
            print(f"  {sysname(o):14} {o['product_name']:28} x{o['remaining_count']} points {o['completed_points']}/{o['required_points']} (total {o['total_required_points']})")

    print('\n== Sides')
    for o in objs:
        if o['class'] == 0xf3:
            print(f"  {rebsave.owner(o['control_kind']):8} maint {o['maint_state']} required {o['maint_required']} "
                  f"R&D order ship/troop/facil {o['shipyard_rd_order']}/{o['training_facil_rd_order']}/{o['construction_yard_rd_order']} "
                  f"done {o['shipyard_rd_done']}/{o['training_facil_rd_done']}/{o['construction_yard_rd_done']} recruit {o['recruitment_done']} victory {o['victory_conditions']}")

    print('\n== Timers by code')
    c = collections.Counter(hex(e['code']) for e in g['queue_a8'])
    print('  ', dict(sorted(c.items())))
    days = [e['fire_day'] for e in g['queue_a8'] if 'fire_day' in e]
    if days: print(f"  fire days {min(days)}..{max(days)} (today {g['game']['day']})")

if __name__ == '__main__':
    main(sys.argv[1])
