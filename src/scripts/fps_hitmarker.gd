extends Control

const HIT_COLOR := Color(0.96, 0.98, 1.0, 1.0)
const HEADSHOT_COLOR := Color(1.0, 0.74, 0.12, 1.0)
const KILL_COLOR := Color(0.95, 0.16, 0.14, 1.0)
const DISPLAY_TIME := 0.08
const FADE_TIME := 0.08

var _color := HIT_COLOR
var _time_left := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func show_hit(is_headshot: bool, is_kill: bool) -> void:
	if is_kill:
		_color = KILL_COLOR
	elif is_headshot:
		_color = HEADSHOT_COLOR
	else:
		_color = HIT_COLOR
	_time_left = DISPLAY_TIME + FADE_TIME
	queue_redraw()


func _process(delta: float) -> void:
	if _time_left <= 0.0:
		return
	_time_left = maxf(_time_left - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	if _time_left <= 0.0:
		return
	var alpha := clampf(_time_left / FADE_TIME, 0.0, 1.0)
	var color := Color(_color, alpha)
	var center := size * 0.5
	var scale := 1.0 + (1.0 - alpha) * 0.06
	var inner := 5.5 * scale
	var outer := 15.5 * scale
	var thickness := 2.2 * scale
	var radius := thickness * 0.5

	_draw_arm(center, Vector2(-1.0, -1.0), inner, outer, thickness, radius, color)
	_draw_arm(center, Vector2(1.0, -1.0), inner, outer, thickness, radius, color)
	_draw_arm(center, Vector2(-1.0, 1.0), inner, outer, thickness, radius, color)
	_draw_arm(center, Vector2(1.0, 1.0), inner, outer, thickness, radius, color)


func _draw_arm(center: Vector2, direction: Vector2, inner: float, outer: float, thickness: float, radius: float, color: Color) -> void:
	var normalized_direction := direction.normalized()
	var from := center + normalized_direction * inner
	var to := center + normalized_direction * outer
	draw_line(from, to, color, thickness, true)
	draw_circle(from, radius, color)
	draw_circle(to, radius, color)
