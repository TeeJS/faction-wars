class_name TacticalBattle
extends RefCounted
## backend/TacticalBattle.cs - THE TACTICAL BATTLE, manual Chapter 4 and
## REBEXE.EXE 0x5AE9C0 onward. "Simulate Results" and "Take Command" are the
## SAME ENGINE; this is it, run headless. Every decoded rule is the source's;
## every omission is the source's too, and named there.
##
## FLOAT FIDELITY: the C# side computes in 32-bit floats. GDScript scalars are
## 64-bit, so every C# float assignment is rounded through f32() here, which
## keeps the two models on the same values except where .NET and Godot's own
## transcendental functions (atan2, sqrt) differ in the last bit.

enum TacticalState { None = 0, Docked = 1, Active = 2, Launching = 3, Recovering = 4, Recovered = 5, HyperingOut = 6, HyperOut = 7, Withdrawing = 8, Withdrawn = 9, DeathStarRun = 10, Dead = 11 }
enum TacticalOrder { None, AttackCapitalShips, AttackFighters, Recover, AttackDeathStar, Escort }
enum TacticalTactic { Surround = 1, StandOff = 2 }

const Dt: float = 1.0
const StallLimit: float = 1200.0
const ReassignPeriod := 6
const KillHorizon: float = 180.0
const GroupNames := ["Red", "Blue", "Green", "Gold"]

static var _f32 := PackedFloat32Array([0.0])


## Round to the nearest 32-bit float, as C# `float` arithmetic does at every step.
static func f32(x: float) -> float:
	_f32[0] = x
	return _f32[0]


## C# Mathf.Wrap(float): min + ((value - min) % range + range) % range.
static func wrap_cs(value: float, min_v: float, max_v: float) -> float:
	var range_v := f32(max_v - min_v)
	if is_zero_approx(range_v):
		return min_v
	return f32(min_v + f32(fmod(f32(fmod(f32(value - min_v), range_v) + range_v), range_v)))


class TacticalUnit:
	var Source: Unit
	var Side: int
	var State: int = TacticalState.Active
	var Order: int = TacticalOrder.None
	var Target: TacticalUnit
	var Carrier: TacticalUnit
	var Position: Vector2
	var Facing: float
	var Damage: ShipDamage
	var SubsystemLevel: Array[int] = [0, 0, 0, 0, 0]

	func IsSquadron() -> bool:
		return Source != null and Source.Type == Enums.UnitType.Fighter

	func Alive() -> bool:
		return State != TacticalState.Dead and State != TacticalState.Withdrawn and State != TacticalState.HyperOut

	func Destroyed() -> bool:
		return Damage != null and Damage.Destroyed()

	func Name() -> String:
		return Source.Name if Source != null else "unit"


class TaskForce:
	var Name: String = "Task Force"
	var Members: Array = []
	var Order: int = TacticalOrder.None
	var Tactic: int = TacticalTactic.StandOff   # "Ships will use the Stand Off tactic by default" (p150)

	func Fighting() -> Array:
		return Members.filter(func(u): return u.Alive() and not u.Destroyed() and u.State == TacticalState.Active)


class TacticalSide:
	var Faction: Faction
	var Fleet: Fleet
	var TaskForces: Array = []
	var Ships: Array = []
	var Squadrons: Array = []
	var Wrecks: Array = []
	var Strength: int

	func All() -> Array:
		return Ships + Squadrons

	func Fighting() -> Array:
		return All().filter(func(u): return u.Alive() and not u.Destroyed() and u.State == TacticalState.Active)

	func Eliminated() -> bool:
		return Fighting().is_empty()


var Sides: Array = [null, null]
var Where: Planet
var Elapsed: float = 0.0
var Over: bool = false
var LoserIndex: int = -1
var _rng: Prng
var _reassign: int = 0


func _init(where: Planet, a: Fleet, b: Fleet, rng: Prng) -> void:
	Where = where
	_rng = rng
	Sides[0] = Build(a, 0)
	Sides[1] = Build(b, 1)
	for s in Sides:
		Organise(s)
	Deploy()


