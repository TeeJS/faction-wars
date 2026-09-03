extends SceneTree
## The two head-to-head speed rules (GameSettings.SpeedRule), every pair of
## settings, against a table. Speeds: Pause 0, Very Slow 1, Slow 2, Medium 3,
## Fast 4. "slowest" is the manual's rule (p163); "average" is TeeJ's (room
## AM-LFGGG3LVQSSJGXSP7P7JE9Q745 #75): floor of the mean, adjacent settings
## give the slower, an unbalanced pair rounds down, Pause on either side pauses.
##
##   Godot_console.exe --headless --path . -s tests/speed_rule.gd

func _init() -> void:
	var fails := 0
	var checks := 0
	var names := ["Pause", "Very Slow", "Slow", "Medium", "Fast"]
	for a in 5:
		for b in 5:
			var slowest := LockstepSession.combine_speeds(a, b, "slowest")
			var average := LockstepSession.combine_speeds(a, b, "average")
			var want_slowest: int = 0 if (a == 0 or b == 0) else mini(a, b)
			@warning_ignore("integer_division")
			var want_average: int = 0 if (a == 0 or b == 0) else (a + b) / 2
			checks += 2
			if slowest != want_slowest:
				fails += 1
				print("  FAIL slowest %s + %s -> %s (want %s)" % [names[a], names[b], names[slowest], names[want_slowest]])
			if average != want_average:
				fails += 1
				print("  FAIL average %s + %s -> %s (want %s)" % [names[a], names[b], names[average], names[want_average]])
	# TeeJ's own examples, by name.
	var examples := [
		["Slow", "Fast", "Medium"],          # the mean
		["Fast", "Very Slow", "Slow"],       # unbalanced: rounds down
		["Slow", "Medium", "Slow"],          # adjacent: the slower
		["Fast", "Fast", "Fast"],            # equal
		["Pause", "Fast", "Pause"],          # a pause pauses both
	]
	for e in examples:
		checks += 1
		var got := LockstepSession.combine_speeds(names.find(e[0]), names.find(e[1]), "average")
		if names[got] != e[2]:
			fails += 1
			print("  FAIL average %s + %s -> %s (TeeJ's example wants %s)" % [e[0], e[1], names[got], e[2]])
	print("[speed_rule] %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
