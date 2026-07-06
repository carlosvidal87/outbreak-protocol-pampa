extends Control

signal closed

const GOLD := Color(0.96, 0.77, 0.19, 1.0)
const TEXT_MAIN := Color(0.94, 0.95, 0.95, 1.0)
const TEXT_MUTED := Color(0.62, 0.66, 0.70, 1.0)
const PANEL_BG := Color(0.035, 0.043, 0.055, 0.94)
const PANEL_BORDER := Color(0.45, 0.48, 0.50, 0.34)
const OVERLAY_COLOR := Color(0.0, 0.0, 0.0, 0.72)
const CATEGORY_KEYS := ["display", "render", "lighting", "post", "advanced"]
const CATEGORY_LABELS := {
	"display": "TELA",
	"render": "RENDER",
	"lighting": "SOMBRAS E LUZ",
	"post": "POS-PROCESSAMENTO",
	"advanced": "AVANCADO"
}
const FPS_LIMIT_OPTIONS := [0, 30, 60, 120, 144, 240]

var preview_root: Node = null
var return_context := "external"
var selected_category := "display"
var live_snapshot: Dictionary = {}
var draft_settings: Dictionary = {}
var pending_confirmation_snapshot: Dictionary = {}
var pending_confirmation_seconds := 0
var updating_ui := false

var category_buttons: Dictionary = {}
var pages: Dictionary = {}
var preset_buttons: Dictionary = {}
var preset_status_label: Label = null
var summary_label: Label = null
var confirmation_overlay: ColorRect = null
var confirmation_label: Label = null
var confirmation_timer: Timer = null

var window_mode_select: OptionButton = null
var vsync_select: OptionButton = null
var fps_limit_select: OptionButton = null
var scale_slider: HSlider = null
var scale_value_label: Label = null
var aa_mode_select: OptionButton = null
var taa_toggle: CheckBox = null
var shadow_quality_select: OptionButton = null
var shadow_distance_slider: HSlider = null
var shadow_distance_value_label: Label = null
var flashlight_shadows_toggle: CheckBox = null
var fog_toggle: CheckBox = null
var glow_toggle: CheckBox = null
var ssao_toggle: CheckBox = null
var camera_far_slider: HSlider = null
var camera_far_value_label: Label = null
var terrain_detail_slider: HSlider = null
var terrain_detail_value_label: Label = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_create_layout()
	_refresh_from_live_settings()


func set_preview_root(root: Node) -> void:
	preview_root = root


func open_menu(context: String = "external") -> void:
	return_context = context
	_refresh_from_live_settings()
	visible = true
	show()
	_select_category(selected_category)
	if category_buttons.has(selected_category):
		(category_buttons[selected_category] as Button).grab_focus()


func close_menu() -> void:
	if confirmation_overlay and confirmation_overlay.visible:
		_rollback_pending_display_change()

	visible = false
	hide()
	closed.emit()


func _refresh_from_live_settings() -> void:
	if confirmation_timer:
		confirmation_timer.stop()
	if confirmation_overlay:
		confirmation_overlay.visible = false
	pending_confirmation_snapshot.clear()
	live_snapshot = GraphicsSettings.get_settings()
	draft_settings = live_snapshot.duplicate(true)
	_refresh_controls_from_draft()
	_refresh_summary()


