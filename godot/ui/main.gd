extends Control
const Rules = preload("res://core/game_rules.gd")
const Loader = preload("res://adapters/content_loader.gd")
const Session = preload("res://application/game_session.gd")
const Store = preload("res://adapters/save_store.gd")
const Field = preload("res://godot/ui/battlefield.gd")
var game: Session
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

func language() -> String:
	return game.data.settings.language if game != null and not game.data.is_empty() else "en"
func named(entry: Dictionary) -> String: return tr(entry.id)

func _ready() -> void:
	var style: Theme = Theme.new()
	style.default_font = load("res://assets/fonts/DoHyeon-Regular.ttf")
	style.default_font_size = 16
	theme = style
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
	TranslationServer.set_locale(language())
	_shell("Three Purses")
	_label(tr("Ready · 3/3"), 20)
	_label(tr("Hold. Grow. Send."), 24)
	_label(tr("Core playtest build\nOffline expedition"))
	_spacer()
	_button(tr("Start"), _home, true)
	_label("v0.1.0 · Seolee Apps", 13)
	scene_state = "title"

func _shell(title: String) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	field = null
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
	_label(title, 22)
	if not notice.is_empty():
		_label(notice, 13)
		notice = ""

func _label(text_value: String, font_size: int = 16, parent: Node = null) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", int(font_size * (1.15 if game != null and game.data.has("settings") and game.data.settings.large_text else 1.0)))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else page).add_child(label)
	return label

