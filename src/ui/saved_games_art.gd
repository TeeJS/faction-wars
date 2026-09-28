extends RefCounted
## The pictures the Saved Games screen's additions are made of, cut and
## stretched from the original's own (PROJECT.md: "built from the original's own
## bitmaps and lettering, placed to this screen's grid"). Nothing is drawn:
##   - the Game Options picture (COMMON.DLL 20002) with its sixth row painted
##     over by the panel's own plain band, for Import Game, Export Game and See
##     all games (TeeJ, 2026-09-27: five rows, the buttons in the sixth's place);
##   - the multiplayer screens' choice box (mp_choice, 152 x 33 - a box the
##     original writes words on) cut to any size, its ends kept;
##   - See all games: the Saved Games panel widened across the whole screen,
##     its rows rebuilt from the Saved Games row's own sockets.
## Each is built once from the player's imported art and kept.
##
## Preloaded by path: a new script can lag the editor's class cache.

const Art := preload("res://src/ui/artwork.gd")

## The Saved Games panel on the Game Options picture (px of its 640 x 480): its
## outer edge x 23..336 (its right bevel 334..336), y 34..339; the plain band
## between rows 5 and 6; the sixth row's sockets (with their shading), which
## the band paints over.
const PanelRect := Rect2i(23, 34, 314, 306)
const Band := Rect2i(23, 273, 314, 11)
const RowSixCover := Rect2i(23, 284, 314, 34)
## The heading bar (black) inside the panel: x 56..300, rows 37..58.
const HeadBarLeft := 56
const HeadBarRight := 300
## The panel's own top (edge, heading bar, space under it) and bottom (bevel)
## rows, kept when it is made taller.
const PanelTopRows := 40
const PanelBottomRows := 6
## See all games: the panel across the whole screen, inside the frame (the
## frame's metal from x 616 and y 455, as on the left from x 22).
const WidePanel := Rect2i(23, 34, 593, 421)
const DividerTick := Vector2i(342, 29)
const DividerTickSource := Rect2i(330, 29, 3, 5)
## A Saved Games row, from the picture's first row (row top 81): its strip
## with the shading above the sockets, and its four sockets - the Save Game
## socket (rounded left end), the side icon's, the name field's, the Load Game
## socket (rounded right end).
const RowStrip := Vector2i(74, 32)   # y 74, 32 rows: 7 above the row top
const RowStripAbove := 7
const SockSave := Vector2i(30, 48)   # x, width
const SockSide := Vector2i(78, 35)
const SockName := Vector2i(113, 170)
const SockLoad := Vector2i(283, 50)
## THE WIRES AND CLAMPS (TeeJ, 2026-09-28: the buttons "are missing the
## greeblies ... there should be wires and/or rivets"): the multiplayer
## screens' bottom strip (mp_connection), its four wires - yellow, red, blue,
## green - running behind its buttons with a clamp between each two and at
## each end. Cut from it: the wires where they run straight (x 108..113,
## y 447..460), tiled along; a clamp (x 98..105, y 439..471, its shadow the
## last column).
const WireSource := Rect2i(108, 447, 6, 14)
const ClampSource := Rect2i(98, 439, 8, 33)

static var _cache: Dictionary = {}


static func _image(tex: Texture2D) -> Image:
	var img: Image = tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	return img


## `img` made `width` wide: its `left` and `right` columns kept, the middle
## stretched (`smooth` for a textured surface, so its dither does not repeat
## into streaks; sharp for sockets and bars).
static func HStretch(img: Image, left: int, right: int, width: int, smooth: bool = false) -> Image:
	var h: int = img.get_height()
	var out := Image.create(width, h, false, Image.FORMAT_RGBA8)
	out.blit_rect(img, Rect2i(0, 0, left, h), Vector2i.ZERO)
	var mid: Image = img.get_region(Rect2i(left, 0, img.get_width() - left - right, h))
	mid.resize(maxi(1, width - left - right), h, Image.INTERPOLATE_BILINEAR if smooth else Image.INTERPOLATE_NEAREST)
	out.blit_rect(mid, Rect2i(Vector2i.ZERO, mid.get_size()), Vector2i(left, 0))
	out.blit_rect(img, Rect2i(img.get_width() - right, 0, right, h), Vector2i(width - right, 0))
	return out


## `img` made `height` tall: its `top` and `bottom` rows kept, the middle stretched.
static func VStretch(img: Image, top: int, bottom: int, height: int) -> Image:
	var w: int = img.get_width()
	var out := Image.create(w, height, false, Image.FORMAT_RGBA8)
	out.blit_rect(img, Rect2i(0, 0, w, top), Vector2i.ZERO)
	var mid: Image = img.get_region(Rect2i(0, top, w, img.get_height() - top - bottom))
	mid.resize(w, maxi(1, height - top - bottom), Image.INTERPOLATE_NEAREST)
	out.blit_rect(mid, Rect2i(Vector2i.ZERO, mid.get_size()), Vector2i(0, top))
	out.blit_rect(img, Rect2i(0, img.get_height() - bottom, w, bottom), Vector2i(0, height - bottom))
	return out


