extends Control

const GAMEPLAY_SCENE := "res://src/scenes/node_3d.tscn"
const MAP_TEXTURE := preload("res://assets/ui/map-logo.png")

const GOLD := Color(0.96, 0.77, 0.19, 1.0)
const TRACK_COLOR := Color(1.0, 1.0, 1.0, 0.16)
const TEXT_COLOR := Color(0.82, 0.84, 0.87, 1.0)
const SHADE_COLOR := Color(0.0, 0.0, 0.0, 0.34)
const FADE_IN_TIME := 0.28
const FADE_OUT_TIME := 0.28
const READY_PROGRESS := 0.96

var progress_track: Control = null
var progress_fill: ColorRect = null
var progress_label: Label = null
var fade_rect: ColorRect = null
var displayed_progress := 0.0
var is_finishing := false
var loading_started_at_ms := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_create_layout()
	_update_progress_ui(0.0)
	loading_started_at_ms = Time.get_ticks_msec()

	var load_error: Error = ResourceLoader.load_threaded_request(
		GAMEPLAY_SCENE,
		"",
		true,
		ResourceLoader.CACHE_MODE_REUSE
	)
	if load_error != OK:
		push_warning("Falha ao iniciar carregamento em background do mapa: %s" % GAMEPLAY_SCENE)
		await _fade_from_black()
		await _fallback_to_direct_load()
		return

	await _fade_from_black()
	set_process(true)


func _process(_delta: float) -> void:
	if is_finishing:
		return

	var progress: Array = []
	var status: int = ResourceLoader.load_threaded_get_status(GAMEPLAY_SCENE, progress)
	var target_progress: float = displayed_progress
	if not progress.is_empty():
		var raw_progress: float = float(progress[0])
		target_progress = clampf(raw_progress, 0.0, 1.0)

	if status == ResourceLoader.THREAD_LOAD_LOADED:
		displayed_progress = 1.0
		_update_progress_ui(displayed_progress)
		call_deferred("_finish_loading")
		return

	if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		push_warning("Carregamento em thread falhou para: %s" % GAMEPLAY_SCENE)
		call_deferred("_fallback_to_direct_load")
		return

	displayed_progress = target_progress
	_update_progress_ui(displayed_progress)


func _create_layout() -> void:
	var background := TextureRect.new()
	background.name = "LoadingBackground"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = MAP_TEXTURE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var shade := ColorRect.new()
	shade.name = "LoadingShade"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = SHADE_COLOR
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var progress_row := HBoxContainer.new()
	progress_row.name = "ProgressRow"
	progress_row.anchor_left = 0.025
	progress_row.anchor_top = 1.0
	progress_row.anchor_right = 0.975
	progress_row.anchor_bottom = 1.0
	progress_row.offset_top = -74.0
	progress_row.offset_bottom = -42.0
	progress_row.add_theme_constant_override("separation", 16)
	progress_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(progress_row)

	progress_track = Control.new()
	progress_track.name = "ProgressTrack"
	progress_track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_track.custom_minimum_size = Vector2(0, 4)
	progress_row.add_child(progress_track)

	var track_bg := ColorRect.new()
	track_bg.name = "ProgressTrackBackground"
	track_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	track_bg.color = TRACK_COLOR
	track_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_track.add_child(track_bg)

	progress_fill = ColorRect.new()
	progress_fill.name = "ProgressFill"
	progress_fill.position = Vector2.ZERO
	progress_fill.size = Vector2.ZERO
	progress_fill.color = GOLD
	progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_track.add_child(progress_fill)

	progress_label = Label.new()
	progress_label.name = "ProgressLabel"
	progress_label.custom_minimum_size = Vector2(78, 0)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress_label.add_theme_font_size_override("font_size", 24)
	progress_label.add_theme_color_override("font_color", TEXT_COLOR)
	progress_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	progress_label.add_theme_constant_override("shadow_offset_x", 1)
	progress_label.add_theme_constant_override("shadow_offset_y", 1)
	progress_row.add_child(progress_label)

	fade_rect = ColorRect.new()
	fade_rect.name = "LoadingFade"
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color.BLACK
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.z_index = 20
	add_child(fade_rect)


func _update_progress_ui(progress: float) -> void:
	if progress_track and progress_fill:
		progress_fill.size = Vector2(progress_track.size.x * progress, progress_track.size.y)

	if progress_label:
		progress_label.text = "%d%%" % int(round(progress * 100.0))


func _finish_loading() -> void:
	if is_finishing:
		return

	is_finishing = true
	set_process(false)
	displayed_progress = READY_PROGRESS
	_update_progress_ui(displayed_progress)
	await get_tree().process_frame

	var packed_scene := ResourceLoader.load_threaded_get(GAMEPLAY_SCENE) as PackedScene
	if packed_scene:
		print("[LOAD] Gameplay carregado em %dms." % (Time.get_ticks_msec() - loading_started_at_ms))
		await _mount_gameplay_scene(packed_scene)
		return

	push_warning("PackedScene do gameplay nao ficou disponivel apos o loading em thread.")
	await _fade_to_black()
	get_tree().change_scene_to_file(GAMEPLAY_SCENE)


func _fallback_to_direct_load() -> void:
	if is_finishing:
		return

	is_finishing = true
	set_process(false)
	await _fade_to_black()
	get_tree().change_scene_to_file(GAMEPLAY_SCENE)


func _mount_gameplay_scene(packed_scene: PackedScene) -> void:
	var gameplay_scene := packed_scene.instantiate()
	if not gameplay_scene:
		push_warning("Nao foi possivel instanciar o mapa carregado.")
		await _fade_to_black()
		get_tree().change_scene_to_file(GAMEPLAY_SCENE)
		return

	_set_if_property(gameplay_scene, "use_external_loading_screen", true)

	var previous_scene := get_tree().current_scene
	get_tree().root.add_child(gameplay_scene)
	get_tree().current_scene = gameplay_scene
	if previous_scene == self:
		get_tree().root.move_child(self, get_tree().root.get_child_count() - 1)

	if gameplay_scene.has_signal("startup_ready"):
		await gameplay_scene.startup_ready
	else:
		await get_tree().process_frame

	displayed_progress = 1.0
	_update_progress_ui(displayed_progress)
	await get_tree().process_frame
	await _fade_loading_out()
	queue_free()


func _fade_from_black() -> void:
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, FADE_IN_TIME)
	await tween.finished


func _fade_to_black() -> void:
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, FADE_OUT_TIME)
	await tween.finished


func _fade_loading_out() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_TIME)
	tween.tween_property(fade_rect, "modulate:a", 0.0, FADE_OUT_TIME)
	await tween.finished


func _set_if_property(object: Object, property_name: String, value: Variant) -> void:
	for property in object.get_property_list():
		if property.get("name", "") == property_name:
			object.set(property_name, value)
			return
