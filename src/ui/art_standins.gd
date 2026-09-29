extends RefCounted
## OUR STAND-INS FOR THE ORIGINAL'S PICTURES (the plain build parity plan,
## phases 2-8; TeeJ, 2026-09-28: "why is the artwork-free version missing the
## sidebars, none of that is the original's IP, we built it", and "we will be
## adding 'generic' artwork in the future, we just need game parity for now").
## A window built in the original's look is built from its pictures; its
## layout is ours to keep, only the pictures are the original's. So for a
## player with no art set, each picture a window asks for (artwork.gd _find)
## is drawn here instead, at the size the original's has - its measured size
## and rectangles, nothing of the picture itself - in the approved palette
## (plain_icons.gd): plates and frames of our grey with their bevels and the
## openings the windows show through, buttons and tabs with our glyphs,
## selection bars in the side's colour. Every window then builds exactly as it
## does with the art.
##
## Only with no art set at all (Active): a partial or older set keeps its own
## gaps, as before. Only the pictures in Table: a window whose pictures are not
## all here stays the plain window it was. Table is the generic art's asset
## list (docs/generic-art-assets.md).
## Preloaded by path (a new class_name can lag the editor's class cache).

const PlainIcons := preload("res://src/ui/plain_icons.gd")
const LookLib := preload("res://src/ui/look.gd")

## The file-name states a picture comes in; the stand-in draws each.
const States := ["pressed", "disabled", "grey", "lit", "picked", "hover", "chosen", "off"]
const Sides := {"alliance": Color(1, 0, 0), "empire": Color(0, 1, 0)}
## The original's planet pictures: 26 of them, 37 x 37 (planet_sprites/<n>).
const PlanetSprites := 26
## A tier's star: the plus's reach from its middle, and its arms' width.
const StarReach := {"big": 7, "mid": 5, "low": 3, "none": 1}

static var _spec: Dictionary = {}
static var _made: Dictionary = {}
## Tests only: off, to see the plain windows a pack with its own look still
## uses (the WWII pack).
static var Enabled: bool = true


## Stand-ins are drawn when the pack's art sets are all absent and the pack
## has no look of its own (the WWII pack draws its screens its own way).
static func Active() -> bool:
	if not Enabled or FactionRegistry.Pack == null or LookLib.Active():
		return false
	var sets: Array = FactionRegistry.Pack.Manifest.ArtSets
	if sets.is_empty():
		return false
	for s in sets:
		if ArtLib().HasArtSet(str(s)):
			return false
	return true


static func ArtLib() -> GDScript:
	return load("res://src/ui/artwork.gd")


static func Reset() -> void:
	_made.clear()


## The stand-in for the art set's picture at `rel` (e.g. "buttons/
## msgindex_delete.pressed.png"), or null when there is none.
static func Picture(rel: String) -> Texture2D:
	if _made.has(rel):
		return _made[rel]
	var parts: PackedStringArray = rel.trim_suffix(".png").split(".")
	var state := ""
	if parts.size() > 1 and States.has(parts[parts.size() - 1]):
		state = parts[parts.size() - 1]
		parts.remove_at(parts.size() - 1)
	var base := ".".join(parts) + ".png"
	var spec: Dictionary = Table().get(base, {})
	var tex: Texture2D = null
	if not spec.is_empty():
		var img: Image = _draw(spec, state)
		if img != null:
			tex = ImageTexture.create_from_image(img)
	_made[rel] = tex
	return tex