func _button(text_value: String, callback: Callable, primary: bool = false, parent: Node = null, disabled_value: bool = false) -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(48, 56 if primary else 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = disabled_value
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.pressed.connect(callback, CONNECT_DEFERRED)
	(parent if parent != null else page).add_child(button)
	return button

func _row(parent: Node = null) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	(parent if parent != null else page).add_child(row)
	return row

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
	scene_state = "home"
	_shell("Three Purses")
	_label(tr("Medals: %d") % game.data.profile.medals)
	_spacer()
	if game.run != null:
		_button(tr("Continue expedition"), _show_run, true)
	else: _button(tr("Expedition"), _preparation, true)
	_button(tr("Daily challenge"), _daily, false, null, game.run != null)
	_spacer()
	var row: HBoxContainer = _row()
	_button(tr("Codex"), _codex, false, row)
	_button(tr("Settings"), _settings, false, row)
	_label(tr("Offline · core playtest"), 13)

func _preparation() -> void:
	scene_state = "preparation"
	_shell(tr("Choose your formation"))
	var contents: VBoxContainer = _scroll()
	for id in core.presets:
		var p: Dictionary = core.presets[id]
		_label(named(p), 20, contents)
		_label("%s / %s" % [named(core.families[p.families[0]]), named(core.families[p.families[1]])], 14, contents)
		if id in game.data.profile.unlocked:
			var row: GridContainer = GridContainer.new()
			row.columns = 3
			row.add_theme_constant_override("h_separation", 6)
			row.add_theme_constant_override("v_separation", 6)
			contents.add_child(row)
			for level in range(game.data.profile.highest_ascension + 1):
				_button(tr("Rank %d") % level, _start.bind(id, level), false, row)
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
	plan = {"builds": [], "workers": 0, "packs": []}
	if game.run.status == "route": _route()
	elif game.run.status == "draft": _draft()
	elif game.run.status == "round": _round()
	else: _settlement()

func _route() -> void:
	scene_state = "route"
	_shell(tr("Chapter %d · choose a route") % (game.run.chapter + 1))
	var contents: VBoxContainer = _scroll()
	for option in game.run.route_options():
		var cmd: Rules.Commander = option.commander
		_label(named(cmd.cfg), 22, contents)
		_label(tr(cmd.id + "_tag"), 16, contents)
		_label(tr("Defense") + ": " + named(core.families[cmd.focus[0]]) + " / " + named(core.families[cmd.focus[1]]), 16, contents)
		_label(tr("Wave armor") + ": " + Field.ARMOR_SYMBOLS[option.armor], 20, contents)
		_button(tr("Take this route"), _perform.bind({"step": "route", "index": option.index}), true, contents)
	_button(tr("Pause"), _pause)

func _perform(step: Dictionary) -> void:
	var outcome: Dictionary = game.perform(step)
	if outcome.get("ok", true) == false:
		_message(outcome.error)
		return
	_show_run()

func _round() -> void:
	scene_state = "round"
	var run: Rules.Run = game.run
	var prepared: Dictionary = run.prepare_action(plan)
	_shell(tr("Chapter %d · round %d/7") % [run.chapter + 1, run.k + 1])
	field = Field.new()
	field.core = core
	field.board = prepared.board if prepared.ok else run.player.board
	field.enemy_board = run.cmd.side.board
	field.player_castle = run.player.castle
	field.enemy_castle = run.cmd.side.castle
	field.armor = run.armor
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field.slot_pressed.connect(_slot)
	page.add_child(field)
	_label(tr("Gold %d   ·   next income %d") % [prepared.gold, run.player.income() + plan.workers * int(core.rules.economy.worker_income) + plan.packs.size()], 18)
	var tabs: HBoxContainer = _row()
	for tab in [["defense", tr("Hold")], ["workers", tr("Grow")], ["mercs", tr("Send")]]:
		_button(("✓ " if allocation == tab[0] else "") + tab[1], _tab.bind(tab[0]), false, tabs)
	if allocation == "defense": _label(tr("Tap a slot to build or upgrade"), 14)
	elif allocation == "workers":
		var row: HBoxContainer = _row()
		_button("−", _worker.bind(-1), false, row, plan.workers == 0)
		_label(tr("Workers +%d · %d gold") % [plan.workers, run.worker_cost()], 16, row)
		_button("+", _worker.bind(1), false, row, prepared.gold < run.worker_cost() or run.player.workers + plan.workers >= int(core.rules.economy.worker_cap))
	else:
		var row: HBoxContainer = _row()
		for mid in run.mercs:
			_button("%s +%d\n%d" % [Field.ARMOR_SYMBOLS[core.mercs[mid].armor], plan.packs.count(mid), run.merc_cost(mid)], _pack.bind(mid), false, row, prepared.gold < run.merc_cost(mid))
	var own: Dictionary = core.resolve(prepared.board, run.wave(), run.player_beats())
	var enemy: Dictionary = core.resolve(run.cmd.side.board, run.wave() + core.pack_enemies(run.captives + plan.packs), core.rules.combat.beats)
	_label(tr("Wave leak %d + ?  ·  enemy damage %d") % [own.castle_damage, enemy.castle_damage], 14)
	var controls: HBoxContainer = _row()
	_button(tr("Reset"), _reset_plan, false, controls)
	_button(tr("Deploy"), _battle, true, controls)
	_button("Ⅱ", _pause, false, controls)

func _tab(value: String) -> void:
	allocation = value
	_round()
func _reset_plan() -> void:
	plan = {"builds": [], "workers": 0, "packs": []}
	_round()
func _worker(delta: int) -> void:
	var candidate: Dictionary = plan.duplicate(true)
	candidate.workers += delta
	_accept_plan(candidate)
func _pack(mid: String) -> void:
	var candidate: Dictionary = plan.duplicate(true)
	candidate.packs.append(mid)
	_accept_plan(candidate)
func _accept_plan(candidate: Dictionary) -> void:
	var prepared: Dictionary = game.run.prepare_action(candidate)
	if prepared.ok:
		plan = candidate
		_round()
	else: _message(prepared.error)

func _slot(index: int) -> void:
	if replaying: return
	var prepared: Dictionary = game.run.prepare_action(plan)
	var board: Array = prepared.board
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = tr("Slot %d") % (index + 1)
	dialog.min_size = Vector2i(300, 220)
	var options: VBoxContainer = VBoxContainer.new()
	dialog.add_child(options)
	if board[index] != null and board[index][1] < 3:
		_button(tr("Upgrade · %d") % core.tier_cost(board[index][0], board[index][1] + 1, game.run.mod.upgrade_cost), func(): dialog.queue_free(); _build(["upgrade", index]), false, options)
	for family in game.run.families:
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
	var old_board: Array = game.run.prepare_action(plan).board
	var old_enemy: Array = game.run.cmd.side.board.duplicate(true)
	var old_player_hp: int = game.run.player.castle
	var old_enemy_hp: int = game.run.cmd.side.castle
	var outcome: Dictionary = game.perform({"step": "round", "action": plan})
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
	field.armor = game.run.armor
	field.replay = game.run.last_combat
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(field)
	_button(tr("Skip"), _skip_battle, true)
	for beat in range(game.run.player_beats()):
		if token != replay_id or not replaying: return
		field.beat = beat
		field.queue_redraw()
		await get_tree().create_timer(0.08 if game.data.settings.reduce_motion else 0.35 / int(game.data.settings.speed)).timeout
	if token == replay_id: _skip_battle()

func _skip_battle() -> void:
	replaying = false
	replay_id += 1
	_summary()

func _summary() -> void:
	scene_state = "summary"
	_shell(tr("Round result"))
	_label(tr("Your castle −%d    Rival −%d") % [result.my_damage, result.cmd_damage], 24)
	var contents: VBoxContainer = _scroll()
	_label(tr("Mercenaries revealed"), 18, contents)
	var counts: Dictionary = {}
	for mid in result.revealed: counts[mid] = counts.get(mid, 0) + 1
	for mid in counts: _label("%s ×%d" % [named(core.mercs[mid]), counts[mid]], 16, contents)
	_label(tr("Leaks into your castle"), 18, contents)
	for leak in game.run.last_combat.player.leaked:
		_label("%s → ♥ −%d" % [Field.ARMOR_SYMBOLS[leak.armor], leak.damage], 16, contents)
	_label(tr("Captives: %d") % result.captives.size(), 18, contents)
	if result.get("timeout", false): _label(tr("Time limit: castle damage, no healing"), 16, contents)
	_button(tr("Continue"), _show_run, true)

func _draft() -> void:
	scene_state = "draft"
	_shell(tr("Chapter reward"))
	var contents: VBoxContainer = _scroll()
	var choices: Array = game.run.draft_options()
	for i in range(choices.size()):
		var choice: Array = choices[i]
		var entry: Dictionary = core.families[choice[1]] if choice[0] == "family" else (core.mercs[choice[1]] if choice[0] == "merc" else core.boons[choice[1]])
		_label(named(entry), 22, contents)
		_label(tr(entry.id + "_description") if choice[0] == "boon" else tr("New defender") if choice[0] == "family" else tr("New mercenary"), 16, contents)
		_button(tr("Choose"), _perform.bind({"step": "draft", "index": i}), true, contents)

func _settlement() -> void:
	scene_state = "settlement"
	_shell(tr("Expedition complete"))
	_label(tr("Victory") if game.run.status == "won" else tr("Castle lost"), 28)
	_label(tr("Score %d · medals +%d") % [game.run.score(), game.data.active.get("result_medals", 0)], 22)
	var contents: VBoxContainer = _scroll()
	for entry in game.run.log: _label(named(core.commanders[entry[0]]) + " · " + tr(entry[1]), 16, contents)
	if game.data.active.mode == "daily": _label(tr("Saved on device. Leaderboard connection pending."), 16, contents)
	_button(tr("Return home"), _finish, true)

func _finish() -> void:
	if game.finish(): _home()
	else: _message(game.error_message)

func _pause() -> void:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = tr("Expedition paused")
	dialog.dialog_text = tr("Progress saved. Abandon this run?")
	dialog.ok_button_text = tr("Abandon")
	dialog.cancel_button_text = tr("Continue")
	dialog.confirmed.connect(func():
		if game.abandon(): _home()
		else: _message(game.error_message))
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
	_spacer()
	_label(tr("Offline play available. Scores remain on this device until online services are ready."))
	_button(tr("Practice") if game.data.daily.has(date) else tr("Challenge"), func():
		if game.start(seed_value, preset, 0, "daily", date): _show_run()
		else: _message(game.error_message), true)
	_button(tr("Back"), _home)

func _codex() -> void:
	scene_state = "codex"
	_shell(tr("Commander codex"))
	var contents: VBoxContainer = _scroll()
	for id in core.commanders:
		var cfg: Dictionary = core.commanders[id]
		_label(named(cfg) if id in game.data.profile.dex else "?", 22, contents)
		if id in game.data.profile.dex:
			_label(tr(id + "_tag"), 16, contents)
			var split: Array = cfg.split.default
			_label(tr("Hold %d%% · grow %d%% · send %d%%") % split, 16, contents)
	_button(tr("Back"), _home)

func _settings() -> void:
	scene_state = "settings"
	_shell(tr("Settings"))
	_button("English / 한국어", func(): game.setting("language", "ko" if language() == "en" else "en"); TranslationServer.set_locale(language()); _settings())
	_button(tr("Large text") + (" ✓" if game.data.settings.large_text else ""), func(): game.setting("large_text", not game.data.settings.large_text); _settings())
	_button(tr("Reduce motion") + (" ✓" if game.data.settings.reduce_motion else ""), func(): game.setting("reduce_motion", not game.data.settings.reduce_motion); _settings())
	_button(tr("Battle speed") + " ×%d" % game.data.settings.speed, func(): game.setting("speed", 2 if game.data.settings.speed == 1 else 1); _settings())
	_spacer()
	_button(tr("Delete device save"), _delete_prompt)
	_button(tr("Back"), _home)

func _delete_prompt() -> void:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.dialog_text = tr("Delete medals, unlocks and saved run on this device?")
	dialog.confirmed.connect(func():
		if game.store.delete_local(): _initialize()
		else: _message(game.store.error_message))
	add_child(dialog)
	dialog.popup_centered()

func _message(message: String) -> void:
	modal = AcceptDialog.new()
	modal.dialog_text = message
	add_child(modal)
	modal.popup_centered()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if scene_state in ["round", "route", "draft"]: _pause()
		elif not scene_state in ["battle", "startup", "title"]: _home()
