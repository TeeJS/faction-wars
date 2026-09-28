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
## plain band (the rows above it untouched).
static func OptionsPlate() -> Texture2D:
	if _cache.has("options"):
		return _cache["options"]
	var src: Texture2D = Art.Screen("options")
	if src == null:
		return null
	var img: Image = _image(src)
	var band: Image = img.get_region(Band)
	for y in RowSixCover.size.y:
		img.blit_rect(band, Rect2i(0, y % Band.size.y, Band.size.x, 1), Vector2i(RowSixCover.position.x, RowSixCover.position.y + y))
	var tex := ImageTexture.create_from_image(img)
	_cache["options"] = tex
	return tex


## See all games: the Game Options picture's frame, with the Saved Games panel
## widened over the whole inside (its heading bar with it) and `rows` rows of
## sockets from `top`, `pitch` apart, laid out as `columns`: an array of
## [socket, x, width] - socket one of "save", "side", "name", "load".
static func AllGamesPlate(rows: int, top: int, pitch: int, columns: Array) -> Texture2D:
	var key := "all.%d.%d.%d.%s" % [rows, top, pitch, str(columns)]
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
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Forget the built pictures (the art was re-imported, or a test swapped it).
static func Reset() -> void:
	_cache.clear()