func _create_layout() -> void:
	var overlay := ColorRect.new()
	overlay.name = "GraphicsOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = OVERLAY_COLOR
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var shell := PanelContainer.new()
	shell.custom_minimum_size = Vector2(1120, 660)
	shell.add_theme_stylebox_override("panel", _create_panel_style(0.98, 1.0, 18))
	center.add_child(shell)

	var shell_margin := MarginContainer.new()
	shell_margin.add_theme_constant_override("margin_left", 18)
	shell_margin.add_theme_constant_override("margin_right", 18)
	shell_margin.add_theme_constant_override("margin_top", 18)
	shell_margin.add_theme_constant_override("margin_bottom", 18)
	shell.add_child(shell_margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	shell_margin.add_child(row)

	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size = Vector2(220, 0)
	sidebar.add_theme_constant_override("separation", 10)
	row.add_child(sidebar)

	var sidebar_title := Label.new()
	sidebar_title.text = "CONFIGURACOES"
	sidebar_title.add_theme_font_size_override("font_size", 18)
	sidebar_title.add_theme_color_override("font_color", TEXT_MUTED)
	sidebar.add_child(sidebar_title)

	for category_key in CATEGORY_KEYS:
		var button := Button.new()
		button.text = CATEGORY_LABELS[category_key]
		button.custom_minimum_size = Vector2(0, 46)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_on_category_pressed.bind(category_key))
		sidebar.add_child(button)
		category_buttons[category_key] = button

	var content_column := VBoxContainer.new()
	content_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_column.add_theme_constant_override("separation", 14)
	row.add_child(content_column)

	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	content_column.add_child(header)

	var title := Label.new()
	title.text = "GRAFICOS"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", TEXT_MAIN)
	header.add_child(title)

	summary_label = Label.new()
	summary_label.add_theme_font_size_override("font_size", 16)
	summary_label.add_theme_color_override("font_color", TEXT_MUTED)
	header.add_child(summary_label)

	var preset_card := PanelContainer.new()
	preset_card.add_theme_stylebox_override("panel", _create_panel_style(0.74, 1.0, 12))
	content_column.add_child(preset_card)

	var preset_margin := MarginContainer.new()
	preset_margin.add_theme_constant_override("margin_left", 16)
	preset_margin.add_theme_constant_override("margin_right", 16)
	preset_margin.add_theme_constant_override("margin_top", 12)
	preset_margin.add_theme_constant_override("margin_bottom", 12)
	preset_card.add_child(preset_margin)

	var preset_column := VBoxContainer.new()
	preset_column.add_theme_constant_override("separation", 10)
	preset_margin.add_child(preset_column)

	var preset_title := Label.new()
	preset_title.text = "PRESETS RAPIDOS"
	preset_title.add_theme_font_size_override("font_size", 15)
	preset_title.add_theme_color_override("font_color", TEXT_MAIN)
	preset_column.add_child(preset_title)

	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 10)
	preset_column.add_child(preset_row)

	for preset_id in ["low", "medium", "high"]:
		var button := Button.new()
		button.text = String(GraphicsSettings.get_available_presets().get(preset_id, preset_id))
		button.custom_minimum_size = Vector2(180, 44)
		button.pressed.connect(_on_preset_pressed.bind(preset_id))
		preset_row.add_child(button)
		preset_buttons[preset_id] = button

	preset_status_label = Label.new()
	preset_status_label.add_theme_font_size_override("font_size", 14)
	preset_status_label.add_theme_color_override("font_color", TEXT_MUTED)
	preset_column.add_child(preset_status_label)

	var pages_host := MarginContainer.new()
	pages_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pages_host.add_theme_constant_override("margin_right", 4)
	content_column.add_child(pages_host)

	var pages_stack := VBoxContainer.new()
	pages_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pages_stack.add_theme_constant_override("separation", 10)
	pages_host.add_child(pages_stack)

	var display_page := _create_page(pages_stack, "display")
	var render_page := _create_page(pages_stack, "render")
	var lighting_page := _create_page(pages_stack, "lighting")
	var post_page := _create_page(pages_stack, "post")
	var advanced_page := _create_page(pages_stack, "advanced")

	_build_display_page(display_page)
	_build_render_page(render_page)
	_build_lighting_page(lighting_page)
	_build_post_page(post_page)
	_build_advanced_page(advanced_page)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 10)
	content_column.add_child(footer)

	var reset_button := Button.new()
	reset_button.text = "RESTAURAR PADRAO"
	reset_button.custom_minimum_size = Vector2(210, 46)
	reset_button.pressed.connect(_on_reset_pressed)
	_apply_secondary_button_theme(reset_button)
	footer.add_child(reset_button)

	var cancel_button := Button.new()
	cancel_button.text = "CANCELAR"
	cancel_button.custom_minimum_size = Vector2(160, 46)
	cancel_button.pressed.connect(close_menu)
	_apply_secondary_button_theme(cancel_button)
	footer.add_child(cancel_button)

	var apply_button := Button.new()
	apply_button.text = "APLICAR"
	apply_button.custom_minimum_size = Vector2(180, 46)
	apply_button.pressed.connect(_on_apply_pressed)
	_apply_primary_button_theme(apply_button)
	footer.add_child(apply_button)

	_create_confirmation_overlay()