## Every stand-in, by the art set's path (its plain state; the others follow
## from the file name). Kinds: "plate" (our grey, bevelled, with `holes` cut
## through and `wells` / `bands` drawn in), "button" (raised, a glyph; sunk
## when pressed, dimmed when disabled), "tab" (the same, the glyph in the
## side's colour when it is the one open), "icon" (a glyph on clear), "bar"
## (the side's colour).
static func Table() -> Dictionary:
	if not _spec.is_empty():
		return _spec
	var t := {}
	# ---- Phase 2: the Message Index (message_window.gd, Figs 2.38, 3.18) ----
	for side in Sides:
		var big: bool = side == "empire"
		t["windows/frame.%s.png" % side] = {"kind": "plate", "size": Vector2i(470, 331),
			"holes": [Rect2i(12, 14, 400, 306), Rect2i(0, 330, 470, 1)]}
		t["windows/msgindex_selection.%s.png" % side] = {"kind": "bar", "size": Vector2i(356, 21), "side": side}
		for b in [["msgindex_summary", "summary"], ["msgindex_post", "post"], ["msgindex_open", "open"],
				["msgindex_compose", "compose"], ["ency_close", "close"]]:
			t["buttons/%s.%s.png" % [b[0], side]] = {"kind": "button", "size": Vector2i(44, 41) if big else Vector2i(32, 31), "glyph": b[1]}
		for c in [["advice", Vector2i(37, 41)], ["fleets", Vector2i(36, 41)], ["loyalty", Vector2i(36, 41)], ["missions", Vector2i(35, 41)]]:
			t["tabs/msg_%s.%s.png" % [c[0], side]] = {"kind": "tab", "size": c[1], "glyph": c[0], "side": side}
		for c in [["advice", 15], ["fleets", 15], ["loyalty", 16], ["manufacturing", 16], ["missions", 16]]:
			t["windows/msgicon.%s.%s.png" % [c[0], side]] = {"kind": "icon", "size": Vector2i(15, c[1]), "glyph": c[0], "side": side}
	t["windows/msgindex_side.alliance.png"] = {"kind": "plate", "size": Vector2i(58, 330)}
	t["windows/msgindex_plate.png"] = {"kind": "plate", "size": Vector2i(400, 306),
		"bands": [Rect2i(11, 74, 373, 20)], "wells": [Rect2i(11, 95, 373, 194)]}
	t["windows/ency_topic_plate.png"] = {"kind": "plate", "size": Vector2i(400, 306)}
	t["buttons/msgindex_select_all.png"] = {"kind": "button", "size": Vector2i(56, 20), "glyph": "select_all"}
	t["buttons/msgindex_delete.png"] = {"kind": "button", "size": Vector2i(56, 20), "glyph": "delete"}
	t["buttons/decision_ok.png"] = {"kind": "button", "size": Vector2i(51, 35), "glyph": "ok"}
	t["buttons/decision_cancel.png"] = {"kind": "button", "size": Vector2i(51, 35), "glyph": "cancel"}
	t["buttons/msgsummary_up.png"] = {"kind": "button", "size": Vector2i(19, 15), "glyph": "up"}
	t["buttons/msgsummary_down.png"] = {"kind": "button", "size": Vector2i(19, 15), "glyph": "down"}
	t["buttons/scroll_up.png"] = {"kind": "button", "size": Vector2i(13, 9), "glyph": "up"}
	t["buttons/scroll_down.png"] = {"kind": "button", "size": Vector2i(13, 9), "glyph": "down"}
	# The thumb is its top, as many middles as it takes, and its bottom: one bar.
	t["buttons/scroll_thumb_top.png"] = {"kind": "plate", "size": Vector2i(13, 6), "edges": "top"}
	t["buttons/scroll_thumb_mid.png"] = {"kind": "plate", "size": Vector2i(13, 12), "edges": "sides"}
	t["buttons/scroll_thumb_bottom.png"] = {"kind": "plate", "size": Vector2i(13, 6), "edges": "bottom"}
	for c in [["all", Vector2i(36, 41)], ["chat", Vector2i(35, 41)], ["conflict", Vector2i(36, 41)], ["defense", Vector2i(34, 41)],
			["manufacturing", Vector2i(36, 41)], ["resources", Vector2i(36, 41)]]:
		t["tabs/msg_%s.png" % c[0]] = {"kind": "tab", "size": c[1], "glyph": c[0]}
	for c in ["chat", "conflict", "defense", "resources"]:
		t["windows/msgicon.%s.png" % c] = {"kind": "icon", "size": Vector2i(15, 15), "glyph": c}
	# ---- Phase 3: the sector window (sector_window.gd, manual p025 Fig 2.8) ----
	# The corner cells: each glyph in its own corner of the cell (measured:
	# manufacturing top-left, fleet top-right, defenses bottom-left, mission
	# bottom-right), a pixel larger when hovered.
	var cells := {
		"manufacturing": [Vector2i(27, 18), Rect2i(1, 1, 11, 8), "manufacturing"],
		"fleet": [Vector2i(28, 18), Rect2i(10, 0, 17, 9), "fleets"],
		"defenses": [Vector2i(27, 19), Rect2i(1, 9, 10, 9), "defense"],
		"mission": [Vector2i(28, 19), Rect2i(16, 7, 11, 11), "missions"],
	}
	for glyph in cells:
		var sides: Array = Sides.keys() + (["neutral"] if glyph == "manufacturing" or glyph == "defenses" else [])
		for side in sides:
			t["icons/%s.%s.png" % [glyph, side]] = {"kind": "corner", "size": cells[glyph][0], "box": cells[glyph][1], "glyph": cells[glyph][2], "side": side}
	for side in Sides:
		t["icons/enroute.%s.png" % side] = {"kind": "icon", "size": Vector2i(20, 20), "glyph": "enroute", "side": side}
	t["icons/uprising.png"] = {"kind": "icon", "size": Vector2i(20, 20), "glyph": "uprising", "side": "uprising"}
	for b in [["title_close", "close"], ["title_minimize", "minimize"], ["title_system", "system"], ["sector_switch", "switch"]]:
		t["buttons/%s.png" % b[0]] = {"kind": "button", "size": Vector2i(14, 14), "glyph": b[1]}
	for n in range(1, PlanetSprites + 1):
		t["planet_sprites/%d.png" % n] = {"kind": "planet", "size": Vector2i(37, 37), "n": n}
	for side in ["alliance", "empire", "neutral", "unexplored"]:
		for tier in ["big", "mid", "low", "none"]:
			t["gid/%s.%s.png" % [side, tier]] = {"kind": "star", "size": Vector2i(15, 15), "side": side, "tier": tier}
	# ---- Phase 4: the Status window (original_ui.gd StatusPlate; manual p064) ----
	# The plate per side: the field list (3,12) 228 x 247, the picture panel
	# (242,15) 130 x 98 and the name panel (242,131) 130 x 55 (measured); the
	# Encyclopedia button beside the close diamond.
	for side in Sides:
		t["windows/status_plate.%s.png" % side] = {"kind": "plate", "size": Vector2i(379, 272),
			"wells": [Rect2i(3, 12, 228, 247), Rect2i(242, 15, 130, 98), Rect2i(242, 131, 130, 55)]}
	t["buttons/status_encyclopedia.png"] = {"kind": "button", "size": Vector2i(32, 31), "glyph": "encyclopedia"}
	# The picture panel's own pictures (122 x 50): a fleet's, a damaged fleet's,
	# and the grey spotlight a regiment stands in.
	for side in Sides:
		t["windows/status_fleet.%s.png" % side] = {"kind": "icon", "size": Vector2i(122, 50), "glyph": "fleets", "side": side}
		t["windows/status_fleet_damage.%s.png" % side] = {"kind": "icon", "size": Vector2i(122, 50), "glyph": "fleets", "side": "uprising"}
	t["windows/status_fleet_damage.png"] = {"kind": "icon", "size": Vector2i(122, 50), "glyph": "fleets", "side": "uprising"}
	t["windows/status_backdrop.troops.png"] = {"kind": "spot", "size": Vector2i(122, 50)}
	# ---- Phase 5: the system windows (defense_window.gd, economy_window.gd,
	# fleet_window.gd) and the Mission window (original_mission_window.gd) ----
	# The plates, their panels measured: the tabs' band and the list's well of
	# System Defenses and Manufacturing, the producers' column and the rows'
	# frames, the Fleet window's band, panel and tiles, the Mission window's two
	# outlined panels.
	t["windows/defense_background.png"] = {"kind": "plate", "size": Vector2i(235, 304),
		"blacks": [Rect2i(2, 2, 231, 48)], "wells": [Rect2i(2, 52, 231, 250)]}
	t["windows/mfg_background.png"] = {"kind": "plate", "size": Vector2i(226, 304),
		"blacks": [Rect2i(0, 2, 226, 48)], "bands": [Rect2i(2, 53, 222, 71)], "wells": [Rect2i(2, 126, 222, 176)]}
	t["windows/mfg_column.png"] = {"kind": "plate", "size": Vector2i(46, 226), "base": "clear",
		"wells": [Rect2i(0, 0, 46, 46), Rect2i(0, 81, 46, 46), Rect2i(0, 162, 46, 46)],
		"blacks": [Rect2i(0, 48, 46, 16), Rect2i(0, 129, 46, 16), Rect2i(0, 209, 46, 16)],
		"glyphs": [["shipyards", Rect2i(4, 4, 38, 38)], ["training_facilities", Rect2i(4, 85, 38, 38)], ["construction_yards", Rect2i(4, 166, 38, 38)]]}
	t["windows/mfg_row.png"] = {"kind": "plate", "size": Vector2i(166, 79),
		"blacks": [Rect2i(1, 70, 161, 7)], "holes": [Rect2i(1, 14, 161, 55)]}
	for side in ["alliance", "empire", "neutral"]:
		t["windows/header.%s.png" % side] = {"kind": "bar", "size": Vector2i(162, 13), "side": side, "dim": true}
		for tab in ["manufacturing"]:
			t["tabs/%s.%s.png" % [tab, side]] = {"kind": "tab", "size": Vector2i(36, 33), "glyph": tab, "side": side}
	t["windows/mine_tile.png"] = {"kind": "tile", "size": Vector2i(67, 35), "glyph": "mine"}
	t["windows/mine_pile.png"] = {"kind": "icon", "size": Vector2i(67, 35), "glyph": "mine", "side": "uprising"}
	t["windows/fleet_background.png"] = {"kind": "plate", "size": Vector2i(235, 304), "blacks": [Rect2i(2, 18, 231, 284)]}
	t["windows/mission_window.png"] = {"kind": "plate", "size": Vector2i(235, 304),
		"outlines": [Rect2i(103, 22, 126, 121), Rect2i(103, 142, 126, 153)], "wells": [Rect2i(108, 37, 114, 53)]}
	t["windows/card_plate.png"] = {"kind": "spot", "size": Vector2i(61, 25)}
	t["windows/card_enroute.png"] = {"kind": "spot", "size": Vector2i(61, 25), "tint": Color(0.35, 0.45, 0.7)}
	t["windows/card_transit.png"] = {"kind": "spot", "size": Vector2i(61, 25), "tint": Color(0.55, 0.5, 0.3)}
	t["windows/card_injured.png"] = {"kind": "icon", "size": Vector2i(61, 25), "glyph": "close", "side": "uprising"}
	for side in Sides:
		t["windows/card_building.%s.png" % side] = {"kind": "grid", "size": Vector2i(61, 25), "side": side}
		for tab in ["personnel", "troops", "fighters"]:
			t["tabs/%s.%s.png" % [tab, side]] = {"kind": "tab", "size": Vector2i(36, 33), "glyph": tab, "side": side}
		t["windows/fleet_panel.%s.png" % side] = {"kind": "plate", "size": Vector2i(132, 266), "base": "black",
			"side": side, "outlines": [Rect2i(3, 95, 126, 168)]}
		t["windows/fleet_tile.%s.png" % side] = {"kind": "plate", "size": Vector2i(73, 47), "base": "clear",
			"side": side, "outlines": [Rect2i(0, 0, 73, 47)]}
		t["windows/mission_frame.%s.png" % side] = {"kind": "plate", "size": Vector2i(73, 48), "base": "clear",
			"side": side, "outlines": [Rect2i(0, 0, 73, 48)]}
		t["windows/fleet_small.%s.png" % side] = {"kind": "icon", "size": Vector2i(66, 25), "glyph": "fleets", "side": "grey"}
		t["windows/fleet_small_damage.%s.png" % side] = {"kind": "icon", "size": Vector2i(61, 25), "glyph": "uprising", "side": "uprising"}
		t["windows/fleet_small_glow.%s.png" % side] = {"kind": "icon", "size": Vector2i(61, 25), "glyph": "enroute", "side": side}
		t["windows/fleet_large_glow.%s.png" % side] = {"kind": "icon", "size": Vector2i(122, 50), "glyph": "enroute", "side": side}
		for b in ["fighter", "troop", "personnel"]:
			t["windows/fleet_badge_%s.%s.png" % [b, side]] = {"kind": "icon", "size": Vector2i(15, 11), "glyph": b, "side": side}
		for f in [["ship", Vector2i(30, 29)], ["fighter", Vector2i(31, 29)], ["troop", Vector2i(31, 29)], ["personnel", Vector2i(30, 29)]]:
			t["tabs/fleet_tab_%s.%s.png" % [f[0], side]] = {"kind": "tab", "size": f[1], "glyph": f[0], "side": side}
		t["tabs/mission_agents_tab.%s.png" % side] = {"kind": "tab", "size": Vector2i(61, 16), "glyph": "agents", "side": side}
		t["tabs/mission_decoys_tab.%s.png" % side] = {"kind": "tab", "size": Vector2i(61, 16), "glyph": "decoys", "side": side}
	for tab in ["planetary_shield", "planetary_battery", "shipyards", "training_facilities", "construction_yards", "refineries", "mines"]:
		t["tabs/%s.png" % tab] = {"kind": "tab", "size": Vector2i(36, 33), "glyph": tab}
	# ---- Phase 6: the four finders (original_finder.gd) and the Encyclopedia
	# (encyclopedia_window.gd) - in the Message Index's frame (phase 2) ----
	# The plates: the band above (the name field, the tabs, the caption), the
	# list below (measured; Personnel's list from y 120, Special Forces' and
	# Troops' from 131); the Encyclopedia's topic page one black reading area.
	var lists := {"finder_fleets": 125, "finder_ships": 125, "finder_personnel": 120, "finder_specforces": 131, "finder_troops": 131}
	for plate in lists:
		for side in Sides:
			t["windows/%s.%s.png" % [plate, side]] = {"kind": "plate", "size": Vector2i(400, 306),
				"bands": [Rect2i(25, 33, 350, lists[plate] - 34)], "wells": [Rect2i(25, lists[plate], 349, 291 - lists[plate])]}
	t["windows/finder_systems.png"] = {"kind": "plate", "size": Vector2i(400, 306),
		"bands": [Rect2i(25, 33, 350, 91)], "wells": [Rect2i(25, 125, 349, 166)]}
	t["windows/ency_index_plate.png"] = {"kind": "plate", "size": Vector2i(400, 306),
		"bands": [Rect2i(25, 33, 350, 91)], "wells": [Rect2i(25, 125, 349, 166)]}
	t["windows/ency_topic_plate.png"] = {"kind": "plate", "size": Vector2i(400, 306), "blacks": [Rect2i(1, 19, 398, 286)]}
	for col in ["finder_side2", "finder_side4", "ency_side"]:
		t["windows/%s.alliance.png" % col] = {"kind": "plate", "size": Vector2i(58, 330)}
	# The tabs: the finders' by side (their glyph always in that side's
	# colour), the Encyclopedia's by database.
	for f in [["all", ""], ["rebel", "alliance"], ["imperial", "empire"], ["neutral", "neutral"], ["unexplored", "unexplored"]]:
		t["tabs/finder_tab_%s.png" % f[0]] = {"kind": "tab", "size": Vector2i(49, 41), "glyph": "all" if f[0] == "all" else f[0], "side": f[1], "tinted": f[0] != "all"}
	for e in ["all", "system", "defense"]:
		t["tabs/ency_tab_%s.png" % e] = {"kind": "tab", "size": Vector2i(49, 41), "glyph": e}
	for side in Sides:
		var big: bool = side == "empire"
		for e in ["facilities", "missions", "ship", "troop"]:
			t["tabs/ency_tab_%s.%s.png" % [e, side]] = {"kind": "tab", "size": Vector2i(49, 41), "glyph": e, "side": side}
		t["tabs/ency_tab_personnel.%s.png" % side] = {"kind": "tab", "size": Vector2i(50, 57) if big else Vector2i(49, 57), "glyph": "personnel", "side": side}
		for b in ["finder_btn_characters", "finder_btn_fleets", "finder_btn_ships", "finder_btn_specforces", "finder_display", "ency_view_index", "ency_view_topic"]:
			t["buttons/%s.%s.png" % [b, side]] = {"kind": "button", "size": Vector2i(44, 41) if big else Vector2i(32, 31), "glyph": b.trim_prefix("finder_").trim_prefix("ency_")}
	t["buttons/ency_prev.png"] = {"kind": "button", "size": Vector2i(21, 17), "glyph": "prev"}
	t["buttons/ency_next.png"] = {"kind": "button", "size": Vector2i(21, 17), "glyph": "next"}
	# ---- Phase 7: the Game Options screen (original_options_screen.gd; manual
	# p075-p076 Fig 3.16) and the alert boxes (REBDLOG) it and the game ask in ----
	# The screen: the Saved Games panel (its heading bar, six rows of sockets -
	# Save, the side's box, the name, Load), the tray under it (Restart, Return,
	# Exit), Sound Options (heading, the music switch and its field, the two
	# volume tracks) over Tactical Display (heading, five lights and fields) -
	# the fields and sockets measured.
	var blacks: Array = [Rect2i(56, 37, 245, 21), Rect2i(360, 37, 245, 21), Rect2i(360, 274, 246, 20),
		Rect2i(352, 77, 19, 34), Rect2i(376, 77, 237, 34), Rect2i(352, 134, 22, 47), Rect2i(376, 134, 237, 47),
		Rect2i(352, 194, 22, 47), Rect2i(376, 194, 237, 47), Rect2i(64, 372, 236, 58)]
	for i in 6:
		var y: int = 81 + 42 * i
		blacks.append_array([Rect2i(33, y - 1, 44, 22), Rect2i(84, y - 1, 28, 21), Rect2i(116, y, 165, 20), Rect2i(286, y - 1, 43, 22)])
	for i in 5:
		blacks.append_array([Rect2i(356, 311 + 27 * i, 37, 22), Rect2i(394, 312 + 27 * i, 213, 19)])
	t["screens/options.png"] = {"kind": "plate", "size": Vector2i(640, 480),
		"wells": [Rect2i(22, 34, 315, 306), Rect2i(22, 350, 315, 105), Rect2i(343, 33, 274, 230), Rect2i(343, 266, 274, 187)],
		"blacks": blacks, "late_bands": [Rect2i(76, 381, 42, 42), Rect2i(162, 382, 42, 42), Rect2i(248, 381, 42, 42)],
		# The two volume tracks' marks: music, then sound effects.
		"glyphs": [["music", Rect2i(352, 146, 22, 22)], ["sound", Rect2i(352, 206, 22, 22)]]}
	# The multiplayer screens' bottom strip, where the Saved Games row's wires and
	# clamps are cut from (saved_games_art.gd): four wires - yellow, red, blue,
	# green - in their rows, a clamp at x 98.
	t["screens/mp_connection.png"] = {"kind": "wirestrip", "size": Vector2i(640, 480)}
	for b in [["options_save", Vector2i(42, 20), "save"], ["options_load", Vector2i(41, 20), "load"],
			["options_restart", Vector2i(42, 42), "restart"], ["options_return", Vector2i(42, 42), "return"],
			["options_exit", Vector2i(42, 42), "exit"]]:
		t["buttons/%s.png" % b[0]] = {"kind": "button", "size": b[1], "glyph": b[2]}
	t["windows/options_side.alliance.png"] = {"kind": "icon", "size": Vector2i(26, 19), "glyph": "loyalty", "side": "alliance"}
	t["windows/options_side.empire.png"] = {"kind": "icon", "size": Vector2i(26, 19), "glyph": "loyalty", "side": "empire"}
	t["windows/options_side.h2h.png"] = {"kind": "icon", "size": Vector2i(26, 19), "glyph": "h2h", "side": "grey"}
	t["windows/options_music.png"] = {"kind": "lever", "size": Vector2i(19, 35)}
	t["windows/options_light.png"] = {"kind": "lamp", "size": Vector2i(35, 22)}
	t["windows/options_knob.png"] = {"kind": "plate", "size": Vector2i(11, 47)}
	t["windows/mp_choice.png"] = {"kind": "choice", "size": Vector2i(152, 33)}
	# The alert boxes: the words' well, and the one socket (the check) or the
	# two (the check and the cross) their buttons sit in.
	t["windows/dialog_plate1.png"] = {"kind": "plate", "size": Vector2i(412, 176),
		"blacks": [Rect2i(26, 36, 360, 68)], "bands": [Rect2i(172, 130, 65, 36)]}
	t["windows/dialog_plate2.png"] = {"kind": "plate", "size": Vector2i(412, 176),
		"blacks": [Rect2i(26, 36, 360, 68)], "bands": [Rect2i(122, 130, 65, 36), Rect2i(225, 131, 65, 36)]}
	t["buttons/dialog_ok.png"] = {"kind": "button", "size": Vector2i(57, 28), "glyph": "ok"}
	t["buttons/dialog_cancel.png"] = {"kind": "button", "size": Vector2i(57, 28), "glyph": "cancel"}
	# ---- Phase 8: the Speed Control's menu, the battle windows, Create Mission,
	# Build Selection and the GID key ----
	# The speed menu (original_menu.gd SpeedMenu): each speed's bars - three,
	# one fewer lit than the speed (Pause and Very Slow none) - as the plain
	# Speed Control draws them (game_manager.gd PlainBars).
	for side in Sides:
		for i in 5:
			t["windows/speed_bars.%s.%d.png" % [side, i]] = {"kind": "speedbars", "size": Vector2i(16, 10), "side": side, "lit": maxi(0, i - 1)}
	# The battle windows (original_battle.gd; manual p141-p142, p152-p153): the
	# alert's frame - the scene shows through its opening, the three buttons
	# sit on its dark foot - the scenes and the forces pages behind it, the
	# column's page buttons, the results' close and Goto System, the lists'
	# scroll bar; the results' tables (a band for the filter's name, then two
	# columns, three for personnel, battle_results_window.gd Table2 / Table3).
	for side in Sides:
		var big: bool = side == "empire"
		var col := Vector2i(44, 41) if big else Vector2i(41, 41)
		t["windows/battle_frame.%s.png" % side] = {"kind": "plate", "size": Vector2i(470, 331),
			"blacks": [Rect2i(11, 295, 404, 29)], "holes": [Rect2i(12, 13 if big else 14, 400, 271), Rect2i(0, 330, 470, 1)]}
		t["windows/battle_alert.%s.png" % side] = _scene("conflict")
		t["windows/battle_result.%s.png" % side] = _scene("conflict")
		t["windows/battle_result_burning.%s.png" % side] = _scene("uprising")
		t["windows/assault_captured.%s.png" % side] = _scene("troop")
		t["windows/battle_forces.%s.png" % side] = {"kind": "plate", "size": Vector2i(410, 280), "base": "black"}
		t["tabs/battle_summary.%s.png" % side] = {"kind": "tab", "size": col, "glyph": "summary", "side": side}
		t["tabs/battle_alliance_forces.%s.png" % side] = {"kind": "tab", "size": col, "glyph": "fleets", "side": "alliance", "tinted": true}
		t["tabs/battle_empire_forces.%s.png" % side] = {"kind": "tab", "size": col, "glyph": "fleets", "side": "empire", "tinted": true}
		t["tabs/battle_system.%s.png" % side] = {"kind": "tab", "size": col, "glyph": "system", "side": side}
		t["tabs/battle_filter_fighter.%s.png" % side] = {"kind": "tab", "size": Vector2i(49, 41), "glyph": "fighter", "side": side}
		for b in [["battle_retreat", "return"], ["battle_simulate", "summary"], ["battle_command", "conflict"]]:
			t["buttons/%s.%s.png" % [b[0], side]] = {"kind": "button", "size": Vector2i(134, 27), "glyph": b[1]}
		t["buttons/battle_close.%s.png" % side] = {"kind": "button", "size": Vector2i(44, 41) if big else Vector2i(32, 31), "glyph": "close"}
		t["buttons/battle_goto.%s.png" % side] = {"kind": "button", "size": col, "glyph": "system"}
		t["buttons/battle_scroll_up.%s.png" % side] = {"kind": "button", "size": Vector2i(13, 9), "glyph": "up"}
		t["buttons/battle_scroll_down.%s.png" % side] = {"kind": "button", "size": Vector2i(13, 9), "glyph": "down"}
		t["windows/battle_thumb_top.%s.png" % side] = {"kind": "plate", "size": Vector2i(13, 6), "edges": "top"}
		t["windows/battle_thumb_mid.%s.png" % side] = {"kind": "plate", "size": Vector2i(13, 12), "edges": "sides"}
		t["windows/battle_thumb_bottom.%s.png" % side] = {"kind": "plate", "size": Vector2i(13, 6), "edges": "bottom"}
	t["windows/battle_result_none.png"] = _scene("conflict")
	t["windows/assault_repulsed.png"] = _scene("defense")
	t["windows/bombardment_result.png"] = _scene("battery")
	t["windows/bombardment_held.png"] = _scene("defense")
	t["windows/battle_table2.png"] = {"kind": "plate", "size": Vector2i(400, 310),
		"bands": [Rect2i(24, 87, 337, 17)], "wells": [Rect2i(24, 105, 167, 182), Rect2i(191, 105, 170, 182)]}
	t["windows/battle_table3.png"] = {"kind": "plate", "size": Vector2i(400, 310),
		"bands": [Rect2i(24, 87, 337, 17)], "wells": [Rect2i(24, 105, 112, 182), Rect2i(136, 105, 111, 182), Rect2i(247, 105, 114, 182)]}
	# Create Mission (create_mission_window.gd; manual p042 Fig 2.34): the
	# Select Mission page - the mission's name and picture, the target's box -
	# and the Decoy page's two columns under the two tabs; the lists' starfield.
	t["windows/mission_plate.png"] = {"kind": "plate", "size": Vector2i(259, 355),
		"blacks": [Rect2i(31, 61, 211, 106), Rect2i(50, 210, 167, 81)]}
	t["windows/mission_decoy_plate.png"] = {"kind": "plate", "size": Vector2i(259, 355),
		"blacks": [Rect2i(7, 64, 117, 251), Rect2i(135, 64, 117, 244)]}
	t["windows/list_starfield.png"] = {"kind": "plate", "size": Vector2i(195, 61), "base": "black"}
	for side in Sides:
		t["tabs/mission_select.%s.png" % side] = {"kind": "tab", "size": Vector2i(116, 33), "glyph": "missions", "side": side}
		t["tabs/mission_decoy.%s.png" % side] = {"kind": "tab", "size": Vector2i(116, 33), "glyph": "decoy", "side": side}
		t["windows/mission_agents.%s.png" % side] = {"kind": "icon", "size": Vector2i(108, 27), "glyph": "personnel", "side": side}
		t["windows/mission_decoys.%s.png" % side] = {"kind": "icon", "size": Vector2i(108, 27), "glyph": "decoy", "side": side}
	for b in [["mission_ok", "ok"], ["mission_cancel", "cancel"], ["mission_encyclopedia", "encyclopedia"]]:
		t["buttons/%s.png" % b[0]] = {"kind": "button", "size": Vector2i(64, 32), "glyph": b[1]}
	t["buttons/mission_list_open.png"] = {"kind": "button", "size": Vector2i(65, 17), "glyph": "down"}
	t["buttons/mission_list_opened.png"] = {"kind": "button", "size": Vector2i(65, 18), "glyph": "up"}
	t["buttons/mission_to_decoys.png"] = {"kind": "button", "size": Vector2i(16, 16), "glyph": "right"}
	t["buttons/mission_to_agents.png"] = {"kind": "button", "size": Vector2i(16, 16), "glyph": "left"}
	# Build Selection (build_selection_window.gd; manual p045 Fig 3.58): the
	# item's picture and name, its two costs, the two times, the number to
	# build, and the buttons.
	t["windows/build_plate.png"] = {"kind": "plate", "size": Vector2i(210, 261),
		"blacks": [Rect2i(6, 22, 200, 67), Rect2i(6, 109, 98, 29), Rect2i(108, 109, 98, 29), Rect2i(6, 140, 200, 49), Rect2i(140, 195, 66, 22)]}
	for b in [["build_ok", "ok"], ["build_cancel", "cancel"], ["build_encyclopedia", "encyclopedia"]]:
		t["buttons/%s.png" % b[0]] = {"kind": "button", "size": Vector2i(66, 33), "glyph": b[1]}
	t["buttons/build_list_open.png"] = {"kind": "button", "size": Vector2i(65, 18), "glyph": "down"}
	t["buttons/build_up.png"] = {"kind": "button", "size": Vector2i(13, 8), "glyph": "up"}
	t["buttons/build_down.png"] = {"kind": "button", "size": Vector2i(13, 8), "glyph": "down"}
	# The GID key (original_gid_key.gd): its closed button - the part the
	# original shows, (1,1) 29 x 23 - and each side's mark in the legend.
	t["windows/gid_key_closed.png"] = {"kind": "plate", "size": Vector2i(47, 25), "base": "clear",
		"raised": [Rect2i(1, 1, 29, 23)], "glyphs": [["gid", Rect2i(4, 2, 23, 21)]]}
	for s in ["alliance", "empire", "neutral"]:
		t["windows/gid_key_%s.png" % s] = {"kind": "icon", "size": Vector2i(9, 9), "glyph": "loyalty", "side": s}
	t["windows/gid_key_unexplored.png"] = {"kind": "star", "size": Vector2i(15, 15), "tier": "low", "side": "unexplored"}
	_spec = t
	return _spec


