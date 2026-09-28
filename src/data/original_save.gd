extends RefCounted
## A Star Wars: Rebellion saved game (SaveGame\SAVEGAME.nnn), read. The grammar
## is the game's own save code in REBEXE.EXE (GOG build), transcribed and
## verified on the savegame-format branch (SAVEGAME-FORMAT.md; its Python reader
## tools/savegame/rebsave.py is this file's model, field for field): every
## self-offset marker the game writes is checked in sequence, so one wrong
## field anywhere fails the read rather than reading nonsense.
##
## Read(bytes) -> { ok, error, name, header, game, queue_a8, views: [master,
## Alliance's copy, Empire's copy], ... }. Each object is a Dictionary with its
## `class` code, the base fields (serial, control_kind, template, name, status,
## eta ...), its class's named fields, `state` (master copy only) and
## `children`. What the fields mean is SAVEGAME-FORMAT.md's "Field names".
## The UI tail after the game (open windows, the message log) is not read.
##
## Preloaded by path (as OriginalSave): a new class_name can lag the editor's
## class cache.

var _b: PackedByteArray
var _pos: int = 0
var _marks: int = 0
var _error: String = ""

const OWNERS := {1: "alliance", 2: "empire", 3: "neutral"}

# ---- bit names (SAVEGAME-FORMAT.md, from the exe's bit setters) ---------------------

const BASE_STATUS := ["usable", "created", "completed", "destroyed", "enroute", "enroute_active", "existing",
	"observed_by_alliance", "observed_by_empire", "damaged", "", "hyperdrive_active",
	"autorouting", "autoscrap_request", "locked", "ready_for_delete", "constructed", "deployed"]
const SYSTEM_FLAGS := ["populated", "explored", "uprising", "never_been_controlled", "battle", "blockade",
	"bombard", "assault", "garrisoned", "suppressing", "combat_unit_fast_repair",
	"death_star_nearby", "battle_pending", "loyalty_caused_current_control_kind",
	"battle_pending_caused_current_blockade", "", "uprising_incident", "informant_incident",
	"disaster_incident", "resource_incident", "blockade_and_battle_pending_management_required"]
const ROLE_FLAGS := ["decoy", "moving_between_missions", "mission_remove_request", "mission_resign_request",
	"can_resign_from_mission", "is_decoying", "adrift", "on_mission", "on_hidden_mission", "on_mandatory_mission"]
const CHARACTER_FLAGS := ["captured", "can_heal", "fast_heal", "", "force_aware", "force_potential", "healing",
	"discovering_force_user", "can_escape", "escape_request", "escape_attempt"]
const MISSION_FLAGS := ["ready_for_next_phase", "implied_team", "mandatory"]
const FACILITY_FLAGS := ["suspended", "point_present", "point_processed", "processing", "on_startup_cycle"]
const FLEET_FLAGS := ["", "", "", "", "battle", "blockade", "bombard", "assault"]


static func Bits(v: int, names: Array) -> Array:
	var out: Array = []
	for i in names.size():
		if not str(names[i]).is_empty() and (v >> i) & 1:
			out.append(names[i])
	return out


static func Has(v: int, names: Array, bit: String) -> bool:
	var i: int = names.find(bit)
	return i >= 0 and (v >> i) & 1 == 1


## The owner in an object's control kind (+0x24 bits 6-7): alliance, empire, neutral or none.
static func Owner(control_kind: int) -> String:
	return str(OWNERS.get((control_kind >> 6) & 3, "none"))


## An object's key as other objects refer to it: class << 24 | serial.
static func Key(o: Dictionary) -> int:
	return (int(o["class"]) << 24) | int(o["serial"])


# ---- the stream ------------------------------------------------------------------

func _u32() -> int:
	if _pos + 4 > _b.size():
		_fail("the file ends early (u32 at 0x%x)" % _pos)
		return 0
	var v: int = _b.decode_u32(_pos)
	_pos += 4
	return v