func _create_page(parent: Control, category_key: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.visible = false
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 10)
	parent.add_child(page)
	pages[category_key] = page
	return page


func _build_display_page(parent: VBoxContainer) -> void:
	window_mode_select = _create_option_row(
		parent,
		"MODO DE TELA",
		"Troca entre janela e tela cheia. Alteracao sensivel pede confirmacao.",
		[
			{"label": "Janela", "value": DisplayServer.WINDOW_MODE_WINDOWED},
			{"label": "Tela cheia", "value": DisplayServer.WINDOW_MODE_FULLSCREEN}
		],
		_on_window_mode_changed
	)

	vsync_select = _create_option_row(
		parent,
		"VSYNC",
		"Sincroniza a imagem com o monitor e ajuda a reduzir tearing.",
		[
			{"label": "Desligado", "value": DisplayServer.VSYNC_DISABLED},
			{"label": "Ligado", "value": DisplayServer.VSYNC_ENABLED}
		],
		_on_vsync_changed
	)

	var fps_options: Array[Dictionary] = []
	for fps_limit in FPS_LIMIT_OPTIONS:
		var label := "Ilimitado" if fps_limit == 0 else "%d FPS" % fps_limit
		fps_options.append({"label": label, "value": fps_limit})
	fps_limit_select = _create_option_row(
		parent,
		"LIMITE DE FPS",
		"Controla o teto de quadros para reduzir consumo e oscilacao.",
		fps_options,
		_on_fps_limit_changed
	)


func _build_render_page(parent: VBoxContainer) -> void:
	var scale_row := _create_slider_row(
		parent,
		"ESCALA 3D",
		"Baixa a resolucao interna do 3D para aliviar GPU sem afetar a UI.",
		0.5,
		1.0,
		0.05,
		_on_scale_changed
	)
	scale_slider = scale_row["slider"]
	scale_value_label = scale_row["value_label"]

	aa_mode_select = _create_option_row(
		parent,
		"ANTI-ALIASING",
		"Define o metodo principal para suavizar serrilhado.",
		[
			{"label": "Desligado", "value": "disabled"},
			{"label": "FXAA", "value": "fxaa"},
			{"label": "MSAA 2x", "value": "msaa_2x"},
			{"label": "MSAA 4x", "value": "msaa_4x"}
		],
		_on_aa_mode_changed
	)

	taa_toggle = _create_toggle_row(
		parent,
		"TAA",
		"Suaviza aliasing temporal, com custo extra e leve arrasto em movimento.",
		_on_taa_toggled
	)


func _build_lighting_page(parent: VBoxContainer) -> void:
	shadow_quality_select = _create_option_row(
		parent,
		"QUALIDADE DE SOMBRAS",
		"Controla se sombras ficam desligadas, rigidas ou mais suaves.",
		[
			{"label": "Desligado", "value": "off"},
			{"label": "Padrao", "value": "hard"},
			{"label": "Suave", "value": "soft"}
		],
		_on_shadow_quality_changed
	)

	var shadow_distance_row := _create_slider_row(
		parent,
		"DISTANCIA DE SOMBRAS",
		"Define ate onde a sombra direcional sera calculada no mapa.",
		80.0,
		600.0,
		20.0,
		_on_shadow_distance_changed
	)
	shadow_distance_slider = shadow_distance_row["slider"]
	shadow_distance_value_label = shadow_distance_row["value_label"]

	flashlight_shadows_toggle = _create_toggle_row(
		parent,
		"SOMBRAS DA LANTERNA",
		"Deixa a lanterna do player projetar sombra real. Custa GPU.",
		_on_flashlight_shadows_toggled
	)


