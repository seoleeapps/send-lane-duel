extends Control
const Rules = preload("res://core/game_rules.gd")
const Loader = preload("res://adapters/content_loader.gd")
const Session = preload("res://application/game_session.gd")
const Store = preload("res://adapters/save_store.gd")
const Field = preload("res://godot/ui/battlefield.gd")
const Practice = preload("res://application/practice_session.gd")
const GameSkin = preload("res://godot/ui/skin.gd")
const Sounds = preload("res://godot/ui/sound_rack.gd")
var game: Session
var sounds: Sounds
var lesson: Practice
var practicing: bool = false
var core: Rules
var page: VBoxContainer
var surface: Control
var field: Field
var plan: Dictionary = {"builds": [], "workers": 0, "packs": []}
var allocation: String = "defense"
var result: Dictionary = {}
var scene_state: String = "startup"
var replaying: bool = false
var replay_id: int = 0
var notice: String = ""
var modal: AcceptDialog
var codex_tab: String = "commanders"

func language() -> String:
	return game.data.settings.language if game != null and not game.data.is_empty() else "en"
func named(entry: Dictionary) -> String: return tr(entry.id)

func _ready() -> void:
	theme = GameSkin.make_theme()
	sounds = Sounds.new()
	add_child(sounds)
	_initialize.call_deferred()

func _initialize() -> void:
	_shell("Three Purses")
	_label("Loading content · 0/3", 20)
	await get_tree().process_frame
	core = Rules.new(Loader.load_content())
	_shell("Three Purses")
	_label("Loading save · 1/3", 20)
	await get_tree().process_frame
	var save_path: String = "user://save.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save="): save_path = arg.trim_prefix("--save=")
	game = Session.new(core, Store.new(save_path))
	if not game.initialize():
		_shell("Three Purses")
		_label(game.error_message)
		_button(tr("Retry"), _initialize)
		return
	lesson = Practice.new(game)
	practicing = false
	TranslationServer.set_locale(language())
	sounds.set_enabled(game.data.settings.sound)
	_title()

func _title() -> void:
	sounds.track("menu")
	_shell("Three Purses")
	var logo: Label = page.get_child(0)
	logo.text = "THREE PURSES"
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_font_size_override("font_size", 38)
	_label(tr("Ready · 3/3"), 13)
	_illustration("castle", 158)
	_label(tr("Protect your castle. Break theirs."), 23)
	_toys(["marksman", "bombard", "charger", "hexer"], 48)
	_spacer()
	_button(tr("Start"), _enter, true)
	_button("English / 한국어", _title_language)
	_label("v%s · Seolee Apps" % ProjectSettings.get_setting("application/config/version"), 13)
	scene_state = "title"

func _title_language() -> void:
	if game.setting("language", "ko" if language() == "en" else "en"):
		TranslationServer.set_locale(language())
		_title()
	else: _message(game.error_message)

func current_run() -> Rules.Run: return lesson.run if practicing else game.run

func _enter() -> void:
	if lesson.active(): _resume_practice()
	elif not game.data.tutorial.completed and not game.data.tutorial.get("skipped", false): _practice_intro()
	else: _home()

func _practice_intro() -> void:
	scene_state = "practice_intro"
	_shell(tr("Learn in three turns"))
	_toys(["marksman", "elite", "castle"], 76)
	_label(tr("Protect your castle. Break theirs."), 23)
	_label(tr("Spend gold before each automatic battle."))
	_spacer()
	_label("▲ " + tr("Defenders stay and stop enemies"), 20)
	_label("+ " + tr("Workers earn more gold every turn"), 20)
	_label("↑ " + tr("Mercenaries attack the rival castle"), 20)
	_spacer()
	_label(tr("Practice keeps your expedition and medals safe."), 14)
	_button(tr("Try it now"), _start_practice, true)
	_button(tr("Skip lesson"), _skip_practice)

