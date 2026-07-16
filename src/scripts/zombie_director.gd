extends Node3D

const IndustrialZone := preload("res://src/scripts/industrial_zone.gd")

const ZOMBIE_SCENE := preload("res://assets/characters/Zombies/zombie.tscn")
const SCRAP_PICKUP_SCENE := preload("res://src/scenes/scrap_pickup.tscn")
const BOSS_SCENE := preload("res://src/scenes/boss.tscn")
const FRAGMENTO_2_SCENE := preload("res://src/scenes/fragmento_2.tscn")
const ZOMBIE_BODY_RADIUS := 0.34
const ZOMBIE_BODY_HEIGHT := 1.78
const ZOMBIE_BODY_SCALE := 1.15
const MAX_ACTIVE_SCRAP_PICKUPS := 64
const COLLECTIBLE_HORDE_SIZES := [24, 36, 50]
const DIFFICULTY_STAGE_DURATION := 120.0
const HEALTH_INCREASE_PER_STAGE := 0.25
const MAX_HEALTH_MULTIPLIER := 4.0
const CALM_RUNNER_RATIO := 0.15
const CALM_RUNNER_DURATION := 120.0
const PRESSURE_RUNNER_DURATION := 60.0
const RUNNER_CYCLE_DURATION := CALM_RUNNER_DURATION + PRESSURE_RUNNER_DURATION
const DANGER_RUNNER_RATIO := 0.90
const DANGER_RUNNER_SPEED_MULTIPLIER := 1.12
const BOSS_COUNTDOWN := 8.0
const BOSS_POPULATION_MULTIPLIER := 1.75
const BOSS_SPAWN_INTERVAL := 0.30
const BOSS_SPAWN_MIN_DISTANCE := 20.0
const BOSS_SPAWN_INITIAL_MAX_DISTANCE := 30.0
const BOSS_SPAWN_FINAL_MAX_DISTANCE := 45.0
const BOSS_SPAWN_RETRY_INTERVAL := 0.5

@export_range(1, 100, 1) var minimum_population := 32
@export_range(1, 100, 1) var maximum_population := 40
@export_range(0.0, 1.0, 0.01) var runner_ratio := 0.45
@export_range(0.0, 1.0, 0.01) var aggressive_spawn_ratio := 0.85
@export var spawn_distance_min := 28.0
@export var spawn_distance_max := 65.0
@export var recycle_distance := 110.0
@export var spawn_interval := 0.45
@export_range(1, 32, 1) var candidate_attempts := 12
@export var navigation_projection_tolerance := 6.0
@export var outdoor_clearance_height := 12.0
@export_range(0.0, 4.0, 0.05) var population_multiplier := 1.0
@export_range(1.0, 30.0, 0.5) var collectible_horde_duration := 8.0
@export_range(1, 200, 1) var horde_population_limit := 180

var active_zombies: Array[Node3D] = []
var pooled_zombies: Array[Node3D] = []
var active_scrap_pickups: Array[Node3D] = []
var spawn_timer: Timer = null
var rng := RandomNumberGenerator.new()
var base_target_population := 0
var collectible_hordes_started := 0
var collectible_horde_jobs: Array[Dictionary] = []
var collected_horde_sources: Dictionary = {}
var boss_battle_requested := false
var boss_battle_active := false
var boss_spawned := false
var boss_countdown_remaining := 0.0
var boss_spawn_origin := Vector3.ZERO
var boss_spawn_retry_timer := 0.0
var match_elapsed := 0.0
var difficulty_stage := 0
var current_health_multiplier := 1.0


func _ready() -> void:
	add_to_group("zombie_director")
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


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.physical_keycode != KEY_P:
		return
	if multiplayer.multiplayer_peer and not multiplayer.is_server():
		_request_debug_fragmento_2_unlock.rpc_id(1)
	else:
		_debug_unlock_fragmento_2(multiplayer.get_unique_id() if multiplayer.multiplayer_peer else 1)
	get_viewport().set_input_as_handled()


@rpc("any_peer", "call_remote", "reliable")
func _request_debug_fragmento_2_unlock() -> void:
	if not OS.is_debug_build() or not multiplayer.is_server():
		return
	_debug_unlock_fragmento_2(multiplayer.get_remote_sender_id())