# --- SETUP ---

static func Build(fleet: Fleet, index: int) -> TacticalSide:
	var side := TacticalSide.new()
	side.Faction = fleet.Faction if fleet != null else null
	side.Fleet = fleet
	if fleet == null:
		return side
	for ship in fleet.Ships:
		var tu := TacticalUnit.new()
		tu.Source = ship
		tu.Side = index
		tu.Damage = ship.DamageState()   # THE SHIP'S OWN DamageState, NOT A FRESH ONE
		tu.State = TacticalState.Active
		if ship.Type == Enums.UnitType.Fighter:
			side.Squadrons.append(tu)
		else:
			side.Ships.append(tu)
		for carried in ship.Hangar:
			if carried.Type != Enums.UnitType.Fighter:
				continue
			var sq := TacticalUnit.new()
			sq.Source = carried
			sq.Side = index
			sq.Carrier = tu
			sq.Damage = carried.DamageState()
			sq.State = TacticalState.Docked
			side.Squadrons.append(sq)
	return side


## ⚠ THE STARTING ARRANGEMENT IS OURS: one task force of capital ships, squadrons
## dealt round the four groups in order.
static func Organise(side: TacticalSide) -> void:
	if side.Ships.size() > 0:
		var tf := TaskForce.new()
		tf.Name = "Task Force 1"
		tf.Members = side.Ships.duplicate()
		side.TaskForces.append(tf)
	var groups: Array = []
	for i in side.Squadrons.size():
		var g := i % GroupNames.size()
		while groups.size() <= g:
			var tf := TaskForce.new()
			tf.Name = "%s Group" % GroupNames[groups.size()]
			groups.append(tf)
		groups[g].Members.append(side.Squadrons[i])
	for g in groups:
		side.TaskForces.append(g)


## ⚠ OURS: facing each other just beyond the longest weapon range.
func Deploy() -> void:
	var reach: float = 1.0
	for s in Sides:
		for u in s.All():
			reach = max(reach, float(LongestRange(u.Source)))
	reach = f32(reach)
	for s in 2:
		var x: float = -reach if s == 0 else reach
		var facing: float = 0.0 if s == 0 else PI
		var line: Array = Sides[s].All()
		for i in line.size():
			line[i].Position = Vector2(x, f32((i - f32(line.size() / 2.0)) * 20.0))
			line[i].Facing = f32(facing)


static func LongestRange(u: Unit) -> int:
	if u == null:
		return 0
	return u.MaxWeaponReach()


# --- GEOMETRY ---

static func ArcTo(from: TacticalUnit, to: TacticalUnit) -> int:
	var bearing := wrap_cs(f32((to.Position - from.Position).angle() - from.Facing), -PI, PI)
	if bearing > -PI / 4 and bearing <= PI / 4:
		return Enums.ShipArc.Fore
	if bearing > PI / 4 and bearing <= 3 * PI / 4:
		return Enums.ShipArc.Starboard
	if bearing < -PI / 4 and bearing >= -3 * PI / 4:
		return Enums.ShipArc.Port
	return Enums.ShipArc.Aft


static func DistanceBetween(a: TacticalUnit, b: TacticalUnit) -> float:
	return a.Position.distance_to(b.Position)


# --- STRENGTH --- (0x5B7A80, as far as it is recoverable)

static func _arc(arr: Array, i: int) -> int:
	return arr[i] if arr != null and i < arr.size() else 0


static func PowerOf(u: TacticalUnit, arc: int, against_fighters: bool) -> int:
	var s: Unit = u.Source if u != null else null
	if s == null or u.Destroyed() or not u.Alive():
		return 0
	# Everything this unit throws in that arc; against fighters the weapons the
	# pack marks no_fighter_effect are left out. The engine names no weapon.
	var power := s.FirepowerInArc(arc, "no_fighter_effect" if against_fighters else "")
	if u.IsSquadron() and u.Damage != null and u.Damage.MaxAircraft > 0:
		power = power * u.Damage.Aircraft / u.Damage.MaxAircraft
	return max(0, power)