func _start_practice() -> void:
	if lesson.start(): _resume_practice()
	else: _message(lesson.error_message)

func _resume_practice() -> void:
	if not lesson.restore():
		_shell(tr("Learn in three turns"))
		_label(tr(lesson.error_message))
		_button(tr("Restart lesson"), _start_practice, true)
		_button(tr("Back"), _home)
		return
	practicing = true
	plan = lesson.planned()
	if lesson.pending_result():
		result = lesson.result
		_summary()
	else:
		allocation = ["defense", "workers", "mercs"][lesson.step_index()]
		_round()

func _skip_practice() -> void:
	if lesson.skip():
		practicing = false
		_home()
	else: _message(lesson.error_message)

func _practice_complete() -> void:
	practicing = false
	scene_state = "practice_complete"
	_shell(tr("You are ready!"))
	_label(tr("Protect your castle. Break theirs."), 23)
	_spacer()
	_label("▲ " + tr("Defenders stay and stop enemies"), 20)
	_label("+ " + tr("Workers earn more gold every turn"), 20)
	_label("↑ " + tr("Mercenaries attack the rival castle"), 20)
	_spacer()
	_button(tr("Continue expedition") if game.run != null else tr("Start expedition"), _show_run if game.run != null else _preparation, true)
	_button(tr("Return home"), _home)

func _shell(title: String) -> void:
	for child in get_children():
		if child == sounds: continue
		remove_child(child)
		child.queue_free()
	field = null
	var background: TextureRect = TextureRect.new()
	background.texture = load("res://assets/art/workbench.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	surface = Control.new()
	surface.custom_minimum_size = Vector2(minf(420, get_viewport_rect().size.x), get_viewport_rect().size.y)
	center.add_child(surface)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var insets: Dictionary = {"left": 12, "right": 12, "top": 12, "bottom": 12}
	if OS.get_name() in ["Android", "iOS"]:
		var safe: Rect2i = DisplayServer.get_display_safe_area()
		var physical: Vector2 = Vector2(get_window().size)
		if safe.size.x > 0 and safe.size.y > 0 and physical.x > 0 and physical.y > 0:
			var ratio: Vector2 = get_viewport_rect().size / physical
			insets.left = maxi(12, ceili(safe.position.x * ratio.x))
			insets.top = maxi(12, ceili(safe.position.y * ratio.y))
			insets.right = maxi(12, ceili((physical.x - safe.end.x) * ratio.x))
			insets.bottom = maxi(12, ceili((physical.y - safe.end.y) * ratio.y))
	for edge in insets: margin.add_theme_constant_override("margin_" + edge, insets[edge])
	surface.add_child(margin)
	page = VBoxContainer.new()
	page.add_theme_constant_override("separation", 6)
	margin.add_child(page)
	var heading: Label = _label(title, 26)
	heading.add_theme_color_override("font_color", GameSkin.BRASS)
	if not notice.is_empty():
		_label(notice, 13)
		notice = ""

func _label(text_value: String, font_size: int = 16, parent: Node = null) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", int(font_size * (1.15 if game != null and game.data.has("settings") and game.data.settings.large_text else 1.0)))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent is HBoxContainer: label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(parent if parent != null else page).add_child(label)
	return label

func _button(text_value: String, callback: Callable, primary: bool = false, parent: Node = null, disabled_value: bool = false) -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(48, 56 if primary else 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = disabled_value
	if game != null and game.data.get("settings", {}).get("large_text", false): button.add_theme_font_size_override("font_size", 18)
	button.theme_type_variation = "PrimaryButton" if primary else "Button"
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.pressed.connect(callback, CONNECT_DEFERRED)
	button.pressed.connect(func(): sounds.cue("click"), CONNECT_DEFERRED)
	(parent if parent != null else page).add_child(button)
	return button

func _illustration(asset: String, height: int, parent: Node = null) -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	icon.texture = load("res://assets/art/%s.png" % asset)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(height, height)
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else page).add_child(icon)
	return icon

func _toys(assets: Array, height: int) -> void:
	var row: HBoxContainer = _row()
	for asset in assets: _illustration(asset, height, row)

func _row(parent: Node = null) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	(parent if parent != null else page).add_child(row)
	return row

func _card(parent: Node) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_to_group("content-card")
	parent.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 10)
	panel.add_child(margin)
	var contents: VBoxContainer = VBoxContainer.new()
	contents.add_theme_constant_override("separation", 6)
	margin.add_child(contents)
	return contents

