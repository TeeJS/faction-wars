"""Reader for Star Wars: Rebellion save games (SaveGame\\SAVEGAME.nnn).

The grammar is transcribed from the game's own save code in REBEXE.EXE (GOG
build, sha256 b3fe3997...ed6ab). Every rule names the function it mirrors.
Field names come from the exe's own property strings (see SAVEGAME-FORMAT.md,
"How fields were named"); a name like f48 means the field is not named yet.
Read-only: nothing here writes a save.

    python rebsave.py SAVEGAME.001            # parse, check every marker
    python rebsave.py SAVEGAME.001 --json     # dump the parsed game as JSON
"""
import struct, sys, json

class SaveError(Exception):
    pass

class Reader:
    def __init__(self, data):
        self.b = data; self.pos = 0; self.marks = 0
    def u32(self):
        if self.pos + 4 > len(self.b): raise SaveError(f'u32 past end at {self.pos:#x}')
        v = struct.unpack_from('<I', self.b, self.pos)[0]; self.pos += 4; return v
    def u16(self):
        v = struct.unpack_from('<H', self.b, self.pos)[0]; self.pos += 2; return v
    def s(self):                                   # 0x5f38f0: u16 length + bytes
        n = self.u16(); v = self.b[self.pos:self.pos + n]; self.pos += n
        return v.decode('latin1')
    def mark(self, what):                          # 0x5f4d70: the u32 is its own offset
        at = self.pos; v = self.u32()
        if v != at: raise SaveError(f'marker expected at {at:#x} ({what}), found {v:#x}')
        self.marks += 1
    def n(self, k): return [self.u32() for _ in range(k)]
    def rec(self): return self.n(2)                # 0x5402e0: timer record (counter, arm word)
    def fields(self, o, spec):
        """spec: space-separated names, each read as u32; 'name:16' reads a u16"""
        for f in spec.split():
            name, _, kind = f.partition(':')
            o[name] = self.u16() if kind == '16' else self.u32()

# ------------------------------------------------------------------ bit names

BASE_STATUS = ['usable', 'created', 'completed', 'destroyed', 'enroute', 'enroute_active', 'existing',
               'observed_by_alliance', 'observed_by_empire', 'damaged', None, 'hyperdrive_active',
               'autorouting', 'autoscrap_request', 'locked', 'ready_for_delete', 'constructed', 'deployed']
SYSTEM_FLAGS = ['populated', 'explored', 'uprising', 'never_been_controlled', 'battle', 'blockade',
                'bombard', 'assault', 'garrisoned', 'suppressing', 'combat_unit_fast_repair',
                'death_star_nearby', 'battle_pending', 'loyalty_caused_current_control_kind',
                'battle_pending_caused_current_blockade', None, 'uprising_incident', 'informant_incident',
                'disaster_incident', 'resource_incident', 'blockade_and_battle_pending_management_required']
ROLE_FLAGS = ['decoy', 'moving_between_missions', 'mission_remove_request', 'mission_resign_request',
              'can_resign_from_mission', 'is_decoying', 'adrift', 'on_mission', 'on_hidden_mission',
              'on_mandatory_mission']
CHARACTER_FLAGS = ['captured', 'can_heal', 'fast_heal', None, 'force_aware', 'force_potential', 'healing',
                   'discovering_force_user', 'can_escape', 'escape_request', 'escape_attempt']
MISSION_FLAGS = ['ready_for_next_phase', 'implied_team', 'mandatory']
FACILITY_FLAGS = ['suspended', 'point_present', 'point_processed', 'processing', 'on_startup_cycle']
FLEET_FLAGS = [None, None, None, None, 'battle', 'blockade', 'bombard', 'assault']
COMBAT_FLAGS = ['under_repair', 'fast_repair']

def bits(v, names):
    return [n for i, n in enumerate(names) if n and v >> i & 1]

def owner(control_kind):                           # +0x24 bits 6-7 (0x4f71d0 family)
    return {1: 'alliance', 2: 'empire', 3: 'neutral'}.get(control_kind >> 6 & 3, 'none')

def copy_of(control_kind):                         # +0x24 bits 4-5
    return {0: 'master', 1: 'alliance', 2: 'empire'}.get(control_kind >> 4 & 3, '?')

# ------------------------------------------------------------------ game objects

