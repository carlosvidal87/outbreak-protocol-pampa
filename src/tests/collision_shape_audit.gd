extends SceneTree

const GAMEPLAY_SCENE := "res://src/scenes/node_3d.tscn"


func _initialize() -> void:
	var packed_scene := load(GAMEPLAY_SCENE) as PackedScene
	if not packed_scene:
		push_error("[COLLISION AUDIT] Nao foi possivel carregar o mapa.")
		quit(1)
		return
	var gameplay: Node = packed_scene.instantiate()
	var concave_count: int = 0
	var suspicious_count: int = 0
	for node in _all_descendants(gameplay):
		if not node is CollisionShape3D:
			continue
		var collision := node as CollisionShape3D
		if not collision.shape is ConcavePolygonShape3D:
			continue
		concave_count += 1
		var faces: PackedVector3Array = (collision.shape as ConcavePolygonShape3D).data
		if not _has_usable_triangle(faces):
			suspicious_count += 1
	print("[COLLISION AUDIT] concavas=%d sem_triangulo_util=%d" % [concave_count, suspicious_count])
	gameplay.free()
	quit(0)


func _all_descendants(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		result.append(current)
		for child in current.get_children():
			pending.append(child)
	return result


func _has_usable_triangle(faces: PackedVector3Array) -> bool:
	if faces.size() < 3 or faces.size() % 3 != 0:
		return false
	for index in range(0, faces.size(), 3):
		var edge_a: Vector3 = faces[index + 1] - faces[index]
		var edge_b: Vector3 = faces[index + 2] - faces[index]
		if edge_a.cross(edge_b).length_squared() > 0.0000000001:
			return true
	return false