func _spacer() -> void:
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(spacer)

func _scroll() -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var contents: VBoxContainer = VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation", 6)
	scroll.add_child(contents)
	return contents

func _home() -> void:
	practicing = false
	scene_state = "home"
	_shell("Three Purses")
	sounds.track("menu")
	_illustration("castle", 116)
	_label(tr("Medals: %d") % game.data.profile.medals)
	_spacer()
	if lesson.active(): _button(tr("Resume lesson"), _resume_practice, true)
	if game.run != null:
		_button(tr("Continue expedition"), _show_run, true)
	else: _button(tr("Expedition"), _preparation, true)
	_button(tr("Daily challenge"), _daily, false, null, game.run != null)
	_button(tr("Learn to play"), _practice_intro)
	_spacer()
	var row: HBoxContainer = _row()
	_button(tr("Codex"), _codex, false, row)
	_button(tr("Settings"), _settings, false, row)
	_label(tr("Offline expedition · saved on this device"), 13)

func _preparation() -> void:
	scene_state = "preparation"
	_shell(tr("Choose your formation"))
	var contents: VBoxContainer = _scroll()
	for id in core.presets:
		var p: Dictionary = core.presets[id]
		var toys: HBoxContainer = _row(contents)
		for family in p.families: _illustration(Field.ART[family], 56, toys)
		_label(named(p), 20, contents)
		_label("%s / %s" % [named(core.families[p.families[0]]), named(core.families[p.families[1]])], 14, contents)
		if id in game.data.profile.unlocked:
			var row: GridContainer = GridContainer.new()
			row.columns = 3
			row.add_theme_constant_override("h_separation", 6)
			row.add_theme_constant_override("v_separation", 6)
			contents.add_child(row)
			for level in range(game.data.profile.highest_ascension + 1):
				_button(tr("Set out · rank %d") % level, _start.bind(id, level), false, row)
		else: _button(tr("Unlock · %d medals") % p.unlock.medals, _unlock.bind(id), false, contents, game.data.profile.medals < p.unlock.medals)
	_button(tr("Back"), _home)

func _unlock(id: String) -> void:
	if not game.unlock(id): notice = game.error_message
	_preparation()

func _start(preset: String, level: int) -> void:
	if game.start(int(Time.get_unix_time_from_system()) & 0xFFFFFFFF, preset, level): _show_run()
	else:
		notice = game.error_message
		_home()

func _show_run() -> void:
	practicing = false
	plan = {"builds": [], "workers": 0, "packs": []}
	if game.run.status == "route": _route()
	elif game.run.status == "draft": _draft()
	elif game.run.status == "round": _round()
	else: _settlement()

func _route() -> void:
	scene_state = "route"
	_shell(tr("Chapter %d · choose a route") % (game.run.chapter + 1))
	_label(tr("Choose a rival. Each spends gold differently."), 14)
	var contents: VBoxContainer = _scroll()
	for option in game.run.route_options():
		var cmd: Rules.Commander = option.commander
		var card: VBoxContainer = _card(contents)
		var army: HBoxContainer = _row(card)
		for family in cmd.focus: _illustration(Field.ART[family], 58, army)
		_label(named(cmd.cfg), 22, card)
		_label(tr(cmd.id + "_tag"), 16, card)
		_label(tr("Wave armor") + ": " + tr("armor_" + option.armor) + " " + Field.ARMOR_SYMBOLS[option.armor], 16, card)
		_button(tr("Take this route"), _perform.bind({"step": "route", "index": option.index}), true, card)
	_button(tr("Pause"), _pause)