def base(r, o):                                    # 0x4f9450 GameObj::Save
    o['serial'] = r.u32()                          # +0x18
    o['control_kind'] = r.u32()                    # +0x24  owner bits 6-7, copy bits 4-5
    o['template'] = r.u32()                        # +0x2c -> +0x18, the .DAT id
    if r.u32(): o['name'] = r.s()                  # +0x34
    r.fields(o, 'status builder destination_at_departure counts eta f48 f4c')
    # +0x50 status bits; +0x38/+0x3c keys; +0x40 bytes: destroyed_reason, deployment_count,
    # destination_count; +0x44 ETA
    return (o['control_kind'] & 0x30) == 0         # master copy: state block follows

# state blocks, [obj+0x54], master copy only: timer records and their parameters
def st_base(r):                                    # 0x553fa0
    return {'s04': r.u32(), 's08': r.u32(), 's0c': r.u32(), 'rec10': r.rec()}
def st_fighter(r):                                 # 0x58b280
    s = st_base(r); s['rec18'] = r.rec(); return s
def st_capship(r):                                 # 0x558740
    s = st_fighter(r); s.update(zip(('s20', 's24', 's28'), r.n(3))); return s
def st_facility(r):                                # 0x5846b0 (timer 0x394 uses rec18, min delay s20)
    s = st_base(r); s['rec18'] = r.rec(); s['s20'] = r.u32(); s['s24'] = r.u32(); return s
def st_character(r):                               # 0x5408e0
    s = st_base(r)
    for k in ('rec18', 'rec20', 'rec28'): s[k] = r.rec()
    s['s30'] = r.u32(); s['s34'] = r.u32(); return s
def st_mission(r):                                 # 0x583720 (timers 0x38b rec20, 0x38c rec28)
    s = st_base(r); s['s18'] = r.u32(); s['s1c'] = r.u32()
    s['rec20'] = r.rec(); s['rec28'] = r.rec(); s['s30'] = r.u32(); return s
def st_system(r):                                  # 0x55a3b0
    s = st_base(r)
    for k in ('rec18', 'rec20', 'rec28', 'rec30', 'rec38', 'rec40'): s[k] = r.rec()
    s['per_side'] = [r.n(3) for _ in range(3)]     # (+0x48, +0x54, +0x68) + 4*i
    r.fields(s, 's60 s64 s74 s78 s7c s80'); return s
def st_manager(r):                                 # 0x5838f0
    s = st_base(r); s['refs'] = reflist(r, 'manager'); return s

def reflist(r, where, size=2):                     # 0x4f5710: count + nodes (vf+0x14)
    n = r.u32()                                    # node 0x65d1f0 = key + value (0x4f5c20)
    if size is None and n:                         # global node 0x65ca50 = key (0x4ece10)
        raise SaveError(f'{where}: non-empty list ({n}) at {r.pos:#x} - node class not decoded yet')
    return [r.n(size) for _ in range(n)]

def role(r, o):                                    # 0x534d20 (Role)
    r.fields(o, 'base_diplomacy:16 base_espionage:16 base_shipyard_rd:16 base_training_facil_rd:16 '
                'base_construction_yard_rd:16 base_combat:16 base_leadership:16 base_loyalty:16 '
                'mission mission_seed parent_at_mission_completion location_at_mission_completion role_flags')

def mission(r, o):                                 # 0x523910
    r.fields(o, 'user_id user_id2 task_status completion_status phase origin_location objective '
                'target target_location leader leader_seed')
    for k in ('team', 'decoys', 'captives', 'members'): o[k] = reflist(r, 'mission')
    o['mission_flags'] = r.u32()                   # +0xa4

def f3_list(r):                                    # 0x583b90; node 0x66a0e0 = 0x583d80
    a = r.u32(); n = r.u32()
    return [a, [r.n(3) for _ in range(n)]]

CLASSES = {}
def cls(codes, state):
    def deco(fn):
        for c in codes: CLASSES[c] = (fn, state)
        return fn
    return deco

@cls([0x08], st_base)
def fleet(r, o, m): o['fleet_flags'] = r.u32()                  # 0x4fef70
@cls([0x10], st_base)
def troop(r, o, m): r.fields(o, 'detector_flags troop_flags withdraw_percent')   # 0x5046d0
@cls([0x14, 0x18], st_capship)
def capship(r, o, m): r.fields(o, 'detector_flags combat_flags hull_damage allocations')  # 0x501f40
@cls([0x1c], st_fighter)
def fighter(r, o, m): r.fields(o, 'detector_flags combat_flags squad_size_damage')  # 0x503660
@cls([0x20, 0x22, 0x23, 0x24, 0x25], st_base)
def defence(r, o, m): pass                                      # 0x526be0
@cls([0x28, 0x29, 0x2a], st_facility)
def manufacturing(r, o, m): r.fields(o, 'proc_state etc proc_flags')   # 0x53aba0
@cls([0x2c, 0x2d], st_facility)
def production(r, o, m):                                        # 0x55acf0
    manufacturing(r, o, m); r.fields(o, 'f64 f68 production_modifier')
