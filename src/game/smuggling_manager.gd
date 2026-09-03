class_name SmugglingManager
extends RefCounted
## backend/SmugglingManager.cs - SMUGGLING, manual p089 and REBEXE.EXE 0x55A0C0:
##   smugglingShift = (support >= entry 158) ? 0 : entry 157
## applied to POPULATED systems, on the controller's own support, on a timer.
## ⚠ The timer is ours (entry 160, 1000, used for both first and followup).

static var _next_theft: Dictionary = {}   # planet name -> day


static func Reset() -> void:
	_next_theft.clear()


static func IsSmuggled(p: Planet) -> bool:
	if p == null or not p.IsInhabited:
		return false
	var holder: Faction = p.ControllingFaction
	if holder == null or holder == FactionRegistry.Neutral:
		return false
	return p.SupportFor(holder) < RuleManager.Get(RuleId.SmugglingSupportThreshold, holder)


static func ProcessDay(galaxy: Array, day: int, _rng: Prng) -> void:
	if galaxy == null:
		return
	for s in galaxy:
		for p in s.Planets:
			if not IsSmuggled(p):
				_next_theft.erase(p.Name)
				continue
			var holder: Faction = p.ControllingFaction
			if not _next_theft.has(p.Name):
				_next_theft[p.Name] = day + Delay(holder)
				continue
			if day < _next_theft[p.Name]:
				continue
			_next_theft[p.Name] = day + Delay(holder)

			var shift := RuleManager.Get(RuleId.SmugglingSupportShift, holder)
			if shift == 0:
				continue
			var before: int = p.SupportFor(holder)
			p.ShiftSupport(holder, shift)
			print("[Smuggling] %s: support for %s %d -> %d (under %d%%)." % [p.Name, holder.Id, before, p.SupportFor(holder), RuleManager.Get(RuleId.SmugglingSupportThreshold, holder)])
			if not GameSettings.IsHuman(holder):
				continue
			var msg := GameMessage.new("Smuggling on %s" % p.Name,
				"%s does not strongly support us, and smugglers are working the mines and refineries there. Support has fallen to %d%%.\n\nA Diplomacy mission would raise it out of their reach." % [p.Name, p.SupportFor(holder)],
				Enums.MessageCategory.Missions, day, p)
			msg.Type = Enums.MessageType.Smuggling
			EventBus.Tell(holder, msg)


static func Delay(f: Faction) -> int:
	return max(1, RuleManager.Get(RuleId.SmugglingFollowupDelay, f))
