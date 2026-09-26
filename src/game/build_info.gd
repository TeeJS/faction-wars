class_name BuildInfo
extends RefCounted
## Which build is this? The image workflow writes res://version.txt before the
## export ("<utc date> <7-char commit>"); a local run has no file and says dev.
## Shown right of the Menu button in play and bottom-right on the Cockpit
## (TeeJ, room AM-LFGGG3LVQSSJGXSP7P7JE9Q745 #106).

static var _cached: String = ""


static func version() -> String:
	if not _cached.is_empty():
		return _cached
	# A web export without the file is not a local run: it says so, and
	# matches no other build (same_build).
	_cached = "web-dev" if OS.has_feature("web") else "dev"
	if FileAccess.file_exists("res://version.txt"):
		var line := FileAccess.get_file_as_string("res://version.txt").strip_edges()
		if not line.is_empty():
			_cached = line
	return _cached


## Can two builds play each other? Their commits - the last word of "<date>
## <sha7>" - must be the same. "dev", a local run (never the web: a web
## export always carries its version file), plays any build, so a local run
## can be tested against the web. A missing build is a mismatch, never a
## wildcard.
static func same_build(a: String, b: String) -> bool:
	a = a.strip_edges()
	b = b.strip_edges()
	if a.is_empty() or b.is_empty():
		return false
	if a == "dev" or b == "dev":
		return true
	return _commit(a) == _commit(b)


static func _commit(v: String) -> String:
	var words := v.split(" ", false)
	return words[words.size() - 1] if words.size() > 0 else ""


## A small grey label for a corner or a bar.
static func label() -> Label:
	var l := Label.new()
	l.name = "BuildVersion"
	l.text = version()
	l.tooltip_text = "Build version: date and commit."
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