func _u16() -> int:
	if _pos + 2 > _b.size():
		_fail("the file ends early (u16 at 0x%x)" % _pos)
		return 0
	var v: int = _b.decode_u16(_pos)
	_pos += 2
	return v


func _s() -> String:                               # 0x5f38f0: u16 length + bytes
	var n: int = _u16()
	if _pos + n > _b.size():
		_fail("the file ends early (string at 0x%x)" % _pos)
		return ""
	var v := ""
	for i in n:                                    # Latin-1: one byte, one character
		v += char(_b[_pos + i])
	_pos += n
	return v


## A count of things to follow: at least 4 bytes each, so more than the file
## has left means the read has gone wrong (and would loop on garbage).
func _count(what: String) -> int:
	var n: int = _u32()
	if n * 4 > _b.size() - _pos:
		_fail("%s: a count of %d at 0x%x, more than the file holds" % [what, n, _pos - 4])
		return 0
	return n


func _mark(what: String) -> void:                  # 0x5f4d70: the u32 is its own offset
	var at: int = _pos
	var v: int = _u32()
	if v != at and _error.is_empty():
		_fail("marker expected at 0x%x (%s), found 0x%x" % [at, what, v])
	_marks += 1


func _n(k: int) -> Array:
	var out: Array = []
	for i in k:
		out.append(_u32())
	return out


func _rec() -> Array:                              # 0x5402e0: timer record (counter, arm word)
	return _n(2)


func _fields(o: Dictionary, spec: String) -> void:
	for f in spec.split(" ", false):
		var parts: PackedStringArray = f.split(":")
		o[parts[0]] = _u16() if parts.size() > 1 and parts[1] == "16" else _u32()


func _fail(why: String) -> void:
	if _error.is_empty():
		_error = why


func _ok() -> bool:
	return _error.is_empty()


# ---- game objects -------------------------------------------------------------------

func _base(o: Dictionary) -> bool:                 # 0x4f9450 GameObj::Save
	o["serial"] = _u32()                           # +0x18
	o["control_kind"] = _u32()                     # +0x24 owner bits 6-7, copy bits 4-5
	o["template"] = _u32()                         # +0x2c -> +0x18, the .DAT id
	if _u32() != 0:
		o["name"] = _s()                           # +0x34
	_fields(o, "status builder destination_at_departure counts eta f48 f4c")
	return (int(o["control_kind"]) & 0x30) == 0    # master copy: the state block follows


func _st_base() -> Dictionary:                     # 0x553fa0
	return {"s04": _u32(), "s08": _u32(), "s0c": _u32(), "rec10": _rec()}


func _st_fighter() -> Dictionary:                  # 0x58b280
	var s := _st_base()
	s["rec18"] = _rec()
	return s


func _st_capship() -> Dictionary:                  # 0x558740
	var s := _st_fighter()
	_fields(s, "s20 s24 s28")
	return s


func _st_facility() -> Dictionary:                 # 0x5846b0
	var s := _st_base()
	s["rec18"] = _rec()
	_fields(s, "s20 s24")
	return s


func _st_character() -> Dictionary:                # 0x5408e0
	var s := _st_base()
	for k in ["rec18", "rec20", "rec28"]:
		s[k] = _rec()
	_fields(s, "s30 s34")
	return s


func _st_mission() -> Dictionary:                  # 0x583720
	var s := _st_base()
	_fields(s, "s18 s1c")
	s["rec20"] = _rec()
	s["rec28"] = _rec()
	s["s30"] = _u32()
	return s


func _st_system() -> Dictionary:                   # 0x55a3b0
	var s := _st_base()
	for k in ["rec18", "rec20", "rec28", "rec30", "rec38", "rec40"]:
		s[k] = _rec()
	s["per_side"] = [_n(3), _n(3), _n(3)]
	_fields(s, "s60 s64 s74 s78 s7c s80")
	return s


