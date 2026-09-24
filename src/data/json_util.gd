class_name JsonUtil
extends RefCounted
## What System.Text.Json does for the C# source, reproduced here so hydration is a
## faithful mirror rather than a reinterpretation (HANDOFF §4, §6 step 1A):
##
##   - PropertyNameCaseInsensitive = true at every load site -> get_ci
##   - a missing key leaves the C# default                    -> the *_or helpers' defaults
##   - `int?` keeps null distinct from 0 (HANDOFF risk 8)      -> int_or_null
##   - JSON numbers arrive as float from JSON.parse             -> int() at every int site
##
## Hydrators call these and nothing else, so the rules live in one place.


static func read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


## Parses a file. Returns null for a missing/empty file (the C# loaders treat
## that as "no data") and pushes an error for malformed JSON.
static func parse(path: String) -> Variant:
	var text := read_text(path)
	if text.strip_edges().is_empty():
		return null
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("%s: malformed JSON at line %d - %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


## A keyed map's entries, without its comments: a key starting with "_" (a
## "_comment", a "_note") is the pack author's, never data - anywhere a map's
## keys are ids, names or stats (SCHEMA.md section 1; the editor handoff,
## 2026-09-23: a "_comment" in mission_tables.tables was a script error, in
## setup's logistics a crash at game start).
static func data_keys(d: Dictionary) -> Array:
	var out: Array = []
	for k in d.keys():
		if not str(k).begins_with("_"):
			out.append(k)
	return out


## Case-insensitive key lookup - exact match first, then a case-folded scan.
static func get_ci(d: Dictionary, key: String, default: Variant = null) -> Variant:
	if d.has(key):
		return d[key]
	var lower := key.to_lower()
	for k in d.keys():
		if str(k).to_lower() == lower:
			return d[k]
	return default


static func int_or(d: Dictionary, key: String, default: int = 0) -> int:
	var v: Variant = get_ci(d, key)
	if v == null:
		return default
	return int(v)


## `int?` on the C# side: null stays null.
static func int_or_null(d: Dictionary, key: String) -> Variant:
	var v: Variant = get_ci(d, key)
	if v == null:
		return null
	return int(v)


static func float_or(d: Dictionary, key: String, default: float = 0.0) -> float:
	var v: Variant = get_ci(d, key)
	if v == null:
		return default
	return float(v)


static func bool_or(d: Dictionary, key: String, default: bool = false) -> bool:
	var v: Variant = get_ci(d, key)
	if v == null:
		return default
	return bool(v)


## C# string default is null; pass "" where the class initialises one.
static func str_or(d: Dictionary, key: String, default: Variant = null) -> Variant:
	var v: Variant = get_ci(d, key)
	if v == null:
		return default
	return str(v)


## List<string>. `default` is what the C# declaration initialises - [] for
## `= new()`, null where there is no initialiser.
static func str_list(d: Dictionary, key: String, default: Variant = null) -> Variant:
	var v: Variant = get_ci(d, key)
	var out: Array[String] = []
	if v == null:
		# A missing key with an Array default still yields a TYPED array, so a
		# DTO's `Array[String]` field can take it (an untyped [] cannot be
		# assigned to one - it raised at load for every character without roles).
		if default is Array:
			out.assign(default)
			return out
		return default
	for x in v:
		out.append(str(x))
	return out


## Dictionary<string,int>
static func str_int_dict(d: Dictionary, key: String) -> Dictionary:
	var v: Variant = get_ci(d, key)
	var out := {}
	if v == null:
		return out
	for k in data_keys(v):
		out[str(k)] = int(v[k])
	return out


## A JsonStringEnumConverter read: the enum's name (case-insensitive) or its number.
static func enum_or(d: Dictionary, key: String, enum_dict: Dictionary, default: int) -> int:
	var v: Variant = get_ci(d, key)
	if v == null:
		return default
	if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
		return int(v)
	var name := str(v).to_lower()
	for k in enum_dict.keys():
		if str(k).to_lower() == name:
			return enum_dict[k]
	push_error("Unknown enum value '%s' for %s" % [v, key])
	return default


## The name of an enum value, for logs and the canonical dump.
static func enum_name(enum_dict: Dictionary, value: int) -> String:
	for k in enum_dict.keys():
		if enum_dict[k] == value:
			return str(k)
	return str(value)


## GENERIC HYDRATION, the STJ way: every script variable on `obj` whose name matches
## a key (case-insensitively) is assigned, coerced to the variable's declared type.
## Used for the game classes (Unit/Character have ~100 fields); the small DTOs use
## explicit from_dict functions so their nullability is visible.
##   enum_fields: var name -> enum Dictionary
##   ref_fields:  var name -> Callable(String) -> Object  (the C# JsonConverters)
static func hydrate(obj: Object, d: Dictionary, enum_fields: Dictionary = {}, ref_fields: Dictionary = {}, skip: Array = []) -> void:
	var script: Script = obj.get_script()
	while script != null:
		for p in script.get_script_property_list():
			if not (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
			var name: String = p.name
			if skip.has(name) or name.begins_with("_"):
				continue
			var v: Variant = get_ci(d, name)
			if v == null:
				continue
			if enum_fields.has(name):
				obj.set(name, enum_or(d, name, enum_fields[name], obj.get(name)))
			elif ref_fields.has(name):
				obj.set(name, ref_fields[name].call(str(v)))
			else:
				match p.type:
					TYPE_INT:
						obj.set(name, int(v))
					TYPE_FLOAT:
						obj.set(name, float(v))
					TYPE_BOOL:
						obj.set(name, bool(v))
					TYPE_STRING:
						obj.set(name, str(v))
					TYPE_ARRAY:
						# Keep the declared element type: an Array[int] var cannot take
						# an untyped Array, and JSON numbers arrive as float.
						var cur: Variant = obj.get(name)
						if cur is Array and cur.is_typed():
							var out: Array = cur.duplicate()
							out.clear()
							var elem_type: int = cur.get_typed_builtin()
							for x in v:
								match elem_type:
									TYPE_INT: out.append(int(x))
									TYPE_FLOAT: out.append(float(x))
									TYPE_STRING: out.append(str(x))
									_: out.append(x)
							obj.set(name, out)
						else:
							obj.set(name, Array(v))
					_:
						pass   # objects and nulls: the source has no JSON-fed ones here
		script = script.get_base_script()