func _perform(step: Dictionary) -> void:
	var outcome: Dictionary = game.perform(step)
	if outcome.get("ok", true) == false:
		_message(outcome.error)
		return
	_show_run()

func _round() -> void:
	scene_state = "round"
	var run: Rules.Run = current_run()
	sounds.track("boss" if run.wave().size() == 1 else "march")
	var prepared: Dictionary = run.prepare_action(plan)
	_shell(tr("Practice %d/3") % (lesson.step_index() + 1) if practicing else tr("Chapter %d · round %d/7") % [run.chapter + 1, run.k + 1])
	if practicing:
		var hint: String = tr("Ready! Press Deploy to see what happens.")
		if not lesson.ready(plan):
			if lesson.step_index() == 0: hint = tr("Tap the outlined + below. Choose Marksmen.")
			elif lesson.step_index() == 1: hint = tr("Press + to hire one worker. Income rises by %d.") % core.rules.economy.worker_income
			else: hint = tr("Tap Hide Champion %d more times to send %d packs.") % [int(lesson.config.packs) - plan.packs.size(), lesson.config.packs]
		_label(hint, 16)
	field = Field.new()
	field.board = prepared.board if prepared.ok else run.player.board
	field.enemy_board = run.cmd.side.board
	field.player_castle = run.player.castle
	field.enemy_castle = run.cmd.side.castle
	field.armor = run.armor
	field.wave = run.wave()
	field.reduce_motion = game.data.settings.reduce_motion
	field.highlight_slot = 0 if practicing and lesson.step_index() == 0 and plan.builds.is_empty() else -1
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field.slot_pressed.connect(_slot)
	page.add_child(field)
	_label(tr("Gold %d   ·   next income %d") % [prepared.gold, run.player.income() + plan.workers * int(core.rules.economy.worker_income) + plan.packs.size()], 18)
	var tabs: HBoxContainer = _row()
	for tab in [["defense", tr("Defenders")], ["workers", tr("Workers")], ["mercs", tr("Mercenaries")]]:
		_button(("✓ " if allocation == tab[0] else "") + tab[1], _tab.bind(tab[0]), false, tabs, practicing and tab[0] != ["defense", "workers", "mercs"][lesson.step_index()])
	if allocation == "defense":
		if not practicing: _label(tr("Tap your lower slots to build or upgrade"), 14)
	elif allocation == "workers":
		var row: HBoxContainer = _row()
		var minus: Button = _button("−", _worker.bind(-1), false, row, plan.workers == 0)
		minus.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_label(tr("Hire +%d · %d gold each") % [plan.workers, run.worker_cost()], 16, row)
		var plus: Button = _button("+", _worker.bind(1), false, row, prepared.gold < run.worker_cost() or run.player.workers + plan.workers >= int(core.rules.economy.worker_cap) or (practicing and plan.workers == 1))
		plus.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	else:
		var row: HBoxContainer = _row()
		for mid in run.mercs:
			if practicing and mid != lesson.config.mercenary: continue
			var caption: String = "%s +%d\n%d" % [Field.ARMOR_SYMBOLS[core.mercs[mid].armor], plan.packs.count(mid), run.merc_cost(mid)]
			if run.mercs.size() <= 3: caption = "%s\n+%d · %d" % [named(core.mercs[mid]), plan.packs.count(mid), run.merc_cost(mid)]
			if practicing: caption = "%s +%d · %d" % [named(core.mercs[mid]), plan.packs.count(mid), run.merc_cost(mid)]
			_button(caption, _pack.bind(mid), false, row, prepared.gold < run.merc_cost(mid) or (practicing and (mid != lesson.config.mercenary or plan.packs.size() == int(lesson.config.packs))))
	if not practicing:
		var own: Dictionary = core.resolve(prepared.board, run.wave(), run.player_beats())
		var enemy: Dictionary = core.resolve(run.cmd.side.board, run.wave() + core.pack_enemies(run.captives + plan.packs), core.rules.combat.beats)
		_label(tr("Castle preview: yours −%d + ? · rival −%d") % [own.castle_damage, enemy.castle_damage], 14)
	var controls: HBoxContainer = _row()
	_button(tr("Reset"), _reset_plan, false, controls)
	_button(tr("Deploy"), _battle, true, controls, practicing and not lesson.ready(plan))
	_button(tr("Help"), _help, false, controls)
	_button("Ⅱ", _pause, false, controls)

