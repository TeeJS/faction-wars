extends RefCounted
## ONE ANIMATION RUN OF THE DROIDS OR THE BRIEFING (docs/advisor-plan.md): the
## art set's anim/<dll>/<anchor>.fwa (exporter 2.6.0), the original's frames
## kept as it stores them - the first whole, each later one a change on the one
## before. The file (little-endian): "FWA1", u16 width, u16 height, u16 frames
## (the first counted), the palette (256 x R, G, B; index 0 is clear), the first
## frame's indices (width x height, top row first), then each later frame as a
## u32 length and its bytes: a 17-byte header (u16 width, u16 height, u32
## payload size, the rest unused), a u32 offset into the payload per row, and
## per row runs that alternate skip / change, a change's bytes ADDED (mod 256)
## to the indices under them.
##
## Open a run, then Next() steps it and Picture() draws the frame it is on.
## Preloaded by path (as Fwa).

const HEADER := 17

var Width: int = 0
var Height: int = 0
## Frames in the run, the first counted.
var Count: int = 0
## The frame shown: 0 is the first.
var At: int = 0

var _rgba: PackedByteArray      # the palette, 4 bytes an index; index 0 clear
var _first: PackedByteArray
var _index: PackedByteArray
var _later: Array[PackedByteArray] = []


## The run in `path`, or null when it is not one.
static func Open(path: String) -> RefCounted:
	var b := FileAccess.get_file_as_bytes(path)
	if b.size() < 10 + 768 or b.slice(0, 4).get_string_from_ascii() != "FWA1":
		return null
	var run: RefCounted = (load("res://src/ui/fwa.gd") as GDScript).new()
	run.Width = b.decode_u16(4)
	run.Height = b.decode_u16(6)
	run.Count = b.decode_u16(8)
	var n: int = run.Width * run.Height
	if run.Width <= 0 or run.Height <= 0 or run.Count <= 0 or b.size() < 10 + 768 + n:
		return null
	var rgba := PackedByteArray()
	rgba.resize(256 * 4)
	for i in 256:
		rgba[i * 4] = b[10 + i * 3]
		rgba[i * 4 + 1] = b[10 + i * 3 + 1]
		rgba[i * 4 + 2] = b[10 + i * 3 + 2]
		rgba[i * 4 + 3] = 0 if i == 0 else 255
	run._rgba = rgba
	var at: int = 10 + 768
	run._first = b.slice(at, at + n)
	at += n
	for f in run.Count - 1:
		if at + 4 > b.size():
			break
		var length: int = b.decode_u32(at)
		at += 4
		if at + length > b.size():
			break
		run._later.append(b.slice(at, at + length))
		at += length
	run.Count = 1 + run._later.size()
	run.Reset()
	return run


## Back to the first frame.
func Reset() -> void:
	_index = _first.duplicate()
	At = 0


## The next frame; false at the end of the run (or at a frame that does not fit).
func Next() -> bool:
	if At + 1 >= Count:
		return false
	var d: PackedByteArray = _later[At]
	var w := Width
	var h := Height
	if d.size() < HEADER + h * 4:
		return false
	var payload: int = HEADER + h * 4
	for row in h:
		var p: int = payload + d.decode_u32(HEADER + row * 4)
		var x := 0
		var change := false
		var base := row * w
		while x < w:
			if p >= d.size():
				return false
			var k: int = d[p]
			p += 1
			if x + k > w:
				return false
			if change:
				for i in k:
					_index[base + x + i] = (_index[base + x + i] + d[p + i]) & 255
				p += k
			x += k
			change = not change
	At += 1
	return true


## The frame on show, as a picture (index 0 clear).
func Picture() -> Image:
	var n := Width * Height
	var px := PackedByteArray()
	px.resize(n * 4)
	for i in n:
		var c: int = _index[i] * 4
		px[i * 4] = _rgba[c]
		px[i * 4 + 1] = _rgba[c + 1]
		px[i * 4 + 2] = _rgba[c + 2]
		px[i * 4 + 3] = _rgba[c + 3]
	return Image.create_from_data(Width, Height, false, Image.FORMAT_RGBA8, px)