static func StrengthOf(side: TacticalSide, enemy: TacticalSide) -> int:
	var total := 0
	for u in side.Fighting():
		var near := Nearest(u, enemy)
		var arc: int = ArcTo(u, near) if near != null else Enums.ShipArc.Fore
		total += PowerOf(u, arc, near.IsSquadron() if near != null else false)
	return total


static func Nearest(from: TacticalUnit, side: TacticalSide) -> TacticalUnit:
	if side == null:
		return null
	var sorted := Lq.order_by(side.Fighting(), func(t): return DistanceBetween(from, t))
	return sorted[0] if not sorted.is_empty() else null


# --- THE STEP --- (AbstractBattle::Step, 0x5AE9C0)

func Step() -> bool:
	if Over:
		return true
	Elapsed = f32(Elapsed + Dt)

	Sides[0].Strength = StrengthOf(Sides[0], Sides[1])
	Sides[1].Strength = StrengthOf(Sides[1], Sides[0])

	Act(Sides[1], Sides[0])
	Act(Sides[0], Sides[1])

	Sides[0].Strength = StrengthOf(Sides[0], Sides[1])
	Sides[1].Strength = StrengthOf(Sides[1], Sides[0])

	var gone0: bool = Sides[0].Eliminated()
	var gone1: bool = Sides[1].Eliminated()
	if gone0 or gone1:
		Over = true
		LoserIndex = -1 if (gone0 and gone1) else (0 if gone0 else 1)
		return true

	if Elapsed < StallLimit:
		return false

	# The force resolution: a tie resolves BOTH sides as losers.
	var s0: int = Sides[0].Strength
	var s1: int = Sides[1].Strength
	Over = true
	LoserIndex = -1 if s0 == s1 else (0 if s0 < s1 else 1)
	return true


## One side's turn (0x5D14D0): launch, task-force update, then tick every unit.
func Act(side: TacticalSide, enemy: TacticalSide) -> void:
	Launch(side)
	for tf in side.TaskForces:
		_reassign -= 1
		if _reassign <= 0:
			AssignTargets(tf, enemy)
		for u in tf.Fighting():
			if u.Target != null and (not u.Target.Alive() or u.Target.Destroyed()):
				u.Target = null
			Steer(u, enemy)
			if u.Target == null:
				continue
			var dps := DamageAgainst(u, u.Target)
			if dps > 0.0:
				ApplyDamage(u.Target, f32(dps * Dt))
	if _reassign <= 0:
		_reassign = ReassignPeriod

	for u in side.All():
		Tick(u, Dt)

	for u in side.All():
		if u.Destroyed() and u.State != TacticalState.Dead:
			u.State = TacticalState.Dead
			side.Wrecks.append(u)


static func Launch(side: TacticalSide) -> void:
	for sq in side.Squadrons:
		if sq.State != TacticalState.Docked:
			continue
		if sq.Carrier != null and (not sq.Carrier.Alive() or sq.Carrier.Destroyed()):
			continue
		sq.State = TacticalState.Active
		sq.Position = sq.Carrier.Position if sq.Carrier != null else sq.Position
		sq.Facing = sq.Carrier.Facing if sq.Carrier != null else sq.Facing


func Steer(u: TacticalUnit, _enemy: TacticalSide) -> void:
	if u.Target == null:
		return
	var toward: Vector2 = u.Target.Position - u.Position
	var range_v: float = float(LongestRange(u.Source))
	var want: float = toward.angle()
	var turn: float = f32(max(1, u.Source.Maneuverability) * 0.05)
	u.Facing = wrap_cs(f32(u.Facing + clampf(wrap_cs(f32(want - u.Facing), -PI, PI), -turn, turn)), -PI, PI)
	if toward.length() <= range_v:
		return
	var speed: int = u.Damage.Sublight if u.Damage != null else u.Source.Sublight
	u.Position += toward.normalized() * float(max(1, speed))


