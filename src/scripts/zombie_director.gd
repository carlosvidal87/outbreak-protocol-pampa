extends Node3D

const ZOMBIE_SCENE := preload("res://assets/characters/Zombies/zombie.tscn")
const ZOMBIE_BODY_RADIUS := 0.34
const ZOMBIE_BODY_HEIGHT := 1.78
const ZOMBIE_BODY_SCALE := 1.15

@export_range(1, 100, 1) var minimum_population := 22
@export_range(1, 100, 1) var maximum_population := 28
@export_range(0.0, 1.0, 0.01) var runner_ratio := 0.15
@export_range(0.0, 1.0, 0.01) var aggressive_spawn_ratio := 0.35
@export var spawn_distance_min := 28.0
@export var spawn_distance_max := 65.0
@export var recycle_distance := 110.0
@export var spawn_interval := 0.7
@export_range(1, 32, 1) var candidate_attempts := 12
@export var navigation_projection_tolerance := 6.0
@export var outdoor_clearance_height := 12.0
@export_range(0.0, 4.0, 0.05) var population_multiplier := 1.0

var active_zombies: Array[Node3D] = []
var pooled_zombies: Array[Node3D] = []
var spawn_timer: Timer = null
var rng := RandomNumberGenerator.new()
var base_target_population := 0


func _ready() -> void:
	if multiplayer.multiplayer_peer and not multiplayer.is_server():
		return
	rng.randomize()
	base_target_population = rng.randi_range(mini(minimum_population, maximum_population), maxi(minimum_population, maximum_population))
	spawn_timer = Timer.new()
	spawn_timer.name = "PopulationTimer"
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_population_tick)
	add_child(spawn_timer)
	spawn_timer.start()


func _on_population_tick() -> void:
	_recycle_distant_zombies()
	var target_population := _get_target_population()
	if active_zombies.size() >= target_population:
		return
	var player := _get_primary_player()
	if not player:
		return
	var spawn_position := _find_spawn_position(player)
	if spawn_position == Vector3.INF:
		return
	_activate_zombie(spawn_position, player)


func _get_target_population() -> int:
	var scaled_max := roundi(maximum_population * population_multiplier)
	return clampi(roundi(base_target_population * population_multiplier), 0, maxi(scaled_max, 0))


func _get_primary_player() -> Node3D:
	for node in get_tree().get_nodes_in_group("player"):
		if node is Node3D and node.is_inside_tree():
			var player_state: Variant = node.get("player_state")
			if player_state == null or int(player_state) == 0:
				return node as Node3D
	return null


func _find_spawn_position(player: Node3D) -> Vector3:
	var nav_map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(nav_map) == 0:
		return Vector3.INF
	for _attempt in candidate_attempts:
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(spawn_distance_min, spawn_distance_max)
		var raw_position := player.global_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var nav_position := NavigationServer3D.map_get_closest_point(nav_map, raw_position)
		if nav_position.distance_to(raw_position) > navigation_projection_tolerance:
			continue
		var ground_position := _get_ground_position(nav_position)
		if ground_position == Vector3.INF:
			continue
		if not _has_complete_path(nav_map, ground_position, player.global_position):
			continue
		if not _has_outdoor_clearance(ground_position):
			continue
		if not _has_body_clearance(ground_position):
			continue
		if _is_visible_to_player(ground_position, player):
			continue
		return ground_position
	return Vector3.INF


func _get_ground_position(position: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 20.0, position + Vector3.DOWN * 40.0)
	query.collision_mask = 1
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Vector3.INF
	var normal: Vector3 = hit["normal"]
	if normal.dot(Vector3.UP) < cos(deg_to_rad(55.0)):
		return Vector3.INF
	var hit_position: Vector3 = hit["position"]
	return hit_position + Vector3.UP * 0.05


func _has_complete_path(nav_map: RID, from: Vector3, to: Vector3) -> bool:
	var path := NavigationServer3D.map_get_path(nav_map, from, to, true)
	if path.size() < 2:
		return false
	return path[0].distance_to(from) <= navigation_projection_tolerance and path[path.size() - 1].distance_to(to) <= navigation_projection_tolerance


func _has_outdoor_clearance(position: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(position + Vector3.UP, position + Vector3.UP * outdoor_clearance_height)
	query.collision_mask = 1
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _has_body_clearance(position: Vector3) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = ZOMBIE_BODY_RADIUS * ZOMBIE_BODY_SCALE
	capsule.height = ZOMBIE_BODY_HEIGHT * ZOMBIE_BODY_SCALE
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, position + Vector3.UP * ZOMBIE_BODY_HEIGHT * ZOMBIE_BODY_SCALE * 0.5)
	query.collision_mask = 3
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _is_visible_to_player(position: Vector3, player: Node3D) -> bool:
	for candidate in get_tree().get_nodes_in_group("player"):
		if not candidate is Node3D:
			continue
		var camera := (candidate as Node3D).get_node_or_null("Camera3D") as Camera3D
		if not camera or not camera.is_position_in_frustum(position + Vector3.UP):
			continue
		var query := PhysicsRayQueryParameters3D.create(camera.global_position, position + Vector3.UP)
		query.collision_mask = 1
		query.collide_with_areas = false
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			return true
	return false


func _activate_zombie(position: Vector3, player: Node3D) -> void:
	var zombie := _take_from_pool()
	var is_runner := _should_spawn_runner()
	var starts_aggressive := rng.randf() < aggressive_spawn_ratio
	active_zombies.append(zombie)
	zombie.call("activate_from_pool", position, player, is_runner, starts_aggressive)


func _should_spawn_runner() -> bool:
	var target_population := _get_target_population()
	var desired_runners := roundi(target_population * runner_ratio)
	var current_runners := 0
	for zombie in active_zombies:
		if bool(zombie.get("is_running")):
			current_runners += 1
	var runners_needed := maxi(desired_runners - current_runners, 0)
	var slots_remaining := maxi(target_population - active_zombies.size(), 1)
	return rng.randf() < float(runners_needed) / float(slots_remaining)


func _take_from_pool() -> Node3D:
	if not pooled_zombies.is_empty():
		return pooled_zombies.pop_back()
	var zombie := ZOMBIE_SCENE.instantiate() as Node3D
	zombie.name = "PooledZombie"
	zombie.set("managed_by_director", true)
	add_child(zombie, true)
	zombie.connect("recycle_requested", _on_zombie_recycle_requested)
	zombie.connect("stuck_detected", _on_zombie_stuck_detected)
	return zombie


func _recycle_distant_zombies() -> void:
	var player := _get_primary_player()
	if not player:
		return
	for zombie in active_zombies.duplicate():
		if not is_instance_valid(zombie):
			active_zombies.erase(zombie)
			continue
		if zombie.global_position.distance_to(player.global_position) > recycle_distance and not _is_visible_to_player(zombie.global_position, player):
			_recycle_zombie(zombie)


func _on_zombie_recycle_requested(zombie: Node3D) -> void:
	_recycle_zombie(zombie)


func _on_zombie_stuck_detected(zombie: Node3D) -> void:
	var player := _get_primary_player()
	if player and not _is_visible_to_player(zombie.global_position, player):
		_recycle_zombie(zombie)


func _recycle_zombie(zombie: Node3D) -> void:
	if not active_zombies.has(zombie):
		return
	active_zombies.erase(zombie)
	zombie.call("deactivate_to_pool")
	pooled_zombies.append(zombie)