func _st_manager() -> Dictionary:                  # 0x5838f0
	var s := _st_base()
	s["refs"] = _reflist("manager", 2)
	return s


func _reflist(where: String, size: int) -> Array:  # 0x4f5710: count + nodes (vf+0x14)
	var n: int = _count(where)
	var out: Array = []
	if size <= 0:
		if n > 0:
			_fail("%s: a non-empty list (%d) at 0x%x, whose node is not decoded" % [where, n, _pos])
		return out
	for i in n:
		if not _ok():
			break
		out.append(_n(size))
	return out


func _role(o: Dictionary) -> void:                 # 0x534d20
	_fields(o, "base_diplomacy:16 base_espionage:16 base_shipyard_rd:16 base_training_facil_rd:16 "
		+ "base_construction_yard_rd:16 base_combat:16 base_leadership:16 base_loyalty:16 "
		+ "mission mission_seed parent_at_mission_completion location_at_mission_completion role_flags")


func _character(o: Dictionary) -> void:            # 0x4ef940
	_role(o)
	_fields(o, "enhanced_diplomacy:16 enhanced_espionage:16 enhanced_shipyard_rd:16 "
		+ "enhanced_training_facil_rd:16 enhanced_construction_yard_rd:16 enhanced_combat:16 "
		+ "enhanced_leadership:16 enhanced_loyalty:16 force:16 force_experience:16 "
		+ "force_training:16 leadership_adjustment:16 injury:16 command_kind:16 character_state:16 "
		+ "mission_hyperdrive_modifier:16 encounter traitor_discovered force_user_discovered "
		+ "commanding character_flags")


func _mission(o: Dictionary) -> void:              # 0x523910
	_fields(o, "user_id user_id2 task_status completion_status phase origin_location objective "
		+ "target target_location leader leader_seed")
	for k in ["team", "decoys", "captives", "members"]:
		o[k] = _reflist("mission", 2)
	o["mission_flags"] = _u32()


func _f3_list() -> Array:                          # 0x583b90; node 0x66a0e0 = 0x583d80
	var a: int = _u32()
	var n: int = _count("side list")
	var nodes: Array = []
	for i in n:
		nodes.append(_n(3))
	return [a, nodes]


