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
const States := ["pressed", "disabled", "grey", "lit", "picked", "hover", "chosen"]
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
	_spec = t
	return _spec


static func _draw(spec: Dictionary, state: String) -> Image:
	var sz: Vector2i = spec["size"]
	var img := Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)
	var lit: Color = Sides.get(str(spec.get("side", "")), Color.WHITE)
	match str(spec["kind"]):
		"plate":
			_raised(img, Rect2i(Vector2i.ZERO, sz), str(spec.get("edges", "all")))
			for b in spec.get("bands", []):
				_sunk(img, b, PlainIcons.Band)
			for w in spec.get("wells", []):
				_sunk(img, w, PlainIcons.Well)
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
		"spot":
			_spot(img)
		"bar":
			img.fill(lit)
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
			if state == "disabled" or state == "grey":
				c = PlainIcons.Dimmed
			elif down:
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


## A soft grey pool of light, for a picture to stand in.
static func _spot(img: Image) -> void:
	var c := Vector2(img.get_width(), img.get_height()) / 2.0
	for y in img.get_height():
		for x in img.get_width():
			var d: float = ((Vector2(x + 0.5, y + 0.5) - c) / c).length()
			if d < 1.0:
				img.set_pixel(x, y, Color(0.35, 0.35, 0.35, (1.0 - d) * 0.8))
