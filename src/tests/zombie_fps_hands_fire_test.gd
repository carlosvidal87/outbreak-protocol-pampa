extends Node3D

const CHARACTER_SCENE := preload("res://src/scenes/character.tscn")
const ZOMBIE_SCENE := preload("res://assets/characters/Zombies/zombie.tscn")


func _ready() -> void:
	var character := CHARACTER_SCENE.instantiate()
	add_child(character)
	character.is_local_player = true
	character.global_position = Vector3.ZERO
	character.rotation = Vector3.ZERO

	var zombie := ZOMBIE_SCENE.instantiate()
	add_child(zombie)
	zombie.global_position = Vector3(0.0, 0.0, -4.0)

	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

	var fps_hands := character.get_node("Camera3D/FPSHands")
	var hp_before := float(zombie.get("hp"))
	fps_hands.fire_bullet(zombie.global_position + Vector3(0.0, 1.1, 0.0), 1000.0)
	await get_tree().create_timer(0.75).timeout

	if float(zombie.get("hp")) >= hp_before or not bool(zombie.get("is_dead")):
		_fail("FPSHands.fire_bullet nao aplicou dano no zombie. hp_before=%s hp_after=%s is_dead=%s" % [
			hp_before,
			zombie.get("hp"),
			zombie.get("is_dead")
		])
		return

	print("[ZOMBIE FPSHANDS TEST] Disparo real do FPSHands matou o zombie.")
	character.queue_free()
	zombie.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("[ZOMBIE FPSHANDS TEST] %s" % message)
	get_tree().quit(1)
