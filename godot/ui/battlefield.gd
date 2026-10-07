extends Control
signal slot_pressed(index: int)
const GameSkin = preload("res://godot/ui/skin.gd")
const ART = {"fam_pierce": "marksman", "fam_blast": "bombard", "fam_slash": "charger", "fam_arcane": "hexer"}
const ARMOR_SYMBOLS = {"plate": "■", "light": "○", "hide": "◇", "ward": "☆"}
const ARMOR_COLORS = {"plate": Color("a7b9c6"), "light": Color("f3c469"), "hide": Color("d79674"), "ward": Color("ae97d9")}
var textures: Dictionary = {}
var board: Array = []
var enemy_board: Array = []
var player_castle: int = 26
var enemy_castle: int = 14
var final_player_castle: int = -1
var final_enemy_castle: int = -1
var armor: String = "plate"
var wave: Array = []
var replay: Dictionary = {}
var beat: int = -1
var last_beat: int = 7
var beat_fraction: float = 0
var beat_duration: float = 0.35
var reduce_motion: bool = false
var slot_rects: Array[Rect2] = []
var highlight_slot: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, 228)
	for name in ["marksman", "bombard", "charger", "hexer", "swarm", "elite", "castle"]:
		textures[name] = load("res://assets/art/%s.png" % name)

func _process(delta: float) -> void:
	if not replay.is_empty():
		beat_fraction = minf(1, beat_fraction + delta / beat_duration)
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not replay.is_empty(): return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in range(slot_rects.size()):
			if slot_rects[i].has_point(event.position):
				slot_pressed.emit(i)
				accept_event()