func _build_post_page(parent: VBoxContainer) -> void:
	fog_toggle = _create_toggle_row(
		parent,
		"NEBLINA",
		"Ativa a neblina atmosferica do mapa.",
		_on_fog_toggled
	)

	glow_toggle = _create_toggle_row(
		parent,
		"GLOW",
		"Realca luzes fortes e destaques visuais.",
		_on_glow_toggled
	)

	ssao_toggle = _create_toggle_row(
		parent,
		"SSAO",
		"Aumenta profundidade de contato entre objetos e solo.",
		_on_ssao_toggled
	)


func _build_advanced_page(parent: VBoxContainer) -> void:
	var camera_far_row := _create_slider_row(
		parent,
		"DISTANCIA DE RENDER",
		"Controla o alcance maximo das cameras do gameplay.",
		200.0,
		650.0,
		25.0,
		_on_camera_far_changed
	)
	camera_far_slider = camera_far_row["slider"]
	camera_far_value_label = camera_far_row["value_label"]

	var terrain_detail_row := _create_slider_row(
		parent,
		"DETALHE DO TERRENO",
		"Define ate onde a camada de detalhes do HTerrain permanece visivel.",
		120.0,
		550.0,
		10.0,
		_on_terrain_detail_changed
	)
	terrain_detail_slider = terrain_detail_row["slider"]
	terrain_detail_value_label = terrain_detail_row["value_label"]


func _create_confirmation_overlay() -> void:
	confirmation_overlay = ColorRect.new()
	confirmation_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirmation_overlay.color = Color(0.0, 0.0, 0.0, 0.76)
	confirmation_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	confirmation_overlay.visible = false
	confirmation_overlay.z_index = 30
	add_child(confirmation_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirmation_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 220)
	panel.add_theme_stylebox_override("panel", _create_panel_style(0.98, 1.0, 16))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var title := Label.new()
	title.text = "CONFIRMAR ALTERACAO"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", TEXT_MAIN)
	column.add_child(title)

	confirmation_label = Label.new()
	confirmation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirmation_label.add_theme_font_size_override("font_size", 16)
	confirmation_label.add_theme_color_override("font_color", TEXT_MUTED)
	column.add_child(confirmation_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 10)
	column.add_child(actions)

	var rollback_button := Button.new()
	rollback_button.text = "REVERTER"
	rollback_button.custom_minimum_size = Vector2(160, 42)
	rollback_button.pressed.connect(_rollback_pending_display_change)
	_apply_secondary_button_theme(rollback_button)
	actions.add_child(rollback_button)

	var confirm_button := Button.new()
	confirm_button.text = "MANTER"
	confirm_button.custom_minimum_size = Vector2(160, 42)
	confirm_button.pressed.connect(_confirm_pending_display_change)
	_apply_primary_button_theme(confirm_button)
	actions.add_child(confirm_button)

	confirmation_timer = Timer.new()
	confirmation_timer.one_shot = false
	confirmation_timer.wait_time = 1.0
	confirmation_timer.timeout.connect(_on_confirmation_tick)
	add_child(confirmation_timer)


func _create_option_row(parent: VBoxContainer, title: String, description: String, options: Array[Dictionary], callback: Callable) -> OptionButton:
	var row := _create_setting_row(parent, title, description)
	var option_button := OptionButton.new()
	option_button.custom_minimum_size = Vector2(300, 40)
	option_button.focus_mode = Control.FOCUS_ALL
	for option in options:
		option_button.add_item(str(option["label"]))
		option_button.set_item_metadata(option_button.item_count - 1, option["value"])
	option_button.item_selected.connect(callback)
	_apply_option_button_theme(option_button)
	row["control_holder"].add_child(option_button)
	return option_button