@cls([0x30, 0x34, 0x35, 0x38], st_character)
def character(r, o, m):                                         # 0x4ef940
    role(r, o)
    r.fields(o, 'enhanced_diplomacy:16 enhanced_espionage:16 enhanced_shipyard_rd:16 '
                'enhanced_training_facil_rd:16 enhanced_construction_yard_rd:16 enhanced_combat:16 '
                'enhanced_leadership:16 enhanced_loyalty:16 force:16 force_experience:16 '
                'force_training:16 leadership_adjustment:16 injury:16 command_kind:16 character_state:16 '
                'mission_hyperdrive_modifier:16 encounter traitor_discovered force_user_discovered '
                'commanding character_flags')
@cls([0x31, 0x32, 0x33], st_character)
def character_b(r, o, m): character(r, o, m); o['fb0'] = r.u32()   # 0x5728b0
@cls([0x3c], st_base)
def special_force(r, o, m): role(r, o)                          # 0x503f60
@cls([0x41, 0x42, 0x43, 0x44, 0x51, 0x54, 0x56, 0x57, 0x61, 0x62, 0x63, 0x64, 0x65, 0x69, 0x6a, 0x72, 0x73], st_mission)
def mission_plain(r, o, m): mission(r, o)
@cls([0x52, 0x55, 0x58, 0x71], st_mission)
def mission_1(r, o, m): mission(r, o); o['fa8'] = r.u32()       # 0x5730e0, 0x5750b0
@cls([0x53], st_mission)
def mission_2(r, o, m): mission(r, o); r.fields(o, 'fa8 fac')   # 0x56cb80
@cls([0x80, 0x98, 0xf2], st_base)
def plain(r, o, m): pass                                        # 0x4f29d0
@cls([0x90, 0x92], st_system)
def system(r, o, m):                                            # 0x50e4e0
    r.fields(o, 'loyalty energy energy_allocated raw_material raw_material_allocated smuggling_percent '
                'production_modifier troop_reg_withdraw_percent system_flags control_kinds '
                'troop_reg_surplus troop_reg_required control_data')
@cls([0xa0, 0xa2, 0xa4], st_manager)
def manager(r, o, m):                                           # 0x52a510 (ManuMgr)
    r.fields(o, 'remaining_count completed_points overflow_points seed_key required_points '
                'total_required_points reserved product_key deployment_key target_key')
    o['product_name'] = r.s()
@cls([0xf1], st_base)
def galaxy(r, o, m):                                            # 0x518ef0
    if m: o['x'] = r.n(4 + 8 + 1 + 6 + 1)
@cls([0xf3], st_base)
def side(r, o, m):                                              # 0x531020
    o['maint_state'] = [r.n(2) for _ in range(3)]               # (capacity, allocated)
    # material ON HAND: mines add 1 raw (0x530670), refineries 1 refined (0x5307e0);
    # the waiting counts are the lengths of the two queues after them
    r.fields(o, 'maint_required f74 raw_material refined_material raw_waiting refined_waiting')
    o['raw_waiters'] = f3_list(r); o['refined_waiters'] = f3_list(r)
    r.fields(o, 'f90 f94 f98 shipyard_rd_order training_facil_rd_order construction_yard_rd_order fa8 '
                'shipyard_rd_done training_facil_rd_done construction_yard_rd_done recruitment_done '
                'victory_conditions fc0 fc4')
    a = r.u32(); n = r.u32(); o['lc8'] = [a, [r.n(3) for _ in range(n)]]   # 0x4f41c0 / 0x540bb0
    o['rec_cc'] = r.rec(); o['rec_d4'] = r.rec()
@cls([0xf8], st_base)
def uniq_f8(r, o, m): o['f58'] = r.u32(); o['rec5c'] = r.rec(); o['rec64'] = r.rec()   # 0x549f00
@cls([0xf9], st_base)
def uniq_f9(r, o, m): o['rec58'] = r.rec(); o['rec60'] = r.rec()                      # 0x5570f0
@cls([0xfa], st_base)
def uniq_fa(r, o, m):                                           # 0x562200
    o['f58'] = r.u32()
    if m: o['f5c'] = r.u32()

def obj(r, code):
    fn, state = CLASSES.get(code, (None, None))
    if fn is None: raise SaveError(f'unknown class code {code:#x} at {r.pos - 4:#x}')
    o = {'class': code, 'at': r.pos}
    master = base(r, o)
    if master: o['state'] = state(r)
    fn(r, o, master)
    o['children'] = children(r)
    return o

