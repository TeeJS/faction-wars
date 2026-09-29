extends SceneTree
## An import in steps, for its progress bar (TeeJ, 2026-09-28: "is there any
## way to show an import progress bar" - "absolutely, yes"): the job checks the
## files one by one, then writes them, then puts the whole in place, saying how
## far it has got; run to its end at once it gives what the import always gave;
## run a slice a frame it says each phase as it goes; the launch screen shows it
## in a box, and the box goes when it is done. A scratch art root, never the
## player's own.
##
##   .\tools\run-gd.ps1 tests/import_progress.gd

const PackImport := preload("res://src/ui/pack_import.gd")
const Art := preload("res://src/ui/artwork.gd")
const ROOT := "user://test-import-progress"
const FILES := 30

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[import_progress] ok   %s" % what)
	else:
		_fails += 1
		print("[import_progress] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = ROOT + "/art"
	PackImport._remove(ROOT)
	DirAccess.make_dir_recursive_absolute(ROOT)
	var zip_path := ROOT + "/test.art.zip"
	var files := {}
	for i in FILES:
		files["windows/pic_%02d.png" % i] = ("picture %d" % i).to_utf8_buffer()
	_zip(zip_path, files)

	# At once, as the import always ran.
	var at_once := PackImport.ImportFile(zip_path)
	_check(at_once.get("ok", false) and int(at_once.get("files", 0)) == FILES, "at once: imported, %d files (%s)" % [FILES, at_once.get("message", "")])

	# In steps: one file a slice, the phases in order.
	var zip := ZIPReader.new()
	zip.open(zip_path)
	var job := PackImport._job(zip)
	var seen: Array = []
	var checks := 0
	var writes := 0
	while PackImport.JobStep(job, 0):
		var ph := str(job["phase"])
		if seen.is_empty() or seen.back() != ph:
			seen.append(ph)
		if ph == "check":
			checks += 1
		elif ph == "write":
			writes += 1
		_check_quiet(int(job["done"]) <= int(job["total"]))
	zip.close()
	_check(seen == ["check", "write", "place"], "in steps: check, then write, then place (%s)" % str(seen))
	_check(checks >= FILES - 1 and writes >= FILES - 1, "a file a slice: %d checking slices, %d writing, of %d files" % [checks, writes, FILES])
	var stepped: Dictionary = job["result"]
	_check(stepped.get("ok", false) and stepped.get("message", "") == at_once.get("message", ""), "in steps: the same result as at once")

	# A slice a frame, saying how it goes, and the result as ever.
	var said: Array = []
	PackImport.OnProgress = func(phase: String, done: int, total: int) -> void: said.append([phase, done, total])
	var got: Array = []
	PackImport.OnImported = func(r: Dictionary) -> void: got.append(r)
	PackImport._run(zip_path)
	for _i in 600:
		if not got.is_empty():
			break
		await process_frame
	_check(not got.is_empty() and bool(got[0].get("ok", false)), "a slice a frame: imported (%s)" % (got[0].get("message", "") if not got.is_empty() else "nothing"))
	var phases: Array = []
	for s in said:
		if phases.is_empty() or phases.back() != s[0]:
			phases.append(s[0])
	_check(not said.is_empty() and said.back() == ["", 0, 0], "... and says it is done at the end")
	_check(phases.has("check") or phases.has("write") or phases.has("place"), "... and how it went on the way (%s)" % str(phases))
	PackImport.OnProgress = Callable()
	PackImport.OnImported = Callable()

	# Cancel (TeeJ, 2026-09-28: "in case it hangs"): a newer file, cancelled on
	# its first word, leaves the copy already in place as it was.
	var v2_path := ROOT + "/test2.art.zip"
	var v2 := {}
	for i in FILES:
		v2["windows/pic_%02d.png" % i] = ("newer %d" % i).to_utf8_buffer()
	_zip(v2_path, v2, "Test 2")
	var dest := Art.UserArtRoot + "/test-progress"
	var before := FileAccess.get_file_as_string(dest + "/windows/pic_00.png")
	var cut: Array = []
	PackImport.OnProgress = func(phase: String, _d: int, _t: int) -> void:
		cut.append(phase)
		if not phase.is_empty():
			PackImport.Cancel()
	got.clear()
	PackImport.OnImported = func(r: Dictionary) -> void: got.append(r)
	PackImport._run(v2_path)
	for _i in 600:
		if not got.is_empty():
			break
		await process_frame
	_check(got.size() == 1 and bool(got[0].get("cancelled", false)) and not bool(got[0].get("ok", true)) and got[0].get("message", "") == "Import cancelled.",
		"cancelled: 'Import cancelled.', once (%s)" % str(got))
	_check(FileAccess.get_file_as_string(dest + "/windows/pic_00.png") == before and before == "picture 0"
		and not DirAccess.dir_exists_absolute(dest + ".importing"),
		"... the copy in place untouched, nothing of the new one left beside it")
	_check(not cut.is_empty() and cut.back() == "", "... and the box is told it is over")
	# Cancel with nothing running here (the browser's own work, which may be
	# what hung): said over at once.
	cut.clear()
	got.clear()
	PackImport.Cancel()
	_check(got.size() == 1 and bool(got[0].get("cancelled", false)) and cut == [""], "Cancel with nothing running: cancelled at once, the box told")
	PackImport.OnProgress = Callable()
	PackImport.OnImported = Callable()

	# The launch screen's box: the phase, the bar, gone when done.
	var picker: Control = load("res://PackPicker.tscn").instantiate()
	root.add_child(picker)
	for _i in 3:
		await process_frame
	picker.call("_on_progress", "check", 15, 30)
	var box: Node = picker.get_node_or_null("ImportProgress")
	var bar: ProgressBar = box.find_child("Bar", true, false) if box != null else null
	var phase: Label = box.find_child("Phase", true, false) if box != null else null
	_check(box != null and bar != null and is_equal_approx(bar.value, 0.25) and phase.text == "Checking the files - 15 of 30",
		"the box: 'Checking the files - 15 of 30', a quarter of the bar")
	picker.call("_on_progress", "write", 30, 30)
	_check(bar != null and is_equal_approx(bar.value, 0.97), "writing done: nearly full")
	picker.call("_on_progress", "store", 0, 0)
	_check(bar != null and bar.indeterminate, "the browser keeping movies: the bar runs without a count")
	_check(box != null and not (box.find_child("Close", true, false) as Control).visible, "no close cross: Cancel is the way out")
	picker.call("_on_progress", "", 0, 0)
	await process_frame
	_check(picker.get_node_or_null("ImportProgress") == null, "done: the box goes")
	# Its Cancel: the box goes, and the files window says so.
	picker.call("_on_progress", "check", 3, 30)
	box = picker.get_node_or_null("ImportProgress")
	var cancel: Button = box.find_child("CancelImport", true, false) if box != null else null
	_check(cancel != null and cancel.text == "CANCEL", "the box has a Cancel button")
	if cancel != null:
		cancel.pressed.emit()
	await process_frame
	await process_frame
	_check(picker.get_node_or_null("ImportProgress") == null, "Cancel: the box goes")
	root.remove_child(picker)
	picker.free()

	PackImport._remove(ROOT)
	Art.Reset()
	print("[import_progress] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _check_quiet(cond: bool) -> void:
	if not cond:
		_check(false, "done never passes total")


func _zip(path: String, files: Dictionary, title: String = "Test") -> void:
	var hashes := {}
	for rel in files:
		hashes[rel] = PackImport._sha256(files[rel])
	var zp := ZIPPacker.new()
	zp.open(path)
	for rel in files:
		zp.start_file(rel)
		zp.write_file(files[rel])
		zp.close_file()
	zp.start_file("manifest.json")
	zp.write_file(JSON.stringify({"format": 1, "kind": "art_set", "id": "test-progress", "title": title,"exporter": PackImport.MIN_EXPORTER.get("swr-original", "2.6.5"), "files": hashes}).to_utf8_buffer())
	zp.close_file()
	zp.close()