## The class-specific part of each object, and its state block's reader.
func _class(o: Dictionary, code: int, master: bool) -> bool:
	match code:
		0x08:                                      # fleet 0x4fef70
			if master: o["state"] = _st_base()
			o["fleet_flags"] = _u32()
		0x10:                                      # troop 0x5046d0
			if master: o["state"] = _st_base()
			_fields(o, "detector_flags troop_flags withdraw_percent")
		0x14, 0x18:                                # capital ship, Death Star 0x501f40
			if master: o["state"] = _st_capship()
			_fields(o, "detector_flags combat_flags hull_damage allocations")
		0x1c:                                      # fighter 0x503660
			if master: o["state"] = _st_fighter()
			_fields(o, "detector_flags combat_flags squad_size_damage")
		0x20, 0x22, 0x23, 0x24, 0x25:              # HQ, defences 0x526be0
			if master: o["state"] = _st_base()
		0x28, 0x29, 0x2a:                          # manufacturing facility 0x53aba0
			if master: o["state"] = _st_facility()
			_fields(o, "proc_state etc proc_flags")
		0x2c, 0x2d:                                # mine, refinery 0x55acf0
			if master: o["state"] = _st_facility()
			_fields(o, "proc_state etc proc_flags f64 f68 production_modifier")
		0x30, 0x34, 0x35, 0x38:                    # characters 0x4ef940
			if master: o["state"] = _st_character()
			_character(o)
		0x31, 0x32, 0x33:                          # characters 0x5728b0
			if master: o["state"] = _st_character()
			_character(o)
			o["fb0"] = _u32()
		0x3c:                                      # special force 0x503f60
			if master: o["state"] = _st_base()
			_role(o)
		0x41, 0x42, 0x43, 0x44, 0x51, 0x54, 0x56, 0x57, 0x61, 0x62, 0x63, 0x64, 0x65, 0x69, 0x6a, 0x72, 0x73:
			if master: o["state"] = _st_mission()
			_mission(o)
		0x52, 0x55, 0x58, 0x71:                    # 0x5730e0, 0x5750b0
			if master: o["state"] = _st_mission()
			_mission(o)
			o["fa8"] = _u32()
		0x53:                                      # 0x56cb80
			if master: o["state"] = _st_mission()
			_mission(o)
			_fields(o, "fa8 fac")
		0x80, 0x98, 0xf2:                          # sector, abode, unique 0x4f29d0
			if master: o["state"] = _st_base()
		0x90, 0x92:                                # system 0x50e4e0
			if master: o["state"] = _st_system()
			_fields(o, "loyalty energy energy_allocated raw_material raw_material_allocated "
				+ "smuggling_percent production_modifier troop_reg_withdraw_percent system_flags "
				+ "control_kinds troop_reg_surplus troop_reg_required control_data")
		0xa0, 0xa2, 0xa4:                          # build manager 0x52a510
			if master: o["state"] = _st_manager()
			_fields(o, "remaining_count completed_points overflow_points seed_key required_points "
				+ "total_required_points reserved product_key deployment_key target_key")
			o["product_name"] = _s()
		0xf1:                                      # the galaxy 0x518ef0
			if master:
				o["state"] = _st_base()
				o["x"] = _n(20)
		0xf3:                                      # a side 0x531020
			if master: o["state"] = _st_base()
			o["maint_state"] = [_n(2), _n(2), _n(2)]
			# Material ON HAND (REBEXE, 2026-09-28): a mine's finished point adds
			# 1 raw (0x530670), a refinery's 1 refined (0x5307e0); a refinery
			# takes 1 raw (0x52fb30), a factory 1 refined per point (0x52fb80),
			# a scrapped item refunds half its cost as refined (0x530270). The
			# two waiting counts are the lengths of the two queues after them:
			# refineries waiting for raw (+0x88), factories for refined (+0x8c).
			_fields(o, "maint_required f74 raw_material refined_material raw_waiting refined_waiting")
			o["raw_waiters"] = _f3_list()
			o["refined_waiters"] = _f3_list()
			_fields(o, "f90 f94 f98 shipyard_rd_order training_facil_rd_order construction_yard_rd_order fa8 "
				+ "shipyard_rd_done training_facil_rd_done construction_yard_rd_done recruitment_done "
				+ "victory_conditions fc0 fc4")
			o["lc8"] = _f3_list()                  # 0x4f41c0 / 0x540bb0: the same shape
			o["rec_cc"] = _rec()
			o["rec_d4"] = _rec()
		0xf8:                                      # 0x549f00
			if master: o["state"] = _st_base()
			o["f58"] = _u32()
			o["rec5c"] = _rec()
			o["rec64"] = _rec()
		0xf9:                                      # 0x5570f0
			if master: o["state"] = _st_base()
			o["rec58"] = _rec()
			o["rec60"] = _rec()
		0xfa:                                      # 0x562200
			if master: o["state"] = _st_base()
			o["f58"] = _u32()
			if master:
				o["f5c"] = _u32()
		_:
			_fail("an unknown kind of object (0x%x) at 0x%x" % [code, _pos - 4])
			return false
	return true


const CLASSES := [0x08, 0x10, 0x14, 0x18, 0x1c, 0x20, 0x22, 0x23, 0x24, 0x25, 0x28, 0x29, 0x2a, 0x2c, 0x2d,
	0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x38, 0x3c, 0x41, 0x42, 0x43, 0x44, 0x51, 0x52, 0x53, 0x54, 0x55,
	0x56, 0x57, 0x58, 0x61, 0x62, 0x63, 0x64, 0x65, 0x69, 0x6a, 0x71, 0x72, 0x73, 0x80, 0x90, 0x92, 0x98,
	0xa0, 0xa2, 0xa4, 0xf1, 0xf2, 0xf3, 0xf8, 0xf9, 0xfa]


