extends Control

const SoldierVisualHelper = preload("res://src/scripts/soldier_visual_helper.gd")
const MenuControllerScript = preload("res://src/scripts/menu_controller.gd")

const GAME_TITLE := "OUTBREAK PROTOCOL: PAMPA"
const MAP_NAME := "ESTANCIA QUEIMADA"
const LOADING_SCENE := "res://src/scenes/loading_screen.tscn"
const LOGO_TEXTURE_PATH := "res://assets/ui/game-logo.png"
const MAP_LOGO_TEXTURE_PATH := "res://assets/ui/map-logo.png"
const BACKGROUND_TEXTURE_PATH := "res://assets/ui/Menu-background.png"
const SOLDIER_SCENE_PATH := "res://assets/_large_files/characters/Soldier/Ch35_nonPBR.fbx"
const SOLDIER_ANIM_LIBRARY := "menu"
const SOLDIER_MENU_ANIMS := {
	"idle": "res://assets/characters/Soldier/Standing W_Briefcase Idle.fbx",
	"stop_walk": "res://assets/characters/Soldier/No Weapon/Stop Walking.fbx"
}

const OPERATOR_FINAL_POSITION := Vector3(-2.25, 0.0, 0.0)
const OPERATOR_ENTRY_POSITION := Vector3(-2.25, 0.0, 1.15)
const STOP_WALK_TOTAL_FRAMES := 90.0
const STOP_WALK_FPS := 30.0
const OPERATOR_IDLE_BLEND_TIME := 0.5
const OPERATOR_IDLE_BLEND_LEAD := 0.34

const GOLD := Color(0.96, 0.77, 0.19, 1.0)
const TEXT_MAIN := Color(0.94, 0.95, 0.95, 1.0)
const TEXT_MUTED := Color(0.62, 0.66, 0.70, 1.0)
const PANEL_BG := Color(0.035, 0.043, 0.055, 0.68)
const PANEL_BORDER := Color(0.45, 0.48, 0.50, 0.34)

var graphics_controller = null
var operator_model: Node3D = null
var operator_anim_player: AnimationPlayer = null
var operator_viewport: SubViewport = null
var menu_preview_root: Node3D = null
var operator_anim_ok := false
var selected_mode := "solo"
var selected_map_name := MAP_NAME
var mission_mode_label: Label = null
var mode_cards: Dictionary = {}
var selected_map_label: Label = null
var map_info_panel: PanelContainer = null
var map_selector_panel: PanelContainer = null
var is_starting_game := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_create_background_layer()
	_create_3d_viewport()
	_create_ui_layer()
	_create_graphics_controller()
	GraphicsSettings.apply_to_viewport(get_viewport())
	GraphicsSettings.apply_to_menu_preview(menu_preview_root)
	_keep_menu_preview_live()
	_play_menu_fade_in()


func _create_background_layer() -> void:
	var background := TextureRect.new()
	background.name = "MenuBackground"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = load(BACKGROUND_TEXTURE_PATH)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.z_index = -10
	add_child(background)

	var shade := ColorRect.new()
	shade.name = "MenuBackgroundShade"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.28)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.z_index = -9
	add_child(shade)


func _play_menu_fade_in() -> void:
	var fade := ColorRect.new()
	fade.name = "MenuFadeIn"
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color.BLACK
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.z_index = 100
	add_child(fade)

	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 0.0, 0.45)
	tween.finished.connect(fade.queue_free)


func _create_3d_viewport() -> void:
	var viewport_container := SubViewportContainer.new()
	viewport_container.name = "OperatorViewportContainer"
	viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_container.stretch = true
	viewport_container.stretch_shrink = 1
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport_container.z_index = 0
	add_child(viewport_container)

	var viewport := SubViewport.new()
	viewport.name = "OperatorViewport"
	viewport.size = Vector2i(960, 540)
	viewport.disable_3d = false
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(viewport)
	operator_viewport = viewport

	var world_root := Node3D.new()
	world_root.name = "Menu3DWorld"
	viewport.add_child(world_root)
	menu_preview_root = world_root

	_create_environment(world_root)
	_create_lighting(world_root)
	_create_stage(world_root)
	_create_operator(world_root)
	_create_camera(world_root)


func _create_environment(root: Node3D) -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.12, 0.15, 0.22, 1.0)
	env.ambient_light_energy = 0.15
	env.fog_enabled = true
	env.fog_density = 0.010
	env.fog_light_color = Color(0.08, 0.10, 0.13, 1.0)
	env.glow_enabled = true
	env.glow_intensity = 0.16
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_set_if_property(env, "tonemap_exposure", 1.0)
	_set_if_property(env, "auto_exposure_enabled", false)
	world_env.environment = env
	root.add_child(world_env)


