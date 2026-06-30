extends Control

const MAIN_MENU_SCENE := "res://src/scenes/main_menu.tscn"
const MATURE_LOGO_TEXTURE := preload("res://assets/ui/ESRB_mature17.png")
const GAME_LOGO_TEXTURE := preload("res://assets/ui/game-logo.png")

const FADE_IN_TIME := 0.65
const HOLD_TIME := 1.05
const FADE_OUT_TIME := 0.65
const BETWEEN_LOGOS_TIME := 0.25
const SKIP_FADE_OUT_TIME := 0.18

var logo_rect: TextureRect
var transition_rect: ColorRect
var intro_running := false
var skip_requested := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_create_layout()
	_play_intro()


func _unhandled_input(event: InputEvent) -> void:
	if not intro_running:
		return

	var wants_to_skip: bool = (
		event.is_action_pressed("ui_accept")
		or event.is_action_pressed("ui_cancel")
		or (event is InputEventMouseButton and event.pressed)
	)
	if wants_to_skip:
		skip_requested = true


func _create_layout() -> void:
	var background := ColorRect.new()
	background.name = "IntroBackground"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color.BLACK
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var center := CenterContainer.new()
	center.name = "LogoCenter"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	logo_rect = TextureRect.new()
	logo_rect.name = "IntroLogo"
	logo_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo_rect.custom_minimum_size = Vector2(520, 260)
	logo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_rect.modulate = Color(1, 1, 1, 0)
	center.add_child(logo_rect)

	transition_rect = ColorRect.new()
	transition_rect.name = "IntroFadeToMenu"
	transition_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition_rect.color = Color.BLACK
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_rect.modulate = Color(1, 1, 1, 1)
	transition_rect.z_index = 10
	add_child(transition_rect)


func _play_intro() -> void:
	intro_running = true
	await _fade_screen_from_black()
	await _show_logo(MATURE_LOGO_TEXTURE, Vector2(360, 260))
	await _wait_seconds_or_skip(BETWEEN_LOGOS_TIME)
	await _show_logo(GAME_LOGO_TEXTURE, Vector2(560, 280))
	await _fade_screen_to_black()
	_go_to_main_menu()


func _show_logo(texture: Texture2D, min_size: Vector2) -> void:
	skip_requested = false
	logo_rect.texture = texture
	logo_rect.custom_minimum_size = min_size
	logo_rect.modulate = Color(1, 1, 1, 0)

	var skipped := await _animate_logo_alpha(1.0, FADE_IN_TIME, true)
	if skipped:
		await _animate_logo_alpha(0.0, SKIP_FADE_OUT_TIME, false)
		return

	skipped = await _wait_seconds_or_skip(HOLD_TIME)
	if skipped:
		await _animate_logo_alpha(0.0, SKIP_FADE_OUT_TIME, false)
		return

	await _animate_logo_alpha(0.0, FADE_OUT_TIME, false)


func _fade_screen_from_black() -> void:
	var tween := create_tween()
	tween.tween_property(transition_rect, "modulate:a", 0.0, 0.35)
	await tween.finished


func _fade_screen_to_black() -> void:
	var tween := create_tween()
	tween.tween_property(transition_rect, "modulate:a", 1.0, 0.45)
	await tween.finished


func _animate_logo_alpha(target_alpha: float, duration: float, allow_skip: bool) -> bool:
	var initial_alpha: float = logo_rect.modulate.a
	var elapsed := 0.0
	while elapsed < duration:
		if allow_skip and skip_requested:
			skip_requested = false
			return true

		await get_tree().process_frame
		elapsed += get_process_delta_time()
		var weight: float = minf(elapsed / duration, 1.0)
		logo_rect.modulate.a = lerpf(initial_alpha, target_alpha, weight)

	logo_rect.modulate.a = target_alpha
	return false


func _wait_seconds_or_skip(duration: float) -> bool:
	var elapsed := 0.0
	while elapsed < duration:
		if skip_requested:
			skip_requested = false
			return true

		await get_tree().process_frame
		elapsed += get_process_delta_time()

	return false


func _go_to_main_menu() -> void:
	if not intro_running:
		return

	intro_running = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