func _debug_unlock_fragmento_2(requester_peer_id := 0) -> void:
	if not _is_server_authority():
		return
	var unlocked_count := 0
	for fragmento_2 in get_tree().get_nodes_in_group("fragmentos_2"):
		if fragmento_2.has_method("unlock") and not bool(fragmento_2.get("collected")):
			fragmento_2.call("unlock")
			unlocked_count += 1
	if unlocked_count == 0 and not boss_battle_requested:
		var player := _get_player_for_peer(requester_peer_id)
		if player:
			_spawn_debug_fragmento_2(player)
			unlocked_count = 1
	print("[BOSS TEST] P liberou %d Fragmento(s) 2." % unlocked_count)


func _spawn_debug_fragmento_2(player: Node3D) -> void:
	var forward := -player.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		forward = Vector3.FORWARD
	var desired_position := player.global_position + forward.normalized() * 4.0
	var ground_position := _get_ground_position(desired_position)
	if ground_position == Vector3.INF:
		ground_position = desired_position
	var fragmento_2 := FRAGMENTO_2_SCENE.instantiate() as Node3D
	fragmento_2.name = "DebugFragmento2"
	fragmento_2.set("available", true)
	fragmento_2.position = to_local(ground_position)
	add_child(fragmento_2, true)


func _get_player_for_peer(peer_id: int) -> Node3D:
	for candidate in get_tree().get_nodes_in_group("player"):
		if not candidate is Node3D or not _is_living_player(candidate as Node3D):
			continue
		var candidate_peer: Variant = candidate.get("network_peer_id")
		if peer_id <= 0 or candidate_peer == null or int(candidate_peer) == peer_id:
			return candidate as Node3D
	return _get_primary_player()


func _process(delta: float) -> void:
	if boss_countdown_remaining > 0.0:
		boss_countdown_remaining = maxf(boss_countdown_remaining - delta, 0.0)
	if not _is_server_authority() or not _is_multiplayer_world_ready():
		return
	_update_time_difficulty(delta)
	if not collectible_horde_jobs.is_empty():
		_process_collectible_hordes(delta)
	_process_boss_spawn(delta)


func request_boss_battle(origin: Vector3, collector: Node3D) -> bool:
	if not _is_server_authority() or not _is_multiplayer_world_ready() or boss_battle_requested:
		return false
	if collector == null or not is_instance_valid(collector) or not _is_living_player(collector):
		return false
	boss_battle_requested = true
	boss_battle_active = true
	boss_spawn_origin = origin
	boss_spawn_retry_timer = 0.0
	population_multiplier = BOSS_POPULATION_MULTIPLIER
	if spawn_timer:
		spawn_timer.wait_time = BOSS_SPAWN_INTERVAL
	_intensify_existing_zombies_for_boss()
	if multiplayer.multiplayer_peer:
		_announce_boss_battle.rpc(BOSS_COUNTDOWN)
	else:
		_announce_boss_battle(BOSS_COUNTDOWN)
	return true


@rpc("authority", "call_local", "reliable")
func _announce_boss_battle(countdown: float) -> void:
	boss_battle_active = true
	boss_countdown_remaining = maxf(countdown, 0.0)


@rpc("authority", "call_local", "reliable")
func _announce_boss_spawned() -> void:
	boss_spawned = true
	boss_countdown_remaining = 0.0


func _process_boss_spawn(delta: float) -> void:
	if not boss_battle_requested or boss_spawned or boss_countdown_remaining > 0.0:
		return
	boss_spawn_retry_timer -= delta
	if boss_spawn_retry_timer > 0.0:
		return
	boss_spawn_retry_timer = BOSS_SPAWN_RETRY_INTERVAL
	var reference_player := _get_nearest_living_player(boss_spawn_origin)
	if not reference_player:
		return
	var spawn_position := _find_boss_spawn_position(reference_player)
	if spawn_position == Vector3.INF:
		return
	_spawn_boss(spawn_position)


func _find_boss_spawn_position(reference_player: Node3D) -> Vector3:
	if IndustrialZone.contains(boss_spawn_origin, 10.0):
		var industrial_position := _find_industrial_boss_spawn_position(reference_player)
		if industrial_position != Vector3.INF:
			return industrial_position
	var nav_map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(nav_map) == 0:
		return Vector3.INF
	for max_distance in [BOSS_SPAWN_INITIAL_MAX_DISTANCE, 35.0, 40.0, BOSS_SPAWN_FINAL_MAX_DISTANCE]:
		for _attempt in candidate_attempts:
			var angle := rng.randf_range(0.0, TAU)
			var radius := rng.randf_range(BOSS_SPAWN_MIN_DISTANCE, max_distance)
			var raw_position := boss_spawn_origin + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
			var nav_position := NavigationServer3D.map_get_closest_point(nav_map, raw_position)
			if nav_position.distance_to(raw_position) > navigation_projection_tolerance:
				continue
			var ground_position := _get_ground_position(nav_position)
			if ground_position == Vector3.INF:
				continue
			if not _has_complete_path(nav_map, ground_position, reference_player.global_position):
				continue
			if not _has_outdoor_clearance(ground_position) or not _has_boss_body_clearance(ground_position):
				continue
			return ground_position
	return Vector3.INF


