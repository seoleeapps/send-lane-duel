extends Control
signal slot_pressed(index: int)
var board: Array = []
var enemy_board: Array = []
var core: Variant
var player_castle: int = 26
var enemy_castle: int = 14
var armor: String = "plate"
var replay: Dictionary = {}
var beat: int = -1
var slot_rects: Array[Rect2] = []
const SYMBOLS: Dictionary = {"fam_pierce": "▲", "fam_blast": "●", "fam_slash": "◆", "fam_arcane": "★"}
const ARMOR_SYMBOLS: Dictionary = {"plate": "■", "light": "○", "hide": "◇", "ward": "☆"}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, 272)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in range(slot_rects.size()):
			if slot_rects[i].has_point(event.position):
				slot_pressed.emit(i)
				accept_event()

func _text(pos: Vector2, message: String, color: Color = Color.WHITE, font_size: int = 16) -> void:
	draw_string(get_theme_default_font(), pos, message, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)

func _draw_board(units: Array, y: float, clickable: bool) -> void:
	var cols: int = units.size() if units.size() <= 6 else 4
	var width: float = (size.x - 12) / cols
	for i in range(units.size()):
		var rect: Rect2 = Rect2(6 + (i % cols) * width, y + (i / cols) * 50, width - 4, 48)
		draw_style_box(_slot_style(), rect)
		if clickable: slot_rects.append(rect)
		var unit: Variant = units[i]
		if unit == null: _text(rect.position + Vector2(14, 29), "+", Color(0.6, 0.6, 0.6), 23)
		else:
			_text(rect.position + Vector2(8, 24), SYMBOLS[unit[0]], Color.WHITE, 22)
			_text(rect.position + Vector2(8, 41), "•".repeat(unit[1]), Color(0.8, 0.8, 0.8), 14)

func _slot_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.22, 0.22)
	style.border_color = Color(0.55, 0.55, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style

func _draw() -> void:
	slot_rects.clear()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.16, 0.16, 0.16))
	_text(Vector2(8, 18), "♥ %d  ·  %s" % [enemy_castle, ARMOR_SYMBOLS.get(armor, "?")])
	if enemy_board.is_empty(): return
	_draw_board(enemy_board, 25, false)
	var rows: int = 1 if board.size() <= 6 else 2
	var player_y: float = size.y - 50 * rows - 24
	var lane_top: float = 81
	var lane_bottom: float = player_y - 26
	for lane in range(2):
		var x: float = size.x * (0.28 if lane == 0 else 0.72)
		draw_rect(Rect2(x - 27, lane_top, 54, lane_bottom - lane_top), Color(0.24, 0.24, 0.24))
		draw_line(Vector2(x, lane_top + 8), Vector2(x, lane_bottom - 8), Color(0.6, 0.6, 0.6), 2)
		_text(Vector2(x - 8, lane_bottom if lane == 0 else lane_top + 22), "↓" if lane == 0 else "↑", Color.WHITE, 24)
		if not replay.is_empty():
			var res: Dictionary = replay.player if lane == 0 else replay.commander
			var enemies: Array = res.enemies
			var hp: Array = []
			for e in enemies: hp.append(e[1])
			for hit in res.events:
				if hit.beat <= beat: hp[hit.enemy] = hit.hp
			for i in range(enemies.size()):
				if hp[i] <= 0: continue
				var fraction: float = float(i % 8) / 8.0
				var y: float = lerpf(lane_top + 18, lane_bottom - 10, fraction)
				var offset: float = -12 if (i / 8) % 2 == 0 else 12
				draw_circle(Vector2(x + offset, y), 5, Color(0.78, 0.78, 0.78))
			for hit in res.events:
				if hit.beat == beat:
					var sy: float = player_y if lane == 0 else 73
					draw_line(Vector2(12 + hit.slot * ((size.x - 12) / 6), sy), Vector2(x, (lane_top + lane_bottom) / 2), Color(0.9, 0.9, 0.9, 0.4), 1)
	_text(Vector2(size.x / 2 - 9, (lane_top + lane_bottom) / 2), "?" if replay.is_empty() else str(beat + 1), Color(0.7, 0.7, 0.7), 22)
	_text(Vector2(8, player_y - 7), "♥ %d" % player_castle)
	_draw_board(board, player_y, true)
	_text(Vector2(8, size.y - 5), "GRAYBOX · CORE GATE", Color(0.6, 0.6, 0.6), 12)
