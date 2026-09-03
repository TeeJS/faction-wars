extends Control
## Step 1B browser profiling harness. It deliberately advances only a few days
## per frame so the HTML build remains responsive while collecting tick timings.

const SNAPSHOT := "res://tests/fixtures/snapshot-seed12345.json"
const SEED := 12345
const DAYS := 100
const DAYS_PER_FRAME := 4
const WARM_DAYS := 5

@onready var output: Label = %Output

var _engine: StrategicTickManager
var _times: Array[float] = []
var _complete := false


func _ready() -> void:
	output.text = "Loading the day-zero snapshot…"
	_engine = GameSession.start_from_snapshot(SNAPSHOT, SEED)
	if _engine == null:
		output.text = "[bench_1b] FAIL\nCould not start from %s" % SNAPSHOT
		push_error(output.text)
		_complete = true
		if DisplayServer.get_name() == "headless":
			get_tree().quit(2)
		return

	output.text = "[bench_1b] snapshot=%s seed=%d days=%d missions=false\nRunning… 0/%d days" % [SNAPSHOT, SEED, DAYS, DAYS]


func _process(_delta: float) -> void:
	if _complete or _engine == null:
		return

	for _step in min(DAYS_PER_FRAME, DAYS - _times.size()):
		var t0 := Time.get_ticks_usec()
		_engine.AdvanceDay()
		var t1 := Time.get_ticks_usec()
		_times.append((t1 - t0) / 1000.0)

	if _times.size() < DAYS:
		output.text = "[bench_1b] snapshot=%s seed=%d days=%d missions=false\nRunning… %d/%d days" % [SNAPSHOT, SEED, DAYS, _times.size(), DAYS]
		return

	_complete = true
	_show_results()
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0)


func _show_results() -> void:
	var steady := _times.slice(WARM_DAYS) if _times.size() > WARM_DAYS else _times.duplicate()
	steady.sort()

	var mean := 0.0
	for t in steady:
		mean += t
	mean /= max(1, steady.size())

	var p50: float = steady[steady.size() / 2] if not steady.is_empty() else 0.0
	var p95: float = steady[int(floor(steady.size() * 0.95))] if not steady.is_empty() else 0.0
	var worst: float = steady[steady.size() - 1] if not steady.is_empty() else 0.0

	var warm_mean := 0.0
	for t in _times.slice(0, min(WARM_DAYS, _times.size())):
		warm_mean += t
	warm_mean /= max(1, min(WARM_DAYS, _times.size()))

	var header := "[bench_1b] snapshot=%s seed=%d days=%d missions=false" % [SNAPSHOT, SEED, DAYS]
	var counts := "[bench_1b] planets=%d characters=%d active_missions=%d messages=%d" % [GameState.AllPlanets().size(), GameState.ActiveRoster.size(), MissionManager.Active().size(), EventBus.MessageLog.size()]
	var timing := "[bench_1b] tick ms: warm-up mean %.3f | steady mean %.3f p50 %.3f p95 %.3f max %.3f" % [warm_mean, mean, p50, p95, worst]
	output.text = "%s\n%s\n%s\n[bench_1b] PASS" % [header, counts, timing]
	print(header)
	print(counts)
	print(timing)
	print("[bench_1b] PASS")