func _find_industrial_boss_spawn_position(reference_player: Node3D) -> Vector3:
	for max_distance: float in [BOSS_SPAWN_INITIAL_MAX_DISTANCE, 35.0, 40.0, BOSS_SPAWN_FINAL_MAX_DISTANCE]:
		for _attempt in candidate_attempts * 4:
			var angle := rng.randf_range(0.0, TAU)
			var radius := rng.randf_range(BOSS_SPAWN_MIN_DISTANCE, max_distance)
			var raw_position := boss_spawn_origin + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
			if not IndustrialZone.contains_strict(raw_position, 3.0):
				continue
			var ground_position := _get_industrial_ground_position(raw_position)
			if ground_position == Vector3.INF:
				continue
			if not _has_outdoor_clearance(ground_position) or not _has_boss_body_clearance(ground_position):
				continue
			if ground_position.distance_to(reference_player.global_position) < BOSS_SPAWN_MIN_DISTANCE:
				continue
			return ground_position
	return Vector3.INF


func _has_boss_body_clearance(position: Vector3) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 1.725
	capsule.height = 9.225
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, position + Vector3.UP * 4.62)
	query.collision_mask = 3
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _spawn_boss(spawn_position: Vector3) -> void:
	var boss := BOSS_SCENE.instantiate() as CharacterBody3D
	boss.name = "FinalBoss"
	boss.position = to_local(spawn_position)
	boss.call("setup_for_players", _count_living_players())
	boss.connect("boss_died", _on_boss_died)
	add_child(boss, true)
	if multiplayer.multiplayer_peer:
		_announce_boss_spawned.rpc()
	else:
		_announce_boss_spawned()


func _on_boss_died() -> void:
	var game_session := get_node_or_null("../GameSession")
	if game_session and game_session.has_method("complete_map"):
		game_session.call("complete_map")


func _count_living_players() -> int:
	var count := 0
	for candidate in get_tree().get_nodes_in_group("player"):
		if candidate is Node3D and _is_living_player(candidate as Node3D):
			count += 1
	return maxi(count, 1)


func _is_living_player(candidate: Node3D) -> bool:
	if not candidate.is_inside_tree() or not candidate.is_in_group("player"):
		return false
	var player_state: Variant = candidate.get("player_state")
	return player_state == null or int(player_state) == 0


func request_collectible_horde(origin: Vector3, source: Node) -> bool:
	if not _is_server_authority() or not _is_multiplayer_world_ready():
		return false
	if source == null or not is_instance_valid(source):
		return false
	if collectible_hordes_started >= COLLECTIBLE_HORDE_SIZES.size():
		return false
	if not _get_nearest_living_player(origin):
		return false
	var source_id: int = source.get_instance_id()
	if collected_horde_sources.has(source_id):
		return false
	var horde_size: int = COLLECTIBLE_HORDE_SIZES[collectible_hordes_started]
	var runner_plan: Array[bool] = []
	var runner_total: int = roundi(float(horde_size) * DANGER_RUNNER_RATIO)
	for index in horde_size:
		runner_plan.append(index < runner_total)
	runner_plan.shuffle()
	collected_horde_sources[source_id] = true
	collectible_hordes_started += 1
	collectible_horde_jobs.append({
		"origin": origin,
		"total": horde_size,
		"spawned": 0,
		"elapsed": 0.0,
		"runner_plan": runner_plan,
	})
	if collectible_hordes_started == COLLECTIBLE_HORDE_SIZES.size():
		_unlock_fragmento_2()
	return true


func _unlock_fragmento_2() -> void:
	for fragmento_2 in get_tree().get_nodes_in_group("fragmentos_2"):
		if fragmento_2.has_method("unlock"):
			fragmento_2.call("unlock")


