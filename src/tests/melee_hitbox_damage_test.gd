extends Node3D

const FPS_HANDS_SCRIPT := preload("res://addons/fps-hands/fps-hands.gd")

var received_damages: Array[float] = []


func _ready() -> void:
	var target := Area3D.new()
	target.name = "ZombieAnimatedHitbox"
	target.position = Vector3(0, 0, -0.8)
	target.collision_layer = 4
	target.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.5, 0.5, 0.5)
	collision.shape = shape
	target.add_child(collision)
	add_child(target)
	var camera := Camera3D.new()
	camera.current = true
	add_child(camera)

	var hands := FPS_HANDS_SCRIPT.new()
	hands.camera = camera
	hands.collision_mask = 5
	hands.sway = false
	hands.recoil = false
	hands.shake = false
	hands.give_damage.connect(_on_damage)
	add_child(hands)
	hands.MeleeRayCast.enabled = true
	hands.FireRayCast.enabled = true
	hands.FireRayCast.collide_with_areas = true
	hands.FireRayCast.collision_mask = 5
	hands.FireRayCast.target_position = Vector3(0, 0, -1.0)

	await get_tree().physics_frame
	await get_tree().physics_frame
	hands.melee_camera_attack(100.0, 2.2)
	hands.melee_camera_attack(70.0, 2.2)

	if received_damages.size() != 2:
		_fail("Ataques corpo a corpo nao atingiram Area3D. impactos=%d" % received_damages.size())
		return
	if not is_equal_approx(received_damages[0], 100.0) or not is_equal_approx(received_damages[1], 70.0):
		_fail("Danos incorretos: %s" % received_damages)
		return
	print("[MELEE HITBOX TEST] Camera central: coronhada=100 e faca=70 atingiram Area3D a frente.")
	get_tree().quit(0)


func _on_damage(_target: Node3D, damage: float, _point: Vector3) -> void:
	received_damages.append(damage)


func _fail(message: String) -> void:
	push_error("[MELEE HITBOX TEST] %s" % message)
	get_tree().quit(1)
