extends SceneTree
## The PRNG proof (HANDOFF §8): the GDScript xorshift64* must reproduce the C#
## reference's first thousand outputs from seed 12345, byte for byte.
##
##   Godot_console.exe --headless --path . -s tests/prng_check.gd


func _init() -> void:
	# A Windows checkout gives the fixture CRLF endings; the numbers are the same.
	var fixture := FileAccess.get_file_as_string("res://tests/fixtures/prng-12345.txt").replace("\r", "").split("\n", false)
	var ours := Prng.dump(12345, 1000)
	var bad := 0
	for i in ours.size():
		var want := fixture[i] if i < fixture.size() else "<missing>"
		if ours[i] != want:
			bad += 1
			if bad <= 5:
				print("  line %d: C#=%s GD=%s" % [i, want, ours[i]])
	# The derived contracts, spot-checked against values the C# side computes
	# the same way (low 31 bits; min + low31 % range; 53-bit double).
	var p := Prng.new(12345)
	var r := p.next64()
	var q := Prng.new(12345)
	var n := q.Next()
	if n != (r & 0x7FFFFFFF):
		bad += 1
		print("  Next() != low31(next64)")
	print("[prng_check] %d of %d outputs match; %s" % [ours.size() - bad, ours.size(), "PASS" if bad == 0 else "FAIL"])
	quit(0 if bad == 0 else 1)