func _create_lighting(root: Node3D) -> void:
	var key_light := DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.visible = true
	key_light.rotation_degrees = Vector3(-30.0, 15.0, 0.0)
	key_light.light_energy = 2.6
	key_light.light_color = Color(0.92, 0.95, 1.0, 1.0)
	key_light.shadow_enabled = false
	root.add_child(key_light)

	var rim_light := SpotLight3D.new()
	rim_light.name = "RimLight"
	rim_light.visible = true
	rim_light.position = Vector3(-3.2, 2.4, 1.8)
	rim_light.light_color = Color(0.25, 0.55, 1.0, 1.0)
	rim_light.light_energy = 5.0
	rim_light.spot_range = 7.0
	rim_light.spot_angle = 45.0
	root.add_child(rim_light)
	rim_light.look_at(Vector3(-0.55, 1.1, 0.0), Vector3.UP)

	var warm_fill := OmniLight3D.new()
	warm_fill.name = "WarmPanelLight"
	warm_fill.visible = true
	warm_fill.position = Vector3(-1.6, 1.35, -1.9)
	warm_fill.light_color = Color(0.7, 0.85, 1.0, 1.0)
	warm_fill.light_energy = 0.5
	warm_fill.omni_range = 5.2
	root.add_child(warm_fill)

	var face_light := SpotLight3D.new()
	face_light.name = "FaceLight"
	face_light.visible = true
	face_light.position = Vector3(-1.25, 1.45, -2.35)
	face_light.light_color = Color(0.95, 0.98, 1.0, 1.0)
	face_light.light_energy = 3.5
	face_light.spot_range = 5.0
	face_light.spot_angle = 38.0
	root.add_child(face_light)
	face_light.look_at(Vector3(-2.2, 1.05, 0.0), Vector3.UP)


func _create_stage(_root: Node3D) -> void:
	pass


func _create_operator(root: Node3D) -> void:
	var packed_scene := load(SOLDIER_SCENE_PATH) as PackedScene
	if not packed_scene:
		push_warning("Menu principal nao carregou o Soldier: %s" % SOLDIER_SCENE_PATH)
		_create_operator_fallback(root)
		return

	operator_model = packed_scene.instantiate() as Node3D
	if not operator_model:
		push_warning("Menu principal recebeu Soldier que nao e Node3D: %s" % SOLDIER_SCENE_PATH)
		_create_operator_fallback(root)
		return

	operator_model.name = "MenuOperatorSoldier"
	operator_model.position = OPERATOR_ENTRY_POSITION
	operator_model.rotation.y = PI
	operator_model.scale = Vector3(1.05, 1.05, 1.05)
	root.add_child(operator_model)

	operator_anim_player = SoldierVisualHelper.setup_animation_library(
		operator_model,
		SOLDIER_MENU_ANIMS,
		SOLDIER_ANIM_LIBRARY
	)
	operator_anim_ok = SoldierVisualHelper.play_animation(operator_anim_player, SOLDIER_ANIM_LIBRARY, "stop_walk", 0.0)
	if not operator_anim_ok:
		operator_anim_ok = SoldierVisualHelper.play_animation(operator_anim_player, SOLDIER_ANIM_LIBRARY, "idle", 0.0)
		if not operator_anim_ok:
			push_warning("Menu principal nao conseguiu tocar animacoes do Soldier. Soldier foi ocultado para evitar T-pose.")
			operator_model.visible = false
			_create_operator_fallback(root)
			call_deferred("_suspend_menu_preview_render")
			return

		operator_model.position = OPERATOR_FINAL_POSITION
		call_deferred("_queue_menu_preview_frame")
		call_deferred("_suspend_menu_preview_render")
		return

	_play_operator_entry()


func _play_operator_entry() -> void:
	if not operator_model:
		return

	var entry_duration: float = _get_operator_entry_duration()
	_keep_menu_preview_live()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(operator_model, "position", OPERATOR_FINAL_POSITION, entry_duration)

	var transition_delay: float = maxf(entry_duration - OPERATOR_IDLE_BLEND_LEAD, 0.0)
	if transition_delay > 0.0:
		await get_tree().create_timer(transition_delay).timeout

	SoldierVisualHelper.play_animation(
		operator_anim_player,
		SOLDIER_ANIM_LIBRARY,
		"idle",
		OPERATOR_IDLE_BLEND_TIME
	)
	await tween.finished
	_suspend_menu_preview_render()


