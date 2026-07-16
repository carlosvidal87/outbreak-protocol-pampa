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
const MULTIPLAYER_READY_TIMEOUT := 120.0
const MENU_SCENE := "res://src/scenes/main_menu.tscn"

var progress_track: Control = null
var progress_fill: ColorRect = null
var progress_label: Label = null
var fade_rect: ColorRect = null
var displayed_progress := 0.0
var is_finishing := false
var loading_started_at_ms := 0
var last_progress_change_at_ms := 0
var last_status_report_at_ms := 0
var last_reported_progress_percent := -1
var stall_warning_count := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_create_layout()
	_update_progress_ui(0.0)
	loading_started_at_ms = Time.get_ticks_msec()
	last_progress_change_at_ms = loading_started_at_ms
	last_status_report_at_ms = loading_started_at_ms
	NetworkManager.report_loading_status("loading_screen_ready", 0.0, "Solicitando mapa")

	var load_error: Error = ResourceLoader.load_threaded_request(
		GAMEPLAY_SCENE,
		"",
		false,
		ResourceLoader.CACHE_MODE_REUSE
	)
	if load_error != OK:
		NetworkManager.log_diagnostic("loading", "thread_request_failed", {"error": load_error, "scene": GAMEPLAY_SCENE})
		NetworkManager.report_loading_status("thread_request_failed", 0.0, "Erro %d" % load_error)
		push_warning("Falha ao iniciar carregamento em background do mapa: %s" % GAMEPLAY_SCENE)
		await _fade_from_black()
		await _fallback_to_direct_load()
		return
	NetworkManager.log_diagnostic("loading", "thread_request_started", {"scene": GAMEPLAY_SCENE, "sub_threads": false})
	NetworkManager.report_loading_status("resource_loading", 0.0, "Carregamento em thread unica")

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
		NetworkManager.report_loading_status("resource_loaded", 1.0, "Mapa carregado")
		call_deferred("_finish_loading")
		return

	if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		NetworkManager.log_diagnostic("loading", "thread_load_failed", {"status": status, "progress": displayed_progress})
		NetworkManager.report_loading_status("resource_failed", displayed_progress, "Status %d" % status)
		push_warning("Carregamento em thread falhou para: %s" % GAMEPLAY_SCENE)
		call_deferred("_fallback_to_direct_load")
		return

	if not is_equal_approx(displayed_progress, target_progress):
		last_progress_change_at_ms = Time.get_ticks_msec()
	displayed_progress = target_progress
	_update_progress_ui(displayed_progress)
	_report_loading_heartbeat(status)


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
	NetworkManager.report_loading_status("resource_finalize", displayed_progress, "Obtendo PackedScene")
	set_process(false)
	displayed_progress = READY_PROGRESS
	_update_progress_ui(displayed_progress)
	await get_tree().process_frame

	var packed_scene := ResourceLoader.load_threaded_get(GAMEPLAY_SCENE) as PackedScene
	if packed_scene:
		NetworkManager.log_diagnostic("loading", "packed_scene_available", {"elapsed_ms": Time.get_ticks_msec() - loading_started_at_ms})
		print("[LOAD] Gameplay carregado em %dms." % (Time.get_ticks_msec() - loading_started_at_ms))
		await _mount_gameplay_scene(packed_scene)
		return

	push_warning("PackedScene do gameplay nao ficou disponivel apos o loading em thread.")
	NetworkManager.log_diagnostic("loading", "packed_scene_missing", {})
	NetworkManager.report_loading_status("direct_load_fallback", displayed_progress, "PackedScene indisponivel")
	await _fade_to_black()
	get_tree().change_scene_to_file(GAMEPLAY_SCENE)


func _fallback_to_direct_load() -> void:
	if is_finishing:
		return

	is_finishing = true
	NetworkManager.report_loading_status("direct_load_fallback", displayed_progress, "Carregamento direto")
	set_process(false)
	await _fade_to_black()
	get_tree().change_scene_to_file(GAMEPLAY_SCENE)


func _mount_gameplay_scene(packed_scene: PackedScene) -> void:
	NetworkManager.report_loading_status("scene_instantiating", READY_PROGRESS, "Instanciando mapa")
	var gameplay_scene := packed_scene.instantiate()
	if not gameplay_scene:
		push_warning("Nao foi possivel instanciar o mapa carregado.")
		await _fade_to_black()
		get_tree().change_scene_to_file(GAMEPLAY_SCENE)
		return
	NetworkManager.report_loading_status("scene_instantiated", READY_PROGRESS, "Instancia criada")

	_set_if_property(gameplay_scene, "use_external_loading_screen", true)
	_disable_invalid_concave_collisions(gameplay_scene)

	var previous_scene := get_tree().current_scene
	get_tree().root.add_child(gameplay_scene)
	get_tree().current_scene = gameplay_scene
	NetworkManager.report_loading_status("scene_mounted", READY_PROGRESS, "Mapa adicionado a arvore")
	if previous_scene == self:
		get_tree().root.move_child(self, get_tree().root.get_child_count() - 1)

	if gameplay_scene.has_signal("startup_ready"):
		await gameplay_scene.startup_ready
	else:
		await get_tree().process_frame
	NetworkManager.report_loading_status("map_startup_ready", READY_PROGRESS, "Navegacao e mapa prontos")

	if progress_label:
		progress_label.custom_minimum_size.x = 220.0
		progress_label.text = "SINCRONIZANDO"
	var gameplay_ready := await _wait_for_local_gameplay_ready(gameplay_scene)
	if not gameplay_ready:
		await _abort_multiplayer_loading(gameplay_scene)
		return

	displayed_progress = 1.0
	NetworkManager.report_loading_status("local_gameplay_ready", 1.0, "Personagem e camera prontos")
	_update_progress_ui(displayed_progress)
	await get_tree().process_frame
	await _fade_loading_out()
	queue_free()