func _create_toggle_row(parent: VBoxContainer, title: String, description: String, callback: Callable) -> CheckBox:
	var row := _create_setting_row(parent, title, description)
	var toggle := CheckBox.new()
	toggle.text = "Ativado"
	toggle.toggled.connect(callback)
	toggle.add_theme_font_size_override("font_size", 15)
	toggle.add_theme_color_override("font_color", TEXT_MAIN)
	row["control_holder"].add_child(toggle)
	return toggle


func _create_slider_row(parent: VBoxContainer, title: String, description: String, min_value: float, max_value: float, step: float, callback: Callable) -> Dictionary:
	var row := _create_setting_row(parent, title, description)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(300, 34)
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value_changed.connect(callback)
	row["value_label"].visible = true
	row["control_holder"].add_child(slider)
	return {"slider": slider, "value_label": row["value_label"]}


func _create_setting_row(parent: VBoxContainer, title: String, description: String) -> Dictionary:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _create_panel_style(0.72, 1.0, 10))
	parent.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)

	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_theme_constant_override("separation", 4)
	row.add_child(text_column)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", TEXT_MAIN)
	text_column.add_child(title_label)

	var description_label := Label.new()
	description_label.text = description
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("font_size", 13)
	description_label.add_theme_color_override("font_color", TEXT_MUTED)
	text_column.add_child(description_label)

	var control_holder := VBoxContainer.new()
	control_holder.custom_minimum_size = Vector2(320, 0)
	control_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	control_holder.add_theme_constant_override("separation", 6)
	row.add_child(control_holder)

	var value_label := Label.new()
	value_label.visible = false
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 13)
	value_label.add_theme_color_override("font_color", GOLD)
	control_holder.add_child(value_label)

	return {"control_holder": control_holder, "value_label": value_label}


func _on_category_pressed(category_key: String) -> void:
	_select_category(category_key)


func _select_category(category_key: String) -> void:
	selected_category = category_key
	for key in pages.keys():
		pages[key].visible = String(key) == category_key
	for key in category_buttons.keys():
		_apply_category_button_theme(category_buttons[key], String(key) == category_key)


func _on_preset_pressed(preset_id: String) -> void:
	var next_settings := GraphicsSettings.get_preset_settings(preset_id)
	next_settings["display"] = draft_settings.get("display", {}).duplicate(true)
	draft_settings = next_settings
	draft_settings["preset_id"] = preset_id
	_refresh_controls_from_draft()
	_refresh_summary()


func _on_reset_pressed() -> void:
	_on_preset_pressed(GraphicsSettings.get_default_preset_id())


func _on_apply_pressed() -> void:
	var previous_live := GraphicsSettings.get_settings()
	var needs_confirmation := int(previous_live["display"]["window_mode"]) != int(draft_settings["display"]["window_mode"])

	_apply_snapshot_to_live_settings(draft_settings)
	_apply_live_settings_to_current_context()

	if needs_confirmation:
		pending_confirmation_snapshot = previous_live
		_show_confirmation_overlay()
		return

	_save_live_settings_snapshot()


func _apply_snapshot_to_live_settings(snapshot: Dictionary) -> void:
	for path in GraphicsSettings.get_schema_paths():
		GraphicsSettings.set_setting(path, _get_nested_value(snapshot, path))


func _show_confirmation_overlay() -> void:
	pending_confirmation_seconds = 10
	confirmation_overlay.visible = true
	_update_confirmation_text()
	confirmation_timer.start()


func _confirm_pending_display_change() -> void:
	if confirmation_timer:
		confirmation_timer.stop()
	confirmation_overlay.visible = false
	pending_confirmation_snapshot.clear()
	_save_live_settings_snapshot()


func _save_live_settings_snapshot() -> void:
	var saved: bool = GraphicsSettings.save_settings()
	live_snapshot = GraphicsSettings.get_settings()
	draft_settings = live_snapshot.duplicate(true)
	_refresh_summary()
	if not saved:
		push_warning("Menu de graficos aplicou as alteracoes, mas nao conseguiu persistir o arquivo de configuracao.")