func _obj(code: int) -> Dictionary:
	var o := {"class": code, "at": _pos}
	if not CLASSES.has(code):
		_fail("an unknown kind of object (0x%x) at 0x%x" % [code, _pos - 4])
		return o
	var master: bool = _base(o)
	if not _ok() or not _class(o, code, master):
		return o
	o["children"] = _children()
	return o


func _children() -> Array:                         # 0x53a350 child walker
	var kids: Array = []
	if _u32() == 0:                                # has a child list
		return kids
	_u32()                                         # list +0x0c
	var n: int = _count("children")                # child count
	if n > 0:
		_mark("children")
	for i in n:
		if not _ok():
			break
		kids.append(_obj(_u32()))                  # class code (vf+4), then Save
	return kids


# ---- the scheduler ---------------------------------------------------------------------

func _event() -> Dictionary:                       # a queue node: code (vf+0x24), then Save (vf+0xc)
	var e := {"code": _u32()}
	_fields(e, "e18 e1c target")                   # 0x54f080: target key +0x3c
	e["context"] = _n(6)                           # 0x4fd540 (+0x20)
	var c: int = int(e["code"])
	if c >= 0x380 and c <= 0x394:                  # timers, 0x586360
		e["fire_day"] = _u32()
		e["record"] = _rec()
	elif (c >= 0x300 and c <= 0x31d) or c == 0x320 or c == 0x321:
		_fields(e, "e40 e44 e48 e4c e50")          # 0x594bd0 + 0x586470 / 0x586660
	elif c >= 0x370 and c <= 0x372:
		pass                                       # 0x577920
	elif c == 0x373:
		e["fire_day"] = _u32()                     # 0x562e00
	elif c == 0x3f0:
		e["fire_day"] = _u32()                     # 0x5802f0
		e["x"] = _n(3)
	else:
		_fail("an unknown scheduled item (0x%x) at 0x%x" % [c, _pos - 4])
	return e


func _eventlist() -> Array:                        # 0x54eb80
	var out: Array = []
	var n: int = _count("queue")
	for i in n:
		if not _ok():
			break
		out.append(_event())
	return out


func _typed_list(where: String) -> Array:          # 0x536f70 / 0x568980 nodes
	var n: int = _u32()
	if n > 0:
		_fail("%s: a non-empty list (%d) at 0x%x, whose node is not decoded" % [where, n, _pos])
	return []


# ---- the whole file ------------------------------------------------------------------

