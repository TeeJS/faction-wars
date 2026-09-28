class_name SmugglingManager
extends RefCounted
## backend/SmugglingManager.cs - SMUGGLING, manual p089 and REBEXE.EXE 0x55A0C0:
##   smugglingShift = (support >= entry 158) ? 0 : entry 157
## applied to POPULATED systems, on the controller's own support, on a timer.
## ⚠ The timer is ours (entry 160, 1000, used for both first and followup).

static var _next_theft: Dictionary = {}   # planet name -> day
static var _robbed: Dictionary = {}       # planet name -> the Faction told the losses began


static func Reset() -> void:
	_next_theft.clear()
	_robbed.clear()


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
				if _robbed.has(p.Name):
					var was: Faction = _robbed[p.Name]
					_robbed.erase(p.Name)
					if p.ControllingFaction == was:
						_Tell(was, p, day, false)
				continue
			var holder: Faction = p.ControllingFaction
			if not _next_theft.has(p.Name):
				_next_theft[p.Name] = day + Delay(holder)
				_robbed[p.Name] = holder
				_Tell(holder, p, day, true)
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


## THE ORIGINAL TELLS THE LOSSES BEGINNING AND ENDING, not each theft (TEXTSTRA
## 28768-28773, STRATEGY 1004 - REBEXE 0x499120): "Smuggling Losses" / "Dissention
## among the population has allowed smugglers to begin operations on <system>.
## As a result, valuable resources are being lost." and "Smuggling Losses End" /
## "Increasing support on <system> has put an end to the smuggling losses there."
static func _Tell(holder: Faction, p: Planet, day: int, begun: bool) -> void:
	if holder == null or not GameSettings.IsHuman(holder):
		return
	var msg := GameMessage.new("Smuggling Losses" if begun else "Smuggling Losses End",
		("Dissention among the population has allowed smugglers to begin operations on %s.  As a result, valuable resources are being lost." if begun
			else "Increasing support on %s has put an end to the smuggling losses there.") % p.Name,
		Enums.MessageCategory.Missions, day, p)
	msg.Type = Enums.MessageType.Smuggling
	msg.Still = "message.1004"
	msg.Sound = "strategy/1103"
	EventBus.Tell(holder, msg)


static func Delay(f: Faction) -> int:
	return max(1, RuleManager.Get(RuleId.SmugglingFollowupDelay, f))
