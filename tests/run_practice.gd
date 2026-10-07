extends SceneTree
const Rules = preload("res://core/game_rules.gd")
const Loader = preload("res://adapters/content_loader.gd")
const Session = preload("res://application/game_session.gd")
const Practice = preload("res://application/practice_session.gd")
const Store = preload("res://adapters/save_store.gd")
var checks: int = 0
var failures: int = 0

class MemoryStore:
	extends RefCounted
	var saved: Dictionary = {}
	var fail: bool = false
	var error_message: String = ""
	func load_save() -> Dictionary: return saved.duplicate(true)
	func write_save(data: Dictionary) -> bool:
		if fail:
			error_message = "disk full"
			return false
		saved = data.duplicate(true)
		return true

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL PRACTICE " + label)

func _initialize() -> void:
	var core: Rules = Rules.new(Loader.load_content())
	var store: MemoryStore = MemoryStore.new()
	var game: Session = Session.new(core, store)
	check(game.initialize(), "initialize old tutorial defaults")
	game.start(20261010, "preset_a")
	game.perform({"step": "route", "index": 0})
	var active: Dictionary = game.data.active.duplicate(true)
	var profile: Dictionary = game.data.profile.duplicate(true)
	var run_before: Dictionary = game.run.snapshot()
	var lesson: Practice = Practice.new(game)
	check(lesson.start(), "lesson starts independently of live expedition")
	check(not lesson.ready(lesson.empty_plan()), "reading does not satisfy action")
	var invalid: Dictionary = lesson.empty_plan()
	invalid.workers = 1
	check(not lesson.plan_action(invalid), "wrong step action rejected")
	invalid = lesson.empty_plan()
	invalid.builds = [["place", 1, "fam_pierce"]]
	check(not lesson.plan_action(invalid), "wrong slot rejected")
	var actions: Array = [
		{"builds": [["place", 0, "fam_pierce"]], "workers": 0, "packs": []},
		{"builds": [], "workers": 1, "packs": []},
		{"builds": [], "workers": 0, "packs": ["m_hide_elite", "m_hide_elite", "m_hide_elite"]}]
	for i in range(3):
		var previous: Dictionary = game.data.duplicate(true)
		store.fail = true
		check(not lesson.plan_action(actions[i]) and game.data == previous, "preview save failure rolls back")
		store.fail = false
		check(lesson.plan_action(actions[i]), "actual preview is saved")
		var resumed: Practice = Practice.new(game)
		check(resumed.restore() and resumed.planned() == actions[i], "preview restores")
		check(resumed.run.snapshot() == lesson.run.snapshot(), "preview does not commit combat")
		previous = game.data.duplicate(true)
		store.fail = true
		check(not lesson.perform(actions[i]).get("ok", true) and game.data == previous, "combat checkpoint failure rolls back")
		store.fail = false
		check(lesson.perform(actions[i]).get("ok", true), "combat checkpoint succeeds")
		check(not lesson.perform(actions[i]).get("ok", true), "duplicate deploy blocked")
		resumed = Practice.new(game)
		check(resumed.restore() and resumed.pending_result(), "interrupted battle restores result")
		check(resumed.run.snapshot() == lesson.run.snapshot() and resumed.result == lesson.result, "battle replay exact")
		if i == 1: check(lesson.run.player.income() == 15 and lesson.run.player.gold == 27, "worker reward is actual income")
		if i == 2: check(lesson.result.cmd_damage == 8 and lesson.run.cmd.side.castle == 2 and lesson.run.player.castle == 13, "sending causes actual castle damage")
		previous = game.data.duplicate(true)
		store.fail = true
		check(not lesson.acknowledge() and game.data == previous, "result acknowledgment failure rolls back")
		store.fail = false
		check(lesson.acknowledge(), "result acknowledgment saved")
		check(game.data.active == active and game.data.profile == profile and game.run.snapshot() == run_before, "live progression unchanged")
		check(Store.new().valid(game.data), "real save validator accepts checkpoint")
	check(game.data.tutorial.completed and not lesson.active(), "completion requires three actions and results")
	check(lesson.start() and game.data.tutorial.completed, "replay retains completed status")
	check(lesson.skip() and not lesson.active() and game.data.profile == profile and game.data.active == active, "skip never grants rewards or touches live expedition")
	check(game.data.tutorial.skipped, "skip persisted independently of completion")
	check(lesson.start(), "restart for corrupt checkpoint test")
	game.data.tutorial.steps = [actions[1]]
	check(not lesson.restore(), "wrong saved step rejected")
	check(lesson.start() and game.data.profile == profile and game.data.active == active, "restart repairs only lesson")
	game.data.tutorial.rules_version = "outdated"
	check(not lesson.restore(), "rules change requires explicit lesson restart")
	check(lesson.start() and lesson.restore(), "lesson restarts with current rules without touching expedition")
	var bad: Dictionary = game.data.duplicate(true)
	bad.tutorial.plan.workers = []
	check(not Store.new().valid(bad), "bad preview shape rejected")
	print("PRACTICE checks=%d failures=%d isolated=true" % [checks, failures])
	quit(0 if failures == 0 else 1)