func _read() -> Dictionary:
	var g := {}
	g["name"] = _s()                               # 0x411970 header
	var h: Array = _n(6)
	g["header"] = {"h0": h[0], "h1": h[1], "multiplayer": h[2], "slot": h[3], "side": h[4], "h5": h[5]}
	_mark("root")                                  # 0x4095b0
	g["root"] = _n(4)
	if _ok() and int(g["root"][1]) != 2:
		_fail("not a saved game this reader knows (mode %d)" % int(g["root"][1]))
	_mark("settings")
	_mark("settings body")                         # 0x41de70
	g["settings"] = _n(7)
	_mark("game")
	_mark("game body")                             # 0x51d2c0
	var n: int = _count("strings")
	g["strings_x"] = _u32()
	var strings: Array = []
	for i in n:
		strings.append(_s())
	g["strings"] = strings                         # 0x568a80
	var game := {}
	_fields(game, "g04 g08 sub_tick day g14 g18 ticks_per_day tick_in_day g24 g28 g2c g30 g34 g38 "
		+ "g3c g40 g44 g48 g4c")
	g["game"] = game
	g["timers"] = [_n(5), _n(5), _n(5)]            # 0x539910
	_mark("a4")
	g["a4"] = _typed_list("a4")
	_mark("queue a8")
	g["queue_a8"] = _eventlist()                   # timers, ordered by day
	_mark("queue ac")
	g["queue_ac"] = _eventlist()
	_mark("queue b0")
	g["queue_b0"] = _eventlist()
	_mark("b4")
	g["b4"] = [_u32(), _typed_list("b4")]          # 0x568980
	_mark("b8")
	g["b8"] = [_u32(), _typed_list("b8")]
	_mark("bc")
	g["bc"] = [_u32(), _reflist("bc", 0)]          # 0x568c80
	_mark("galaxy")
	g["global_list"] = _reflist("global", 1)       # 0x53f610 -> 0x4f5710
	var views: Array = []
	for v in 3:                                    # 0x513df0: master, Alliance, Empire
		if not _ok():
			break
		views.append(_obj(0xf1))                   # no class code: Save + children only
	g["views"] = views
	g["one"] = _u32()
	g["tail"] = _n(20 + 30)                        # 0x5685a0
	_mark("after game")                            # 0x41de70
	g["ui"] = _n(6)                                # 0x435ec0
	g["read_to"] = _pos
	# The players: the human's block holds the message list (its windows).
	# A tail that cannot be read loses the messages, never the game.
	if _ok() and _players:
		var at := _pos
		var marks := _marks
		g["human"] = _find_human()
		g["tail_error"] = _tail_error
		_pos = at
		_marks = marks
	return g


# ---- the players after the game (REBEXE 0x435ec0; SAVEGAME-FORMAT.md) ------------------
#
# The UI object writes its players: 1 human (0x486440), 2 remote, 3 AI
# (0x485990). The human's block is read in full; the AI's is not (its plans
# are no use here), so the human's is found as the one that ends exactly on
# the file's closing words: a word, two markers, a word, a marker.

var _tail_error := ""
## Read the players too (the message list): off for a quick check of a file.
var _players := false


func _u16v() -> int:
	return _u16()


func _u8v() -> int:
	if _pos + 1 > _b.size():
		_fail("the file ends early (u8 at 0x%x)" % _pos)
		return 0
	var v: int = _b[_pos]
	_pos += 1
	return v


## A UI message (table 0x6b2fd8): 0x51f840's five words, 0x5840d0's key, then its layout's.
func _uimsg(code: int) -> Dictionary:
	var m := {"type": code, "h": _n(5), "key": _u32()}
	if code in [1, 2, 0x600]:
		m["a"] = _n(4)                                 # 0x5394f0
	elif code in [0x500, 0x520]:
		m["title"] = _s()                              # 0x539660
		m["text"] = _s()
	elif (code >= 0x300 and code <= 0x306) or code in [0x320, 0x321, 0x340, 0x360, 0x361, 0x362, 0x370, 0x380, 0x400]:
		m["keys"] = _n(2)                              # 0x5397a0
	elif code >= 0x100 and code <= 0x231:
		m["a"] = _n(2)                                 # 0x539400
		if code == 0x1e0:
			m["keys"] = _n(4)                          # 0x43dcf0
		elif code == 0x200:
			m["key2"] = _u32()                         # 0x43c7c0
			m["x"] = _u32()
	else:
		_fail("an unknown UI message (0x%x) at 0x%x" % [code, _pos - 4])
	return m


func _msglog() -> Array:                           # 0x4bef30 -> 0x4e4eb0: groups of UI messages
	var out: Array = []
	var n: int = _count("message groups")
	for i in n:
		if not _ok():
			break
		var g := {"id": _u32(), "count": _count("messages"), "g28": _u32(), "items": []}
		for k in int(g["count"]):
			if not _ok():
				break
			g["items"].append(_uimsg(_u32()))
		out.append(g)
	return out


func _win_base() -> Array:                          # 0x4c4f30: 7 words, 5 halfwords
	return [_u32(), _u32(), _u32(), _u16v(), _u32(), _u32(), _u16v(), _u16v(), _u16v(), _u16v(), _u32(), _u32()]