## A scene the original paints (a battle, an assault, a bombardment): black,
## our glyph for what happened dim in its upper middle - the game's words go
## over it, the title above and the text below.
static func _scene(glyph: String) -> Dictionary:
	return {"kind": "plate", "size": Vector2i(400, 310), "base": "black",
		"glyphs": [[glyph, Rect2i(145, 45, 110, 110), PlainIcons.Plate]]}


static func _draw(spec: Dictionary, state: String) -> Image:
	var sz: Vector2i = spec["size"]
	var img := Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)
	var lit: Color = Sides.get(str(spec.get("side", "")), Color.WHITE)
	match str(spec["kind"]):
		"plate":
			match str(spec.get("base", "raised")):
				"black":
					img.fill(Color.BLACK)
				"clear":
					pass
				_:
					_raised(img, Rect2i(Vector2i.ZERO, sz), str(spec.get("edges", "all")))
			for r in spec.get("raised", []):
				_raised(img, r)
			for b in spec.get("bands", []):
				_sunk(img, b, PlainIcons.Band)
			for w in spec.get("wells", []):
				_sunk(img, w, PlainIcons.Well)
			for w in spec.get("blacks", []):
				_sunk(img, w, Color.BLACK)
			for b in spec.get("late_bands", []):
				_sunk(img, b, PlainIcons.Band)
			for o in spec.get("outlines", []):
				_outline(img, o, _side_colour(str(spec.get("side", ""))) if spec.has("side") else PlainIcons.BevelLight)
			for g in spec.get("glyphs", []):
				_glyph(img, str(g[0]), g[2] if g.size() > 2 else PlainIcons.LabelColor, g[1])
			for h in spec.get("holes", []):
				img.fill_rect(h, Color(0, 0, 0, 0))
		"corner":
			var hover: bool = state == "hover"
			var box: Rect2i = spec["box"]
			_glyph(img, str(spec["glyph"]), Color.WHITE if hover else _side_colour(str(spec["side"])), box.grow(1) if hover else box, true)
		"planet":
			_planet(img, int(spec["n"]))
		"star":
			_star(img, str(spec["tier"]), _side_colour(str(spec["side"])))
		"wirestrip":
			_raised(img, Rect2i(Vector2i.ZERO, sz))
			_wirestrip(img)
		"lever":
			var on: bool = state == "lit"
			_sunk(img, Rect2i(Vector2i.ZERO, sz), Color.BLACK)
			var knob := Rect2i(3, 3 if on else sz.y - 15, sz.x - 6, 12)
			_raised(img, knob)
			if state == "grey":
				img.fill_rect(knob.grow(-2), PlainIcons.Dimmed)
			elif on:
				img.fill_rect(Rect2i(knob.position.x + 3, knob.position.y + 4, knob.size.x - 6, 4), Color(0, 1, 0))
		"lamp":
			_sunk(img, Rect2i(Vector2i.ZERO, sz), Color.BLACK)
			var lamp_on: bool = state == "lit" or state == "on"
			var lc: Color = Color(0, 1, 0) if state == "lit" else (Color(0, 0.75, 0) if lamp_on else Color(0, 0.25, 0))
			img.fill_rect(Rect2i(6, 5, sz.x - 12, sz.y - 10), lc)
		"choice":
			_raised(img, Rect2i(Vector2i.ZERO, sz))
			var ends: Color = Color(1, 0, 0) if state == "chosen" else PlainIcons.BevelLight
			img.fill_rect(Rect2i(2, 3, 3, sz.y - 6), ends)
			img.fill_rect(Rect2i(sz.x - 5, 3, 3, sz.y - 6), ends)
			_sunk(img, Rect2i(12, 5, sz.x - 24, sz.y - 10), Color("#222222"))
		"speedbars":
			var on: Color = _side_colour(str(spec.get("side", "")))
			img.fill(Color.BLACK)
			for i in 3:
				img.fill_rect(Rect2i(i * 6, 0, 4, sz.y - 1), on if i < int(spec.get("lit", 0)) else on.darkened(0.55))
		"spot":
			_spot(img, spec.get("tint", Color(0.35, 0.35, 0.35)))
		"bar":
			var bc: Color = _side_colour(str(spec.get("side", "")))
			if spec.get("dim", false) and state != "lit":
				bc = bc.darkened(0.35)
			img.fill(bc)
		"tile":
			_sunk(img, Rect2i(Vector2i.ZERO, sz), PlainIcons.Well)
			_glyph(img, str(spec["glyph"]), PlainIcons.LabelColor, Rect2i(Vector2i.ZERO, sz).grow(-3))
		"grid":
			var gc: Color = _side_colour(str(spec.get("side", "")))
			gc.a = 0.6
			for x in range(0, sz.x, 4):
				img.fill_rect(Rect2i(x, 0, 1, sz.y), gc)
			for y in range(0, sz.y, 4):
				img.fill_rect(Rect2i(0, y, sz.x, 1), gc)
		"icon":
			var c: Color = Color.WHITE if state == "picked" or state == "hover" else _side_colour(str(spec.get("side", "")))
			_glyph(img, str(spec["glyph"]), c, Rect2i(Vector2i.ZERO, sz))
		"button", "tab":
			var down: bool = state == "pressed" or state == "chosen" or state == "lit"
			var r := Rect2i(Vector2i.ZERO, sz)
			if down:
				_sunk(img, r, Color("#222222"))
			else:
				_raised(img, r)
			var c: Color = PlainIcons.LabelColor
			if spec.get("tinted", false):
				c = _side_colour(str(spec.get("side", "")))
				if not down:
					c = c.darkened(0.3)
			if state == "disabled" or state == "grey":
				c = PlainIcons.Dimmed
			elif down and not spec.get("tinted", false):
				c = lit if spec["kind"] == "tab" else Color.WHITE
			var inner := r.grow(-2)
			if down:
				inner.position += Vector2i(1, 1)
			_glyph(img, str(spec["glyph"]), c, inner)
	return img


