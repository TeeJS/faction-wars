extends SceneTree
## "View credits" (manual p021, Fig. 2.2) opens from either form of the
## Cockpit and shows the pack's own lines (the editor handoff, 2026-09-23: the
## WWII pack's credits were never shown, and without the Cockpit picture no
## pack's could be opened):
##   - the button form has a View Credits button;
##   - the WWII pack (no `menu`) shows pack.json's top-level `credits`;
##   - the Star Wars pack shows its `menu.credits`, in the button form too.
##
##   .\tools\run-gd.ps1 tests/pack_credits.gd

const Art := preload("res://src/ui/artwork.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[pack_credits] ok   %s" % what)
	else:
		_fails += 1
		print("[pack_credits] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true   # the button form, whatever art this checkout has
	for id in ["ww2", "star-wars-rebellion"]:
		FactionRegistry.Unload()
		FactionRegistry.EnsureLoaded(id)
		var want: Array[String] = Menu.PackCredits()
		_check(not want.is_empty(), "%s declares credits (%d lines)" % [id, want.size()])
		var menu: Node = load("res://Menu.tscn").instantiate()
		root.add_child(menu)
		await process_frame
		var btn: Button = menu.get_node_or_null("BtnCredits")
		_check(btn != null, "%s: the button Cockpit has View Credits" % id)
		if btn != null:
			btn.pressed.emit()
			await process_frame
			var win: Node = menu.get_node_or_null("CreditsWindow")
			var shown: Array[String] = []
			if win != null:
				for l in win.find_child("Lines", true, false).get_children():
					shown.append((l as Label).text)
			_check(shown == want, "%s: it shows the pack's lines (%s)" % [id, " / ".join(shown.slice(0, 2))])
		menu.queue_free()
		await process_frame
	print("[pack_credits] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