func _get_operator_entry_duration() -> float:
	if operator_anim_player:
		var animation: Animation = operator_anim_player.get_animation("%s/%s" % [SOLDIER_ANIM_LIBRARY, "stop_walk"])
		if animation:
			return animation.length

	return STOP_WALK_TOTAL_FRAMES / STOP_WALK_FPS


func _create_operator_fallback(root: Node3D) -> void:
	var fallback := MeshInstance3D.new()
	fallback.name = "OperatorFallbackSilhouette"
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.34
	mesh.height = 1.65
	fallback.mesh = mesh
	fallback.position = Vector3(-2.25, 0.88, 0.0)
	fallback.material_override = _make_material(Color(0.045, 0.050, 0.058, 1.0), 0.9)
	root.add_child(fallback)


func _create_camera(root: Node3D) -> void:
	var camera := Camera3D.new()
	camera.name = "MenuCamera"
	camera.position = Vector3(-1.45, 1.35, -2.1)
	camera.fov = 44.0
	camera.near = 0.05
	camera.far = 35.0
	camera.current = true
	root.add_child(camera)
	camera.look_at(Vector3(-2.15, 1.35, 0.0), Vector3.UP)


func _create_ui_layer() -> void:
	var overlay := Control.new()
	overlay.name = "MenuOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 2
	add_child(overlay)

	_create_top_row(overlay)
	_create_right_mode_cards(overlay)
	_create_mission_card(overlay)
	_create_bottom_left_info(overlay)
	_create_map_selector(overlay)
	_refresh_mode_cards()


func _create_top_row(parent: Control) -> void:
	# Card "OPERADOR" removido por decisao de design para dar destaque ao personagem.

	var logo_margin := MarginContainer.new()
	logo_margin.name = "LogoMargin"
	logo_margin.anchor_left = 1.0
	logo_margin.anchor_top = 0.0
	logo_margin.anchor_right = 1.0
	logo_margin.anchor_bottom = 0.0
	logo_margin.offset_left = -240.0
	logo_margin.offset_top = 16.0
	logo_margin.offset_right = -36.0
	logo_margin.offset_bottom = 116.0
	parent.add_child(logo_margin)
	var logo := TextureRect.new()
	logo.name = "TitleLogo"
	logo.texture = load(LOGO_TEXTURE_PATH)
	logo.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(200, 100)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_margin.add_child(logo)

	var nav_margin := MarginContainer.new()
	nav_margin.name = "TopNavMargin"
	nav_margin.anchor_left = 0.0
	nav_margin.anchor_top = 0.0
	nav_margin.anchor_right = 1.0
	nav_margin.anchor_bottom = 0.0
	nav_margin.offset_left = 388.0
	nav_margin.offset_top = 34.0
	nav_margin.offset_right = -356.0
	nav_margin.offset_bottom = 74.0
	parent.add_child(nav_margin)
	var nav_card := _create_panel_container(Vector2(0, 36), 0.58)
	nav_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_margin.add_child(nav_card)
	var nav_row := HBoxContainer.new()
	nav_row.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_row.add_theme_constant_override("separation", 8)
	nav_card.add_child(nav_row)
	for item in ["BASE", "ARMAMENTO", "MAPA", "PERSONAGEM"]:
		_add_nav_button(nav_row, item, Callable())
	_add_nav_button(nav_row, "CONFIGURAÇÕES", Callable(self, "_on_settings_pressed"))


func _create_right_mode_cards(parent: Control) -> void:
	var margin := MarginContainer.new()
	margin.name = "ModeCardsMargin"
	margin.anchor_left = 1.0
	margin.anchor_top = 0.0
	margin.anchor_right = 1.0
	margin.anchor_bottom = 0.0
	margin.offset_left = -336.0
	margin.offset_top = 160.0
	margin.offset_right = -36.0
	margin.offset_bottom = 400.0
	parent.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	_create_mode_card(column, "SOLO", MAP_NAME, "Mapa atual", true)
	_create_mode_card(column, "COOP", "EM BREVE", "Preparado para expansão", false)


