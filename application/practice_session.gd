extends RefCounted
## The real combat core, with an isolated, checkpointed three-round lesson.
const Rules = preload("res://core/game_rules.gd")
const Loader = preload("res://adapters/content_loader.gd")
var game: Variant
var config: Dictionary = Loader.read_json("res://data/core/practice.json")
var run: Rules.Run
var result: Dictionary = {}
var error_message: String = ""

func _init(session: Variant) -> void:
	game = session

func active() -> bool: return game.data.tutorial.get("active", false)
func pending_result() -> bool: return game.data.tutorial.get("awaiting_result", false)
func step_index() -> int: return game.data.tutorial.get("steps", []).size()
func planned() -> Dictionary: return game.data.tutorial.get("plan", empty_plan()).duplicate(true)
func empty_plan() -> Dictionary: return {"builds": [], "workers": 0, "packs": []}

func _new_run() -> Rules.Run:
	var lesson: Rules.Run = game.core.new_run(config.seed, config.preset, 0)
	lesson.cmd = Rules.Commander.new(game.core, game.core.rules.tutorial.commander, 0, game.core.stream(config.seed, "commander", 0), 0)
	lesson.cmd.side.castle = game.core.rules.tutorial.castle_hp
	lesson.cmd.side.castle_max = lesson.cmd.side.castle
	lesson.armor = config.armor
	lesson.status = "round"
	lesson._begin_round()
	return lesson

func restore() -> bool:
	if not active():
		run = null
		return true
	if game.data.tutorial.get("rules_version") != game.core.rules.schema or game.data.tutorial.get("scenario") != config.schema: return _invalid()
	var next: Rules.Run = _new_run()
	var last: Dictionary = {}
	var actions: Array = game.data.tutorial.get("steps", [])
	for index in range(actions.size()):
		if not matches(actions[index], index, true): return _invalid()
		last = next.apply_action(actions[index])
		if last.get("ok", true) == false: return _invalid()
	if actions.size() == 3 and not pending_result(): return _invalid()
	if pending_result() and actions.is_empty(): return _invalid()
	if not matches(planned(), actions.size(), false): return _invalid()
	run = next
	result = last
	error_message = ""
	return true

func _invalid() -> bool:
	error_message = "Practice save could not be restored. Restart the lesson."
	return false

func start() -> bool:
	var candidate: Dictionary = game.data.duplicate(true)
	candidate.tutorial = {"version": 1, "completed": candidate.tutorial.completed, "skipped": false,
		"active": true, "steps": [], "plan": empty_plan(), "awaiting_result": false, "rules_version": game.core.rules.schema, "scenario": config.schema}
	if not game.persist(candidate):
		error_message = game.error_message
		return false
	return restore()

func matches(action: Dictionary, index: int, complete: bool) -> bool:
	if action.keys().size() != 3 or not action.get("builds") is Array or not action.get("workers") is int or not action.get("packs") is Array: return false
	var builds: Array = action.builds
	var workers: int = action.workers
	var packs: Array = action.packs
	if index == 0:
		var forced: Dictionary = game.core.rules.tutorial.forced[0]
		return workers == 0 and packs.is_empty() and (builds == [[forced.action, 0, forced.family]] or (not complete and builds.is_empty()))
	if index == 1: return builds.is_empty() and packs.is_empty() and (workers == 1 or (not complete and workers == 0))
	if index == 2:
		if not builds.is_empty() or workers != 0 or packs.size() > int(config.packs): return false
		for pack in packs:
			if pack != config.mercenary: return false
		return not complete or packs.size() == int(config.packs)
	return not complete and builds.is_empty() and workers == 0 and packs.is_empty()

func ready(action: Dictionary) -> bool:
	return active() and not pending_result() and step_index() < 3 and matches(action, step_index(), true)

func plan_action(action: Dictionary) -> bool:
	if not active() or pending_result() or not matches(action, step_index(), false): return false
	if not run.prepare_action(action).ok: return false
	var candidate: Dictionary = game.data.duplicate(true)
	candidate.tutorial.plan = action.duplicate(true)
	if not game.persist(candidate):
		error_message = game.error_message
		return false
	error_message = ""
	return true

func perform(action: Dictionary) -> Dictionary:
	if not ready(action): return {"ok": false, "error": "Complete the highlighted action first."}
	var next: Rules.Run = _new_run()
	for previous in game.data.tutorial.steps: next.apply_action(previous)
	var outcome: Dictionary = next.apply_action(action)
	if outcome.get("ok", true) == false: return outcome
	var candidate: Dictionary = game.data.duplicate(true)
	candidate.tutorial.steps.append(action.duplicate(true))
	candidate.tutorial.plan = empty_plan()
	candidate.tutorial.awaiting_result = true
	if not game.persist(candidate): return {"ok": false, "error": game.error_message}
	run = next
	result = outcome
	return outcome

func acknowledge() -> bool:
	if not active() or not pending_result(): return false
	var candidate: Dictionary = game.data.duplicate(true)
	candidate.tutorial.awaiting_result = false
	if step_index() == 3:
		candidate.tutorial.completed = true
		candidate.tutorial.active = false
	if not game.persist(candidate):
		error_message = game.error_message
		return false
	return true

func skip() -> bool:
	var candidate: Dictionary = game.data.duplicate(true)
	candidate.tutorial.merge({"active": false, "skipped": true, "steps": [], "plan": empty_plan(), "awaiting_result": false}, true)
	if not game.persist(candidate):
		error_message = game.error_message
		return false
	run = null
	return true
