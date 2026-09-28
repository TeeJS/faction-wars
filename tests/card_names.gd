extends SceneTree
## A card's name wraps inside its card (TeeJ, 2026-09-28: "with your recent
## font changes, we are now getting overlap in the defence window" - "Imperial
## Probe" ran into "Bothan Spies"). The original's Yavin Personnel page:
## "Jan Dodonna" on one line, "Luke Skywalker" and "Wedge Antilles" on two.
##
##   .\tools\run-gd.ps1 tests/card_names.gd

const OUI := preload("res://src/ui/original_ui.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[card_names] ok   %s" % what)
	else:
		_fails += 1
		print("[card_names] FAIL %s" % what)


func _init() -> void:
	await process_frame
	var box := Control.new()
	root.add_child(box)
	var lines := {"Imperial Probe Droid": 2, "Jan Dodonna": 1, "Luke Skywalker": 2, "Wedge Antilles": 2, "Bothan Spies": 1, "Emperor Palpatine": 2}
	for title in lines:
		var card := Button.new()
		box.add_child(card)
		OUI.Card(card, title, null, Color.WHITE, Color.GREEN)
		await process_frame
		var name: Label = card.get_node("Name")
		var font: Font = name.get_theme_font("font")
		var widest := 0.0
		for word_line in _wrapped(title, font, name.size.x, name.get_theme_font_size("font_size")):
			widest = maxf(widest, font.get_string_size(word_line, HORIZONTAL_ALIGNMENT_LEFT, -1, name.get_theme_font_size("font_size")).x)
		_check(name.size.x == (OUI.CardW - 2) * OUI.K and name.get_line_count() == lines[title] and widest <= name.size.x,
			"'%s': %d line(s) inside the card's %d (%d, widest %.0f)" % [title, lines[title], (OUI.CardW - 2) * OUI.K, name.get_line_count(), widest])
	print("[card_names] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## The lines a word wrap at `w` makes.
static func _wrapped(text: String, font: Font, w: float, px: int) -> Array:
	var out: Array = []
	var line := ""
	for word in text.split(" "):
		var next := word if line.is_empty() else line + " " + word
		if not line.is_empty() and font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > w:
			out.append(line)
			line = word
		else:
			line = next
	out.append(line)
	return out
