extends RefCounted
## THE SECTOR WINDOW AS A THEATRE PLATE (docs/ww2-look-plan.md, phase 8; TeeJ,
## 2026-09-29: "the sector view still looks like SWR"). For a pack with a look,
## the plain sector window's contents are drawn as a plotting board. Every
## element the manual gives the window (manual p025-p026, Figs 2.8 and 2.9)
## stays where it was, meaning what it meant and answering as it did:
##   - the ground: the theatre cut from the pack's map picture - or from a
##     sharper inset of that part of the world when the look ships one that
##     holds the whole theatre (look.json `map_insets`) - under a parchment
##     wash so the marks read, framed in brass;
##   - each system: a plotting mark in its side's map colour with an ink rim
##     (an unheld one an ink ring); the HQ ring in brass;
##   - its name: the look's face, in its holder's colour darkened until it
##     reads on the parchment, in ink when no side holds it, with a paper halo;
##   - the corner icons: the same glyphs in ink on small paper tabs edged in
##     the tint's colour; an uprising's in signal red;
##   - the three bars: energy used ink and free open, mines built olive and
##     free open, all ink-edged; the loyalty bar in the sides' map colours with
##     an ink edge;
##   - the GID star: the map's cross with an ink rim.
##
## One pass at the end of each Populate (the window repaints by rebuilding),
## over the entries by their roles. It changes colours, faces and style boxes
## only - never a size, a position, a mouse filter or a signal - so clicks,
## drops, drags and the crosshairs work as before. The map keeps factions.json's
## side colours on the plate, as the strategic map does.
##
## Preloaded by path (as LookSector) from sector_window.gd.

const Art := preload("res://src/ui/artwork.gd")

## How much parchment is laid over the map picture (0 none, 1 plain paper).
const WASH := 0.58
## THE MAP OR THE SHEET (TeeJ, 2026-09-29: "b"). The plate is the map, each
## system over its own place, while the map needs magnifying no more than
## this many window pixels per picture pixel to reach the window's scale.
## Beyond it the map is too soft to read, so the plate is a plain plotting
## sheet: parchment with a faint grid. With the WWII pack's detail map alone
## the five small European theatres needed 5.1-8.8 and went to the sheet;
## with its Europe inset they need 1.4-2.5, and every theatre is a map
## (TeeJ, 2026-09-29: "we need them all to be the same"). The sheet stays for
## a pack whose pictures cannot reach a theatre sharply.
const SHARP_ZOOM := 4.0
## Tests and captures: the sheet for every theatre.
static var SHEET := false
const GRID := 40.0


## The plotting sheet's grid: faint ink lines every GRID px.
class Grid extends Control:
	func _draw() -> void:
		var c := Look.C("ink_muted")
		c.a = 0.16
		var x := GRID
		while x < size.x:
			draw_line(Vector2(x, 0), Vector2(x, size.y), c, 1.0)
			x += GRID
		var y := GRID
		while y < size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), c, 1.0)
			y += GRID
## A name's paper halo, and a mark's ink rim, in px.
const HALO := 4
const RIM := 2


## The whole pass. `padding` and `padding_bottom` are Populate's, so the plate
## covers the theatre around the systems as the window lays them out.
static func Dress(sector_map: Control, sector: Sector, map_size: Vector2, padding: float, padding_bottom: float) -> void:
	if not Look.Active() or sector_map == null:
		return
	_plate(sector_map, sector, map_size, padding, padding_bottom)
	for c in sector_map.get_children():
		if c.is_queued_for_deletion() or not c.has_meta("system"):
			continue
		var planet: Planet = c.get_meta("system")
		if c is SectorWindow.PlanetMapButton:
			_mark(c as Button, planet)
		elif c.has_meta("corner"):
			_corner(c as Button)
		elif c.has_meta("bar_row"):
			_bars(c as Control)
		elif c is Label and (c as Label).text == planet.Name:
			_name(c as Label, planet)
		elif c is Label and (c as Label).text == "+":
			_star(c as Label)


# ---------------------------------------------------------------------------
# The ground
# ---------------------------------------------------------------------------

## The ground, under every entry and taking no clicks, bottom up: parchment;
## the theatre cut from the map (where it stays sharp) under a parchment
## wash, or else the sheet's grid; the brass frame. The sector map carries
## `look_plate` ("map" or "sheet") and `look_zoom` (the map's magnification).
const LAYERS := ["LookPaper", "LookPlate", "LookWash", "LookGrid", "LookFrame"]


