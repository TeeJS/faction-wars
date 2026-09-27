class_name Result
extends RefCounted
## The C# `bool Try(..., out string error)` shape. `ok` is the return value and
## `error` the out parameter; `value` carries an int result where C# returned one.

var ok: bool
var error: String = ""
var value: Variant = null
## Why, as a word the interface can act on (the agent's answer, docs/advisor-plan.md
## phase 3): "no_maintenance", "not_controlled", "in_transit"; "" when nothing says.
var code: String = ""


static func success(value: Variant = null) -> Result:
	var r := Result.new()
	r.ok = true
	r.value = value
	return r


## This result with its reason's `code`.
func coded(c: String) -> Result:
	code = c
	return self


static func fail(error: String, value: Variant = null) -> Result:
	var r := Result.new()
	r.ok = false
	r.error = error
	r.value = value
	return r
