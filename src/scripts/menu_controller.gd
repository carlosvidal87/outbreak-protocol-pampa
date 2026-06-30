extends Control

@export var pause_enabled := true

var pause_menu: ColorRect
var graphics_menu: ColorRect
var graphics_status_label: Label
var graphics_return_menu := "pause"

const GRAPHICS_CONFIG_PATH := "user://graphics_settings.cfg"
const GRAPHICS_PRESETS := {
	"low": {
		"label": "PC FRACO",
		"scale": 0.65,
		"msaa": Viewport.MSAA_DISABLED,
		"screen_space_aa": Viewport.SCREEN_SPACE_AA_DISABLED,
		"taa": false,
		"ssao": false,
		"glow": false,
		"fog": false,
		"shadows": false,
		"camera_far": 250.0,
		"light_range_mult": 0.65
	},
	"medium": {
		"label": "EQUILIBRADO",
		"scale": 0.85,
		"msaa": Viewport.MSAA_DISABLED,
		"screen_space_aa": Viewport.SCREEN_SPACE_AA_FXAA,
		"taa": false,
		"ssao": false,
		"glow": true,
		"fog": true,
		"shadows": false,
		"camera_far": 400.0,
		"light_range_mult": 0.85
	},
	"high": {
		"label": "QUALIDADE",
		"scale": 1.0,
		"msaa": Viewport.MSAA_2X,
		"screen_space_aa": Viewport.SCREEN_SPACE_AA_FXAA,
		"taa": true,
		"ssao": true,
		"glow": true,
		"fog": true,
		"shadows": true,
		"camera_far": 600.0,
		"light_range_mult": 1.0
	}
}


func _init() -> void:
	process_mode = PROCESS_MODE_ALWAYS


func _ready() -> void:
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_create_pause_menu()
	_create_graphics_menu()
	_load_graphics_preset()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		if graphics_menu.visible:
			get_viewport().set_input_as_handled()
			_close_graphics_menu()
			return

		if not pause_enabled:
			return

		get_viewport().set_input_as_handled()
		if pause_menu.visible:
			resume_game()
		else:
			pause_game()


func _create_pause_menu() -> void:
	pause_menu = _create_fullscreen_panel(Color(0.02, 0.02, 0.02, 0.8))
	pause_menu.visible = false
	add_child(pause_menu)

	var container := _create_center_container(pause_menu, Vector2(300, 470))

	var title := Label.new()
	title.text = "PAUSADO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	container.add_child(title)

	_add_spacer(container, 40)

	var styles := _make_gray_button_styles()
	_add_menu_button(container, "RETOMAR JOGO", styles, resume_game)
	_add_spacer(container, 15)
	_add_menu_button(container, "RECOMECAR", styles, _on_restart_pressed)
	_add_spacer(container, 15)
	_add_menu_button(container, "GRAFICOS", styles, _open_graphics_menu.bind("pause"))
	_add_spacer(container, 15)
	_add_menu_button(container, "MENU PRINCIPAL", styles, _on_menu_pressed)
	_add_spacer(container, 15)
	_add_menu_button(container, "SAIR", styles, _on_quit_pressed)


func _create_graphics_menu() -> void:
	graphics_menu = _create_fullscreen_panel(Color(0.02, 0.02, 0.02, 0.88))
	graphics_menu.visible = false
	add_child(graphics_menu)

	var container := _create_center_container(graphics_menu, Vector2(340, 460))

	var title := Label.new()
	title.text = "GRAFICOS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	container.add_child(title)

	graphics_status_label = Label.new()
	graphics_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	graphics_status_label.custom_minimum_size = Vector2(320, 48)
	graphics_status_label.add_theme_font_size_override("font_size", 18)
	graphics_status_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	container.add_child(graphics_status_label)

	_add_spacer(container, 20)

	var styles := _make_gray_button_styles()
	for preset_id in ["low", "medium", "high"]:
		_add_menu_button(container, GRAPHICS_PRESETS[preset_id]["label"], styles, _on_graphics_preset_pressed.bind(preset_id), Vector2(280, 50))
		_add_spacer(container, 12)

	_add_menu_button(container, "VOLTAR", styles, _close_graphics_menu, Vector2(280, 50))


