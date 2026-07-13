extends Node3D

const CHARACTER_SCENE := preload("res://src/scenes/character.tscn")
const ZOMBIE_SCENE := preload("res://src/scenes/zombie.tscn")


func _ready() -> void:
	seed(1)
	var character := CHARACTER_SCENE.instantiate()
	add_child(character)
	character.is_local_player = true
	character.global_position = Vector3.ZERO

	var zombie := ZOMBIE_SCENE.instantiate()
	add_child(zombie)
	zombie.global_position = Vector3(0.0, 0.0, -4.0)

	for _frame in range(6):
		await get_tree().physics_frame

	var fps_hands := character.get_node("Camera3D/FPSHands")
	var camera := character.get_node("Camera3D") as Camera3D
	zombie.set_physics_process(false)
	zombie.global_position = camera.global_position + (-camera.global_basis.z * 4.0) - Vector3.UP * 1.76
	await get_tree().physics_frame
	var hp_before := float(zombie.hp)
	var aim_rotation: Vector3 = camera.global_rotation
	var character_rotation: Vector3 = character.global_rotation
	var character_position: Vector3 = character.global_position
	fps_hands.ads = true
	fps_hands.recoil = false
	fps_hands.shake = false
	fps_hands.sway = false
	fps_hands.call("_on_animation_tree_animation_started", StringName("fire"))
	await get_tree().create_timer(0.5).timeout
	if float(zombie.hp) >= hp_before:
		_fail("O evento fire da arma nao reduziu o HP. hp=%s" % zombie.hp)
		return

	for _shot in range(8):
		character.global_position = character_position
		character.global_rotation = character_rotation
		camera.global_rotation = aim_rotation
		fps_hands.call("_on_animation_tree_animation_started", StringName("fire"))
		await get_tree().create_timer(0.15).timeout
		if zombie.is_dead:
			break
	if not zombie.is_dead:
		_fail("A arma real causou dano, mas nao matou o zombie. hp=%s" % zombie.hp)
		return

	print("[ZOMBIE REAL WEAPON TEST] Evento fire, raycast, dano e morte confirmados.")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("[ZOMBIE REAL WEAPON TEST] %s" % message)
	get_tree().quit(1)
