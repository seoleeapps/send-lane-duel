extends SceneTree
const Rules = preload("res://core/game_rules.gd")
const Loader = preload("res://adapters/content_loader.gd")
const Session = preload("res://application/game_session.gd")
const Store = preload("res://adapters/save_store.gd")
var failures: int = 0
var checks: int = 0

class MemoryStore:
	extends RefCounted
	var saved: Dictionary = {}
	var fail: bool = false
	var error_message: String = ""
	func load_save() -> Dictionary: return saved.duplicate(true)
	func write_save(candidate: Dictionary) -> bool:
		if fail:
			error_message = "disk unavailable"
			return false
		saved = candidate.duplicate(true)
		return true

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL " + label)

func _initialize() -> void:
	var core: Rules = Rules.new(Loader.load_content())
	var vectors: Dictionary = Loader.read_json("res://tests/fixtures/vectors.json")
	for v in vectors.runs:
		var store: MemoryStore = MemoryStore.new()
		var game: Session = Session.new(core, store)
		game.initialize()
		game.data.profile.unlocked = core.presets.keys()
		game.data.profile.highest_ascension = 5
		check(game.start(v.seed, v.preset, v.ascension), "start")
		for step in v.steps:
			var action: Dictionary = {"step": step.step}
			if step.step == "round": action.action = step.action
			else: action.index = step.index
			check(game.perform(action).get("ok", true), "perform")
			var resumed: Session = Session.new(core, store)
			check(resumed.initialize(), "resume")
			check(resumed.run.snapshot() == game.run.snapshot(), "checkpoint replay")
			check(resumed.data.profile.medals == game.data.profile.medals, "settlement idempotent")
		check(game.run.score() == v.expect.score, "session score")
	var memory: MemoryStore = MemoryStore.new()
	var game: Session = Session.new(core, memory)
	game.initialize()
	game.start(20261010, "preset_a")
	var before: Dictionary = game.data.duplicate(true)
	memory.fail = true
	check(not game.perform({"step": "route", "index": 0}).ok, "failed save rejected")
	check(game.data == before and game.run.status == "route", "failed save preserves game")
	memory.fail = false
	game.abandon()
	var date: String = "2026-10-06"
	var seed_value: int = 20261006
	var preset: String = core.presets.keys()[seed_value % core.presets.size()]
	check(game.start(seed_value, preset, 0, "daily", date) and game.data.active.ranked, "first daily attempt")
	game.abandon()
	check(game.start(seed_value, preset, 0, "daily", date) and not game.data.active.ranked, "second daily practice")
	var test_path: String = "user://tests-session/save.json"
	DirAccess.make_dir_recursive_absolute("user://tests-session")
	var disk: Store = Store.new(test_path)
	disk.delete_local()
	check(disk.write_save(game.defaults()), "disk first write")
	var updated: Dictionary = game.defaults()
	updated.profile.medals = 9
	var invalid: Dictionary = updated.duplicate(true)
	invalid.daily["2026-10-06"] = "broken"
	check(not disk.write_save(invalid), "invalid daily shape rejected")
	invalid = updated.duplicate(true)
	invalid.settings.large_text = 1
	check(not disk.write_save(invalid), "invalid setting type rejected")
	invalid = game.data.duplicate(true)
	invalid.active.ascension = -1
	check(not disk.write_save(invalid), "invalid active rank rejected")
	check(disk.write_save(updated), "disk second write")
	var file: FileAccess = FileAccess.open(test_path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	check(disk.load_save().profile.medals == 0 and disk.recovered, "backup recovery")
	check(disk.write_save(updated), "write after recovery")
	check(disk.load_save().profile.medals == 9, "recovery commit")
	disk.delete_local()
	print("SESSION checks=%d failures=%d isolated_save=%s" % [checks, failures, test_path])
	quit(0 if failures == 0 else 1)