## The multiplayer screens' choice box, `size` big, its bracketed ends kept;
## `chosen` is the red-ended one the original shows while it is chosen.
static func Box(size: Vector2i, chosen: bool) -> Texture2D:
	var key := "box.%d.%d.%s" % [size.x, size.y, chosen]
	if _cache.has(key):
		return _cache[key]
	var src: Texture2D = Art.WindowPicture("mp_choice.chosen" if chosen else "mp_choice")
	if src == null:
		return null
	var img: Image = HStretch(_image(src), 12, 12, size.x)
	img = VStretch(img, 5, 5, size.y)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## The Game Options picture with its sixth row painted over by the panel's own
## plain band (the rows above it untouched) - and, given a row of buttons
## there (`wired`: [its top, its height, the gaps' centres x]), the wires
## behind it from the panel's one side to the other and a clamp in each gap.
static func OptionsPlate(wired: Array = []) -> Texture2D:
	var key := "options.%s" % str(wired)
	if _cache.has(key):
		return _cache[key]
	var src: Texture2D = Art.Screen("options")
	if src == null:
		return null
	var img: Image = _image(src)
	var band: Image = img.get_region(Band)
	for y in RowSixCover.size.y:
		img.blit_rect(band, Rect2i(0, y % Band.size.y, Band.size.x, 1), Vector2i(RowSixCover.position.x, RowSixCover.position.y + y))
	if wired.size() >= 3:
		Wire(img, PanelInside.x, PanelInside.y, int(wired[0]) + int(wired[1]) / 2, wired[2], wired[3] if wired.size() > 3 else [])
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## The Saved Games panel's inside, between its bevels: x 26..333; widened for
## See all games, x 26..612.
const PanelInside := Vector2i(26, 334)
const WideInside := Vector2i(26, 613)


## The multiplayer screens' wires across `img` from x `from` to `to`, centred
## on row `mid`, and a clamp centred on each of `clamps` (x); `loops`, wires
## led out of the clamps through the empty bands above and below the row
## (Loop). Without that screen's picture, nothing.
static func Wire(img: Image, from: int, to: int, mid: int, clamps: Array, loops: Array = []) -> void:
	var tex: Texture2D = Art.Screen("mp_connection")
	if tex == null:
		return
	var strip: Image = _image(tex)
	var wires: Image = strip.get_region(WireSource)
	var top: int = mid - WireSource.size.y / 2
	var x: int = from
	while x < to:
		var w: int = mini(WireSource.size.x, to - x)
		img.blit_rect(wires, Rect2i(0, 0, w, WireSource.size.y), Vector2i(x, top))
		x += w
	for l in loops:
		var xa: int = _gap(float(clamps[l[1]]), int(l[2]))
		var xb: int = _gap(float(clamps[l[3]]), int(l[4]))
		Loop(img, strip, str(l[0]), xa, xb, int(l[5]), top)
	var clamp: Image = strip.get_region(ClampSource)
	for cx in clamps:
		img.blit_rect(clamp, Rect2i(Vector2i.ZERO, ClampSource.size),
			Vector2i(roundi(float(cx) - ClampSource.size.x / 2.0), mid - ClampSource.size.y / 2))


## Each wire's rows in the strip where it runs straight (mp_connection, x 110):
## lit to dark - the yellow, the red, the blue, the green - and the dark row
## that shades them.
const WireProfileX := 110
const WireProfile := {"yellow": [447, 448, 449], "red": [451, 452, 453], "blue": [455, 456, 457], "green": [459, 460]}
const WireShadeRow := 450
## A loop's upright: two columns, the wire's lit and dark rows turned on end -
## the room in a gap beside a clamp.
const LoopUpright := 2


## The first column of the 2-px gap beside the clamp centred on `cx`: its left
## (`side` < 0) or its right, between the clamp and the box.
static func _gap(cx: float, side: int) -> int:
	var left: int = roundi(cx - ClampSource.size.x / 2.0)
	return left - LoopUpright if side < 0 else left + ClampSource.size.x


