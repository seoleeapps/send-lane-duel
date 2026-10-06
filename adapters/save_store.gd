extends RefCounted
## Atomic writes, validated backup recovery. Tests pass a separate directory.
const Loader = preload("res://adapters/content_loader.gd")
var path: String
var recovered: bool = false
var error_message: String = ""

func _init(save_path: String = "user://save.json") -> void:
	path = save_path

func valid(value: Variant) -> bool:
	var basic: bool = value is Dictionary and value.get("schema_version") == 1 and value.get("profile") is Dictionary \
		and value.profile.get("medals") is int and value.profile.medals >= 0 \
		and value.profile.get("unlocked") is Array and value.profile.get("highest_ascension") is int \
		and value.profile.get("dex") is Array and value.get("settings") is Dictionary \
		and value.get("active") is Dictionary and value.get("daily") is Dictionary
	if not basic: return false
	for key in ["unlocked", "dex"]:
		for id in value.profile[key]:
			if not id is String: return false
	if value.profile.highest_ascension < 0 or value.profile.highest_ascension > 5: return false
	var settings: Dictionary = value.settings
	if not settings.get("language") in ["en", "ko"] or not settings.get("speed") in [1, 2]: return false
	for key in ["large_text", "reduce_motion", "sound", "haptics"]:
		if not settings.get(key) is bool: return false
	for date in value.daily:
		var attempt: Variant = value.daily[date]
		if not date is String or not attempt is Dictionary: return false
		if not attempt.get("attempted") is bool or not attempt.get("submitted") is bool: return false
		if attempt.has("record") and not attempt.record is Dictionary: return false
	var active: Dictionary = value.active
	if active.is_empty(): return true
	if not active.get("seed") is int or not active.get("preset") is String or not active.get("ascension") is int: return false
	if active.seed < 0 or active.seed > 0xFFFFFFFF or active.ascension < 0 or active.ascension > 5: return false
	if not active.get("rules_version") is String or not active.get("steps") is Array or active.steps.size() > 35: return false
	if not active.get("mode") in ["expedition", "daily"] or not active.get("settled") is bool: return false
	if not active.get("ranked") is bool or not active.get("date") is String: return false
	if not active.get("earned_medals") is int or active.earned_medals < 0: return false
	for step in active.steps:
		if not step is Dictionary: return false
		if step.get("step") in ["route", "draft"]:
			if not step.get("index") is int: return false
		elif step.get("step") == "round":
			if not step.get("action") is Dictionary: return false
		else: return false
	return true

func load_save() -> Dictionary:
	recovered = false
	error_message = ""
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"): return {}
	var primary: Variant = Loader.read_json(path)
	if valid(primary): return primary
	var backup: Variant = Loader.read_json(path + ".bak")
	if valid(backup):
		recovered = true
		return backup
	error_message = "저장 파일과 백업을 읽을 수 없습니다. 기존 파일은 보존했습니다."
	return {}

func write_save(data: Dictionary) -> bool:
	error_message = ""
	if not valid(data):
		error_message = "저장 형식 오류"
		return false
	var temp: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		error_message = "저장 파일을 쓸 수 없습니다."
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var code: Error = file.get_error()
	file.close()
	if code != OK or not valid(Loader.read_json(temp)):
		error_message = "저장 파일 쓰기 검증 실패"
		return false
	if valid(Loader.read_json(path)):
		if DirAccess.copy_absolute(path, path + ".bak") != OK:
			error_message = "저장 백업 실패"
			return false
	if DirAccess.rename_absolute(temp, path) != OK:
		error_message = "저장 교체 실패"
		return false
	return true

func delete_local() -> bool:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix) and DirAccess.remove_absolute(path + suffix) != OK:
			error_message = "저장 삭제 실패"
			return false
	return true
