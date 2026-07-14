extends Node3D

const ZOMBIE_SCENE := preload("res://assets/characters/Zombies/zombie.tscn")
const SPAWN_RADIUS_MIN := 10.0
const SPAWN_RADIUS_MAX := 20.0
const MAX_CONCURRENT_ZOMBIES := 10
const SPAWN_COOLDOWN := 2.0
const INITIAL_SPAWN_DELAY := 1.0
const ZOMBIE_DROPS_ENABLED := false

var zombies_active := 0
var kill_count := 0
var spawn_timer: Timer = null


func _ready() -> void:
	spawn_timer = Timer.new()
	spawn_timer.name = "SpawnTimer"
	spawn_timer.wait_time = SPAWN_COOLDOWN
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)

	await NavigationServer3D.map_changed
	spawn_timer.start(INITIAL_SPAWN_DELAY)


func _on_spawn_timer_timeout() -> void:
	if zombies_active >= MAX_CONCURRENT_ZOMBIES:
		return
	_spawn_zombie()


func _spawn_zombie() -> void:
	var player_group := get_tree().get_nodes_in_group("player")
	if player_group.is_empty():
		return
	var player_pos: Vector3 = player_group[0].global_position

	var angle := randf() * TAU
	var radius := randf_range(SPAWN_RADIUS_MIN, SPAWN_RADIUS_MAX)
	var raw_pos := player_pos + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)

	var nav_map := get_world_3d().navigation_map
	var safe_pos := NavigationServer3D.map_get_closest_point(nav_map, raw_pos)
	safe_pos = _snap_position_to_ground(safe_pos)

	var zombie := ZOMBIE_SCENE.instantiate()
	get_tree().current_scene.add_child(zombie)
	zombie.global_position = safe_pos
	zombie.zombie_died.connect(_on_zombie_died)

	zombies_active += 1


func _on_zombie_died(death_pos: Vector3) -> void:
	kill_count += 1
	zombies_active = maxi(zombies_active - 1, 0)

	if ZOMBIE_DROPS_ENABLED and randf() < 0.12:
		_spawn_powerup_at(death_pos)


func _spawn_powerup_at(pos: Vector3) -> void:
	var powerup_types = ["max_ammo", "insta_kill", "nuke"]
	var selected_type = powerup_types[randi() % powerup_types.size()]

	var powerup_script = preload("res://src/scripts/powerup.gd")
	var powerup = Node3D.new()
	powerup.set_script(powerup_script)
	powerup.type = selected_type
	get_tree().current_scene.add_child(powerup)
	powerup.global_position = _snap_position_to_ground(pos)
	print("[SPAWNER] Dropped power-up: ", selected_type, " em ", powerup.global_position)


func _snap_position_to_ground(pos: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(
		pos + Vector3.UP * 80.0,
		pos + Vector3.DOWN * 160.0
	)
	query.collision_mask = 1
	query.collide_with_areas = false
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return pos
	var hit_position: Vector3 = hit["position"]
	return hit_position + Vector3.UP * 0.05
