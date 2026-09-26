extends RefCounted
## THE ORIGINAL'S MOVIES IN THE GAME (docs/cutscenes-plan.md, phase 3). The
## pack says which movie plays at which engine event (pack.json `movies`,
## SCHEMA.md section 2); the movies are the player's own, converted by the
## Faction Wars Exporter into a movies file and imported like the art set
## (src/ui/pack_import.gd, kind "movies") to user://movies/<art set>/. A
## reference whose movie is not there plays nothing, so a player without the
## movies file sees the game as it was.
##
## Played now: `launch` when the Cockpit first opens in a run of the game
## (manual p022, "the introductory graphics"), and `credits` from the
## Cockpit's View credits (menu.gd). The rest of the events are phase 4.
##
## Preloaded by path (as Movies): a new script can lag the editor's class cache.

const Player := preload("res://src/ui/movie_player.gd")

## Where movies files are imported: <root>/<art set>/movies/<nnn>.ogv.
const USER_ROOT := "user://movies"
static var UserRoot: String = USER_ROOT

## The launch movies play once per run of the game.
static var LaunchPlayed: bool = false
## No movie plays in a headless run: the test runs share the player's user://,
## and a movie holds the scene tree. The movies' own tests turn this on.
static var PlayHeadless: bool = false


## The loaded pack's movies for `event` that are there to play, in order.
static func For(event: String) -> Array[String]:
	var out: Array[String] = []
	if FactionRegistry.Pack == null or (DisplayServer.get_name() == "headless" and not PlayHeadless):
		return out
	for ref in FactionRegistry.Pack.Manifest.Movies.get(event, []):
		var path := PathOf(str(ref))
		if not path.is_empty():
			out.append(path)
	return out


static func Has(event: String) -> bool:
	return not For(event).is_empty()


## A reference's file, or "" when it is not there: "<art set>:<path>" in the
## imported movies (only an art set the pack declares), else a pack file.
static func PathOf(ref: String) -> String:
	var split: PackedStringArray = PackLoader.SplitArtRef(ref)
	var path: String
	if split[0].is_empty():
		path = "%s/%s" % [FactionRegistry.LoadedDir, ref]
	else:
		if FactionRegistry.Pack == null or not FactionRegistry.Pack.Manifest.ArtSets.has(split[0]):
			return ""
		path = "%s/%s/%s" % [UserRoot, split[0], split[1]]
	return path if FileAccess.file_exists(path) else ""


## Plays `event`'s movies over everything, then calls `done` - at once when
## there are none. Returns the player, or null. With one already playing (a
## system destroyed, then the war won that same day), these follow its own.
static func Play(tree: SceneTree, event: String, done: Callable = Callable()) -> Node:
	var paths := For(event)
	if paths.is_empty():
		if done.is_valid():
			done.call()
		return null
	var playing: Node = tree.root.get_node_or_null("MoviePlayer")
	if playing != null and not playing.is_queued_for_deletion():
		playing.Paths.append_array(paths)
		if done.is_valid():
			var before: Callable = playing.Done
			playing.Done = func() -> void:
				if before.is_valid():
					before.call()
				done.call()
		return playing
	var p := Player.new()
	p.Paths = paths
	p.Done = done
	tree.root.add_child(p)
	return p


## The launch movies, the first time the Cockpit opens in this run.
static func PlayLaunch(tree: SceneTree) -> Node:
	if LaunchPlayed:
		return null
	LaunchPlayed = true
	return Play(tree, "launch")


## The imported movies files: [{id, files}].
static func Installed() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(UserRoot)
	if dir == null:
		return out
	for id in dir.get_directories():
		var n: int = 0
		var movies := DirAccess.open("%s/%s/movies" % [UserRoot, id])
		if movies != null:
			for f in movies.get_files():
				if f.get_extension().to_lower() == "ogv":
					n += 1
		out.append({"id": id, "files": n})
	return out
