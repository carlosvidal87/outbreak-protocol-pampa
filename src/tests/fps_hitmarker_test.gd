extends Node

const HITMARKER_SCRIPT := preload("res://src/scripts/fps_hitmarker.gd")


func _ready() -> void:
	var hitmarker := Control.new()
	hitmarker.set_script(HITMARKER_SCRIPT)
	add_child(hitmarker)
	await get_tree().process_frame

	hitmarker.show_hit(false, false)
	_assert_color(hitmarker._color, hitmarker.HIT_COLOR, "acerto comum")
	hitmarker.show_hit(true, false)
	_assert_color(hitmarker._color, hitmarker.HEADSHOT_COLOR, "headshot")
	hitmarker.show_hit(true, true)
	_assert_color(hitmarker._color, hitmarker.KILL_COLOR, "eliminacao")
	if hitmarker._time_left <= 0.0:
		_fail("O hitmarker nao recebeu tempo de exibicao.")
		return

	print("[HITMARKER TEST] Cores de acerto, headshot e eliminacao confirmadas.")
	get_tree().quit(0)


func _assert_color(actual: Color, expected: Color, label: String) -> void:
	if not actual.is_equal_approx(expected):
		_fail("Cor incorreta para %s." % label)


func _fail(message: String) -> void:
	push_error("[HITMARKER TEST] %s" % message)
	get_tree().quit(1)