def children(r):                                   # 0x53a350 child walker
    kids = []
    if not r.u32(): return kids                    # has a child list
    r.u32()                                        # list +0x0c
    n = r.u32()                                    # child count
    if n: r.mark('children')
    for _ in range(n):
        kids.append(obj(r, r.u32()))               # class code (vf+4), then Save
    return kids

# ------------------------------------------------------------------ scheduler

def event(r):                                      # queue node: code (vf+0x24), then Save (vf+0xc)
    e = {'code': r.u32()}
    r.fields(e, 'e18 e1c target')                  # 0x54f080: target key +0x3c
    e['context'] = r.n(6)                          # 0x4fd540 (+0x20)
    c = e['code']
    if 0x380 <= c <= 0x394:                        # timers, 0x586360
        e['fire_day'] = r.u32(); e['record'] = r.rec()
    elif 0x300 <= c <= 0x31d or c in (0x320, 0x321):   # 0x594bd0 + 0x586470 / 0x586660
        r.fields(e, 'e40 e44 e48 e4c e50')
    elif c in (0x370, 0x371, 0x372): pass          # 0x577920
    elif c == 0x373: e['fire_day'] = r.u32()       # 0x562e00
    elif c == 0x3f0: e['fire_day'] = r.u32(); e['x'] = r.n(3)   # 0x5802f0
    else: raise SaveError(f'unknown event code {c:#x} at {r.pos - 4:#x}')
    return e

def eventlist(r):                                  # 0x54eb80
    return [event(r) for _ in range(r.u32())]

def typed_list(r, where):                          # 0x536f70 / 0x568980 nodes
    n = r.u32()
    if n: raise SaveError(f'{where}: non-empty list ({n}) at {r.pos:#x} - node class not decoded yet')
    return []

# ------------------------------------------------------------------ whole file

def parse(data):
    r = Reader(data); g = {}
    g['name'] = r.s()                              # 0x411970 header
    g['header'] = dict(zip(('h0', 'h1', 'multiplayer', 'slot', 'side', 'h5'), r.n(6)))
    r.mark('root')                                 # 0x4095b0
    g['root'] = r.n(4)
    if g['root'][1] != 2: raise SaveError('not a mode-2 save')
    r.mark('settings')
    r.mark('settings body')                        # 0x41de70
    g['settings'] = r.n(7)
    r.mark('game')
    r.mark('game body')                            # 0x51d2c0
    n = r.u32(); g['strings_x'] = r.u32(); g['strings'] = [r.s() for _ in range(n)]   # 0x568a80
    game = {}
    r.fields(game, 'g04 g08 sub_tick day g14 g18 ticks_per_day tick_in_day g24 g28 g2c g30 g34 g38 '
                   'g3c g40 g44 g48 g4c')
    g['game'] = game
    g['timers'] = [r.n(5) for _ in range(3)]       # 0x539910
    r.mark('a4')
    g['a4'] = typed_list(r, 'a4')                  # 0x536f70: count, then nodes
    r.mark('queue a8')
    g['queue_a8'] = eventlist(r)                   # timers, ordered by day
    r.mark('queue ac')
    g['queue_ac'] = eventlist(r)
    r.mark('queue b0')
    g['queue_b0'] = eventlist(r)
    r.mark('b4')
    g['b4'] = [r.u32(), typed_list(r, 'b4')]       # 0x568980
    r.mark('b8')
    g['b8'] = [r.u32(), typed_list(r, 'b8')]
    r.mark('bc')
    g['bc'] = [r.u32(), reflist(r, 'bc', None)]    # 0x568c80
    r.mark('galaxy')
    g['global_list'] = reflist(r, 'global', 1)     # 0x53f610 -> 0x4f5710
    g['views'] = []
    for v in range(3):                             # 0x513df0: master, Alliance, Empire
        g['views'].append(obj(r, 0xf1))            # no class code: Save + children only
    g['one'] = r.u32()                             # constant 1
    g['tail'] = r.n(20 + 30)                       # 0x5685a0: 0x5682d0 + 3 x 0x5684c0
    r.mark('after game')                           # 0x41de70
    g['ui'] = r.n(6)                               # 0x435ec0; the rest (UI, message log) is not decoded
    return r, g

if __name__ == '__main__':
    data = open(sys.argv[1], 'rb').read()
    try:
        r, g = parse(data)
    except SaveError as e:
        print('FAILED:', e); sys.exit(1)
    if '--json' in sys.argv:
        json.dump(g, sys.stdout, indent=1)
    else:
        print('parsed to', hex(r.pos), 'of', hex(len(data)), 'markers', r.marks)
