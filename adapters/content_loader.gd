extends RefCounted

static func integers(value: Variant) -> Variant:
	if value is float: return int(value) if value == floor(value) else value
	if value is Array:
		var out: Array = []
		for item in value: out.append(integers(item))
		return out
	if value is Dictionary:
		var out: Dictionary = {}
		for key in value: out[key] = integers(value[key])
		return out
	return value

static func read_json(path: String) -> Variant:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null: return null
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text()) != OK: return null
	return integers(parser.data)

static func load_content() -> Dictionary:
	var out: Dictionary = {"rules": read_json("res://data/core/rules.json")}
	for name in ["units", "mercenaries", "commanders", "draft"]:
		out[name] = read_json("res://data/content/%s.json" % name)
	return out
