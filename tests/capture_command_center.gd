extends SceneTree
## Renders the Command Center of a fresh game, the whole screen, to a PNG - in
## the original's look with the player's art, or with --noart as a player
## without it - so both builds can be laid side by side (docs: the plain build
## parity plan, TeeJ 2026-09-28). Needs a window (NOT --headless):
##
##   Godot_console.exe --path . --resolution 1440x850 -s tests/capture_command_center.gd -- --out=C:/tmp/cc.png [--faction=empire] [--noart]

const ArtScript := preload("res://src/ui/artwork.gd")


func _init() -> void:
	await process_frame
	var out := _arg("--out=", "user://command_center.png")
	if OS.get_cmdline_user_args().has("--noart"):
		ArtScript.IgnoreProjectFolder = true
		ArtScript.UserArtRoot = "user://capture-noart"
		ArtScript.Reset()
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.PlayerFaction = FactionRegistry.ById(_arg("--faction=", "alliance"))
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 12:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	# The briefing, where it plays, off: the screen as it is in play.
	var b: Node = ui.get_node_or_null("Briefing")
	if b == null:
		for c in root.find_children("Briefing", "", true, false):
			b = c
	if b != null and b.has_method("Skip"):
		b.call("Skip")
	for _i in 6:
		await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	var err := img.save_png(out)
	print("[capture_command_center] %s -> %s" % [out, "ok" if err == OK else ("error %d" % err)])
	quit(0 if err == OK else 1)


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