## A window (prototype table 0x6b1f40). The base's third word is the tick it was
## posted; b1/b2 windows carry a title and a text, and two keys (what it is about).
func _window(t: int) -> Dictionary:
	var w := {"type": t}
	var b1 := func() -> void:                       # 0x4c4c90
		w["b0"] = _win_base()
		w["title"] = _s()
		w["text"] = _s()
		w["keys"] = _n(2)
	var b2 := func() -> void:                       # 0x4c51f0
		w["b0"] = _win_base()
		w["title"] = _s()
		w["text"] = _s()
		w["keys"] = [_u32(), _u32()]
	match t:
		1:                                          # 0x49afa0
			w["b0"] = _win_base(); w["x"] = _n(5)
			for i in 4: _reflist("window", 2)
			w["strings"] = [_s(), _s(), _s(), _s(), _s()]
		2:                                          # 0x49c040
			w["b0"] = _win_base(); w["x"] = _n(4)
			for i in 2: _reflist("window", 2)
			w["strings"] = [_s(), _s()]
		8:                                          # 0x49a2c0
			w["b0"] = _win_base(); w["strings"] = [_s(), _s()]
		3, 4, 0xc, 0x22, 0x2b, 0x13, 0x20:          # 0x48b980, 0x495e70, 0x48e820
			b1.call(); w["x"] = _n(1)
		5, 6, 7, 0xa, 0xb, 0x18, 0x19, 0x1a, 0x1c, 0x1d, 0x24, 0x25, 0x26, 0x27, 0x29, 0x2a, 0x2c, 0x2d:
			b1.call()                               # 0x499dd0
		9, 0xd, 0xe, 0x10, 0x14, 0x28:              # 0x497910, 0x495580, 0x48c490
			b1.call(); w["x"] = _n(2)
		0xf:                                        # 0x4966f0
			b1.call(); w["x"] = _n(4)
			for i in 4: _reflist("window", 2)
		0x15:                                       # 0x495090
			b2.call(); w["x"] = _n(3)
		0x1e, 0x1f:                                 # 0x48f770
			b2.call(); w["x"] = _n(1)
		0x21:                                       # 0x48be20
			b1.call(); w["x"] = _n(3)
		0x23:                                       # 0x48d460
			b2.call()
		0x16:                                       # 0x492740: a mission report asking to continue
			b1.call(); w["x"] = _n(7)
		0x17:                                       # 0x4914a0
			b1.call(); w["x"] = _n(6)
		_:
			_fail("an unknown window (0x%x) at 0x%x" % [t, _pos - 4])
	return w


func _windows() -> Array:                          # 0x437720: u16 count, (type, window)
	var out: Array = []
	var n: int = _u16v()
	for i in n:
		if not _ok():
			break
		out.append(_window(_u32()))
	return out


func _pairs16() -> void:                           # 0x5f5da0: u16 count, items of 2 words (0x5f5f80)
	var n: int = _u16v()
	for i in n:
		_n(2)


func _opt_obj() -> void:                           # a class word, then its key when non-zero
	if _u32() != 0:
		_u32()


func _player_base() -> Dictionary:                  # 0x4886d0 -> 0x48a8a0
	var p := {"side": _u32(), "p14": _u32()}
	var flag: int = _u32()
	p["p1c"] = _u32()
	if flag != 0:
		_fail("a player object (class 0x440910) this reader does not know at 0x%x" % _pos)
		return p
	_n(2)
	var n: int = _count("player list")              # 0x536f70: (type, object); type 1 = 0x440ad0
	for i in n:
		if _u32() != 1:
			_fail("a player list object this reader does not know at 0x%x" % (_pos - 4))
			return p
		_n(11)
	_n(6)
	p["key40"] = _u32()
	_u32()
	return p


func _member_list() -> void:                        # 0x435720
	_u32()
	if _u32() != 0:
		_fail("a member list this reader does not know at 0x%x" % _pos)