## Raised: our plate, lit edge top and left, shadow bottom and right - or,
## for a piece of a longer bar (dges "top" / "sides" / "bottom"), only the
## edges that piece has.
static func _raised(img: Image, r: Rect2i, edges: String = "all") -> void:
	img.fill_rect(r, PlainIcons.Plate)
	if edges == "all" or edges == "top":
		img.fill_rect(Rect2i(r.position, Vector2i(r.size.x, 1)), PlainIcons.BevelLight)
	img.fill_rect(Rect2i(r.position, Vector2i(1, r.size.y)), PlainIcons.BevelLight)
	if edges == "all" or edges == "bottom":
		img.fill_rect(Rect2i(Vector2i(r.position.x, r.end.y - 1), Vector2i(r.size.x, 1)), PlainIcons.Well)
	img.fill_rect(Rect2i(Vector2i(r.end.x - 1, r.position.y), Vector2i(1, r.size.y)), PlainIcons.Well)


## Sunk: `fill`, shadow top and left, lit edge bottom and right.
static func _sunk(img: Image, r: Rect2i, fill: Color) -> void:
	img.fill_rect(r, fill)
	img.fill_rect(Rect2i(r.position, Vector2i(r.size.x, 1)), Color.BLACK)
	img.fill_rect(Rect2i(r.position, Vector2i(1, r.size.y)), Color.BLACK)
	img.fill_rect(Rect2i(Vector2i(r.position.x, r.end.y - 1), Vector2i(r.size.x, 1)), PlainIcons.BevelLight)
	img.fill_rect(Rect2i(Vector2i(r.end.x - 1, r.position.y), Vector2i(1, r.size.y)), PlainIcons.BevelLight)