## ✅ "THE MOST DANGEROUS" (0x5ED8E0): the target's own anti-capital firepower, x15.
static func Danger(t: TacticalUnit) -> float:
	if t == null or t.Source == null:
		return 0.0
	var d := f32(15.0 * DamageAgainst(t, t))
	if t.Damage != null and t.Damage.MaxShieldRecharge > 0:
		d = f32(d - f32(0.01 * f32(float(t.Damage.ShieldRecharge) / float(t.Damage.MaxShieldRecharge))))
	if t.State == TacticalState.Docked or t.State == TacticalState.Launching:
		d = f32(d - 0.01)
	return d


## ✅ THE PAIR SCORE (0x5ED170): TIME TO KILL IN SECONDS, lower is better; -1 = never.
static func TimeToKill(ship: TacticalUnit, target: TacticalUnit, accum: float) -> float:
	if ship == null or target == null or target.Damage == null:
		return -1.0
	var eff_hp := f32(target.Damage.Shield + f32(0.65 * target.Damage.Hull))
	var net := f32(accum - ShieldRecharge(target))
	if net <= 0.0:
		return -1.0
	var score := f32(max(eff_hp, 1.0) / net)
	score = f32(score + f32(0.001 * max(DistanceBetween(ship, target), 1.0)))
	return score


## AssignTargets (0x5C9200): sort the enemy by danger, hand the list to the tactic.
static func AssignTargets(tf: TaskForce, enemy: TacticalSide) -> void:
	var fighting := enemy.Fighting()
	var pool: Array
	match tf.Order:
		TacticalOrder.AttackCapitalShips:
			pool = fighting.filter(func(t): return not t.IsSquadron())
		TacticalOrder.AttackFighters:
			pool = fighting.filter(func(t): return t.IsSquadron())
		_:
			pool = fighting
	if pool.is_empty():
		pool = fighting
	if pool.is_empty():
		for u in tf.Members:
			u.Target = null
		return

	pool = Lq.order_by(pool, Danger, true)

	var ships := tf.Fighting()
	if ships.is_empty():
		return

	if tf.Tactic == TacticalTactic.Surround:
		for u in ships:
			u.Target = pool[0]
		return

	# 0x5EC740 - distribute, with a RUNNING TOTAL of committed firepower.
	var committed: Dictionary = {}
	for u in ships:
		var best: TacticalUnit = null
		var best_score: float = 3.4028234663852886e38   # float.MaxValue
		for t in pool:
			var mine := DamageAgainst(u, t)
			if mine <= 0.0:
				continue
			var already: float = committed.get(t, 0.0)
			var score := TimeToKill(u, t, f32(already + mine))
			if score < 0.0 or score > KillHorizon:
				score = f32(100000.0 - f32(already + mine))
			if score >= best_score:
				continue
			best_score = score
			best = t
		u.Target = best if best != null else pool[0]
		var sofar: float = committed.get(u.Target, 0.0)
		committed[u.Target] = f32(sofar + DamageAgainst(u, u.Target))


static func MaxWeaponRange(u: TacticalUnit) -> float:
	var s: Unit = u.Source if u != null else null
	if s == null:
		return 0.0
	# The reach of every weapon that actually bears in some arc.
	var best := 0.0
	for a in 4:
		for w in MilitaryCatalog.WeaponOrder():
			var fitted: PackDefs.UnitWeaponDef = s.Weapon(w.Id)
			if fitted != null and fitted.in_arc(a) > 0:
				best = max(best, float(fitted.Reach))
	return best


# --- COMBAT --- a CONTINUOUS DAMAGE-PER-SECOND MODEL (0x5D16B5 / 0x5B7780 / 0x5B54D0)

