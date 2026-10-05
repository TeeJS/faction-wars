extends SceneTree
## THE ENGINE SELECTS FACILITIES BY ROLE, NOT BY THE PACK'S IDS (TeeJ,
## 2026-10-04: "is shipyard hardcoded in like planets ... we should make a more
## generic name"). Research, the Manufacturing window's tabs, a new HQ and the
## HQ checks used the family ids "shipyard", "headquarters" and the rest; now a
## pack may call its families anything. And a sighting lists a tier-2 facility
## by its own name - it read "Advanced Advanced Shipyard" (WWII: "Advanced
## Arsenal"), which the stale Manufacturing tabs never matched. Both packs:
##
##   .\tools\run-gd.ps1 tests/facility_roles.gd
##   .\tools\run-gd.ps1 tests/facility_roles.gd -- --pack=ww2

const Economy := preload("res://src/ui/economy_window.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[facility_roles] ok   %s" % what)
	else:
		_fails += 1
		print("[facility_roles] FAIL %s" % what)


func _init() -> void:
	FactionRegistry.EnsureLoaded()
	FacilityCatalog.LoadFromPack(FactionRegistry.Pack)
	print("[facility_roles] pack %s" % FactionRegistry.LoadedId())
	for role in ["produces_unit", "produces_troop", "produces_facility", "headquarters", "extracts_raw", "refines"]:
		var family := FacilityCatalog.FamilyForRole(role)
		_check(not family.is_empty(), "%s: the pack's family for it is '%s'" % [role, family])
		var names: Array = Economy.RoleNames(role)
		var defs: Array = FacilityCatalog.WithRole(role)
		_check(names.size() == defs.size() and not names.is_empty(), "%s: every tier's name (%s)" % [role, ", ".join(names)])
		for def in defs:
			var f := Facility.Make(def.Family, def.Tier)
			var line := IntelManager.Describe(f)
			_check(line == def.DisplayName and names.has(line), "%s tier %d is sighted as its own name '%s'" % [role, def.Tier, line])
			_check(not line.begins_with("Advanced Advanced"), "%s tier %d: no doubled 'Advanced'" % [role, def.Tier])
	print("[facility_roles] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