func _side_ui() -> void:                            # 0x4397a0
	_n(4 + 5)
	_n(4)                                           # 0x49c9f0
	for node in [124, 172]:                         # containers: systems (0x4ebd80), sectors (0x4c61d0)
		_u32()
		var n: int = _count("side records")
		if node == 124:
			for i in n:
				_n(7); _u16v(); _u16v(); _n(23)
		else:
			for i in n:
				_n(5); _u16v(); _u16v(); _u16v(); _n(36)
		_opt_obj(); _opt_obj()
	_n(31)
	_opt_obj()
	var e: int = _count("side list")                # 0x4e5210 of 0x4c5380
	for i in e:
		_n(2)
		var k: int = _count("side list items")
		_u32()
		for j in k:
			if not _ok():
				return
			_u16v(); _n(3)
	_u32()
	_u32()                                          # 0x49de40
	var p: int = _u16v()
	for i in p:
		var t: int = _u32()
		_n(6)
		match t:
			0x14: _n(4); _member_list(); _u32()     # 0x4c6c40
			0x15: _n(5); _member_list(); _u32()     # 0x4c74b0
			0x17: _n(4); _member_list()             # 0x49e310
			_: _fail("a side entry (0x%x) this reader does not know" % t)
		if not _ok():
			return
	_n(3)
	_u32(); _u8v()
	_n(2)
	var cnt: int = _count("side array")
	_n(3)
	_n(cnt)
	_n(3)
	_pairs16()


func _human() -> Dictionary:                        # 0x486440
	var h := {"base": _player_base()}
	h["h50"] = _n(2)
	h["log"] = _msglog()
	h["screen_a"] = _n(2)                           # 0x488ac0
	h["windows"] = _windows()                       # the message list
	h["windows2"] = _windows()
	_pairs16()
	_n(3)
	h["windows3"] = _windows()
	if _ok():
		_side_ui()
	return h


func _closes(at: int) -> bool:
	_pos = at
	_u32()
	_mark("after ui")
	_mark("root")
	_u32()
	_mark("end")
	return _ok() and _pos == _b.size()


## The human's block, read and proven by the file's closing words; {} with
## _tail_error set when it cannot be.
func _find_human() -> Dictionary:
	var start := _pos
	var end := _b.size() - 20
	var kept := _error
	var first: int = _u32()
	if first == 1:
		var h := _human()
		if _ok() and _u32() == 3 and _closes(end):
			return h
		_tail_error = _error if not _error.is_empty() else "the human's block does not end where the AI's begins"
		_error = kept
		return {}
	if first != 3:
		_tail_error = "the first player is of type %d" % first
		return {}
	var p := start + 4
	while p < end - 8:
		if _b.decode_u32(p) == 1:
			_pos = p + 4
			_error = ""
			var h := _human()
			if _ok() and _pos == end and _closes(end):
				_error = kept
				return h
		p += 1
	_error = kept
	_tail_error = "no block of the human's ends on the file's closing words"
	return {}


## Read a saved game. { ok, error, ... } - ok false with the reason if any part
## of the file is not what the game writes. `players`: also the human player's
## block after the game - its message list - as "human" ({} and "tail_error"
## when it cannot be read; the game itself is unaffected).
static func Read(bytes: PackedByteArray, players: bool = false) -> Dictionary:
	var r = load("res://src/data/original_save.gd").new()
	r._b = bytes
	r._players = players
	var g: Dictionary = r._read()
	g["ok"] = r._error.is_empty()
	g["error"] = r._error
	g["markers"] = r._marks
	g["read_to"] = r._pos
	return g


## Every object in a copy of the galaxy, in the game's order, as
## { o: the object, parent: the object it is under ({} for the galaxy) }.
static func Walk(o: Dictionary, parent: Dictionary = {}, out: Array = []) -> Array:
	out.append({"o": o, "parent": parent})
	for k: Dictionary in o.get("children", []):
		Walk(k, o, out)
	return out
