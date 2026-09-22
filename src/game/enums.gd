class_name Enums
extends RefCounted
## The source's enums, declaration order preserved because several are ORDINAL
## (MissionType joins MISSNSD by position; MissionCatalog says so). Names match
## the C# names exactly so the canonical dump, GameSignature and the logs read
## the same as the source's.

enum UnitType { Troop, Fighter, SpecForce, CapitalShip }                 # backend/Unit.cs

enum Status { AwaitingOrders, Enroute, OnMission, Kidnapped, Dead }       # backend/Character.cs

enum Rank { None, General, Admiral, Commander, Captain }                  # backend/Character.cs

## "There are FIVE LEVELS of Force users" (manual p092); None means not a Force user.
enum SpecialPowerRank { None, Novice, Trainee, JediStudent, JediKnight, JediMaster }

## FACILITIES ARE PACK DATA (SCHEMA.md section 5). This used to be a closed enum
## naming Star Wars structures - IonCannon, DeathStarShield - which a pack could
## not add to without a recompile. facilities.json replaces it and the engine
## selects on ROLE tags; see PackDefs.FacilityDef and FacilityCatalog.


enum Difficulty { Multiplayer, Easy, Medium, Hard }                       # backend/GameContext.cs

enum GalaxySize { Standard, Large, Huge }                                 # backend/GameContext.cs

## backend/Mission.cs. The fifteen missions of the manual (p106-p111).
enum MissionType {
	Diplomacy,
	Espionage,
	Recruitment,
	InciteUprising,
	SubdueUprising,
	Reconnaissance,
	Abduction,
	Assassination,
	Rescue,
	Sabotage,
	DeathStarSabotage,
	ShipDesignResearch,
	TroopTrainingResearch,
	FacilityDesignResearch,
	JediTraining,
}

## backend/GameMessage.cs - the TABS on the message index (TEXTSTRA.DLL's own strip).
enum MessageCategory { All, Loyalty, Fleets, Missions, Resources, Manufacturing, Defense, Conflict, Chat, Advice }

## backend/GameMessage.cs - the original's finer message kinds, its order and wording.
enum MessageType {
	None = 0,
	TacticalAfterActionReport,
	TacticalPreBattle,
	Uprising,
	SystemControl,
	ResearchReport,
	Repair,
	Blockade,
	Confirmation,
	Smuggling,
	Chat,
	GarrisonWarning,
	MaintenanceShortfall,
	UnitArrival,
	UnitDeployment,
	OperationReports,
	DeploymentFailed,
	UnitRerouted,
	EvacuationLosses,
	PersonnelArrive,
	PlanetDestroyed,
	MissionReport,
	MissionFailed,
	InformantReport,
	CharacterCaptured,
	CharacterHealth,
	BountyHunters,
}

## backend/ShipDamage.cs - CAPSHPSD.DAT's own arc order.
enum ShipArc { Fore = 0, Aft = 1, Starboard = 2, Port = 3 }

enum ShipSystem { ShieldRecharge, WeaponRecharge, TractorPower, Engines, Hyperdrive }

## backend/IntelManager.cs - the original's own categories (REBEXE.EXE 0x50E18C).
enum IntelCategory { SystemStatus, MilitaryUnits, DefensiveFacilities, ProductionFacilities, SpecForces, Characters, Manufacturing }

enum IntelSection { SystemStatus, Troopers, Fighters, OrbitingShips, DefensiveFacilities, ProductionFacilities, SpecForces, Characters, Manufacturing }

## backend/ResearchManager.cs - the three R&D tracks.
enum ResearchTrackKind { ShipDesign = 0, TroopTraining = 1, FacilityDesign = 2 }
const RESEARCH_TRACK_COUNT := 3