func _tab(value: String) -> void:
	allocation = value
	_round()
func _reset_plan() -> void:
	_accept_plan({"builds": [], "workers": 0, "packs": []})
func _worker(delta: int) -> void:
	var candidate: Dictionary = plan.duplicate(true)
	candidate.workers += delta
	_accept_plan(candidate)
func _pack(mid: String) -> void:
	var candidate: Dictionary = plan.duplicate(true)
	candidate.packs.append(mid)
	_accept_plan(candidate)
func _accept_plan(candidate: Dictionary) -> void:
	var prepared: Dictionary = current_run().prepare_action(candidate)
	if prepared.ok:
		if practicing and not lesson.plan_action(candidate):
			_message(tr(lesson.error_message) if not lesson.error_message.is_empty() else tr("Complete the highlighted action first."))
			return
		if candidate.builds.size() > plan.builds.size(): sounds.cue("place")
		elif candidate.workers > plan.workers: sounds.cue("worker")
		elif candidate.packs.size() > plan.packs.size(): sounds.cue("send")
		plan = candidate
		_round()
	else: _message(prepared.error)

func _slot(index: int) -> void:
	if replaying: return
	if practicing and (lesson.step_index() != 0 or index != 0 or not plan.builds.is_empty()): return
	var run: Rules.Run = current_run()
	var prepared: Dictionary = run.prepare_action(plan)
	var board: Array = prepared.board
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = tr("Slot %d") % (index + 1)
	dialog.min_size = Vector2i(300, 220)
	var options: VBoxContainer = VBoxContainer.new()
	dialog.add_child(options)
	if board[index] != null and board[index][1] < 3:
		_button(tr("Upgrade · %d") % core.tier_cost(board[index][0], board[index][1] + 1, run.mod.upgrade_cost), func(): dialog.queue_free(); _build(["upgrade", index]), false, options)
	for family in run.families:
		if practicing and family != core.rules.tutorial.forced[0].family: continue
		var action: String = "place" if board[index] == null else "replace"
		var cost: int = core.tier_cost(family, 1)
		if action == "replace": cost -= core.unit_value(board[index][0], board[index][1]) * int(core.rules.economy.replace_refund_pct) / 100
		_button("%s · %d" % [named(core.families[family]), cost], func(): dialog.queue_free(); _build([action, index, family]), false, options)
	add_child(dialog)
	dialog.popup_centered()

func _build(action: Array) -> void:
	var candidate: Dictionary = plan.duplicate(true)
	candidate.builds.append(action)
	_accept_plan(candidate)