static func _plate(sector_map: Control, sector: Sector, map_size: Vector2, padding: float, padding_bottom: float) -> void:
	for n in LAYERS:
		var old: Node = sector_map.get_node_or_null(n)
		if old != null:
			sector_map.remove_child(old)
			old.queue_free()
	var cut: Dictionary = PlateCut(sector, map_size, padding, padding_bottom)
	var map_on: bool = cut.has("texture") and not SHEET and float(cut.get("zoom", INF)) <= SHARP_ZOOM
	sector_map.set_meta("look_plate", "map" if map_on else "sheet")
	sector_map.set_meta("look_zoom", float(cut.get("zoom", 0.0)))
	var layers: Array = []
	var base := ColorRect.new()
	base.name = "LookPaper"
	base.color = Look.C("paper")
	base.size = map_size
	layers.append(base)
	if map_on:
		var picture := TextureRect.new()
		picture.name = "LookPlate"
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_SCALE
		picture.texture = cut["texture"]
		var at: Rect2 = cut["at"]
		picture.position = at.position
		picture.size = at.size
		layers.append(picture)
		var wash := ColorRect.new()
		wash.name = "LookWash"
		var paper := Look.C("paper")
		paper.a = WASH
		wash.color = paper
		wash.size = map_size
		layers.append(wash)
	else:
		var grid := Grid.new()
		grid.name = "LookGrid"
		grid.size = map_size
		layers.append(grid)
	var frame := Panel.new()
	frame.name = "LookFrame"
	frame.size = map_size
	frame.add_theme_stylebox_override("panel", Look.Box("", "brass_dim", 1, 0, 0))
	layers.append(frame)
	for i in layers.size():
		var layer: Control = layers[i]
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sector_map.add_child(layer)
		sector_map.move_child(layer, i)


## The part of the pack's map picture under the window, where it lands and how
## much it is magnified: {"texture": AtlasTexture, "at": Rect2 in the window,
## "zoom": window px per picture px}. The window's area at the layout's own
## scale, so each system sits over its place on the map. The sharpest picture
## that holds the whole theatre: an inset of the look's (`map_insets`, a
## larger-scale map of part of the world, lined up with the map) when one
## does, else the map. {} without a map picture; no "texture" when the theatre
## is off the picture.
static func PlateCut(sector: Sector, map_size: Vector2, padding: float, padding_bottom: float) -> Dictionary:
	var manifest = FactionRegistry.Pack.Manifest if FactionRegistry.Pack != null else null
	if manifest == null or sector == null:
		return {}
	# The look's detail copy of the map when it ships one (look.json
	# `map_detail`: the same picture over the same map_image_rect, more pixels,
	# so a theatre stays sharp at the window's scale); else the map itself.
	var tex: Texture2D = Look.Tex("map_detail")
	if tex == null:
		tex = Art.PackImage(manifest.MapImage)
	if tex == null:
		return {}
	var rect: Rect2 = MapRect(manifest, tex)
	var span := Vector2(maxf(sector.MaxX - sector.MinX, 1.0), maxf(sector.MaxY - sector.MinY, 1.0))
	var usable := Vector2(maxf(map_size.x - padding * 2.0, 1.0), maxf(map_size.y - padding - padding_bottom, 1.0))
	# Each system over its own place on the map: the layout's own scale each
	# way, in map units per window pixel (the same one both ways, unless a flat
	# sector's floor stretched one - then the other's).
	var sx: float = span.x / usable.x
	var sy: float = span.y / usable.y
	if sector.MaxX - sector.MinX < 1.0:
		sx = sy
	if sector.MaxY - sector.MinY < 1.0:
		sy = sx
	var cover := Rect2(Vector2(sector.MinX - padding * sx, sector.MinY - padding * sy), Vector2(map_size.x * sx, map_size.y * sy))
	var best: Dictionary = _cut(tex, rect, cover, map_size, sx, sy)
	for inset in Look.MapInsets():
		var at: Rect2 = inset["at"]
		if at.encloses(cover):
			var c: Dictionary = _cut(inset["texture"], at, cover, map_size, sx, sy)
			if float(c["zoom"]) < float(best["zoom"]):
				best = c
	return best


## One picture's cut: `tex` covers `rect` in map units; `cover` is the window's
## area in map units at sx, sy map units per window pixel.
static func _cut(tex: Texture2D, rect: Rect2, cover: Rect2, map_size: Vector2, sx: float, sy: float) -> Dictionary:
	# Map units to the picture's pixels; the magnification that makes.
	var k := Vector2(tex.get_width() / rect.size.x, tex.get_height() / rect.size.y)
	var zoom: float = maxf(1.0 / (sx * k.x), 1.0 / (sy * k.y))
	var full := Rect2((cover.position - rect.position) * k, cover.size * k)
	var px := full.intersection(Rect2(Vector2.ZERO, tex.get_size()))
	if px.size.x < 2.0 or px.size.y < 2.0:
		return {"zoom": zoom}
	var cut := AtlasTexture.new()
	cut.atlas = tex
	cut.region = px
	# Where that part lands in the window: all of it, unless the theatre runs
	# off the picture's edge (the parchment under it shows there).
	var scale := map_size / full.size
	return {"texture": cut, "at": Rect2((px.position - full.position) * scale, px.size * scale), "zoom": zoom}