func _text(pos: Vector2, message: String, color: Color = GameSkin.PAPER, font_size: int = 16) -> void:
	draw_string(get_theme_default_font(), pos, message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _sprite(name: String, rect: Rect2, color: Color = Color.WHITE) -> void:
	if textures.has(name): draw_texture_rect(textures[name], rect, false, color)

func _draw_board(units: Array, y: float, clickable: bool) -> void:
	var cols: int = units.size() if units.size() <= 6 else 4
	var width: float = (size.x - 12) / cols
	for i in range(units.size()):
		var rect: Rect2 = Rect2(6 + (i % cols) * width, y + (i / cols) * 50, width - 4, 48)
		var style: StyleBoxFlat = GameSkin.box(Color("24484b") if clickable else Color("293f49"), GameSkin.BRASS if clickable else Color("6e8b98"), 4)
		style.shadow_size = 0
		if clickable and i == highlight_slot:
			style.border_color = Color("ffe5a0")
			style.set_border_width_all(3)
		draw_style_box(style, rect)
		if clickable: slot_rects.append(rect)
		var unit: Variant = units[i]
		if unit == null:
			_text(rect.position + Vector2(rect.size.x / 2 - 6, 30), "+", GameSkin.BRASS, 24)
		else:
			var recoil: float = 0
			if not replay.is_empty() and not reduce_motion:
				var events: Array = replay.player.events if clickable else replay.commander.events
				for hit in events:
					if hit.beat == beat and hit.slot == i: recoil = -sin(beat_fraction * PI) * 3
			var extent: float = 32 * [1.0, 1.12, 1.25][int(unit[1]) - 1]
			_sprite(ART[unit[0]], Rect2(rect.position + Vector2((rect.size.x - extent) / 2, 1 + recoil), Vector2.ONE * extent))
			_text(rect.position + Vector2(3, 44), tr(unit[0] + "_short"), GameSkin.PAPER, 13)
			for dot in range(unit[1]): draw_circle(rect.position + Vector2(rect.size.x - 16 + dot * 5, 41), 1.7, GameSkin.BRASS)

func _draw_enemy(enemy: Array, point: Vector2, hp: int, alpha: float = 1.0) -> void:
	var large: bool = int(enemy[2]) > 1
	var extent: float = (38 if large else 29) if not replay.is_empty() else (28 if large else 21)
	var color: Color = ARMOR_COLORS[enemy[0]]
	color.a = alpha
	draw_circle(point + Vector2(0, 8), extent * 0.38, Color(color, alpha * 0.65))
	_sprite("elite" if large else "swarm", Rect2(point - Vector2.ONE * extent / 2, Vector2.ONE * extent), Color(1, 1, 1, alpha))
	_text(point + Vector2(7, 9), ARMOR_SYMBOLS[enemy[0]], color, 10)
	if hp > 0 and not replay.is_empty():
		draw_rect(Rect2(point + Vector2(-8, -extent / 2 - 3), Vector2(16, 2)), Color("2e4148"))
		draw_rect(Rect2(point + Vector2(-8, -extent / 2 - 3), Vector2(16 * clampf(float(hp) / int(enemy[1]), 0, 1), 2)), GameSkin.BRASS)

func _draw() -> void:
	slot_rects.clear()
	var frame: StyleBoxFlat = GameSkin.box(Color(0.06, 0.17, 0.2, 0.93), GameSkin.BRASS, 9)
	frame.shadow_size = 0
	draw_style_box(frame, Rect2(Vector2.ZERO, size))
	if enemy_board.is_empty(): return
	var final_beat: bool = not replay.is_empty() and beat >= last_beat
	var my_hp: int = maxi(0, final_player_castle) if final_beat and final_player_castle >= 0 else player_castle
	var rival_hp: int = maxi(0, final_enemy_castle) if final_beat and final_enemy_castle >= 0 else enemy_castle
	_text(Vector2(8, 19), tr("Rival castle") + " ♥ %d · " % rival_hp + tr("armor_" + armor) + " " + ARMOR_SYMBOLS.get(armor, "?"), GameSkin.PAPER, 16)
	_sprite("castle", Rect2(size.x - 38, 1, 32, 25))
	_draw_board(enemy_board, 28, false)
	var rows: int = 1 if board.size() <= 6 else 2
	var player_y: float = size.y - 50 * rows - 23
	var lane_top: float = 88
	var lane_bottom: float = player_y - 28
	for lane in range(2):
		var x: float = size.x * (0.29 if lane == 0 else 0.71)
		var lane_rect: Rect2 = Rect2(x - 31, lane_top - 6, 62, lane_bottom - lane_top + 14)
		draw_style_box(GameSkin.box(Color("17383e"), Color("827350"), 5), lane_rect)
		draw_line(Vector2(x - 26, lane_top), Vector2(x - 26, lane_bottom), GameSkin.BRASS, 1)
		draw_line(Vector2(x + 26, lane_top), Vector2(x + 26, lane_bottom), GameSkin.BRASS, 1)
		_text(Vector2(x - 5, lane_bottom + 4 if lane == 0 else lane_top + 12), "↓" if lane == 0 else "↑", GameSkin.BRASS, 18)
		if replay.is_empty():
			for i in range(mini(wave.size(), 3)):
				var y: float = lerpf(lane_top + 12, lane_bottom - 8, (i + 1) / 4.0)
				_draw_enemy(wave[i], Vector2(x + (9 if i % 2 == 0 else -9), y), 0, 0.9)
		else:
			var res: Dictionary = replay.player if lane == 0 else replay.commander
			var enemies: Array = res.enemies
			var hp: Array = []
			for enemy in enemies: hp.append(enemy[1])
			for hit in res.events:
				if hit.beat <= beat: hp[hit.enemy] = hit.hp
			for i in range(enemies.size()):
				if hp[i] <= 0: continue
				var fraction: float = (i % 5 + 0.6) / 6.0
				if not reduce_motion: fraction = fmod(fraction + (beat + beat_fraction) * 0.055, 0.85)
				var y: float = lerpf(lane_top + 8, lane_bottom - 8, fraction if lane == 0 else 1.0 - fraction)
				_draw_enemy(enemies[i], Vector2(x + (-11 if (i / 5) % 2 == 0 else 11), y), hp[i])
			for hit in res.events:
				if hit.beat != beat: continue
				var sy: float = player_y if lane == 0 else 74
				var impact: Vector2 = Vector2(x, (lane_top + lane_bottom) / 2)
				var fade: float = 1.0 - beat_fraction
				if not reduce_motion:
					draw_line(Vector2(20 + hit.slot * ((size.x - 12) / 6), sy), impact, Color(GameSkin.BRASS, fade * 0.8), 2)
					draw_circle(impact, 4 + beat_fraction * 10, Color(GameSkin.BRASS, fade * 0.4))
				_text(impact + Vector2(4, -beat_fraction * 14), "−%d" % hit.damage, Color("ffe3a0"), 13)
	if replay.is_empty(): _text(Vector2(size.x/2 - 6, (lane_top + lane_bottom)/2), "?", GameSkin.PAPER, 22)
	_text(Vector2(8, player_y - 7), tr("Your castle") + " ♥ %d" % my_hp, GameSkin.PAPER, 16)
	_sprite("castle", Rect2(size.x - 38, player_y - 26, 32, 24))
	_draw_board(board, player_y, true)
	_text(Vector2(8, size.y - 5), tr("Defenders stay here"), Color("b8cbc8"), 13)
