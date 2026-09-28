extends SceneTree
## The original's click on its controls (TeeJ, 2026-09-27: "no menu button
## sounds"). REBEXE gives a control its click sound at 0x602840: STRATEGY 608
## on the strategy windows' buttons and the Control Panel's monitors, the GID
## monitor's 600 (0x4286b0). The pack names them (pack.json `sounds`); with
## the test tone standing in for the art set's sounds:
##   - the moments are in the pack, as the original's ids;
##   - an original-look window's button plays 608 when pressed;
##   - a Control Panel monitor plays 608, the GID's 600.
##
##   .\tools\run-gd.ps1 tests/click_sounds.gd

const Art := preload("res://src/ui/artwork.gd")
const OUI := preload("res://src/ui/original_ui.gd")
const SoundLib := preload("res://src/ui/sound.gd")
const MusicLib := preload("res://src/ui/music.gd")
const Frame := preload("res://src/ui/command_frame.gd")
const Tone := "res://tests/fixtures/music_test.ogg"
const ArtRoot := "user://test-click-sounds-art"
const Settings := "user://test-click-sounds.cfg"

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[click_sounds] ok   %s" % what)
	else:
		_fails += 1
		print("[click_sounds] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = ArtRoot
	_remove(ArtRoot)
	MusicLib.SettingsFile = Settings
	DirAccess.remove_absolute(Settings)
	SoundLib._loaded = false
	SoundLib.Volume = SoundLib.DEFAULT_VOLUME
	SoundLib.PlayHeadless = true
	FactionRegistry.EnsureLoaded()
	var m: PackDefs.PackManifest = FactionRegistry.Pack.Manifest
	_check(m.Sounds.get("window_button", "") == "swr-original:sound/strategy/608.ogg"
		and m.Sounds.get("control_panel", "") == "swr-original:sound/strategy/608.ogg"
		and m.Sounds.get("control_panel_gid", "") == "swr-original:sound/strategy/600.ogg",
		"the pack names the clicks: STRATEGY 608, the GID monitor's 600")
	for key in ["window_button", "control_panel_gid"]:
		_stand_in(str(m.Sounds[key]), FileAccess.get_file_as_bytes(Tone))
	Art.Reset()

	# A window's button.
	var host := Control.new()
	root.add_child(host)
	var b := TextureButton.new()
	host.add_child(b)
	OUI.ClickSound(b)
	b.pressed.emit()
	await process_frame
	_check(_playing().any(func(p: String) -> bool: return p.ends_with("strategy/608.ogg")), "a window's button clicks with 608 (%s)" % str(_playing()))
	_stop()

	# The Control Panel.
	var frame: Control = Frame.new()
	root.add_child(frame)
	frame.Side = "alliance"
	var opened := []
	frame.AddConsoles({ "gid": func() -> void: opened.append("gid"), "fleet_finder": func() -> void: opened.append("fleet_finder") })
	var cons: Dictionary = frame.Consoles()
	_check(cons.has("gid") and cons.has("fleet_finder"), "the Control Panel's monitors are there")
	if cons.has("fleet_finder"):
		(cons["fleet_finder"] as Button).pressed.emit()
		await process_frame
		_check(opened.has("fleet_finder") and _playing().any(func(p: String) -> bool: return p.ends_with("strategy/608.ogg")),
			"the Fleet Finder monitor opens its finder and clicks with 608")
		_stop()
	if cons.has("gid"):
		(cons["gid"] as Button).pressed.emit()
		await process_frame
		_check(opened.has("gid") and _playing().any(func(p: String) -> bool: return p.ends_with("strategy/600.ogg")),
			"the GID monitor clicks with 600 (%s)" % str(_playing()))
		_stop()

	frame.queue_free()
	host.queue_free()
	_remove(ArtRoot)
	DirAccess.remove_absolute(Settings)
	print("[click_sounds] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _playing() -> Array:
	var out := []
	for n in root.get_children():
		if n is AudioStreamPlayer and n.has_meta("path"):
			out.append(str(n.get_meta("path")))
	return out


func _stop() -> void:
	for n in root.get_children():
		if n is AudioStreamPlayer:
			(n as AudioStreamPlayer).stop()
			n.free()


func _stand_in(ref: String, bytes: PackedByteArray) -> void:
	var split: PackedStringArray = PackLoader.SplitArtRef(ref)
	var path := "%s/%s/%s" % [ArtRoot, split[0], split[1]]
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)