## Unit::DamageAgainst (0x5B7780): result = P * V / N.
static func DamageAgainst(self_u: TacticalUnit, target: TacticalUnit) -> float:
	if self_u == null or self_u.Source == null or target == null or target.Source == null:
		return 0.0
	var v := WeaponRecharge(self_u)
	if v <= 0.0:
		return 0.0
	var vs_fighter := target.IsSquadron()
	var arc := BestArc(self_u, vs_fighter)
	if arc < 0:
		return 0.0

	# What this unit throws in that arc, weapon by weapon, IN THE PACK'S DECLARED
	# ORDER. The divisor counts every weapon, including the ones that will not
	# fire at a fighter.
	var hull_frac := HullFraction(self_u)
	var throw_by_weapon := []   # [WeaponDef, amount], pack order
	var total := 0
	for w in MilitaryCatalog.WeaponOrder():
		var fitted: PackDefs.UnitWeaponDef = self_u.Source.Weapon(w.Id)
		if fitted == null:
			continue
		var amount := fitted.in_arc(arc)
		if amount <= 0:
			continue
		throw_by_weapon.append([w, amount])
		total += amount
	var n := f32(float(total))
	if self_u.IsSquadron():
		n = f32(n * hull_frac)
	if n <= 0.0:
		return 0.0

	var acc := f32(max(f32(0.1), f32(f32(Maneuver(self_u)) / f32(max(f32(0.0001), f32(Maneuver(target)))))))
	var self_scale := hull_frac if self_u.IsSquadron() else 1.0

	# ⚠ ONE f32 ROUNDING PER WEAPON, in pack order. Float addition is not
	# associative: summing two weapons together and rounding once gives a
	# different answer from rounding each. The original rounded per weapon, and
	# the pack declares them in the order it did so.
	var p := 0.0
	for pair in throw_by_weapon:
		var w: PackDefs.WeaponDef = pair[0]
		var amount: int = pair[1]
		if w.HasRole("no_fighter_effect"):
			# Nothing against fighters; unscaled against everything else.
			if not vs_fighter:
				p = f32(p + f32(amount * self_scale))
		elif w.HasRole("fighter_accuracy_scaled"):
			p = f32(p + f32(f32(amount * (acc if vs_fighter else 1.0)) * self_scale))
		else:
			p = f32(p + f32(amount * self_scale))

	# The pack's squadron_only + requires_shields_down weapons - torpedoes in the
	# Star Wars pack. The hull fraction is applied TWICE in the original and is
	# reproduced rather than corrected.
	if self_u.IsSquadron() and not vs_fighter and ShieldFraction(target) <= 0.0:
		for pair in self_u.Source.WeaponsWithRole("requires_shields_down"):
			var w: PackDefs.WeaponDef = MilitaryCatalog.WeaponById(pair[0])
			if w == null or not w.HasRole("squadron_only"):
				continue
			var payload: int = (pair[1] as PackDefs.UnitWeaponDef).total()
			if payload > 0:
				p = f32(p + f32(f32(f32(payload * f32(0.53333336)) * hull_frac) * hull_frac))

	return f32(f32(p * v) / n)


## Unit::ApplyDamage (0x5B54D0): shields absorb the full nominal damage; hull loss
## is capped at 1.0 per application; the critical ladder slides down as it burns.
static func ApplyDamage(u: TacticalUnit, dmg: float) -> void:
	var d: ShipDamage = u.Damage if u != null else null
	if d == null or d.Hull <= 0:
		return
	var h0 := f32(float(d.Hull))
	var s0 := f32(float(d.Shield))
	var shield := f32(s0 - dmg)

	if s0 > 0.0:
		var chance := f32(max(1.0, f32(f32(100.0 * dmg) / f32(s0))))
		if Prng.Session.NextRange(0, 100) < chance:
			DamageSubsystem(u, 0)

	if shield >= 0.0:
		d.Shield = int(shield)
		return

	var spill := f32(max(shield, -1.0))
	d.Hull = int(max(f32(h0 + spill), 0.0))
	d.Shield = 0

	var v := f32(Prng.Session.NextRange(0, 100) + f32(f32(100.0 * f32(d.Hull - h0)) / f32(max(1.0, h0))))
	if v <= 50.0 or v > 100.0:
		return
	if v <= 65.0:
		DamageSubsystem(u, 0)
	elif v <= 80.0:
		DamageSubsystem(u, 1)
	elif v <= 90.0:
		DamageSubsystem(u, 2)
	elif v <= 95.0:
		DamageSubsystem(u, 3)
	else:
		DamageSubsystem(u, 4)