func _battle() -> void:
	if replaying: return
	var run: Rules.Run = current_run()
	var old_board: Array = run.prepare_action(plan).board
	var old_enemy: Array = run.cmd.side.board.duplicate(true)
	var old_player_hp: int = run.player.castle
	var old_enemy_hp: int = run.cmd.side.castle
	var outcome: Dictionary = lesson.perform(plan) if practicing else game.perform({"step": "round", "action": plan})
	if outcome.get("ok", true) == false:
		_message(outcome.error)
		return
	result = outcome
	replaying = true
	replay_id += 1
	var token: int = replay_id
	scene_state = "battle"
	_shell(tr("Battle"))
	field = Field.new()
	field.board = old_board
	field.enemy_board = old_enemy
	field.player_castle = old_player_hp
	field.enemy_castle = old_enemy_hp
	field.armor = current_run().armor
	field.replay = current_run().last_combat
	field.reduce_motion = game.data.settings.reduce_motion
	field.final_player_castle = old_player_hp - int(result.my_damage)
	field.final_enemy_castle = old_enemy_hp - int(result.cmd_damage)
	field.last_beat = current_run().player_beats() - 1
	field.beat_duration = 0.08 if game.data.settings.reduce_motion else 0.35 / int(game.data.settings.speed)
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(field)
	_button(tr("Skip"), _skip_battle, true)
	for beat in range(current_run().player_beats()):
		if token != replay_id or not replaying: return
		field.beat = beat
		field.beat_fraction = 0
		field.queue_redraw()
		var played: Array = []
		for hit in current_run().last_combat.player.events:
			if hit.beat != beat: continue
			var family: String = old_board[hit.slot][0]
			if not family in played:
				played.append(family)
				sounds.cue({"fam_pierce": "shot", "fam_blast": "boom", "fam_slash": "hoof", "fam_arcane": "magic"}[family])
		await get_tree().create_timer(0.08 if game.data.settings.reduce_motion else 0.35 / int(game.data.settings.speed)).timeout
	if token == replay_id: _skip_battle()

func _skip_battle() -> void:
	replaying = false
	replay_id += 1
	_summary()

func _summary() -> void:
	scene_state = "summary"
	_shell(tr("Round result"))
	sounds.cue("leak" if int(result.my_damage) > 0 else "coin")
	if not result.revealed.is_empty(): sounds.cue("reveal")
	_toys(["castle", "elite", "castle"], 60)
	_label(tr("Your castle −%d    Rival −%d") % [result.my_damage, result.cmd_damage], 24)
	if practicing:
		var text_value: String
		if lesson.step_index() == 1: text_value = tr("Your defender stays for the next battle.\nNext turn: +%d gold.") % current_run().player.income()
		elif lesson.step_index() == 2: text_value = tr("One worker: income %d → %d every turn.") % [int(core.rules.run.base_income), current_run().player.income()]
		else: text_value = tr("Sent %d packs → rival castle −%d.\nMercenaries also raise future income by %d.") % [lesson.config.packs, result.cmd_damage, int(lesson.config.packs) * int(core.rules.economy.merc_income_per_pack)]
		_label(text_value, 20)
	var contents: VBoxContainer = _scroll()
	_label(tr("Mercenaries revealed"), 18, contents)
	var counts: Dictionary = {}
	for mid in result.revealed: counts[mid] = counts.get(mid, 0) + 1
	for mid in counts: _label("%s ×%d" % [named(core.mercs[mid]), counts[mid]], 16, contents)
	_label(tr("Leaks into your castle"), 18, contents)
	for leak in current_run().last_combat.player.leaked:
		_label("%s → ♥ −%d" % [Field.ARMOR_SYMBOLS[leak.armor], leak.damage], 16, contents)
	_label(tr("Captives: %d") % result.captives.size(), 18, contents)
	if result.get("timeout", false): _label(tr("Time limit: castle damage, no healing"), 16, contents)
	_button(tr("Continue"), _continue_result, true)

func _continue_result() -> void:
	if not practicing:
		_show_run()
		return
	if not lesson.acknowledge():
		_message(lesson.error_message)
		return
	if not lesson.active(): _practice_complete()
	else: _resume_practice()