## Where the picture sits in map space (pack.json `map_image_rect`), else the
## picture's own pixels.
static func MapRect(manifest, tex: Texture2D) -> Rect2:
	var r: Rect2 = manifest.MapImageRect
	if r.size.x > 0.0 and r.size.y > 0.0:
		return r
	return Rect2(Vector2.ZERO, tex.get_size())


# ---------------------------------------------------------------------------
# The marks
# ---------------------------------------------------------------------------

## A system: its side's map colour with an ink rim; an unheld one an ink ring
## on the parchment. The HQ ring (Gid.ShowHqHighlight) in brass.
static func _mark(btn: Button, planet: Planet) -> void:
	var was: StyleBox = btn.get_theme_stylebox("normal")
	var disc: StyleBoxFlat = (was as StyleBoxFlat).duplicate() if was is StyleBoxFlat else StyleBoxFlat.new()
	var owner: Faction = Holder(planet)
	var hq: bool = Gid.ShowHqHighlight(planet)
	disc.bg_color = owner.FactionColor if owner != null else Look.C("paper")
	disc.border_color = Look.C("brass") if hq else Look.C("ink")
	disc.set_border_width_all(3 if hq else RIM)
	disc.anti_aliasing = true
	for state in ["normal", "hover", "pressed"]:
		btn.add_theme_stylebox_override(state, disc)


## The GID star: the map's cross, rimmed in ink so it holds on the plate.
static func _star(star: Label) -> void:
	star.add_theme_color_override("font_outline_color", Look.C("ink"))
	star.add_theme_constant_override("outline_size", RIM + 1)


## A system's name: the look's face; its holder's colour made dark enough to
## read on parchment, or ink; a paper halo round it.
## The playable side we know to hold the system, or null: a neutral
## holder and an unknown one both read as unheld.
static func Holder(planet: Planet) -> Faction:
	var owner: Faction = IntelManager.OwnerSeen(GameSettings.LocalFaction(), planet)
	return owner if owner != null and FactionRegistry.OrderOf(owner) >= 0 else null


static func _name(label: Label, planet: Planet) -> void:
	var owner: Faction = Holder(planet)
	label.add_theme_font_override("font", Look.F("body_bold"))
	label.add_theme_color_override("font_color", OnPaper(owner.FactionColor) if owner != null else Look.C("ink"))
	label.add_theme_color_override("font_outline_color", Look.C("paper"))
	label.add_theme_constant_override("outline_size", HALO)


## `c`, darkened step by step until it reads at 4.5:1 on the parchment.
static func OnPaper(c: Color) -> Color:
	var paper := Look.C("paper")
	var out := c
	var guard := 0
	while Look.Contrast(out, paper) < 4.5 and guard < 20:
		out = out.darkened(0.08)
		guard += 1
	out.a = 1.0
	return out


## A corner icon: its glyph in ink on a small paper tab edged in the colour
## the window tinted it (the owner's, the fleet's side, ours for a mission);
## an uprising's glyph in signal red. Brass under the pointer. The original's
## own pictures (with the art) never reach here: this is the plain window.
static func _corner(btn: Button) -> void:
	var tint: Color = btn.get_theme_color("icon_normal_color")
	var uprising: bool = str(btn.get_meta("corner", "")) == "uprising"
	var tab := Look.Box("paper", "", 0, 2, 0)
	tab.border_color = Color(tint.r, tint.g, tint.b, 1.0)
	tab.set_border_width_all(1)
	var lit := tab.duplicate() as StyleBoxFlat
	lit.border_color = Look.C("brass")
	lit.set_border_width_all(2)
	btn.add_theme_stylebox_override("normal", tab)
	btn.add_theme_stylebox_override("hover", lit)
	btn.add_theme_stylebox_override("pressed", lit)
	var glyph := Look.C("signal") if uprising else Look.C("ink")
	for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		btn.add_theme_color_override(state, glyph)


## The three bars. Energy: ink used, open free. Raw materials: olive built,
## open free. Loyalty: the sides' map colours. Every block ink-edged.
static func _bars(row: Control) -> void:
	var kind: String = str(row.get_meta("bar_row"))
	if kind == "loyalty":
		for seg in row.get_children():
			if seg is Panel:
				_edge(seg as Panel, null)
		return
	var filled: int = int(row.get_meta("filled", 0))
	var i := 0
	for sq in row.get_children():
		if not sq is Panel:
			continue
		var fill: Color
		if i < filled:
			fill = Look.C("ink") if kind == "energy" else Look.C("olive")
		else:
			fill = Look.C("paper")
		_edge(sq as Panel, fill)
		i += 1


static func _edge(block: Panel, fill: Variant) -> void:
	var was: StyleBox = block.get_theme_stylebox("panel")
	var sb: StyleBoxFlat = (was as StyleBoxFlat).duplicate() if was is StyleBoxFlat else StyleBoxFlat.new()
	if fill is Color:
		sb.bg_color = fill
	sb.border_color = Look.C("ink")
	sb.set_border_width_all(1)
	block.add_theme_stylebox_override("panel", sb)