static func DamageSubsystem(u: TacticalUnit, which: int) -> void:
	if u == null or u.Damage == null or which < 0 or which > 4:
		return
	u.SubsystemLevel[which] = min(4, u.SubsystemLevel[which] + 1)


## effective = base * (hullFraction - 0.25 * level), floored at 0.
static func EffectiveStat(u: TacticalUnit, base_value: int, subsystem: int) -> float:
	if u == null:
		return 0.0
	var e := f32(base_value * f32(HullFraction(u) - f32(0.25 * u.SubsystemLevel[subsystem])))
	return max(0.0, e)


static func WeaponRecharge(u: TacticalUnit) -> float:
	if u.IsSquadron():
		return f32(f32(HullOf(u) * f32(3.750999927520752)) / 8.0)
	return EffectiveStat(u, u.Source.WeaponRecharge, 1)


static func ShieldRecharge(u: TacticalUnit) -> float:
	if u.IsSquadron():
		return f32(f32(HullOf(u) * f32(0.025)) / 8.0)
	return EffectiveStat(u, u.Source.ShieldRecharge, 0)


## min(sideBonus + base, 9), or 1 when the engines are dead. ⚠ The side bonus is
## NOT implemented (the Admiral question).
static func Maneuver(u: TacticalUnit) -> float:
	if u == null or u.Source == null:
		return 1.0
	if EffectiveStat(u, u.Source.Sublight, 2) <= 0.0:
		return 1.0
	return min(9.0, max(1.0, float(u.Source.Maneuverability)))


static func HullOf(u: TacticalUnit) -> float:
	return float(u.Damage.Hull) if u.Damage != null else 0.0


static func HullFraction(u: TacticalUnit) -> float:
	if u == null or u.Damage == null or u.Damage.MaxHull <= 0:
		return 0.0
	return clampf(f32(float(u.Damage.Hull) / float(u.Damage.MaxHull)), 0.0, 1.0)


static func ShieldFraction(u: TacticalUnit) -> float:
	if u == null or u.Damage == null or u.Damage.MaxShield <= 0:
		return 0.0
	return f32(float(u.Damage.Shield) / float(u.Damage.MaxShield))


## Unit::Tick (0x5B6320): recharge and repair. ⚠ The squadron branch compounds,
## as the bytes say.
static func Tick(u: TacticalUnit, dt: float) -> void:
	var d: ShipDamage = u.Damage if u != null else null
	if d == null:
		return
	if u.IsSquadron() and d.MaxShield > 0:
		d.MaxShield = int(f32(d.MaxShield * HullFraction(u)))
		d.Shield = min(d.Shield, d.MaxShield)
	var r := ShieldRecharge(u)
	if d.MaxShield - d.Shield > 0:
		d.Shield = int(min(f32(d.Shield + f32(r * dt)), float(d.MaxShield)))


## 0x5B4C60: the arc with the highest total firepower; -1 when every arc is empty.
static func BestArc(u: TacticalUnit, vs_fighter: bool) -> int:
	var best := -1
	var best_total := 0
	for a in 4:
		var total := u.Source.FirepowerInArc(a, "no_fighter_effect" if vs_fighter else "")
		if total <= best_total:
			continue
		best_total = total
		best = a
	return best


# --- RUNNING IT ---

func RunToCompletion() -> void:
	var guard := int(StallLimit / Dt) + 2
	while not Step() and guard > 0:
		guard -= 1
	Over = true