func _draft() -> void:
	scene_state = "draft"
	_shell(tr("Chapter reward"))
	sounds.cue("victory")
	var contents: VBoxContainer = _scroll()
	var choices: Array = game.run.draft_options()
	for i in range(choices.size()):
		var choice: Array = choices[i]
		var entry: Dictionary = core.families[choice[1]] if choice[0] == "family" else (core.mercs[choice[1]] if choice[0] == "merc" else core.boons[choice[1]])
		var card: VBoxContainer = _card(contents)
		var row: HBoxContainer = _row(card)
		_illustration(Field.ART[entry.id] if choice[0] == "family" else ("elite" if choice[0] == "merc" else "hexer"), 56, row)
		_label(named(entry), 22, row)
		_label(tr(entry.id + "_description") if choice[0] == "boon" else tr("New defender") if choice[0] == "family" else tr("New mercenary"), 16, card)
		_button(tr("Choose"), _perform.bind({"step": "draft", "index": i}), true, card)

func _settlement() -> void:
	scene_state = "settlement"
	_shell(tr("Expedition complete"))
	_illustration("castle", 100)
	sounds.cue("victory" if game.run.status == "won" else "defeat")
	_label(tr("Victory") if game.run.status == "won" else tr("Castle lost"), 28)
	_label(tr("Score %d · medals +%d") % [game.run.score(), game.data.active.get("result_medals", 0)], 22)
	var contents: VBoxContainer = _scroll()
	for entry in game.run.log: _label(named(core.commanders[entry[0]]) + " · " + tr(entry[1]), 16, contents)
	if game.data.active.mode == "daily": _label(tr("Today's score is saved on this device."), 16, contents)
	_button(tr("Return home"), _finish, true)

func _finish() -> void:
	if game.finish(): _home()
	else: _message(game.error_message)

func _pause() -> void:
	if practicing:
		var pause_dialog: AcceptDialog = AcceptDialog.new()
		pause_dialog.title = tr("Practice paused")
		pause_dialog.dialog_text = tr("Your lesson is saved. Resume it from home.")
		pause_dialog.ok_button_text = tr("Continue")
		pause_dialog.add_button(tr("Return home"), false, "home")
		pause_dialog.custom_action.connect(func(action: String):
			if action == "home":
				pause_dialog.queue_free()
				_home(), CONNECT_DEFERRED)
		add_child(pause_dialog)
		pause_dialog.popup_centered()
		return
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = tr("Expedition paused")
	dialog.dialog_text = tr("Progress saved. Abandon this run?")
	dialog.ok_button_text = tr("Abandon")
	dialog.cancel_button_text = tr("Continue")
	dialog.confirmed.connect(func():
		if game.abandon(): _home()
		else: _message(game.error_message), CONNECT_DEFERRED)
	add_child(dialog)
	dialog.popup_centered()

func _daily() -> void:
	scene_state = "daily"
	_shell(tr("Daily challenge"))
	var date: String = Time.get_date_string_from_system(true)
	var seed_value: int = int(date.replace("-", ""))
	var preset: String = core.presets.keys()[seed_value % core.presets.size()]
	_label(date + " · UTC", 20)
	_label(named(core.presets[preset]), 22)
	_label(tr("Same seed · first attempt only · no continue"))
	var record: Dictionary = game.data.daily.get(date, {}).get("record", {})
	if not record.is_empty(): _label(tr("Your best recorded score: %d") % record.score, 24)
	_spacer()
	_label(tr("Today's score is saved on this device."))
	_button(tr("Practice") if game.data.daily.has(date) else tr("Challenge"), func():
		if game.start(seed_value, preset, 0, "daily", date): _show_run()
		else: _message(game.error_message), true)
	_button(tr("Back"), _home)

