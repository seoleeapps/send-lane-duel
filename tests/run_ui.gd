extends SceneTree
const Main = preload("res://godot/ui/main.gd")
const Store = preload("res://adapters/save_store.gd")
var main: Main
var failed: int = 0
var assertions: int = 0

func _initialize() -> void:
	call_deferred("run_test")

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failed += 1
		printerr("FAIL UI " + message)

func click(button: Button) -> void:
	check(button != null and button.is_visible_in_tree() and not button.disabled, "button visible and enabled")
	if button == null: return
	var position: Vector2 = button.get_global_rect().get_center()
	if button.get_window() != root:
		position += Vector2(button.get_window().position)
	await click_at(position)

func click_at(position: Vector2, target: Viewport = null) -> void:
	if target == null: target = root
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = position
	target.push_input(motion, true)
	await process_frame
	for pressed in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		target.push_input(event, true)
		await process_frame

func drag(from: Vector2, to: Vector2) -> void:
	Input.set_emulate_touch_from_mouse(true)
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.position = from
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press, true)
	await process_frame
	var previous: Vector2 = from
	for i in range(1, 11):
		var position: Vector2 = from.lerp(to, i / 10.0)
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.position = position
		motion.relative = position - previous
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion, true)
		previous = position
		await process_frame
	press.position = to
	press.pressed = false
	root.push_input(press, true)
	for _i in range(3): await process_frame
	Input.set_emulate_touch_from_mouse(false)

func find_button(text: String) -> Button:
	for node in main.find_children("*", "Button", true, false):
		if node.text == text: return node
	return null

func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "res://docs/07-qa/captures/" + name + ".png"
	root.get_texture().get_image().save_png(path)
	print("CAPTURE " + name)

func check_bounds(node: Node) -> void:
	for child in node.get_children():
		if child is Button and child.is_visible_in_tree() and not child.get_parent() is ScrollContainer:
			var rect: Rect2 = child.get_global_rect()
			# Scrolling content is intentionally allowed outside the viewport.
			var parent: Node = child.get_parent()
			var scrolling: bool = false
			while parent != null:
				if parent is ScrollContainer: scrolling = true
				parent = parent.get_parent()
			if not scrolling:
				check(root.get_visible_rect().encloses(rect), "button in viewport: " + child.text)
		check_bounds(child)

func run_test() -> void:
	root.gui_embed_subwindows = true
	var save_path: String = "user://tests-ui/save.json"
	DirAccess.make_dir_recursive_absolute("user://tests-ui")
	Store.new(save_path).delete_local()
	DirAccess.make_dir_recursive_absolute("res://docs/07-qa/captures")
	main = Main.new()
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(main)
	for _i in range(10): await process_frame
	check(main.scene_state == "title", "ready title")
	await capture("title-en-360")
	await click(find_button("Start"))
	check(main.scene_state == "home", "start to home")
	main.game.start(20261010, "preset_a")
	main._show_run()
	await process_frame
	await click(find_button("Take this route"))
	check(main.scene_state == "round", "route to allocation")
	await RenderingServer.frame_post_draw
	await click_at(main.field.global_position + main.field.slot_rects[0].get_center())
	await process_frame
	check(main.find_children("*", "AcceptDialog", true, false).size() == 1, "slot opens build dialog")
	await capture("slot-dialog-en-360")
	await click(find_button(main.named(main.core.families["fam_pierce"]) + " · %d" % main.core.tier_cost("fam_pierce", 1)))
	check(main.plan.builds.size() == 1, "queued build")
	main._tab("workers")
	await process_frame
	await click(find_button("+"))
	check(main.plan.workers == 1, "worker mouse input")
	main._tab("defense")
	await process_frame
	check_bounds(main)
	await capture("round-en-360")
	await click(find_button("Deploy"))
	check(main.scene_state == "battle", "battle input")
	await capture("battle-en-360")
	await click(find_button("Skip"))
	check(main.scene_state == "summary", "skip to summary")
	await capture("summary-en-360")
	main._show_run()
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(430, 932)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		main.game.setting("language", "ko")
		TranslationServer.set_locale("ko")
		main.game.setting("large_text", true)
		main._round()
		for _i in range(4): await process_frame
		check_bounds(main)
		await capture("round-ko-large-%d" % dimensions.x)
	# Long lists must drag from their cards rather than requiring the scrollbar.
	root.size = Vector2i(360, 640)
	root.content_scale_size = root.size
	main.game.data.profile.highest_ascension = 5
	main.game.data.profile.unlocked = main.core.presets.keys()
	main._preparation()
	for _i in range(4): await process_frame
	var scroll: ScrollContainer = main.find_children("*", "ScrollContainer", true, false)[0]
	var from: Vector2 = scroll.global_position + Vector2(100, scroll.size.y * 0.8)
	await drag(from, from - Vector2(0, 250))
	check(scroll.scroll_vertical > 0, "formation list emulated touch drag")
	# Drive a complete winning reference run through battle and result controls.
	main.game.abandon()
	main.game.setting("language", "en")
	TranslationServer.set_locale("en")
	main.game.setting("large_text", false)
	var vector: Dictionary = preload("res://adapters/content_loader.gd").read_json("res://tests/fixtures/vectors.json").runs[0]
	main.game.start(vector.seed, vector.preset, vector.ascension)
	for step in vector.steps:
		main._show_run()
		await process_frame
		if step.step == "round":
			main.plan = step.action.duplicate(true)
			main._round()
			await process_frame
			await click(find_button("Deploy"))
			await click(find_button("Skip"))
			await click(find_button("Continue"))
		else: main._perform(step)
	check(main.scene_state == "settlement" and main.game.run.score() == vector.expect.score, "full UI run reaches matching settlement")
	await capture("settlement-en-360")
	await click(find_button("Return home"))
	check(main.scene_state == "home" and main.game.run == null, "settlement closes to home")
	main.queue_free()
	await process_frame
	Store.new(save_path).delete_local()
	print("UI checks=%d failures=%d renderer=%s" % [assertions, failed, RenderingServer.get_current_rendering_method()])
	quit(0 if failed == 0 else 1)
