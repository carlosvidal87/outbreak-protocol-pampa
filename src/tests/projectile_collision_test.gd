extends Node3D

const BULLET_SCENE := preload("res://addons/fps-hands/bullet/bullet.tscn")

var impact_received := false


func _ready() -> void:
	var bullet: Node3D = BULLET_SCENE.instantiate()
	bullet.distance = 10.0
	bullet.collision_mask = 1
	bullet.shooter = $Shooter
	bullet.collision.connect(_on_bullet_collision)
	add_child(bullet)
	bullet.global_position = Vector3(0.0, 1.0, 0.0)
	bullet.look_at_from_position(bullet.global_position, Vector3(0.0, 1.0, -4.0), Vector3.UP)
	await get_tree().create_timer(1.0).timeout
	if not impact_received:
		push_error("[PROJECTILE TEST] O projétil não colidiu com a parede de teste.")
		get_tree().quit(1)
		return
	print("[PROJECTILE TEST] Colisão, ponto e normal confirmados.")
	get_tree().quit(0)


func _on_bullet_collision(collider: Node3D, _damage: float, point: Vector3, normal: Vector3) -> void:
	if collider != $Wall or normal.length_squared() < 0.9 or point.z > -3.7:
		push_error("[PROJECTILE TEST] Impacto inválido: collider=%s point=%s normal=%s" % [collider, point, normal])
		return
	impact_received = true
