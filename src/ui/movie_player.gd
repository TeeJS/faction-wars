extends CanvasLayer
## ONE MOVIE AFTER ANOTHER, OVER EVERYTHING (docs/cutscenes-plan.md, "The
## player"): a black screen, each movie's frame scaled to fit it (letterboxed,
## nearest - the originals are 640 pixels wide), and a click or Esc skips to the
## next ("To skip the introductory graphics, click the mouse", manual p022).
## The game is held while it plays: the scene tree is paused (every timer, the
## clock's included) and this layer alone runs; the tree's own state comes back
## after. Not in a head-to-head game, where the other player's clock is not
## ours to stop (docs/cutscenes-plan.md, phase 4).
##
## A movie that cannot be opened is skipped. `Done` runs once, at the end.
## Built by Movies.Play (src/ui/movies.gd).
##
## `Fetch` (path, done(local path or "")) readies a movie that is not a file
## yet - the browser's, read out of its storage (Movies.WebFetch); the black
## screen holds while it comes, and a skip meanwhile skips it.

var Paths: Array[String] = []
var Done: Callable = Callable()
var Fetch: Callable = Callable()

var _at: int = -1
var _ask: int = 0            # which fetch is wanted: an older answer is dropped
var _fetched: String = ""    # a fetched movie's file, removed when it ends
var _video: VideoStreamPlayer
var _black: ColorRect
var _held: bool = false
var _was_paused: bool = false
var _finished: bool = false


func _ready() -> void:
	name = "MoviePlayer"
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_black = ColorRect.new()
	_black.name = "Black"
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_black)
	_video = VideoStreamPlayer.new()
	_video.name = "Video"
	_video.expand = true
	_video.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_video)
	_video.finished.connect(_next)
	get_viewport().size_changed.connect(_fit)
	if MpSetup.session == null:
		_was_paused = get_tree().paused
		get_tree().paused = true
		_held = true
	_next()


func _input(event: InputEvent) -> void:
	var skip: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE) \
		or (event is InputEventMouseButton and event.pressed)
	if skip:
		get_viewport().set_input_as_handled()
		Skip()


## The movie now playing ends; the next starts (or the player closes).
func Skip() -> void:
	if _video != null:
		_video.stop()
	_next()


func Playing() -> String:
	return Paths[_at] if _at >= 0 and _at < Paths.size() else ""


func _next() -> void:
	if _finished:
		return
	_let_go()
	_at += 1
	_ask += 1
	if _at >= Paths.size():
		_finish()
		return
	if not Fetch.is_valid():
		_start(Paths[_at])
		return
	var ask := _ask
	Fetch.call(Paths[_at], func(file: String) -> void:
		if ask != _ask or _finished:
			return   # skipped while it came
		if file != Paths[_at]:
			_fetched = file
		_start(file))


func _start(file: String) -> void:
	if not file.is_empty():
		var stream := VideoStreamTheora.new()
		stream.file = file
		_video.stream = stream
		_video.play()
		if _video.is_playing():
			_fit()
			return
	push_warning("Movie %s could not be played; skipped." % Paths[_at])
	_next()


## The movie that played lets go of its file, and a fetched copy goes.
func _let_go() -> void:
	if _video != null:
		_video.stop()
		_video.stream = null
	if not _fetched.is_empty():
		DirAccess.remove_absolute(_fetched)
		_fetched = ""


## The frame as large as the screen allows, its shape kept, centred.
func _fit() -> void:
	if _video == null:
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	var frame := Vector2(640, 324)
	var tex: Texture2D = _video.get_video_texture()
	if tex != null and tex.get_width() > 0 and tex.get_height() > 0:
		frame = tex.get_size()
	var scale: float = minf(view.x / frame.x, view.y / frame.y)
	_video.size = (frame * scale).floor()
	_video.position = ((view - _video.size) / 2.0).floor()


func _process(_delta: float) -> void:
	# The texture's size is known once the first frame is out.
	_fit()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_let_go()
	if _held:
		get_tree().paused = _was_paused
	queue_free()
	if Done.is_valid():
		Done.call()