func _create_mode_card(parent: BoxContainer, mode: String, region: String, detail: String, active: bool) -> void:
	var mode_id := mode.to_lower()
	var card := Panel.new()
	card.clip_contents = true
	card.custom_minimum_size = Vector2(300, 96 if active else 76)
	card.add_theme_stylebox_override("panel", _create_panel_style(0.72 if active else 0.50))
	card.modulate = Color(1, 1, 1, 1.0 if active else 0.62)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(_on_mode_card_input.bind(mode_id))
	parent.add_child(card)
	mode_cards[mode_id] = card

	if mode_id == "solo":
		var image := TextureRect.new()
		image.name = "MapLogo"
		image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image.texture = load(MAP_LOGO_TEXTURE_PATH)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		card.add_child(image)

		var overlay := ColorRect.new()
		overlay.name = "MapOverlay"
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.color = Color(0.0, 0.0, 0.0, 0.42)
		card.add_child(overlay)

	var content_margin := MarginContainer.new()
	content_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_margin.add_theme_constant_override("margin_left", 14)
	content_margin.add_theme_constant_override("margin_right", 14)
	content_margin.add_theme_constant_override("margin_top", 10)
	content_margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(content_margin)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	content_margin.add_child(box)
	_add_label(box, mode, 20, TEXT_MAIN if active else TEXT_MUTED)
	_add_label(box, region, 12, GOLD if active else TEXT_MUTED)
	_add_label(box, detail, 11, TEXT_MUTED)


func _create_mission_card(parent: Control) -> void:
	var margin := MarginContainer.new()
	margin.name = "MissionCardMargin"
	margin.anchor_left = 1.0
	margin.anchor_top = 1.0
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.offset_left = -360.0
	margin.offset_top = -180.0
	margin.offset_right = -36.0
	margin.offset_bottom = -34.0
	parent.add_child(margin)

	var panel := _create_panel_container(Vector2(324, 146), 0.74)
	margin.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	_add_label(box, GAME_TITLE, 14, TEXT_MAIN)
	mission_mode_label = _add_label(box, "", 12, TEXT_MUTED)
	_update_mission_card()

	var play_button := Button.new()
	play_button.text = "PLAY"
	play_button.custom_minimum_size = Vector2(300, 60)
	play_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_button.pressed.connect(_on_play_pressed)
	_apply_play_button_theme(play_button)
	box.add_child(play_button)


