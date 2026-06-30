extends Node3D

const NAV_EXTENT := 260.0
const NAV_STEP := 8.0
const NAV_RAY_TOP := 220.0
const NAV_RAY_BOTTOM := -260.0
const NAV_SURFACE_OFFSET := 0.05
const NAV_MAX_CELL_HEIGHT_DELTA := 4.0
const CAMERA_FAR_DISTANCE := 600.0
const TERRAIN_DETAIL_DISTANCE := 500.0

var is_night := false
var world_environment: WorldEnvironment = null
var directional_light: DirectionalLight3D = null


func _ready() -> void:
	_cache_lighting_nodes()
	_apply_render_distance()
	_apply_night_state(false)

	await get_tree().physics_frame
	await get_tree().physics_frame

	_setup_navigation()
	_setup_spawner()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.physical_keycode == KEY_F8:
			is_night = not is_night
			_apply_night_state(is_night)
			get_viewport().set_input_as_handled()


func _setup_navigation() -> void:
	var old_region := get_node_or_null("GeneratedTerrainNavigation")
	if old_region:
		old_region.queue_free()

	var nav_region := NavigationRegion3D.new()
	nav_region.name = "GeneratedTerrainNavigation"
	nav_region.navigation_mesh = _build_terrain_navigation_mesh()
	add_child(nav_region)


func _build_terrain_navigation_mesh() -> NavigationMesh:
	var nav_mesh := NavigationMesh.new()
	var vertices := PackedVector3Array()
	var heights: Array[float] = []
	var points_per_axis := int((NAV_EXTENT * 2.0) / NAV_STEP) + 1

	for z_index in range(points_per_axis):
		for x_index in range(points_per_axis):
			var x := -NAV_EXTENT + float(x_index) * NAV_STEP
			var z := -NAV_EXTENT + float(z_index) * NAV_STEP
			var y := _sample_ground_height(Vector3(x, 0.0, z))
			heights.append(y)
			if y == INF:
				vertices.append(Vector3(x, 0.0, z))
			else:
				vertices.append(Vector3(x, y + NAV_SURFACE_OFFSET, z))

	nav_mesh.vertices = vertices

	for z_index in range(points_per_axis - 1):
		for x_index in range(points_per_axis - 1):
			var i0 := z_index * points_per_axis + x_index
			var i1 := i0 + 1
			var i2 := i0 + points_per_axis
			var i3 := i2 + 1
			if _cell_is_walkable(heights, [i0, i1, i2, i3]):
				nav_mesh.add_polygon(PackedInt32Array([i0, i2, i1]))
				nav_mesh.add_polygon(PackedInt32Array([i1, i2, i3]))

	return nav_mesh


func _cell_is_walkable(heights: Array[float], indices: Array[int]) -> bool:
	var min_height := INF
	var max_height := -INF
	for index in indices:
		var height := heights[index]
		if height == INF:
			return false
		min_height = minf(min_height, height)
		max_height = maxf(max_height, height)
	return max_height - min_height <= NAV_MAX_CELL_HEIGHT_DELTA


func _sample_ground_height(pos: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(pos.x, NAV_RAY_TOP, pos.z),
		Vector3(pos.x, NAV_RAY_BOTTOM, pos.z)
	)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.exclude = _get_navigation_raycast_excludes()

	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return INF

	var hit_position: Vector3 = hit["position"]
	return hit_position.y


func _get_navigation_raycast_excludes() -> Array[RID]:
	var excludes: Array[RID] = []
	for player in get_tree().get_nodes_in_group("player"):
		if player is CollisionObject3D:
			excludes.append((player as CollisionObject3D).get_rid())
	return excludes


func _setup_spawner() -> void:
	var spawner := Node3D.new()
	spawner.name = "Spawner"
	spawner.set_script(preload("res://src/scripts/spawner.gd"))
	add_child(spawner)