func _codex() -> void:
	scene_state = "codex"
	_shell(tr("Codex"))
	var tabs: HBoxContainer = _row()
	for tab in [["commanders", tr("Rivals")], ["families", tr("Defenders")], ["mercs", tr("Send")], ["boons", tr("Rewards")]]:
		_button(("✓ " if codex_tab == tab[0] else "") + tab[1], func(): codex_tab = tab[0]; _codex(), false, tabs)
	var contents: VBoxContainer = _scroll()
	var entries: Dictionary = core.get(codex_tab)
	for id in entries:
		var cfg: Dictionary = entries[id]
		var card: VBoxContainer = _card(contents)
		var row: HBoxContainer = _row(card)
		_illustration(Field.ART[id] if codex_tab == "families" else ("swarm" if codex_tab == "mercs" and cfg.count > 1 else "elite" if codex_tab == "mercs" else "marksman" if codex_tab == "commanders" else "hexer"), 64, row)
		_label(named(cfg), 22, row)
		if codex_tab == "commanders":
			_label(tr(id + "_tag"), 16, card)
			var split: Array = cfg.split.default
			_label(tr("Hold %d%% · grow %d%% · send %d%%") % split, 14, card)
		elif codex_tab == "families":
			_label(tr("Strong: %s · weak: %s") % [tr("armor_" + core.rules.combat.strong_against[cfg.attack]), tr("armor_" + core.rules.combat.weak_against[cfg.attack])], 16, card)
			_label(tr("Build %d · upgrade %d / %d gold") % [cfg.tiers[0].cost, cfg.tiers[1].cost, cfg.tiers[2].cost], 14, card)
		elif codex_tab == "mercs":
			_label(tr("%d gold → %d toys · %s") % [cfg.cost, cfg.count, tr("armor_" + cfg.armor)], 16, card)
			_label(tr("Each: %d HP · castle damage %d") % [cfg.hp, cfg.leak], 14, card)
		else: _label(tr(id + "_description"), 16, card)
	_button(tr("Back"), _home)

func _settings() -> void:
	scene_state = "settings"
	_shell(tr("Settings"))
	_button("English / 한국어", func(): game.setting("language", "ko" if language() == "en" else "en"); TranslationServer.set_locale(language()); _settings())
	_button(tr("Large text") + (" ✓" if game.data.settings.large_text else ""), func(): game.setting("large_text", not game.data.settings.large_text); _settings())
	_button(tr("Reduce motion") + (" ✓" if game.data.settings.reduce_motion else ""), func(): game.setting("reduce_motion", not game.data.settings.reduce_motion); _settings())
	_button(tr("Battle speed") + " ×%d" % game.data.settings.speed, func(): game.setting("speed", 2 if game.data.settings.speed == 1 else 1); _settings())
	_button(tr("Sound") + (" ✓" if game.data.settings.sound else ""), func():
		if game.setting("sound", not game.data.settings.sound):
			sounds.set_enabled(game.data.settings.sound)
			_settings()
		else: _message(game.error_message))
	_button(tr("Learn to play"), _practice_intro)
	_spacer()
	_button(tr("Delete device save"), _delete_prompt)
	_button(tr("Back"), _home)

func _delete_prompt() -> void:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.dialog_text = tr("Delete medals, unlocks and saved run on this device?")
	dialog.confirmed.connect(func():
		if game.store.delete_local(): _initialize()
		else: _message(game.store.error_message), CONNECT_DEFERRED)
	add_child(dialog)
	dialog.popup_centered()

func _message(message: String) -> void:
	modal = AcceptDialog.new()
	modal.dialog_text = message
	add_child(modal)
	modal.popup_centered()

func _help() -> void:
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = tr("How to play")
	dialog.dialog_text = tr("Protect your castle. Break theirs.") + "\n\n" + "▲ " + tr("Defenders stay and stop enemies") + "\n" + "+ " + tr("Workers earn more gold every turn") + "\n" + "↑ " + tr("Mercenaries attack the rival castle") + "\n\n" + tr("Choose your spending, then press Deploy.\nEnemies that get through damage the castle.")
	dialog.ok_button_text = tr("Continue")
	add_child(dialog)
	dialog.popup_centered(Vector2i(320, 280))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if scene_state in ["round", "route", "draft"]: _pause()
		elif not scene_state in ["battle", "startup", "title"]: _home()