func _rollback_pending_display_change() -> void:
	if pending_confirmation_snapshot.is_empty():
		return

	if confirmation_timer:
		confirmation_timer.stop()
	confirmation_overlay.visible = false
	_apply_snapshot_to_live_settings(pending_confirmation_snapshot)
	_apply_live_settings_to_current_context()
	live_snapshot = GraphicsSettings.get_settings()
	draft_settings = live_snapshot.duplicate(true)
	pending_confirmation_snapshot.clear()
	_refresh_controls_from_draft()
	_refresh_summary()


func _apply_live_settings_to_current_context() -> void:
	var viewport: Viewport = get_viewport()
	if viewport:
		GraphicsSettings.apply_to_viewport(viewport)

	if preview_root and is_instance_valid(preview_root) and preview_root.is_inside_tree():
		GraphicsSettings.apply_to_menu_preview(preview_root)
		return

	var current_scene: Node = get_tree().current_scene
	if current_scene and is_instance_valid(current_scene) and current_scene.is_inside_tree():
		GraphicsSettings.apply_to_scene(current_scene)


func _on_confirmation_tick() -> void:
	pending_confirmation_seconds -= 1
	if pending_confirmation_seconds <= 0:
		_rollback_pending_display_change()
		return
	_update_confirmation_text()


func _update_confirmation_text() -> void:
	confirmation_label.text = "Confirme a alteracao de tela. Se nada for confirmado, o jogo reverte sozinho em %d segundos." % pending_confirmation_seconds


func _refresh_controls_from_draft() -> void:
	updating_ui = true

	_select_option_by_metadata(window_mode_select, draft_settings["display"]["window_mode"])
	_select_option_by_metadata(vsync_select, draft_settings["display"]["vsync"])
	_select_option_by_metadata(fps_limit_select, draft_settings["display"]["fps_limit"])

	scale_slider.value = float(draft_settings["render"]["scale_3d"])
	_select_option_by_metadata(aa_mode_select, draft_settings["render"]["aa_mode"])
	taa_toggle.button_pressed = bool(draft_settings["render"]["taa"])

	_select_option_by_metadata(shadow_quality_select, draft_settings["quality"]["shadow_quality"])
	shadow_distance_slider.value = float(draft_settings["quality"]["shadow_distance"])
	flashlight_shadows_toggle.button_pressed = bool(draft_settings["quality"]["flashlight_shadows"])

	fog_toggle.button_pressed = bool(draft_settings["quality"]["fog"])
	glow_toggle.button_pressed = bool(draft_settings["quality"]["glow"])
	ssao_toggle.button_pressed = bool(draft_settings["quality"]["ssao"])

	camera_far_slider.value = float(draft_settings["quality"]["camera_far"])
	terrain_detail_slider.value = float(draft_settings["quality"]["terrain_detail_distance"])

	updating_ui = false
	_refresh_value_labels()


func _refresh_value_labels() -> void:
	scale_value_label.text = "%d%%" % int(round(float(draft_settings["render"]["scale_3d"]) * 100.0))
	shadow_distance_value_label.text = "%dm" % int(round(float(draft_settings["quality"]["shadow_distance"])))
	camera_far_value_label.text = "%dm" % int(round(float(draft_settings["quality"]["camera_far"])))
	terrain_detail_value_label.text = "%dm" % int(round(float(draft_settings["quality"]["terrain_detail_distance"])))

	taa_toggle.text = "Ativado" if taa_toggle.button_pressed else "Desativado"
	flashlight_shadows_toggle.text = "Ativado" if flashlight_shadows_toggle.button_pressed else "Desativado"
	fog_toggle.text = "Ativado" if fog_toggle.button_pressed else "Desativado"
	glow_toggle.text = "Ativado" if glow_toggle.button_pressed else "Desativado"
	ssao_toggle.text = "Ativado" if ssao_toggle.button_pressed else "Desativado"

	_refresh_preset_buttons()