func _cache_lighting_nodes() -> void:
	world_environment = get_node_or_null("WorldEnvironment") as WorldEnvironment
	directional_light = get_node_or_null("DirectionalLight3D") as DirectionalLight3D


func _apply_render_distance() -> void:
	for node in _collect_nodes(self):
		if node is Camera3D:
			(node as Camera3D).far = CAMERA_FAR_DISTANCE
		elif node is DirectionalLight3D:
			(node as DirectionalLight3D).directional_shadow_max_distance = CAMERA_FAR_DISTANCE
		elif node.get("view_distance") != null:
			node.set("view_distance", TERRAIN_DETAIL_DISTANCE)
		elif node.has_method("set_view_distance"):
			node.call("set_view_distance", TERRAIN_DETAIL_DISTANCE)


func _collect_nodes(root: Node) -> Array[Node]:
	var nodes: Array[Node] = [root]
	for child in root.get_children():
		nodes.append_array(_collect_nodes(child))
	return nodes


func _apply_night_state(enabled: bool) -> void:
	if enabled:
		_apply_night_lighting()
	else:
		_apply_day_lighting()
	_set_player_flashlights(enabled)


func _apply_day_lighting() -> void:
	if world_environment and world_environment.environment:
		var env := world_environment.environment
		env.background_mode = Environment.BG_SKY
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_color = Color(0.7, 0.8, 0.9, 1.0)
		env.ambient_light_energy = 1.0
		env.ambient_light_sky_contribution = 0.85
		env.fog_enabled = true
		env.fog_light_color = Color(0.7, 0.8, 0.9, 1.0)
		env.fog_density = 0.001
		env.fog_sky_affect = 0.5
		if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
			var sky := env.sky.sky_material as ProceduralSkyMaterial
			sky.sky_top_color = Color(0.35, 0.55, 0.85, 1.0)
			sky.sky_horizon_color = Color(0.7, 0.8, 0.9, 1.0)
			sky.ground_bottom_color = Color(0.2, 0.16, 0.13, 1.0)
			sky.ground_horizon_color = Color(0.7, 0.8, 0.9, 1.0)

	if directional_light:
		directional_light.visible = true
		directional_light.light_color = Color(1.0, 0.95, 0.85, 1.0)
		directional_light.light_energy = 1.2
		directional_light.rotation_degrees = Vector3(-45.0, 30.0, 0.0)
		directional_light.directional_shadow_max_distance = CAMERA_FAR_DISTANCE


func _apply_night_lighting() -> void:
	if world_environment and world_environment.environment:
		var env := world_environment.environment
		env.background_mode = Environment.BG_SKY
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.07, 0.09, 0.16, 1.0)
		env.ambient_light_energy = 0.35
		env.ambient_light_sky_contribution = 0.25
		env.fog_enabled = true
		env.fog_light_color = Color(0.08, 0.1, 0.18, 1.0)
		env.fog_density = 0.0025
		env.fog_sky_affect = 0.35
		if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
			var sky := env.sky.sky_material as ProceduralSkyMaterial
			sky.sky_top_color = Color(0.015, 0.025, 0.06, 1.0)
			sky.sky_horizon_color = Color(0.05, 0.07, 0.12, 1.0)
			sky.ground_bottom_color = Color(0.01, 0.012, 0.018, 1.0)
			sky.ground_horizon_color = Color(0.03, 0.04, 0.07, 1.0)

	if directional_light:
		directional_light.visible = true
		directional_light.light_color = Color(0.55, 0.65, 1.0, 1.0)
		directional_light.light_energy = 0.38
		directional_light.rotation_degrees = Vector3(-65.0, -35.0, 0.0)
		directional_light.directional_shadow_max_distance = CAMERA_FAR_DISTANCE


func _set_player_flashlights(enabled: bool) -> void:
	for player in get_tree().get_nodes_in_group("player"):
		if player.has_method("set_flashlight_enabled"):
			player.call("set_flashlight_enabled", enabled)