func _process_collectible_hordes(delta: float) -> void:
	for job in collectible_horde_jobs.duplicate():
		job["elapsed"] = float(job["elapsed"]) + delta
		var total: int = int(job["total"])
		var elapsed: float = float(job["elapsed"])
		var progress: float = clampf(elapsed / collectible_horde_duration, 0.0, 1.0)
		var desired_spawned: int = mini(ceili(progress * total), total)
		while int(job["spawned"]) < desired_spawned and active_zombies.size() < horde_population_limit:
			var origin: Vector3 = job["origin"]
			var player: Node3D = _get_nearest_living_player(origin)
			if not player:
				break
			var spawn_position: Vector3 = _find_spawn_position(player)
			if spawn_position == Vector3.INF:
				break
			var runner_plan: Array = job["runner_plan"]
			var spawn_index: int = int(job["spawned"])
			_activate_zombie(spawn_position, player, true, 1 if bool(runner_plan[spawn_index]) else 0)
			job["spawned"] = int(job["spawned"]) + 1
		if int(job["spawned"]) >= total:
			collectible_horde_jobs.erase(job)


func _update_time_difficulty(delta: float) -> void:
	match_elapsed = maxf(match_elapsed + delta, 0.0)
	var new_stage: int = floori(match_elapsed / DIFFICULTY_STAGE_DURATION)
	if new_stage <= difficulty_stage:
		return
	difficulty_stage = new_stage
	current_health_multiplier = minf(1.0 + float(difficulty_stage) * HEALTH_INCREASE_PER_STAGE, MAX_HEALTH_MULTIPLIER)
	for zombie in active_zombies:
		if not is_instance_valid(zombie) or not zombie.has_method("set_difficulty"):
			continue
		var speed_multiplier: float = float(zombie.get("difficulty_runner_speed_multiplier"))
		zombie.call("set_difficulty", current_health_multiplier, speed_multiplier)
	for zombie in pooled_zombies:
		if is_instance_valid(zombie) and zombie.has_method("set_difficulty"):
			zombie.call("set_difficulty", current_health_multiplier, 1.0)


func _intensify_existing_zombies_for_boss() -> void:
	var living_zombies: Array[Node3D] = []
	for zombie in active_zombies:
		if is_instance_valid(zombie) and not bool(zombie.get("is_dead")):
			living_zombies.append(zombie)
	living_zombies.shuffle()
	var runner_total: int = roundi(float(living_zombies.size()) * DANGER_RUNNER_RATIO)
	for index in living_zombies.size():
		var zombie: Node3D = living_zombies[index]
		var becomes_runner: bool = index < runner_total
		zombie.set("is_running", becomes_runner)
		if zombie.has_method("set_difficulty"):
			zombie.call("set_difficulty", current_health_multiplier, DANGER_RUNNER_SPEED_MULTIPLIER if becomes_runner else 1.0)
		var nearest_player := _get_nearest_living_player(zombie.global_position)
		if nearest_player:
			zombie.set("player", nearest_player)
			zombie.call("_change_state", zombie.State.CHASE)


func _on_population_tick() -> void:
	if not _is_multiplayer_world_ready():
		return
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


func _is_multiplayer_world_ready() -> bool:
	if not multiplayer.multiplayer_peer:
		return true
	var game_session := get_node_or_null("../GameSession")
	return game_session != null and game_session.has_method("is_multiplayer_world_ready") and bool(game_session.call("is_multiplayer_world_ready"))


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


func _get_nearest_living_player(origin: Vector3) -> Node3D:
	var nearest: Node3D = null
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group("player"):
		if not node is Node3D or not node.is_inside_tree():
			continue
		var player_state: Variant = node.get("player_state")
		if player_state != null and int(player_state) != 0:
			continue
		var distance := (node as Node3D).global_position.distance_squared_to(origin)
		if distance < nearest_distance:
			nearest = node as Node3D
			nearest_distance = distance
	return nearest


func _find_spawn_position(player: Node3D) -> Vector3:
	if IndustrialZone.contains(player.global_position, 10.0):
		var industrial_position := _find_industrial_spawn_position(player)
		if industrial_position != Vector3.INF:
			return industrial_position
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


func _find_industrial_spawn_position(player: Node3D) -> Vector3:
	for _attempt in candidate_attempts * 4:
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(spawn_distance_min, spawn_distance_max)
		var raw_position := player.global_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		if not IndustrialZone.contains_strict(raw_position, 2.0):
			continue
		var ground_position := _get_industrial_ground_position(raw_position)
		if ground_position == Vector3.INF:
			continue
		if not _has_outdoor_clearance(ground_position) or not _has_body_clearance(ground_position):
			continue
		if _is_visible_to_player(ground_position, player):
			continue
		return ground_position
	return Vector3.INF