## Our glyph centred in `r`, blown up by whole pixels as far as it fits (or
## shrunk to a triangle's worth where the room is under 11 pixels).
static func _glyph(img: Image, kind: String, c: Color, r: Rect2i, fit: bool = false) -> void:
	var g: Image = PlainIcons.Picture(kind, c)
	if g == null:
		return
	var room: int = mini(r.size.x, r.size.y)
	if fit:
		g.resize(maxi(3, room), maxi(3, room), Image.INTERPOLATE_NEAREST)
	elif room < g.get_width():
		g.resize(maxi(3, room), maxi(3, room), Image.INTERPOLATE_NEAREST)
	else:
		var k: int = maxi(1, room / g.get_width())
		g.resize(g.get_width() * k, g.get_height() * k, Image.INTERPOLATE_NEAREST)
	var at := r.position + (r.size - g.get_size()) / 2
	img.blend_rect(g, Rect2i(Vector2i.ZERO, g.get_size()), at)

## A side's colour for its stand-ins: the original's red and green, the pack's
## neutral and uncharted colours, an uprising's orange; white for none.
static func _side_colour(side: String) -> Color:
	if Sides.has(side):
		return Sides[side]
	match side:
		"neutral":
			return FactionRegistry.Neutral.FactionColor if FactionRegistry.Neutral != null else Color(0.35, 0.6, 1)
		"unexplored":
			return FactionRegistry.Unknown.FactionColor if FactionRegistry.Unknown != null else Color(0.8, 0.8, 0.8)
		"uprising":
			return Color(249 / 255.0, 92 / 255.0, 15 / 255.0)
		"grey":
			return PlainIcons.LabelColor
	return Color.WHITE


