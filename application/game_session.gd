extends RefCounted

const Rules = preload("res://core/game_rules.gd")
var core: Rules
var store: Variant
var data: Dictionary
var run: Rules.Run
var error_message: String = ""

func _init(rules_core: Rules, save_store: Variant) -> void:
	core = rules_core
	store = save_store

func defaults() -> Dictionary:
	return {"schema_version": 1, "profile": {"medals": 0, "unlocked": ["preset_a"], "highest_ascension": 0, "dex": []},
		"settings": {"language": "en", "large_text": false, "reduce_motion": false, "speed": 1, "sound": true, "haptics": true},
		"active": {}, "daily": {}, "tutorial": {"version": 1, "completed": false}, "session_index": 0}

func initialize() -> bool:
	data = store.load_save()
	if not store.error_message.is_empty():
		error_message = store.error_message
		return false
	if data.is_empty(): data = defaults()
	data.session_index = int(data.get("session_index", 0)) + 1
	if not data.active.is_empty():
		if data.active.rules_version != core.rules.schema:
			data.profile.medals += int(data.active.get("earned_medals", 0))
			data.active = {}
		else:
			run = replay(data.active)
			if run == null: return false
	return persist(data)

func persist(candidate: Dictionary) -> bool:
	if not store.write_save(candidate):
		error_message = store.error_message
		return false
	data = candidate
	error_message = ""
	return true

func replay(active: Dictionary) -> Rules.Run:
	if not core.presets.has(active.get("preset", "")) or not active.get("steps") is Array:
		error_message = "런 기록 형식 오류"
		return null
	var restored: Rules.Run = core.new_run(active.seed, active.preset, active.ascension)
	for step in active.steps:
		var result: Dictionary
		if step.get("step") == "route": result = restored.choose_route(step.index)
		elif step.get("step") == "draft": result = restored.choose_draft(step.index)
		elif step.get("step") == "round": result = restored.apply_action(step.action)
		else:
			error_message = "알 수 없는 런 기록"
			return null
		if result.get("ok", true) == false:
			error_message = "런 기록 복원 실패: " + result.error
			return null
	return restored

func start(seed_value: int, preset: String, ascension: int = 0, mode: String = "expedition", date: String = "") -> bool:
	if run != null and run.status in ["route", "round", "draft"]:
		error_message = "진행 중인 런을 먼저 마쳐 주세요."
		return false
	if not core.presets.has(preset) or ascension < 0 or ascension > int(data.profile.highest_ascension): return false
	if mode == "expedition" and not preset in data.profile.unlocked: return false
	if not mode in ["expedition", "daily"]: return false
	var candidate: Dictionary = data.duplicate(true)
	var ranked: bool = false
	if mode == "daily":
		if date.is_empty() or int(date.replace("-", "")) != seed_value or ascension != 0: return false
		if core.presets.keys()[seed_value % core.presets.size()] != preset: return false
		ranked = not candidate.daily.has(date)
		if ranked: candidate.daily[date] = {"attempted": true, "submitted": false}
	candidate.active = {"seed": seed_value, "preset": preset, "ascension": ascension, "mode": mode, "date": date,
		"ranked": ranked, "rules_version": core.rules.schema, "steps": [], "earned_medals": 0, "settled": false}
	if not persist(candidate): return false
	run = core.new_run(seed_value, preset, ascension)
	return true

func perform(step: Dictionary) -> Dictionary:
	if run == null: return {"ok": false, "error": "진행 중인 런 없음"}
	var candidate: Dictionary = data.duplicate(true)
	var next: Rules.Run = replay(candidate.active)
	if next == null: return {"ok": false, "error": error_message}
	var result: Dictionary
	if step.get("step") == "route": result = next.choose_route(step.index)
	elif step.get("step") == "draft": result = next.choose_draft(step.index)
	elif step.get("step") == "round": result = next.apply_action(step.action)
	else: return {"ok": false, "error": "알 수 없는 단계"}
	if result.get("ok", true) == false: return result
	candidate.active.steps.append(step.duplicate(true))
	candidate.active.earned_medals = next.chapter * 3
	if next.cmd != null and not next.cmd.id in candidate.profile.dex: candidate.profile.dex.append(next.cmd.id)
	if next.status in ["won", "lost"] and not candidate.active.settled:
		var cleared: int = next.chapter + (1 if next.status == "won" else 0)
		var medals: int = cleared * 3 + (6 if next.status == "won" else 0)
		candidate.profile.medals += medals
		candidate.active.settled = true
		candidate.active.earned_medals = 0
		candidate.active.result_medals = medals
		if next.status == "won" and candidate.active.mode == "expedition":
			candidate.profile.highest_ascension = maxi(candidate.profile.highest_ascension, mini(int(core.rules.ascension.levels), next.ascension + 1))
		if candidate.active.mode == "daily" and candidate.active.ranked:
			candidate.daily[candidate.active.date].record = {"seed": next.seed, "preset": next.preset_id, "score": next.score(),
				"rounds_used": next.rounds_used, "gold": next.player.gold, "steps": candidate.active.steps.duplicate(true), "rules_version": core.rules.schema}
	if not persist(candidate): return {"ok": false, "error": error_message}
	run = next
	return result

func finish() -> bool:
	if run != null and not run.status in ["won", "lost"]: return false
	var candidate: Dictionary = data.duplicate(true)
	candidate.active = {}
	if not persist(candidate): return false
	run = null
	return true

func abandon() -> bool:
	var candidate: Dictionary = data.duplicate(true)
	candidate.profile.medals += int(candidate.active.get("earned_medals", 0))
	candidate.active = {}
	if not persist(candidate): return false
	run = null
	return true

func unlock(preset: String) -> bool:
	if not core.presets.has(preset) or preset in data.profile.unlocked: return false
	var cost: int = core.presets[preset].unlock.medals
	if data.profile.medals < cost: return false
	var candidate: Dictionary = data.duplicate(true)
	candidate.profile.medals -= cost
	candidate.profile.unlocked.append(preset)
	return persist(candidate)

func setting(key: String, value: Variant) -> bool:
	if not data.settings.has(key): return false
	var candidate: Dictionary = data.duplicate(true)
	candidate.settings[key] = value
	return persist(candidate)
