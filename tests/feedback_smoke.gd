extends SceneTree
## The feedback box end to end, headless: a single-player game with a few
## orders in its log, a note submitted through a running relay, the relay's
## reply, and the report's contents. Run by tools/feedback-local.ps1.
##
##   Godot_console.exe --headless --path . -s tests/feedback_smoke.gd -- --relay=ws://127.0.0.1:8790/ws

func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.ProvideFeedback = true
	var engine := GameSession.new_game("alliance", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4242)
	CommandLog.Open("user://feedback-smoke.jsonl", CommandLog.Header())
	CommandBus.issue("chat", { "text": "a line in the log" })
	engine.AdvanceDay()
	CommandBus.day_done()
	var panel := FeedbackPanel.new()
	root.add_child(panel)
	await process_frame
	var fails := 0
	var url := FeedbackPanel.feedback_url()
	print("[feedback_smoke] posting to %s" % url)
	if not url.begins_with("http://127.0.0.1"):
		print("  FAIL feedback_url did not derive from --relay: %s" % url)
		fails += 1
	var r := FeedbackPanel.report("cannot target the planetary shield for sabotage")
	if r.get("game") != "single" or int(r.get("day", 0)) != 2 or int(r.get("seed", 0)) != 4242 or str(r.get("log", "")).count("\n") < 3:
		print("  FAIL report facts: game=%s day=%s seed=%s log lines=%d" % [str(r.get("game")), str(r.get("day")), str(r.get("seed")), str(r.get("log", "")).count("\n")])
		fails += 1
	panel._text.text = "cannot target the planetary shield for sabotage"
	panel.submit()
	var deadline := Time.get_ticks_msec() + 15000
	while panel._status.text == "Sending..." and Time.get_ticks_msec() < deadline:
		await process_frame
	print("[feedback_smoke] status: %s" % panel._status.text)
	if not panel._status.text.begins_with("Sent. Thank you."):
		fails += 1
		print("  FAIL the relay did not accept the report")
	print("[feedback_smoke] %d failed" % fails)
	CommandLog.Close()
	quit(1 if fails > 0 else 0)
