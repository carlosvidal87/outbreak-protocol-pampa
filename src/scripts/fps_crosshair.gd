extends Control

const COLOR := Color(0.94, 0.98, 1.0, 0.82)

var _weapon: Node3D = null
var _aiming := false
var _movement := 0.0
var _fire_kick := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func set_weapon(weapon: Node3D) -> void:
	_weapon = weapon
	queue_redraw()


func set_aiming(enabled: bool) -> void:
	_aiming = enabled
	queue_redraw()


func set_movement_speed(speed: float) -> void:
	_movement = clampf(speed / 8.0, 0.0, 1.0)


func kick() -> void:
	if _weapon:
		var pellets: int = int(_weapon.get_meta("bullet_count", 1))
		var spread: float = float(_weapon.get_meta("spread", 1.0))
		_fire_kick = minf(_fire_kick + 3.5 + spread * 0.65 + pellets * 0.2, 18.0)


func _process(delta: float) -> void:
	_fire_kick = move_toward(_fire_kick, 0.0, delta * 38.0)
	queue_redraw()


func _draw() -> void:
	if _aiming or not _weapon:
		return
	var center := size * 0.5
	var pellets: int = int(_weapon.get_meta("bullet_count", 1))
	var base_spread: float = float(_weapon.get_meta("spread", 1.0))
	var gap := 5.0 + base_spread * 1.15 + _movement * 5.5 + _fire_kick
	var thickness := 1.35
	if pellets > 1:
		var radius := gap + 3.0
		draw_arc(center, radius, 0.0, TAU, 28, COLOR, thickness, true)
		for i in 4:
			var angle := TAU * float(i) / 4.0
			var point := center + Vector2(cos(angle), sin(angle)) * radius
			draw_circle(point, 1.1, COLOR)
		return
	var length := 4.5
	draw_line(center + Vector2(-gap - length, 0), center + Vector2(-gap, 0), COLOR, thickness, true)
	draw_line(center + Vector2(gap, 0), center + Vector2(gap + length, 0), COLOR, thickness, true)
	draw_line(center + Vector2(0, -gap - length), center + Vector2(0, -gap), COLOR, thickness, true)
	draw_line(center + Vector2(0, gap), center + Vector2(0, gap + length), COLOR, thickness, true)
