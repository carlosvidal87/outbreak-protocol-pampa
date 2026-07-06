extends Control

const GraphicsMenuScene = preload("res://src/scenes/graphics_menu.tscn")

@export var pause_enabled := true

var pause_menu: ColorRect = null
var graphics_menu: Control = null
var graphics_return_menu := "pause"
var menu_preview_root: Node = null
var is_changing_scene := false


func _init() -> void:
	process_mode = PROCESS_MODE_ALWAYS


func _ready() -> void:
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if pause_enabled:
		_create_pause_menu()
	_create_graphics_menu()


func _input(event: InputEvent) -> void:
	if is_changing_scene:
		return

	if graphics_menu and graphics_menu.visible:
		if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
			get_viewport().set_input_as_handled()
			_close_graphics_menu()
		return

	if not pause_enabled:
		return

	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		if pause_menu and pause_menu.visible:
			resume_game()
		else:
			pause_game()


func set_menu_preview_root(root: Node) -> void:
	menu_preview_root = root
	if graphics_menu and graphics_menu.has_method("set_preview_root"):
		graphics_menu.call("set_preview_root", menu_preview_root)


func pause_game() -> void:
	if not pause_enabled or is_changing_scene:
		return

	get_tree().paused = true
	if pause_menu:
		pause_menu.visible = true
	if graphics_menu:
		graphics_menu.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func resume_game() -> void:
	if is_changing_scene:
		return

	get_tree().paused = false
	if pause_menu:
		pause_menu.visible = false
	if graphics_menu:
		graphics_menu.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func open_graphics_menu() -> void:
	_open_graphics_menu("external")


func _open_graphics_menu(return_menu: String) -> void:
	if is_changing_scene:
		return

	graphics_return_menu = return_menu
	if pause_menu:
		pause_menu.visible = false
	if graphics_menu and graphics_menu.has_method("open_menu"):
		graphics_menu.call("open_menu", return_menu)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _close_graphics_menu() -> void:
	if graphics_menu and graphics_menu.has_method("close_menu"):
		graphics_menu.call("close_menu")


func _on_graphics_menu_closed() -> void:
	if is_changing_scene or not is_inside_tree():
		return

	if graphics_return_menu == "pause" and pause_enabled and get_tree().paused and pause_menu:
		pause_menu.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _on_restart_pressed() -> void:
	is_changing_scene = true
	_hide_all_menus()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	is_changing_scene = true
	_hide_all_menus()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/scenes/main_menu.tscn")


func _on_quit_pressed() -> void:
	is_changing_scene = true
	get_tree().quit()


func _hide_all_menus() -> void:
	if pause_menu:
		pause_menu.visible = false
	if graphics_menu:
		graphics_menu.visible = false


func _create_pause_menu() -> void:
	pause_menu = _create_fullscreen_panel(Color(0.02, 0.02, 0.02, 0.8))
	pause_menu.visible = false
	add_child(pause_menu)

	var container := _create_center_container(pause_menu, Vector2(320, 480))

	var title := Label.new()
	title.text = "PAUSADO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	container.add_child(title)

	_add_spacer(container, 36)

	var styles := _make_gray_button_styles()
	_add_menu_button(container, "RETOMAR JOGO", styles, resume_game, Vector2(280, 52))
	_add_spacer(container, 14)
	_add_menu_button(container, "RECOMECAR", styles, _on_restart_pressed, Vector2(280, 52))
	_add_spacer(container, 14)
	_add_menu_button(container, "GRAFICOS", styles, _open_graphics_menu.bind("pause"), Vector2(280, 52))
	_add_spacer(container, 14)
	_add_menu_button(container, "MENU PRINCIPAL", styles, _on_menu_pressed, Vector2(280, 52))
	_add_spacer(container, 14)
	_add_menu_button(container, "SAIR", styles, _on_quit_pressed, Vector2(280, 52))


func _create_graphics_menu() -> void:
	graphics_menu = GraphicsMenuScene.instantiate()
	graphics_menu.visible = false
	graphics_menu.connect("closed", Callable(self, "_on_graphics_menu_closed"))
	add_child(graphics_menu)

	if menu_preview_root and graphics_menu.has_method("set_preview_root"):
		graphics_menu.call("set_preview_root", menu_preview_root)


func _create_fullscreen_panel(color: Color) -> ColorRect:
	var panel := ColorRect.new()
	panel.color = color
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	return panel


func _create_center_container(parent: Control, min_size: Vector2) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)

	var container := VBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.custom_minimum_size = min_size
	center.add_child(container)
	return container


func _add_spacer(container: BoxContainer, height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	container.add_child(spacer)


func _add_menu_button(container: BoxContainer, text: String, styles: Dictionary, callback: Callable, min_size := Vector2(250, 50)) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	_apply_button_theme(btn, styles["normal"], styles["hover"], styles["pressed"])
	btn.pressed.connect(callback)
	container.add_child(btn)
	return btn


func _make_gray_button_styles() -> Dictionary:
	return {
		"normal": _create_button_style(Color(0.12, 0.12, 0.12, 0.9), Color(0.4, 0.4, 0.4, 0.8)),
		"hover": _create_button_style(Color(0.2, 0.2, 0.2, 0.95), Color(0.8, 0.8, 0.8, 1.0)),
		"pressed": _create_button_style(Color(0.3, 0.3, 0.3, 1.0), Color(1.0, 1.0, 1.0, 1.0))
	}


func _create_button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = border
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style


func _apply_button_theme(btn: Button, normal: StyleBoxFlat, hover: StyleBoxFlat, pressed: StyleBoxFlat) -> void:
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.5, 0.5))