## One wire led out of the row (TeeJ, 2026-09-28: "the wires can go anywhere we
## want them to, they are just decorative - I want the dang empty space
## filled"), out of a clamp's opening - where the wires pass through its band,
## "not under the mounting legs" (TeeJ, the same day): from its own row where
## it leaves the clamp, up (or down) the gap beside it at x `xa`, along the
## band with its top at row `level`, and down (or up) the gap at `xb` into
## another clamp's opening (xa < xb). `band_top` is the straight wires' top
## row. The strip's own colours: the run lit to dark with the strip's shade
## under it, the uprights its lit and dark rows.
static func Loop(img: Image, strip: Image, colour: String, xa: int, xb: int, level: int, band_top: int) -> void:
	var rows: Array = WireProfile.get(colour, [])
	if rows.is_empty() or xb <= xa:
		return
	var cols: Array = []
	for r in rows:
		cols.append(strip.get_pixel(WireProfileX, r))
	var shade: Color = strip.get_pixel(WireProfileX, WireShadeRow)
	var w: int = cols.size()
	var size := Vector2i(img.get_width(), img.get_height())
	var put := func(x: int, y: int, c: Color) -> void:
		if x >= 0 and y >= 0 and x < size.x and y < size.y:
			img.set_pixel(x, y, c)
	# Where this wire passes the clamps: its own rows in the band.
	var own_first: int = band_top + int(rows[0]) - WireSource.position.y
	var own_last: int = own_first + w - 1
	var above: bool = level < band_top
	var y0: int = level + w if above else own_first
	var y1: int = own_last + 1 if above else level
	var upright: Array = [cols[0], cols[w - 1]]
	for x in [xa, xb]:
		for y in range(y0, y1):
			for k in LoopUpright:
				put.call(x + k, y, upright[k])
	for x in range(xa, xb + LoopUpright):
		for k in w:
			put.call(x, level + k, cols[k])
		put.call(x, level + w, shade)


## See all games: the Game Options picture's frame, with the Saved Games panel
## widened over the whole inside (its heading bar with it) and `rows` rows of
## sockets from `top`, `pitch` apart, laid out as `columns`: an array of
## [socket, x, width] - socket one of "save", "side", "name", "load". `foot`,
## for the row of page boxes (TeeJ, 2026-09-28: "this screen is missing the
## greeblies as well"): [its middle y, the clamps' centres x, and a name
## socket for the page line as [x, width, row top]] - the multiplayer screens'
## wires across the panel's inside behind the boxes, as on those screens.
static func AllGamesPlate(rows: int, top: int, pitch: int, columns: Array, foot: Array = []) -> Texture2D:
	var key := "all.%d.%d.%d.%s.%s" % [rows, top, pitch, str(columns), str(foot)]
	if _cache.has(key):
		return _cache[key]
	var src: Texture2D = Art.Screen("options")
	if src == null:
		return null
	var img: Image = _image(src)
	# The panel, its rows painted over by its own plain band.
	var panel: Image = img.get_region(PanelRect)
	var band: Image = img.get_region(Band)
	for y in range(PanelTopRows, PanelRect.size.y - PanelBottomRows):
		panel.blit_rect(band, Rect2i(0, y % Band.size.y, Band.size.x, 1), Vector2i(0, y))
	# Wider: the edges and the heading bar's two ends kept, the rest stretched.
	var l: int = HeadBarLeft - PanelRect.position.x + 8
	var r: int = PanelRect.end.x - HeadBarRight - 1 + 8   # the bar's end and the bevel
	panel = HStretch(panel, l, r, WidePanel.size.x, true)
	panel = VStretch(panel, PanelTopRows, PanelBottomRows, WidePanel.size.y)
	img.blit_rect(panel, Rect2i(Vector2i.ZERO, panel.get_size()), WidePanel.position)
	# The frame's top edge where the two panels' divider met it (x 342..344,
	# y 29..33): the same rows just left of it, so the edge runs unbroken.
	img.blit_rect(img.get_region(DividerTickSource), Rect2i(Vector2i.ZERO, DividerTickSource.size), DividerTick)
	# The rows: each column's socket cut from the first row and sized.
	var strip: Image = _image(src).get_region(Rect2i(0, RowStrip.x, 640, RowStrip.y))
	var sockets := {"save": SockSave, "side": SockSide, "name": SockName, "load": SockLoad}
	for k in rows:
		var y0: int = top + k * pitch - RowStripAbove
		for c: Array in columns:
			var s: Vector2i = sockets[c[0]]
			var piece: Image = strip.get_region(Rect2i(s.x, 0, s.y, RowStrip.y))
			if int(c[2]) != s.y:
				var keep: int = mini(12, s.y / 3)
				piece = HStretch(piece, keep, keep, int(c[2]))
			img.blit_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()), Vector2i(int(c[1]), y0))
	if foot.size() == 3:
		Wire(img, WideInside.x, WideInside.y, int(foot[0]), foot[1])
		var at: Array = foot[2]
		var socket: Image = HStretch(strip.get_region(Rect2i(SockName.x, 0, SockName.y, RowStrip.y)), 12, 12, int(at[1]))
		img.blit_rect(socket, Rect2i(Vector2i.ZERO, socket.get_size()), Vector2i(int(at[0]), int(at[2]) - RowStripAbove))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Forget the built pictures (the art was re-imported, or a test swapped it).
static func Reset() -> void:
	_cache.clear()