func _create_bottom_left_info(parent: Control) -> void:
	var margin := MarginContainer.new()
	margin.name = "BottomLeftInfo"
	margin.anchor_left = 0.0
	margin.anchor_top = 1.0
	margin.anchor_right = 0.0
	margin.anchor_bottom = 1.0
	margin.offset_left = 38.0
	margin.offset_top = -140.0
	margin.offset_right = 278.0
	margin.offset_bottom = -34.0
	parent.add_child(margin)

	map_info_panel = _create_panel_container(Vector2(240, 106), 0.58)
	map_info_panel.clip_contents = true
	map_info_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	map_info_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	map_info_panel.gui_input.connect(_on_map_panel_input)
	margin.add_child(map_info_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	map_info_panel.add_child(box)

	var map_logo := TextureRect.new()
	map_logo.name = "SelectedMapLogo"
	map_logo.texture = load(MAP_LOGO_TEXTURE_PATH)
	map_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	map_logo.custom_minimum_size = Vector2(204, 60)
	map_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(map_logo)

	selected_map_label = _add_label(box, "", 12, TEXT_MUTED)
	_update_map_ui()


func _create_map_selector(parent: Control) -> void:
	map_selector_panel = _create_panel_container(Vector2(260, 124), 0.74)
	map_selector_panel.name = "MapSelectorPanel"
	map_selector_panel.visible = false
	map_selector_panel.anchor_left = 0.0
	map_selector_panel.anchor_top = 1.0
	map_selector_panel.anchor_right = 0.0
	map_selector_panel.anchor_bottom = 1.0
	map_selector_panel.offset_left = 38.0
	map_selector_panel.offset_top = -274.0
	map_selector_panel.offset_right = 298.0
	map_selector_panel.offset_bottom = -150.0
	map_selector_panel.z_index = 5
	parent.add_child(map_selector_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	map_selector_panel.add_child(box)

	_add_label(box, "SELECIONAR MAPA", 12, TEXT_MAIN)

	var map_button := Button.new()
	map_button.text = MAP_NAME
	map_button.custom_minimum_size = Vector2(220, 42)
	map_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_button.pressed.connect(_on_map_selected.bind(MAP_NAME))
	_apply_small_menu_button_theme(map_button)
	box.add_child(map_button)

	_add_label(box, "Espaco reservado para outros mapas.", 11, TEXT_MUTED)


func _create_graphics_controller() -> void:
	graphics_controller = MenuControllerScript.new()
	graphics_controller.pause_enabled = false
	add_child(graphics_controller)
	if graphics_controller.has_method("set_menu_preview_root"):
		graphics_controller.set_menu_preview_root(menu_preview_root)


func _on_settings_pressed() -> void:
	if graphics_controller and graphics_controller.has_method("open_graphics_menu"):
		graphics_controller.open_graphics_menu()


func _on_play_pressed() -> void:
	if is_starting_game:
		return

	is_starting_game = true
	get_tree().paused = false
	await _fade_screen_to_black(0.24)
	get_tree().change_scene_to_file(LOADING_SCENE)


func _on_mode_card_input(event: InputEvent, mode: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected_mode = mode
		_refresh_mode_cards()
		_update_mission_card()


func _update_mission_card() -> void:
	if not mission_mode_label:
		return

	if selected_mode == "solo":
		mission_mode_label.text = "1 JOGADOR | %s" % selected_map_name
	else:
		mission_mode_label.text = "1-4 JOGADORES | %s" % selected_map_name


func _refresh_mode_cards() -> void:
	for mode_id in mode_cards.keys():
		var card: Panel = mode_cards[mode_id]
		if not card:
			continue
		var is_selected: bool = String(mode_id) == selected_mode
		card.add_theme_stylebox_override("panel", _create_panel_style(0.72 if is_selected else 0.50))
		card.modulate = Color(1, 1, 1, 1.0 if is_selected else 0.62)


func _update_map_ui() -> void:
	if selected_map_label:
		selected_map_label.text = "MAPA: %s" % selected_map_name
	_update_mission_card()


func _on_map_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if map_selector_panel:
			map_selector_panel.visible = not map_selector_panel.visible


func _on_map_selected(map_name: String) -> void:
	selected_map_name = map_name
	_update_map_ui()
	if map_selector_panel:
		map_selector_panel.visible = false


func _add_nav_button(parent: BoxContainer, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(90, 26)
	button.focus_mode = Control.FOCUS_NONE
	button.flat = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", TEXT_MUTED)
	button.add_theme_color_override("font_hover_color", TEXT_MAIN)
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if callback.is_valid():
		button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _add_label(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _create_panel_container(min_size: Vector2, alpha := 0.68) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	panel.add_theme_stylebox_override("panel", _create_panel_style(alpha))
	return panel


func _create_panel_style(alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(PANEL_BG.r, PANEL_BG.g, PANEL_BG.b, alpha)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = PANEL_BORDER
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 5)
	return style


func _apply_play_button_theme(button: Button) -> void:
	var normal := _create_button_style(GOLD, Color(1.0, 0.90, 0.38, 1.0))
	var hover := _create_button_style(Color(1.0, 0.84, 0.27, 1.0), Color(1.0, 0.96, 0.58, 1.0))
	var pressed := _create_button_style(Color(0.78, 0.58, 0.13, 1.0), Color(1.0, 0.84, 0.22, 1.0))
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_font_size_override("font_size", 30)
	button.add_theme_color_override("font_color", Color(0.09, 0.09, 0.08, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.04, 0.04, 0.04, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.0, 0.0, 0.0, 1.0))


func _apply_small_menu_button_theme(button: Button) -> void:
	var normal := _create_button_style(Color(0.10, 0.11, 0.12, 0.94), PANEL_BORDER)
	var hover := _create_button_style(Color(0.15, 0.16, 0.18, 0.98), GOLD)
	var pressed := _create_button_style(Color(0.18, 0.18, 0.19, 1.0), GOLD)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", TEXT_MAIN)
	button.add_theme_color_override("font_hover_color", TEXT_MAIN)
	button.add_theme_color_override("font_pressed_color", TEXT_MAIN)


func _create_button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = border
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	return style


func _make_material(color: Color, roughness: float) -> StandardMaterial3D:
	var unshaded_material := StandardMaterial3D.new()
	unshaded_material.albedo_color = color
	unshaded_material.roughness = roughness
	unshaded_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return unshaded_material


func _fade_screen_to_black(duration: float) -> void:
	var fade := ColorRect.new()
	fade.name = "MenuFadeOut"
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color.BLACK
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	fade.modulate = Color(1, 1, 1, 0)
	fade.z_index = 200
	add_child(fade)

	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, duration)
	await tween.finished


func _keep_menu_preview_live() -> void:
	if operator_viewport:
		operator_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _queue_menu_preview_frame() -> void:
	if operator_viewport and operator_viewport.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
		operator_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _suspend_menu_preview_render() -> void:
	if operator_viewport:
		operator_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_queue_menu_preview_frame()


func _set_if_property(object: Object, property_name: String, value: Variant) -> void:
	for property in object.get_property_list():
		if property.get("name", "") == property_name:
			object.set(property_name, value)
			return
