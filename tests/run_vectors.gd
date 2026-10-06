extends SceneTree

const Rules = preload("res://core/game_rules.gd")
const Loader = preload("res://adapters/content_loader.gd")
var failures: int = 0
var assertions: int = 0

func check(actual: Variant, expected: Variant, label: String) -> void:
	assertions += 1
	if actual != expected:
		failures += 1
		printerr("FAIL %s: actual=%s expected=%s" % [label, actual, expected])

func _initialize() -> void:
	var core: Rules = Rules.new(Loader.load_content())
	var vectors: Dictionary = Loader.read_json("res://tests/fixtures/vectors.json")
	var combat_ok: int = 0
	var runs_ok: int = 0
	for i in range(vectors.combat.size()):
		var v: Dictionary = vectors.combat[i]
		var before: int = failures
		var result: Dictionary = core.resolve(v.board, core.make_wave(v.round, v.armor) + core.pack_enemies(v.packs), v.beats, true)
		for key in v.expect: check(result[key], v.expect[key], "combat %d %s" % [i, key])
		if failures == before: combat_ok += 1
	for i in range(vectors.runs.size()):
		var v: Dictionary = vectors.runs[i]
		var before: int = failures
		var run: Rules.Run = core.new_run(v.seed, v.preset, v.ascension)
		for step in v.steps:
			if step.step == "route": check(run.choose_route(step.index).ok, true, "route")
			elif step.step == "draft": check(run.choose_draft(step.index).ok, true, "draft")
			else:
				var result: Dictionary = run.apply_action(step.action)
				check(result, step.result, "run %d round result" % i)
				check({"gold": run.player.gold, "castle": run.player.castle, "cmd_castle": run.cmd.side.castle, "status": run.status}, step.after, "run %d round state" % i)
		check({"status": run.status, "score": run.score(), "rounds_used": run.rounds_used, "chapter": run.chapter, "fail_reason": run.fail_reason}, v.expect, "run %d final" % i)
		if failures == before: runs_ok += 1
	var run: Rules.Run = core.new_run(20261010)
	run.choose_route(0)
	for action in [{"builds": [["place", 0, "fam_pierce"], ["place", 1, "fam_pierce"], ["place", 2, "fam_pierce"], ["place", 3, "fam_pierce"]]}, {"packs": ["unknown"]}, {"workers": 11}, {"builds": [["place", -1, "fam_pierce"]]}, {"workers": 0.5}]:
		var state: Dictionary = run.snapshot()
		check(run.apply_action(action).ok, false, "invalid rejected")
		check(run.snapshot(), state, "invalid atomic")
	print("VECTORS combat=%d/60 runs=%d/40 assertions=%d failures=%d" % [combat_ok, runs_ok, assertions, failures])
	quit(0 if failures == 0 else 1)