func _refresh_summary() -> void:
	var preset_id := str(draft_settings.get("preset_id", "custom"))
	var preset_name := String(GraphicsSettings.get_available_presets().get(preset_id, preset_id))
	preset_status_label.text = "Preset em edicao: %s" % preset_name
	summary_label.text = "Mudancas ficam locais ate voce aplicar. Modo atual: %s." % preset_name


func _refresh_preset_buttons() -> void:
	var preset_id := str(draft_settings.get("preset_id", "custom"))
	for key in preset_buttons.keys():
		_apply_preset_button_theme(preset_buttons[key], String(key) == preset_id)


func _on_window_mode_changed(index: int) -> void:
	_set_draft_setting("display.window_mode", window_mode_select.get_item_metadata(index))


func _on_vsync_changed(index: int) -> void:
	_set_draft_setting("display.vsync", vsync_select.get_item_metadata(index))


func _on_fps_limit_changed(index: int) -> void:
	_set_draft_setting("display.fps_limit", fps_limit_select.get_item_metadata(index))


func _on_scale_changed(value: float) -> void:
	_set_draft_setting("render.scale_3d", value)


func _on_aa_mode_changed(index: int) -> void:
	_set_draft_setting("render.aa_mode", aa_mode_select.get_item_metadata(index))


func _on_taa_toggled(enabled: bool) -> void:
	_set_draft_setting("render.taa", enabled)


func _on_shadow_quality_changed(index: int) -> void:
	_set_draft_setting("quality.shadow_quality", shadow_quality_select.get_item_metadata(index))


func _on_shadow_distance_changed(value: float) -> void:
	_set_draft_setting("quality.shadow_distance", value)


func _on_flashlight_shadows_toggled(enabled: bool) -> void:
	_set_draft_setting("quality.flashlight_shadows", enabled)


func _on_fog_toggled(enabled: bool) -> void:
	_set_draft_setting("quality.fog", enabled)


func _on_glow_toggled(enabled: bool) -> void:
	_set_draft_setting("quality.glow", enabled)


func _on_ssao_toggled(enabled: bool) -> void:
	_set_draft_setting("quality.ssao", enabled)


func _on_camera_far_changed(value: float) -> void:
	_set_draft_setting("quality.camera_far", value)


func _on_terrain_detail_changed(value: float) -> void:
	_set_draft_setting("quality.terrain_detail_distance", value)


func _set_draft_setting(path: String, value: Variant) -> void:
	if updating_ui:
		return

	_set_nested_value(draft_settings, path, value)
	draft_settings["preset_id"] = GraphicsSettings.get_matching_preset_id(draft_settings)
	_refresh_value_labels()
	_refresh_summary()


func _select_option_by_metadata(option_button: OptionButton, target_value: Variant) -> void:
	for index in range(option_button.item_count):
		if option_button.get_item_metadata(index) == target_value:
			option_button.select(index)
			return


func _create_panel_style(alpha: float, border_alpha: float, corner_radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(PANEL_BG.r, PANEL_BG.g, PANEL_BG.b, alpha)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(PANEL_BORDER.r, PANEL_BORDER.g, PANEL_BORDER.b, border_alpha)
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	return style


func _apply_category_button_theme(button: Button, selected: bool) -> void:
	var bg := Color(0.15, 0.16, 0.18, 0.98) if selected else Color(0.08, 0.09, 0.10, 0.82)
	var border := GOLD if selected else PANEL_BORDER
	button.add_theme_stylebox_override("normal", _create_button_style(bg, border, 8))
	button.add_theme_stylebox_override("hover", _create_button_style(Color(0.17, 0.18, 0.20, 1.0), GOLD, 8))
	button.add_theme_stylebox_override("pressed", _create_button_style(Color(0.20, 0.20, 0.20, 1.0), GOLD, 8))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", TEXT_MAIN if selected else TEXT_MUTED)
	button.add_theme_color_override("font_hover_color", TEXT_MAIN)
	button.add_theme_color_override("font_pressed_color", GOLD)


func _apply_preset_button_theme(button: Button, selected: bool) -> void:
	var bg := GOLD if selected else Color(0.10, 0.11, 0.12, 0.94)
	var border := Color(1.0, 0.90, 0.38, 1.0) if selected else PANEL_BORDER
	button.add_theme_stylebox_override("normal", _create_button_style(bg, border, 6))
	button.add_theme_stylebox_override("hover", _create_button_style(Color(1.0, 0.84, 0.27, 1.0) if selected else Color(0.15, 0.16, 0.18, 0.98), GOLD, 6))
	button.add_theme_stylebox_override("pressed", _create_button_style(Color(0.78, 0.58, 0.13, 1.0) if selected else Color(0.18, 0.18, 0.19, 1.0), GOLD, 6))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color(0.08, 0.08, 0.08, 1.0) if selected else TEXT_MAIN)
	button.add_theme_color_override("font_hover_color", Color(0.04, 0.04, 0.04, 1.0) if selected else TEXT_MAIN)
	button.add_theme_color_override("font_pressed_color", Color(0.0, 0.0, 0.0, 1.0) if selected else TEXT_MAIN)