## A planet: a disc lit from the upper left, its own muted colour (by its
## number, so the 26 are told apart) - never the original's picture.
static func _planet(img: Image, n: int) -> void:
	var base := Color.from_hsv(fmod(n * 0.137, 1.0), 0.28, 0.72)
	var c := Vector2(18.5, 18.5)
	var r := 17.0
	var light := Vector2(-0.6, -0.6).normalized()
	for y in 37:
		for x in 37:
			var d := (Vector2(x + 0.5, y + 0.5) - c) / r
			if d.length() > 1.0:
				continue
			var z: float = sqrt(maxf(0.0, 1.0 - d.length_squared()))
			var lit: float = clampf(0.35 + 0.75 * maxf(0.0, d.x * light.x + d.y * light.y + z * 0.55), 0.2, 1.1)
			img.set_pixel(x, y, Color(base.r * lit, base.g * lit, base.b * lit, 1.0))


## A tier's star: a plus in the side's colour, its reach by tier (StarReach);
## the smallest a dot.
static func _star(img: Image, tier: String, c: Color) -> void:
	var reach: int = StarReach.get(tier, 1)
	var mid := 7
	var arm: int = 1 if reach <= 3 else 3
	var half: int = arm / 2
	img.fill_rect(Rect2i(mid - reach, mid - half, reach * 2 + 1, arm), c)
	img.fill_rect(Rect2i(mid - half, mid - reach, arm, reach * 2 + 1), c)


