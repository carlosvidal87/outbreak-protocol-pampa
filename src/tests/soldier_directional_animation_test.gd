extends Node

const CHARACTER_SCENE := preload("res://src/scenes/character.tscn")


func _ready() -> void:
	var character := CHARACTER_SCENE.instantiate() as CharacterBody3D
	add_child(character)
	await get_tree().process_frame

	var animation_player := character.get("soldier_anim_player") as AnimationPlayer
	if not animation_player:
		_fail("AnimationPlayer do Soldier nao foi configurado.")
		return

	var expected_names: Array = character.SOLDIER_ANIM_NAMES
	for state_name: String in expected_names:
		var animation_name := "pistol/%s" % state_name
		if not animation_player.has_animation(animation_name):
			_fail("Animacao ausente: %s" % animation_name)
			return
		if not _has_zero_horizontal_root_motion(animation_player.get_animation(animation_name)):
			_fail("Root motion horizontal encontrado: %s" % animation_name)
			return

	var directions := {
		Vector2(0.0, -1.0): character.SoldierAnimState.WALK_FORWARD,
		Vector2(0.0, 1.0): character.SoldierAnimState.WALK_BACKWARD,
		Vector2(-1.0, 0.0): character.SoldierAnimState.WALK_LEFT,
		Vector2(1.0, 0.0): character.SoldierAnimState.WALK_RIGHT,
		Vector2(-1.0, -1.0): character.SoldierAnimState.WALK_FORWARD_LEFT,
		Vector2(1.0, -1.0): character.SoldierAnimState.WALK_FORWARD_RIGHT,
		Vector2(-1.0, 1.0): character.SoldierAnimState.WALK_BACKWARD_LEFT,
		Vector2(1.0, 1.0): character.SoldierAnimState.WALK_BACKWARD_RIGHT,
	}
	var run_offset: int = character.SoldierAnimState.RUN_FORWARD - character.SoldierAnimState.WALK_FORWARD
	for direction: Vector2 in directions:
		var walk_state: int = character.call("_select_soldier_animation_state", direction, false, false)
		if walk_state != int(directions[direction]):
			_fail("Direcao de caminhada incorreta: %s" % direction)
			return
		var run_state: int = character.call("_select_soldier_animation_state", direction, true, false)
		if run_state != walk_state + run_offset:
			_fail("Direcao de corrida incorreta: %s" % direction)
			return

	if int(character.call("_select_soldier_animation_state", Vector2.ZERO, false, false)) != character.SoldierAnimState.IDLE:
		_fail("Idle nao foi selecionado.")
		return
	if int(character.call("_select_soldier_animation_state", Vector2.ZERO, false, true)) != character.SoldierAnimState.JUMP:
		_fail("Jump nao foi selecionado.")
		return

	print("[SOLDIER ANIMATION TEST] 18 estados, oito direcoes e root motion confirmados.")
	get_tree().quit(0)


func _has_zero_horizontal_root_motion(animation: Animation) -> bool:
	for track_index in range(animation.get_track_count()):
		if animation.track_get_type(track_index) != Animation.TYPE_POSITION_3D:
			continue
		var track_path := String(animation.track_get_path(track_index))
		if not track_path.contains("Hips") and track_path.contains("mixamorig:"):
			continue
		for key_index in range(animation.track_get_key_count(track_index)):
			var value: Variant = animation.track_get_key_value(track_index, key_index)
			if value is Vector3:
				var position := value as Vector3
				if absf(position.x) > 0.0001 or absf(position.z) > 0.0001:
					return false
	return true


func _fail(message: String) -> void:
	push_error("[SOLDIER ANIMATION TEST] %s" % message)
	get_tree().quit(1)
