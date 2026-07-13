extends Node3D

const CHARACTER_SCENE := preload("res://src/scenes/character.tscn")
const ZOMBIE_SCENE := preload("res://src/scenes/zombie.tscn")


func _ready() -> void:
	var character := CHARACTER_SCENE.instantiate()
	add_child(character)
	character.is_local_player = true
	character.global_position = Vector3.ZERO

	var zombie := ZOMBIE_SCENE.instantiate()
	add_child(zombie)
	zombie.global_position = Vector3(0.0, 0.0, -4.0)

	await get_tree().physics_frame
	await get_tree().physics_frame

	var head_hitbox := zombie.get_node("HeadHitbox") as Area3D
	var hp_before := float(zombie.get("hp"))
	character.call("_on_fps_hands_give_damage", head_hitbox, 20.0, head_hitbox.global_position)
	if float(zombie.get("hp")) >= hp_before:
		_fail("Ponte character.gd nao reduziu HP ao acertar HeadHitbox.")
		return

	character.call("_on_fps_hands_give_damage", zombie, 999.0, zombie.global_position)
	if not bool(zombie.get("is_dead")):
		_fail("Ponte character.gd nao matou o zombie ao acertar o corpo.")
		return

	print("[ZOMBIE BRIDGE TEST] character.gd aplica dano e morte no zombie.")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("[ZOMBIE BRIDGE TEST] %s" % message)
	get_tree().quit(1)
