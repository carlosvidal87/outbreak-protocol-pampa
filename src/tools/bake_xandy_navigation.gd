extends SceneTree

const WORLD_SCENE := "res://src/scenes/node_3d.tscn"
const OUTPUT_PATH := "res://assets/terrain/outdoor_navigation_mesh.tres"
const SPAWN_XZ := [
	Vector2(-8.092144, -31.736805),
	Vector2(-6.092144, -31.736805),
	Vector2(-8.092144, -29.236805),
	Vector2(-6.092144, -29.236805),
]


func _initialize() -> void:
	call_deferred("_bake")


func _bake() -> void:
	var packed_world := load(WORLD_SCENE) as PackedScene
	if not packed_world:
		push_error("Nao foi possivel carregar %s" % WORLD_SCENE)
		quit(1)
		return
	var world := packed_world.instantiate()
	root.add_child(world)
	if world.has_signal("startup_ready"):
		await world.startup_ready
	else:
		await process_frame
	var region := world.get_node_or_null("TerrainNavigationRegion") as NavigationRegion3D
	if not region or not region.navigation_mesh:
		push_error("TerrainNavigationRegion nao foi criada")
		quit(1)
		return
	var mesh := region.navigation_mesh
	if mesh.get_polygon_count() <= 0:
		push_error("A navegacao externa foi gerada sem poligonos")
		quit(1)
		return
	mesh.agent_radius = 0.34
	var save_error := ResourceSaver.save(mesh, OUTPUT_PATH)
	if save_error != OK:
		push_error("Falha ao salvar navegacao: %s" % error_string(save_error))
		quit(1)
		return
	print("[NAV BAKE] %d vertices, %d poligonos salvos em %s" % [
		mesh.get_vertices().size(),
		mesh.get_polygon_count(),
		OUTPUT_PATH,
	])
	_print_spawn_heights(mesh.get_vertices())
	await physics_frame
	_print_spawn_ground(world)
	world.queue_free()
	quit(0)


func _print_spawn_heights(vertices: PackedVector3Array) -> void:
	for spawn_index in range(SPAWN_XZ.size()):
		var spawn_xz: Vector2 = SPAWN_XZ[spawn_index]
		var closest := Vector3.ZERO
		var closest_distance := INF
		for vertex in vertices:
			var distance := Vector2(vertex.x, vertex.z).distance_squared_to(spawn_xz)
			if distance < closest_distance:
				closest_distance = distance
				closest = vertex
		print("[SPAWN HEIGHT] %d: x=%.3f y=%.3f z=%.3f distance=%.3f" % [
			spawn_index + 1,
			spawn_xz.x,
			closest.y,
			spawn_xz.y,
			sqrt(closest_distance),
		])


func _print_spawn_ground(world: Node) -> void:
	var world_3d := (world as Node3D).get_world_3d()
	for spawn_index in range(SPAWN_XZ.size()):
		var spawn_xz: Vector2 = SPAWN_XZ[spawn_index]
		var query := PhysicsRayQueryParameters3D.create(
			Vector3(spawn_xz.x, 220.0, spawn_xz.y),
			Vector3(spawn_xz.x, -260.0, spawn_xz.y)
		)
		var excluded: Array[RID] = []
		for player in get_nodes_in_group("player"):
			if player is CollisionObject3D:
				excluded.append((player as CollisionObject3D).get_rid())
		query.exclude = excluded
		var hit := world_3d.direct_space_state.intersect_ray(query)
		if hit.is_empty():
			print("[SPAWN GROUND] %d: sem superficie" % (spawn_index + 1))
			continue
		var collider := hit.get("collider") as Node
		print("[SPAWN GROUND] %d: y=%.3f collider=%s" % [
			spawn_index + 1,
			(hit["position"] as Vector3).y,
			collider.get_path() if collider else "desconhecido",
		])