func _get_industrial_ground_position(position: Vector3) -> Vector3:
	var ray_start := Vector3(position.x, IndustrialZone.FLOOR_Y + 2.0, position.z)
	var ray_end := Vector3(position.x, IndustrialZone.FLOOR_Y - 3.0, position.z)
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collision_mask = 1
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Vector3.INF
	var normal: Vector3 = hit["normal"]
	var hit_position: Vector3 = hit["position"]
	if normal.dot(Vector3.UP) < cos(deg_to_rad(55.0)) or not IndustrialZone.is_floor_height(hit_position.y):
		return Vector3.INF
	return hit_position + Vector3.UP * 0.05


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


func _activate_zombie(position: Vector3, player: Node3D, is_horde_spawn := false, runner_override: int = -1) -> void:
	var zombie := _take_from_pool()
	var danger_spawn: bool = is_horde_spawn or boss_battle_active
	var is_runner: bool = bool(runner_override) if runner_override >= 0 else (_should_spawn_runner_for_ratio(DANGER_RUNNER_RATIO) if danger_spawn else _should_spawn_runner())
	var starts_aggressive: bool = true if danger_spawn else rng.randf() < aggressive_spawn_ratio
	var speed_multiplier: float = DANGER_RUNNER_SPEED_MULTIPLIER if danger_spawn and is_runner else 1.0
	if zombie.has_method("set_difficulty"):
		zombie.call("set_difficulty", current_health_multiplier, speed_multiplier)
	active_zombies.append(zombie)
	zombie.call("activate_from_pool", position, player, is_runner, starts_aggressive)


func _should_spawn_runner() -> bool:
	return _should_spawn_runner_for_ratio(_get_current_normal_runner_ratio())


func _get_current_normal_runner_ratio() -> float:
	var cycle_elapsed := fposmod(match_elapsed, RUNNER_CYCLE_DURATION)
	return CALM_RUNNER_RATIO if cycle_elapsed < CALM_RUNNER_DURATION else runner_ratio


func _should_spawn_runner_for_ratio(target_ratio: float) -> bool:
	var target_population := _get_target_population()
	var desired_runners := roundi(target_population * clampf(target_ratio, 0.0, 1.0))
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
	zombie.connect("zombie_died", _on_zombie_died)
	return zombie


func _on_zombie_died(death_position: Vector3) -> void:
	if multiplayer.multiplayer_peer and not multiplayer.is_server():
		return
	_spawn_scrap_pickup(death_position, _roll_scrap_value())


func _roll_scrap_value(forced_roll: float = -1.0) -> int:
	var roll := rng.randf() if forced_roll < 0.0 else clampf(forced_roll, 0.0, 0.999999)
	if roll < 0.60:
		return 50
	if roll < 0.85:
		return 75
	if roll < 0.97:
		return 125
	return 250


func _spawn_scrap_pickup(death_position: Vector3, value: int) -> void:
	if value <= 0:
		return
	_prune_scrap_pickups()
	if active_scrap_pickups.size() >= MAX_ACTIVE_SCRAP_PICKUPS:
		var nearest := _find_nearest_scrap_pickup(death_position)
		if nearest and bool(nearest.call("add_scrap", value)):
			return
	var pickup := SCRAP_PICKUP_SCENE.instantiate() as Node3D
	pickup.name = "ScrapPickup"
	pickup.set("scrap_value", value)
	pickup.position = to_local(death_position + Vector3.UP * 0.05)
	pickup.tree_exiting.connect(_on_scrap_pickup_exiting.bind(pickup))
	active_scrap_pickups.append(pickup)
	add_child(pickup, true)


func _find_nearest_scrap_pickup(world_position: Vector3) -> Node3D:
	var nearest: Node3D = null
	var nearest_distance := INF
	for pickup in active_scrap_pickups:
		if not is_instance_valid(pickup) or bool(pickup.get("collected")):
			continue
		var distance := pickup.global_position.distance_squared_to(world_position)
		if distance < nearest_distance:
			nearest = pickup
			nearest_distance = distance
	return nearest


func _prune_scrap_pickups() -> void:
	for pickup in active_scrap_pickups.duplicate():
		if not is_instance_valid(pickup) or pickup.is_queued_for_deletion():
			active_scrap_pickups.erase(pickup)


func _on_scrap_pickup_exiting(pickup: Node3D) -> void:
	active_scrap_pickups.erase(pickup)


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


func _is_server_authority() -> bool:
	return not multiplayer.multiplayer_peer or multiplayer.is_server()