func _apply_option_button_theme(option_button: OptionButton) -> void:
	var normal := _create_button_style(Color(0.10, 0.11, 0.12, 0.94), PANEL_BORDER, 6)
	var hover := _create_button_style(Color(0.15, 0.16, 0.18, 0.98), GOLD, 6)
	var pressed := _create_button_style(Color(0.18, 0.18, 0.19, 1.0), GOLD, 6)
	option_button.add_theme_stylebox_override("normal", normal)
	option_button.add_theme_stylebox_override("hover", hover)
	option_button.add_theme_stylebox_override("pressed", pressed)
	option_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	option_button.add_theme_font_size_override("font_size", 15)
	option_button.add_theme_color_override("font_color", TEXT_MAIN)
	option_button.add_theme_color_override("font_hover_color", TEXT_MAIN)
	option_button.add_theme_color_override("font_pressed_color", TEXT_MAIN)


func _apply_primary_button_theme(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _create_button_style(GOLD, Color(1.0, 0.90, 0.38, 1.0), 6))
	button.add_theme_stylebox_override("hover", _create_button_style(Color(1.0, 0.84, 0.27, 1.0), Color(1.0, 0.96, 0.58, 1.0), 6))
	button.add_theme_stylebox_override("pressed", _create_button_style(Color(0.78, 0.58, 0.13, 1.0), Color(1.0, 0.84, 0.22, 1.0), 6))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color(0.08, 0.08, 0.08, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.04, 0.04, 0.04, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.0, 0.0, 0.0, 1.0))


func _apply_secondary_button_theme(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _create_button_style(Color(0.10, 0.11, 0.12, 0.94), PANEL_BORDER, 6))
	button.add_theme_stylebox_override("hover", _create_button_style(Color(0.15, 0.16, 0.18, 0.98), GOLD, 6))
	button.add_theme_stylebox_override("pressed", _create_button_style(Color(0.18, 0.18, 0.19, 1.0), GOLD, 6))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", TEXT_MAIN)
	button.add_theme_color_override("font_hover_color", TEXT_MAIN)
	button.add_theme_color_override("font_pressed_color", TEXT_MAIN)


func _create_button_style(bg: Color, border: Color, corner_radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = border
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	return style


func _get_nested_value(source: Dictionary, path: String, fallback: Variant = null) -> Variant:
	var current: Variant = source
	for key in path.split("."):
		if current is Dictionary and current.has(key):
			current = current[key]
		else:
			return fallback
	return current


func _set_nested_value(target: Dictionary, path: String, value: Variant) -> void:
	var parts: PackedStringArray = path.split(".")
	var current: Dictionary = target
	for index in range(parts.size() - 1):
		var key := parts[index]
		if not current.has(key) or not (current[key] is Dictionary):
			current[key] = {}
		current = current[key] as Dictionary
	current[parts[parts.size() - 1]] = value