func _wait_for_local_gameplay_ready(gameplay_scene: Node) -> bool:
	var game_session := gameplay_scene.get_node_or_null("GameSession")
	if not game_session or not game_session.has_method("is_local_gameplay_ready"):
		return true
	var started_at := Time.get_ticks_msec()
	var last_status_second := -1
	while is_instance_valid(game_session) and not bool(game_session.call("is_local_gameplay_ready")):
		if multiplayer.multiplayer_peer == null and NetworkManager.state == NetworkManager.SessionState.OFFLINE:
			return false
		var elapsed_ms := Time.get_ticks_msec() - started_at
		var elapsed_second := int(elapsed_ms / 1000.0)
		if elapsed_second != last_status_second:
			last_status_second = elapsed_second
			if progress_label:
				progress_label.text = NetworkManager.get_loading_wait_description()
			if elapsed_second % 5 == 0:
				NetworkManager.report_loading_status("waiting_for_players", READY_PROGRESS, NetworkManager.get_loading_wait_description())
		if elapsed_ms >= int(MULTIPLAYER_READY_TIMEOUT * 1000.0):
			var timeout_details := {"state": NetworkManager.state, "peers": NetworkManager.get_alive_peer_ids(), "ready": NetworkManager.server_ready_peer_ids, "missing": NetworkManager.get_server_missing_map_ready_peer_ids(), "peer_status": NetworkManager.get_loading_status_snapshot()}
			NetworkManager.log_diagnostic("loading", "local_gameplay_timeout", timeout_details)
			push_error("[NET] Timeout aguardando personagem e camera locais. Dados=%s Log=%s" % [timeout_details, NetworkManager.get_diagnostic_log_path()])
			return false
		await get_tree().process_frame
	return is_instance_valid(game_session)


func _abort_multiplayer_loading(gameplay_scene: Node) -> void:
	if progress_label:
		progress_label.text = "FALHA NA SINCRONIZACAO"
	var message := "O mapa nao sincronizou. Verifique a conexao UDP 7000. Log: %s" % NetworkManager.get_diagnostic_log_path()
	NetworkManager.log_diagnostic("loading", "local_abort", {"message": message})
	NetworkManager.leave_session(message)
	get_tree().current_scene = self
	if is_instance_valid(gameplay_scene):
		gameplay_scene.queue_free()
	await get_tree().process_frame
	get_tree().change_scene_to_file(MENU_SCENE)


func _report_loading_heartbeat(status: int) -> void:
	var now := Time.get_ticks_msec()
	var progress_percent := int(round(displayed_progress * 100.0))
	var progress_changed := progress_percent != last_reported_progress_percent
	var heartbeat_due := now - last_status_report_at_ms >= 5000
	if progress_changed or heartbeat_due:
		last_reported_progress_percent = progress_percent
		last_status_report_at_ms = now
		NetworkManager.report_loading_status("resource_loading", displayed_progress, "Loader status %d" % status)
	var stalled_for_ms := now - last_progress_change_at_ms
	var expected_warning_count := int(stalled_for_ms / 15000)
	if expected_warning_count > stall_warning_count:
		stall_warning_count = expected_warning_count
		NetworkManager.log_diagnostic("loading", "progress_stalled", {"progress_percent": progress_percent, "stalled_ms": stalled_for_ms, "loader_status": status})


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


func _disable_invalid_concave_collisions(root: Node) -> void:
	var disabled_count := 0
	for candidate in root.find_children("*", "CollisionShape3D", true, false):
		var collision := candidate as CollisionShape3D
		if not collision or not collision.shape is ConcavePolygonShape3D:
			continue
		var faces: PackedVector3Array = (collision.shape as ConcavePolygonShape3D).data
		if _has_usable_triangle(faces):
			continue
		collision.disabled = true
		disabled_count += 1
	if disabled_count > 0:
		print("[PHYSICS] %d colisoes concavas invalidas foram desativadas." % disabled_count)


func _has_usable_triangle(faces: PackedVector3Array) -> bool:
	if faces.size() < 3 or faces.size() % 3 != 0:
		return false
	for index in range(0, faces.size(), 3):
		var edge_a: Vector3 = faces[index + 1] - faces[index]
		var edge_b: Vector3 = faces[index + 2] - faces[index]
		if edge_a.cross(edge_b).length_squared() > 0.0000000001:
			return true
	return false
