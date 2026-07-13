extends Node3D

const ZOMBIE_SCENE := preload("res://src/scenes/zombie.tscn")
const BULLET_SCENE := preload("res://addons/fps-hands/bullet/bullet.tscn")

var damage_received := false


func _ready() -> void:
	var zombie := ZOMBIE_SCENE.instantiate()
	add_child(zombie)
	zombie.global_position = Vector3(0.0, 0.0, -4.0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var query := PhysicsRayQueryParameters3D.create(Vector3(0.0, 1.2, 0.0), Vector3(0.0, 1.2, -8.0))
	query.collision_mask = 7
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_fail("Raycast com mascara 7 nao acertou o zombie.")
		return

	var legacy_query := PhysicsRayQueryParameters3D.create(Vector3(0.0, 1.2, 0.0), Vector3(0.0, 1.2, -8.0))
	legacy_query.collision_mask = 1
	legacy_query.collide_with_areas = true
	legacy_query.collide_with_bodies = true
	if get_world_3d().direct_space_state.intersect_ray(legacy_query).is_empty():
		_fail("Raycast com mascara 1 nao acertou o zombie.")
		return

	var collider := hit["collider"] as Node
	var target := _resolve_damageable(collider)
	if target != zombie:
		_fail("Collider acertado nao resolve para o zombie. collider=%s target=%s" % [collider, target])
		return

	var hp_before := float(zombie.get("hp"))
	target.call("take_damage", 25.0, false)
	if float(zombie.get("hp")) >= hp_before:
		_fail("Dano via collider resolvido nao reduziu HP.")
		return

	var bullet := BULLET_SCENE.instantiate()
	bullet.distance = 10.0
	bullet.collision_mask = 7
	bullet.damage = 1000.0
	bullet.collision.connect(func(obj: Node3D, damage: float, _point: Vector3, _normal: Vector3) -> void:
		var damage_target := _resolve_damageable(obj)
		if damage_target:
			damage_target.call("take_damage", damage, false)
			damage_received = true
	)
	add_child(bullet)
	bullet.global_position = Vector3(0.0, 1.2, 0.0)
	bullet.look_at_from_position(bullet.global_position, Vector3(0.0, 1.2, -4.0), Vector3.UP)
	await get_tree().create_timer(0.5).timeout
	if not damage_received or not bool(zombie.get("is_dead")):
		_fail("Projetil real nao matou o zombie. damage_received=%s hp=%s is_dead=%s" % [
			damage_received,
			zombie.get("hp"),
			zombie.get("is_dead")
		])
		return

	print("[ZOMBIE DAMAGE TEST] Raycast, resolver de dano e projetil real confirmados.")
	get_tree().quit(0)


func _resolve_damageable(collider: Node) -> Node:
	var current := collider
	while current:
		if current.has_method("take_damage"):
			return current
		current = current.get_parent()
	return null


func _fail(message: String) -> void:
	push_error("[ZOMBIE DAMAGE TEST] %s" % message)
	get_tree().quit(1)
