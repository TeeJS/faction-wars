class_name MpSetup
extends RefCounted
## The state that crosses the head-to-head screens (docs/multiplayer-ui-design.md
## section 0): the relay, the player's and game's names, the lobby client, the
## seat, and - once the host starts - the settings both clients build the same
## game from. GameManager reads it when Main.tscn loads.
##
## reset() runs on EVERY exit path (Cancel on each screen, Previous from the
## Options screen, Leave Game, Exit to Menu / Desktop, game end): the static
## outlives the screens, and stale state is the classic session bug.

const NamesFile := "user://mp.cfg"
const DefaultRelay := "wss://wars.schmitzplex.com/ws"

static var player_name: String = ""
static var game_name: String = ""
static var hosting: bool = false
## The code typed into Locate Session ("" = search, the manual's blank box).
static var join_code: String = ""
static var lobby: RelayClient = null
static var session: LockstepSession = null
## The relay's whole log of a loaded game (Load Game, M5): GameManager rebuilds
## from it instead of starting at day one.
static var load_lines: Array = []


## Is a head-to-head game configured and started, so Main.tscn must run in lockstep?
static func active() -> bool:
	return lobby != null and lobby.started


static func reset() -> void:
	if lobby != null:
		lobby.transport.close()
	lobby = null
	session = null
	load_lines = []
	hosting = false
	join_code = ""
	CommandBus.Session = null
	CommandBus.Immediate = true
	GameSettings.HumanFactions = []
	GameSettings.HostFaction = null
	GameSettings.SpeedRule = "slowest"


## The relay to talk to. In the browser: the page's own origin (hosting option
## A), or ?relay=ws://... on the page URL for a test against a local relay. On
## the desktop: --relay=, else the production relay. Never a field on a screen.
static func relay_url() -> String:
	var arg := _arg("--relay=")
	if not arg.is_empty():
		return arg
	if OS.has_feature("web"):
		var q: Variant = JavaScriptBridge.eval("new URLSearchParams(location.search).get('relay') || ''", true)
		if q is String and not (q as String).is_empty():
			return q
		var origin: Variant = JavaScriptBridge.eval("location.protocol + '//' + location.host", true)
		if origin is String and not (origin as String).is_empty():
			return (origin as String).replace("http", "ws") + "/ws"
	return DefaultRelay


static func new_lobby() -> RelayClient:
	if lobby != null:
		lobby.transport.close()
	lobby = RelayClient.new(relay_url(), player_name)
	return lobby


## "If you do not specify a name, it will default to..." (manual p158): the
## last names used, kept in user://, since a browser has no user or computer name.
static func load_names() -> void:
	# Fills only what this session has not set: a name typed on an earlier
	# screen (or by a test) is not overwritten by the remembered one.
	var cfg := ConfigFile.new()
	var remembered := cfg.load(NamesFile) == OK
	if player_name.is_empty():
		player_name = str(cfg.get_value("names", "player", "")) if remembered else ""
	if player_name.is_empty():
		player_name = "Player"
	if game_name.is_empty():
		game_name = str(cfg.get_value("names", "game", "")) if remembered else ""
	if game_name.is_empty():
		game_name = "%s's game" % player_name


static func remember_names() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("names", "player", player_name)
	cfg.set_value("names", "game", game_name)
	cfg.save(NamesFile)


## The host's side, as a Faction, from the room settings.
static func host_faction(settings: Dictionary) -> Faction:
	FactionRegistry.EnsureLoaded()
	var f: Faction = FactionRegistry.ById(str(settings.get("side", "")))
	return f if f != null else FactionRegistry.Playable[0]


static func other_faction(f: Faction) -> Faction:
	for p in FactionRegistry.Playable:
		if p != f:
			return p
	return f


## Both clients call this with the started room's settings: the same game on
## both, only the local side differs. Difficulty is the Multiplayer column
## (manual p161: no difficulty choice on the Options screen).
static func apply_settings(settings: Dictionary, my_seat: String) -> void:
	var host_side := host_faction(settings)
	var mine := host_side if my_seat == "host" else other_faction(host_side)
	GameSettings.PlayerFaction = mine
	GameSettings.HumanFactions = [host_side, other_faction(host_side)]
	GameSettings.HostFaction = host_side
	GameSettings.SelectedDifficulty = Enums.Difficulty.Multiplayer
	GameSettings.SelectedSize = int(settings.get("size", Enums.GalaxySize.Large)) as Enums.GalaxySize
	GameSettings.HQOnlyVictory = bool(settings.get("hq_only", false))
	GameSettings.SpeedRule = str(settings.get("speed_rule", "slowest"))
	GameSettings.Seed = int(settings.get("seed", 0))


static func _arg(prefix: String) -> String:
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return ""
