class_name MailboxTransport
extends Transport
## Two files in a directory: I append to <side>.out and read the other side's.
## No sockets, deterministic, and both halves of the exchange stay on disk for
## inspection (docs/m2-plan.md section 1).

var _dir: String
var _side: String
var _other: String
var _out: FileAccess
var _in_path: String
var _offset: int = 0
var _partial: String = ""


func _init(dir: String, side: String, other: String) -> void:
	_dir = dir
	_side = side
	_other = other
	DirAccess.make_dir_recursive_absolute(dir)
	_out = FileAccess.open("%s/%s.out" % [dir, side], FileAccess.WRITE)
	_in_path = "%s/%s.out" % [dir, other]


func send(msg: Dictionary) -> void:
	if _out == null:
		return
	_out.store_line(JSON.stringify(msg))
	_out.flush()


func poll() -> Array:
	var out: Array = []
	if not FileAccess.file_exists(_in_path):
		return out
	var f := FileAccess.open(_in_path, FileAccess.READ)
	if f == null:
		return out
	var size := f.get_length()
	if size <= _offset:
		return out
	f.seek(_offset)
	var chunk: String = f.get_buffer(size - _offset).get_string_from_utf8()
	_offset = size
	var text: String = _partial + chunk
	var lines := text.split("\n")
	# The last piece is complete only if the text ended with a newline.
	_partial = "" if text.ends_with("\n") else lines[lines.size() - 1]
	var complete: int = lines.size() if text.ends_with("\n") else lines.size() - 1
	for i in complete:
		var line: String = lines[i]
		if line.is_empty():
			continue
		var d: Variant = JSON.parse_string(line)
		if d is Dictionary:
			out.append(d)
	return out


func close() -> void:
	if _out != null:
		_out.close()
		_out = null