func pause_game() -> void:
	if not pause_enabled:
		return
	get_tree().paused = true
	pause_menu.visible = true
	graphics_menu.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func resume_game() -> void:
	get_tree().paused = false
	pause_menu.visible = false
	graphics_menu.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/scenes/main_menu.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _open_graphics_menu(return_menu: String) -> void:
	graphics_return_menu = return_menu
	pause_menu.visible = false
	graphics_menu.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func open_graphics_menu() -> void:
	_open_graphics_menu("external")


func _close_graphics_menu() -> void:
	graphics_menu.visible = false
	if graphics_return_menu == "pause":
		pause_menu.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _on_graphics_preset_pressed(preset_id: String) -> void:
	_apply_graphics_preset(preset_id)
	_save_graphics_preset(preset_id)


func _load_graphics_preset() -> void:
	var config := ConfigFile.new()
	var err := config.load(GRAPHICS_CONFIG_PATH)
	var preset_id := "low"
	if err == OK:
		preset_id = str(config.get_value("graphics", "preset", "low"))
	if not GRAPHICS_PRESETS.has(preset_id):
		preset_id = "low"
	_apply_graphics_preset(preset_id)


func _save_graphics_preset(preset_id: String) -> void:
	var config := ConfigFile.new()
	config.set_value("graphics", "preset", preset_id)
	config.save(GRAPHICS_CONFIG_PATH)


func _apply_graphics_preset(preset_id: String) -> void:
	if not GRAPHICS_PRESETS.has(preset_id):
		return

	var preset: Dictionary = GRAPHICS_PRESETS[preset_id]
	var viewport := get_viewport()
	viewport.scaling_3d_scale = preset["scale"]
	viewport.msaa_3d = preset["msaa"]
	viewport.screen_space_aa = preset["screen_space_aa"]
	viewport.use_taa = preset["taa"]

	var camera := viewport.get_camera_3d()
	if camera:
		camera.far = preset["camera_far"]

	var scene := get_tree().current_scene
	if scene:
		_apply_graphics_to_node(scene, preset)

	if graphics_status_label:
		graphics_status_label.text = "Preset atual: %s" % preset["label"]


func _apply_graphics_to_node(node: Node, preset: Dictionary) -> void:
	if node is Light3D:
		var light := node as Light3D
		light.shadow_enabled = preset["shadows"]
		if light is OmniLight3D:
			light.omni_range = 3.0 * float(preset["light_range_mult"])
		elif light is SpotLight3D:
			light.spot_range = 25.0 * float(preset["light_range_mult"])
		elif light is DirectionalLight3D:
			light.directional_shadow_max_distance = preset["camera_far"]

	if node is WorldEnvironment:
		var world_env := node as WorldEnvironment
		if world_env.environment:
			world_env.environment.ssao_enabled = preset["ssao"]
			world_env.environment.glow_enabled = preset["glow"]
			world_env.environment.fog_enabled = preset["fog"]

	for child in node.get_children():
		_apply_graphics_to_node(child, preset)


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


func _make_red_button_styles() -> Dictionary:
	return {
		"normal": _create_button_style(Color(0.12, 0.12, 0.12, 0.9), Color(0.5, 0.05, 0.05, 0.8)),
		"hover": _create_button_style(Color(0.25, 0.05, 0.05, 0.95), Color(0.9, 0.1, 0.1, 1.0)),
		"pressed": _create_button_style(Color(0.4, 0.05, 0.05, 1.0), Color(1.0, 0.2, 0.2, 1.0))
	}


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