## A soft pool of light (grey, or 	int), for a picture to stand in.
static func _spot(img: Image, tint: Color = Color(0.35, 0.35, 0.35)) -> void:
	var c := Vector2(img.get_width(), img.get_height()) / 2.0
	for y in img.get_height():
		for x in img.get_width():
			var d: float = ((Vector2(x + 0.5, y + 0.5) - c) / c).length()
			if d < 1.0:
				img.set_pixel(x, y, Color(tint.r, tint.g, tint.b, (1.0 - d) * 0.8))


## A one-pixel outline round  in c.
static func _outline(img: Image, r: Rect2i, c: Color) -> void:
	img.fill_rect(Rect2i(r.position, Vector2i(r.size.x, 1)), c)
	img.fill_rect(Rect2i(r.position, Vector2i(1, r.size.y)), c)
	img.fill_rect(Rect2i(Vector2i(r.position.x, r.end.y - 1), Vector2i(r.size.x, 1)), c)
	img.fill_rect(Rect2i(Vector2i(r.end.x - 1, r.position.y), Vector2i(1, r.size.y)), c)

## The multiplayer screens' bottom strip as the Saved Games wires sample it
## (saved_games_art.gd WireSource, WireProfile, ClampSource): across the
## screen's foot, four wires lit to dark - yellow rows 447-449, red 451-453,
## blue 455-457, green 459-460 - a shade row between, and a clamp at x 98.
static func _wirestrip(img: Image) -> void:
	_sunk(img, Rect2i(0, 437, img.get_width(), 43), PlainIcons.Band)
	var rows := {447: Color("#d8d840"), 448: Color("#f0f070"), 449: Color("#707028"), 450: PlainIcons.Well,
		451: Color("#d04040"), 452: Color("#b03030"), 453: Color("#702020"), 454: PlainIcons.Well,
		455: Color("#4a64d8"), 456: Color("#3048b8"), 457: Color("#203070"), 458: PlainIcons.Well,
		459: Color("#50c050"), 460: Color("#308a30")}
	for y in rows:
		img.fill_rect(Rect2i(0, y, img.get_width(), 1), rows[y])
	_raised(img, Rect2i(98, 439, 8, 33))
