extends SceneTree
## The game's audio buses come from default_bus_layout.tres, never from
## AudioServer.add_bus() at run time. On the web, Godot 4.7.1's driver puts a
## bus added at run time one place early: Master ends up sending into the new
## bus and the buses form a ring with nothing reaching the speakers, so the
## music, the briefing and every other sound are silent (TeeJ, 2026-09-27;
## traced in the browser's Web Audio graph). A layout the engine loads at
## start is made in order on the web too.
##   - Music and Effects are there before either library asks for its bus;
##   - both send to Master; Master is bus 0;
##   - asking for them (music.gd / sound.gd Bus) adds no bus.
##
##   .\tools\run-gd.ps1 tests/audio_buses.gd

const MusicLib := preload("res://src/ui/music.gd")
const SoundLib := preload("res://src/ui/sound.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[audio_buses] ok   %s" % what)
	else:
		_fails += 1
		print("[audio_buses] FAIL %s" % what)


func _init() -> void:
	var count := AudioServer.bus_count
	var music := AudioServer.get_bus_index(MusicLib.BUS)
	var effects := AudioServer.get_bus_index(SoundLib.BUS)
	_check(AudioServer.get_bus_name(0) == "Master", "bus 0 is Master")
	_check(music > 0, "the Music bus is there at start (index %d)" % music)
	_check(effects > 0, "the Effects bus is there at start (index %d)" % effects)
	_check(music > 0 and AudioServer.get_bus_send(music) == &"Master", "Music sends to Master")
	_check(effects > 0 and AudioServer.get_bus_send(effects) == &"Master", "Effects sends to Master")
	_check(MusicLib.Bus() == music and SoundLib.Bus() == effects, "the libraries find the layout's buses")
	_check(AudioServer.bus_count == count, "asking for them adds no bus (%d -> %d)" % [count, AudioServer.bus_count])
	print("[audio_buses] %d/%d passed" % [_checks - _fails, _checks])
	quit(1 if _fails > 0 else 0)
