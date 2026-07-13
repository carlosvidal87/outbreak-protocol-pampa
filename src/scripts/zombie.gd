extends CharacterBody3D

signal zombie_died(death_position: Vector3)
signal recycle_requested(zombie: Node3D)
signal stuck_detected(zombie: Node3D)

const BASE_HP := 100.0
const BASE_SPEED := 2.0
const RUN_SPEED := 3.2
const ATTACK_RANGE := 2.0
const ATTACK_DAMAGE := 10.0
const ATTACK_COOLDOWN := 1.5
const NAV_TARGET_UPDATE_INTERVAL := 0.25
const TERRAIN_FLOOR_SNAP := 0.6
const DEATH_CLEANUP_DELAY := 2.5
const DETECTION_DISTANCE := 28.0
const LOSE_TARGET_DISTANCE := 45.0
const WANDER_RADIUS := 12.0
const WANDER_TARGET_INTERVAL := 3.0
const SEARCH_DURATION := 5.0
const STUCK_CHECK_INTERVAL := 2.0
const STUCK_MIN_PROGRESS := 0.35
const STUCK_REPATH_ATTEMPTS := 2
const OBSTACLE_PROBE_DISTANCE := 1.2
const NETWORK_INTERPOLATION_SPEED := 14.0
const NETWORK_SNAP_DISTANCE := 10.0

const ANIM_IDLE := "idle"
const ANIM_WALK := "walk"
const ANIM_RUN := "run"
const ANIM_ATTACK := "attack"
const ANIM_DIE := "die"

const HITBOX_BONES := {
	"CollisionShape3D10": "mixamorig5_Head",
	"CollisionShape3D8": "mixamorig5_Spine2",
	"CollisionShape3D6": "mixamorig5_Spine1",
	"CollisionShape3D2": "mixamorig5_RightFoot",
	"CollisionShape3D3": "mixamorig5_RightUpLeg",
	"CollisionShape3D4": "mixamorig5_LeftFoot",
	"CollisionShape3D5": "mixamorig5_LeftUpLeg",
	"CollisionShape3D7": "mixamorig5_RightArm",
	"CollisionShape3D9": "mixamorig5_LeftArm",
}

enum State { WANDER, CHASE, ATTACK, SEARCH, DEATH }

static var cached_walk_speed := -1.0
static var cached_run_speed := -1.0
static var cached_attack_impact_delay := -1.0

@export var max_hp := BASE_HP
@export var move_speed := BASE_SPEED
@export var run_speed := RUN_SPEED
@export var is_running := false
@export var synchronize_speed_with_animation := true
@export_range(1.0, 1.25, 0.01) var body_scale := 1.15
@export_range(1.0, 1.5, 0.05) var chase_speed_multiplier := 1.10
@export_range(1.0, 2.0, 0.05) var behind_player_speed_multiplier := 1.45

var state := State.WANDER
var hp := BASE_HP
var attack_timer := 0.0
var attack_impact_delay := 0.0
var attack_sequence := 0
var nav_target_timer := 0.0
var is_dead := false
var player: Node3D = null
var anim_player: AnimationPlayer = null
var hitbox_skeleton: Skeleton3D = null
var animated_hitboxes: Array[Dictionary] = []
var managed_by_director := false
var spawn_origin := Vector3.ZERO
var last_known_player_position := Vector3.ZERO
var state_timer := 0.0
var wander_target_timer := 0.0
var stuck_check_timer := STUCK_CHECK_INTERVAL
var stuck_attempts := 0
var last_progress_position := Vector3.ZERO
var avoidance_velocity := Vector3.ZERO
var next_target_selection_ms := 0
var replicated_visual_state := -1
var replicated_visual_runner := false
var replicated_attack_sequence := -1
var network_position := Vector3.ZERO
var network_rotation := Vector3.ZERO

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D


func _ready() -> void:
	add_to_group("zombies")
	add_to_group("enemies")
	floor_max_angle = deg_to_rad(55.0)
	floor_snap_length = TERRAIN_FLOOR_SNAP
	scale = Vector3.ONE * body_scale
	network_position = position
	network_rotation = rotation
	hp = max_hp
	anim_player = _find_anim_player(self)
	_attach_hitboxes_to_skeleton()
	_configure_animation_loops()
	_synchronize_locomotion_speed()
	if cached_attack_impact_delay < 0.0:
		cached_attack_impact_delay = _measure_attack_impact_time()
	attack_impact_delay = cached_attack_impact_delay
	_connect_animation_finished()
	_configure_navigation_avoidance()

	set_physics_process(false)
	await get_tree().physics_frame
	player = _find_player()
	spawn_origin = global_position
	last_progress_position = global_position
	nav_target_timer = randf() * NAV_TARGET_UPDATE_INTERVAL
	set_physics_process(not multiplayer.multiplayer_peer or multiplayer.is_server())
	_play_move_anim()


func _physics_process(delta: float) -> void:
	if is_dead or not player or not is_inside_tree():
		return

	if not is_on_floor():
		velocity.y += get_gravity().y * delta

	var dist_sq := global_position.distance_squared_to(player.global_position)
	var attack_range_sq := ATTACK_RANGE * ATTACK_RANGE

	match state:
		State.WANDER:
			_update_perception()
			_update_wander(delta)

		State.CHASE:
			_update_perception()
			_update_navigation_target(delta, player.global_position)
			if dist_sq <= attack_range_sq:
				_change_state(State.ATTACK)
			else:
				_move_on_navigation(delta, _get_chase_speed())

		State.ATTACK:
			velocity.x = 0.0
			velocity.z = 0.0
			_face_player(delta)
			attack_timer -= delta
			if attack_timer <= 0.0:
				attack_timer = ATTACK_COOLDOWN
				_do_attack()
			if dist_sq > attack_range_sq * 4.0:
				_change_state(State.CHASE)

		State.SEARCH:
			_update_perception()
			state_timer -= delta
			_update_navigation_target(delta, last_known_player_position)
			_move_on_navigation(delta, move_speed)
			if state_timer <= 0.0 or nav_agent.is_navigation_finished():
				_change_state(State.WANDER)

	move_and_slide()
	_publish_network_transform()
	_update_stuck_detection(delta)


func _process(delta: float) -> void:
	if multiplayer.multiplayer_peer and not multiplayer.is_server():
		_interpolate_network_transform(delta)
		_update_replicated_visual()
	_update_animated_hitboxes()


func _update_replicated_visual() -> void:
	if replicated_visual_state == state and replicated_visual_runner == is_running and replicated_attack_sequence == attack_sequence:
		return
	replicated_visual_state = state
	replicated_visual_runner = is_running
	replicated_attack_sequence = attack_sequence
	match state:
		State.ATTACK:
			_play_anim(ANIM_ATTACK)
		State.DEATH:
			_play_anim(ANIM_DIE)
		State.CHASE:
			_play_anim(ANIM_RUN if is_running else ANIM_WALK)
		_:
			_play_anim(ANIM_WALK)


func take_damage(amount: float, is_headshot: bool = false) -> void:
	if is_dead:
		return
	if multiplayer.multiplayer_peer and not multiplayer.is_server():
		return
	hp = maxf(hp - amount, 0.0)
	if hp <= 0.0:
		_die(is_headshot)
		return
	_play_move_anim()


func _publish_network_transform() -> void:
	if not multiplayer.multiplayer_peer or not multiplayer.is_server():
		return
	network_position = position
	network_rotation = rotation


func _interpolate_network_transform(delta: float) -> void:
	if position.distance_to(network_position) > NETWORK_SNAP_DISTANCE:
		position = network_position
		rotation = network_rotation
		return
	var weight := 1.0 - exp(-NETWORK_INTERPOLATION_SPEED * delta)
	position = position.lerp(network_position, weight)
	rotation.x = lerp_angle(rotation.x, network_rotation.x, weight)
	rotation.y = lerp_angle(rotation.y, network_rotation.y, weight)
	rotation.z = lerp_angle(rotation.z, network_rotation.z, weight)


func _do_attack() -> void:
	if anim_player:
		anim_player.speed_scale = 1.0
	_play_anim(ANIM_ATTACK)
	attack_sequence += 1
	var sequence: int = attack_sequence
	get_tree().create_timer(attack_impact_delay).timeout.connect(_apply_attack_damage.bind(sequence))


func _apply_attack_damage(sequence: int) -> void:
	if is_dead or state != State.ATTACK or sequence != attack_sequence:
		return
	if not player or global_position.distance_to(player.global_position) > ATTACK_RANGE:
		return
	if player.has_method("take_damage"):
		player.take_damage(ATTACK_DAMAGE)


func _die(is_headshot: bool = false) -> void:
	is_dead = true
	state = State.DEATH
	velocity = Vector3.ZERO
	set_physics_process(false)
	_disable_hitboxes()
	_play_anim(ANIM_DIE)
	if is_headshot:
		_handle_headshot_visual()
	zombie_died.emit(global_position)
	if managed_by_director:
		get_tree().create_timer(DEATH_CLEANUP_DELAY).timeout.connect(func() -> void:
			recycle_requested.emit(self)
		)
	else:
		get_tree().create_timer(DEATH_CLEANUP_DELAY).timeout.connect(queue_free)


func _update_navigation_target(delta: float, target_position: Vector3) -> void:
	nav_target_timer -= delta
	if nav_target_timer > 0.0:
		return
	var nav_map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(nav_map) == 0:
		nav_target_timer = NAV_TARGET_UPDATE_INTERVAL
		return
	nav_agent.target_position = NavigationServer3D.map_get_closest_point(nav_map, target_position)
	nav_target_timer = NAV_TARGET_UPDATE_INTERVAL


func _move_on_navigation(delta: float, speed: float) -> void:
	var dir := _get_chase_direction()
	if dir.length_squared() <= 0.001:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	dir = dir.normalized()
	dir = _steer_around_obstacle(dir)
	var desired_velocity := dir * speed
	avoidance_velocity = desired_velocity
	if nav_agent.avoidance_enabled:
		nav_agent.velocity = desired_velocity
	velocity.x = avoidance_velocity.x
	velocity.z = avoidance_velocity.z
	_face_direction(dir, delta)
	_update_locomotion_playback(speed)
	_play_move_anim()


func _get_chase_speed() -> float:
	var base_speed := run_speed if is_running else move_speed
	var chase_speed := base_speed * chase_speed_multiplier
	if not player:
		return chase_speed
	var player_to_zombie := global_position - player.global_position
	player_to_zombie.y = 0.0
	if player_to_zombie.length_squared() <= 0.001:
		return chase_speed
	var player_backward := player.global_transform.basis.z
	player_backward.y = 0.0
	if player_backward.length_squared() > 0.001 and player_to_zombie.normalized().dot(player_backward.normalized()) > 0.0:
		return chase_speed * behind_player_speed_multiplier
	return chase_speed


func _update_locomotion_playback(actual_speed: float) -> void:
	if not anim_player:
		return
	var reference_speed := (run_speed if is_running else move_speed) * chase_speed_multiplier
	anim_player.speed_scale = actual_speed / maxf(reference_speed, 0.001)


func _steer_around_obstacle(direction: Vector3) -> Vector3:
	if not _direction_hits_obstacle(direction):
		return direction
	var left := Vector3(-direction.z, 0.0, direction.x).normalized()
	var right := -left
	var left_direction := (direction + left).normalized()
	var right_direction := (direction + right).normalized()
	var left_blocked := _direction_hits_obstacle(left_direction)
	var right_blocked := _direction_hits_obstacle(right_direction)
	if not left_blocked:
		return left_direction
	if not right_blocked:
		return right_direction
	return -direction


func _direction_hits_obstacle(direction: Vector3) -> bool:
	var origin := global_position + Vector3.UP * 0.75
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * OBSTACLE_PROBE_DISTANCE)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _get_chase_direction() -> Vector3:
	var nav_map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(nav_map) > 0 and not nav_agent.is_navigation_finished():
		var next := nav_agent.get_next_path_position()
		var nav_dir := next - global_position
		nav_dir.y = 0.0
		if nav_dir.length_squared() > 0.001:
			return nav_dir

	var direct_dir := nav_agent.target_position - global_position
	direct_dir.y = 0.0
	return direct_dir


func _update_wander(delta: float) -> void:
	wander_target_timer -= delta
	if wander_target_timer <= 0.0 or nav_agent.is_navigation_finished():
		_choose_wander_target()
	_move_on_navigation(delta, move_speed)


func _choose_wander_target() -> void:
	var nav_map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(nav_map) == 0:
		return
	var angle := randf() * TAU
	var distance := randf_range(WANDER_RADIUS * 0.35, WANDER_RADIUS)
	var raw_target := spawn_origin + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
	nav_agent.target_position = NavigationServer3D.map_get_closest_point(nav_map, raw_target)
	wander_target_timer = WANDER_TARGET_INTERVAL


func _update_perception() -> void:
	var now := Time.get_ticks_msec()
	if now >= next_target_selection_ms:
		var nearest_player := _find_player()
		if nearest_player:
			player = nearest_player
		next_target_selection_ms = now + 650 + randi_range(0, 250)
	if not player:
		player = _find_player()
		if not player:
			return
	var distance := global_position.distance_to(player.global_position)
	if state == State.CHASE and distance > LOSE_TARGET_DISTANCE and not _has_line_of_sight_to_player():
		last_known_player_position = player.global_position
		_change_state(State.SEARCH)
		return
	if state in [State.WANDER, State.SEARCH] and distance <= DETECTION_DISTANCE and _has_line_of_sight_to_player():
		last_known_player_position = player.global_position
		_change_state(State.CHASE)


func _has_line_of_sight_to_player() -> bool:
	if not player:
		return false
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.4, player.global_position + Vector3.UP * 1.0)
	query.collision_mask = 3
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == player


func _face_player(delta: float) -> void:
	if not player:
		return
	var dir := player.global_position - global_position
	dir.y = 0.0
	if dir.length_squared() < 0.001:
		return
	_face_direction(dir.normalized(), delta)


func _face_direction(dir: Vector3, delta: float) -> void:
	var target_angle := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, target_angle, 10.0 * delta)


func _change_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	match state:
		State.WANDER:
			wander_target_timer = 0.0
			_play_move_anim()
		State.CHASE:
			if player:
				last_known_player_position = player.global_position
			_play_move_anim()
		State.ATTACK:
			attack_timer = 0.0
		State.SEARCH:
			state_timer = SEARCH_DURATION
			_play_move_anim()


func get_state_name() -> StringName:
	return StringName(State.keys()[state])


func _play_move_anim() -> void:
	if state == State.ATTACK or is_dead:
		return
	_play_anim(ANIM_RUN if is_running else ANIM_WALK)


func _play_anim(anim_name: String) -> void:
	if not anim_player:
		push_warning("Zombie sem AnimationPlayer.")
		return
	if not anim_player.has_animation(anim_name):
		push_warning("Zombie sem animacao obrigatoria: %s" % anim_name)
		return
	if anim_name not in [ANIM_WALK, ANIM_RUN]:
		anim_player.speed_scale = 1.0
	if anim_player.current_animation != anim_name:
		anim_player.play(anim_name, 0.12)


func _configure_animation_loops() -> void:
	if not anim_player:
		return
	for anim_name in [ANIM_IDLE, ANIM_WALK, ANIM_RUN]:
		if anim_player.has_animation(anim_name):
			anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	for anim_name in [ANIM_ATTACK, ANIM_DIE]:
		if anim_player.has_animation(anim_name):
			anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_NONE


func _synchronize_locomotion_speed() -> void:
	if not synchronize_speed_with_animation or not anim_player or not hitbox_skeleton:
		return
	if cached_walk_speed < 0.0:
		cached_walk_speed = _measure_animation_travel_speed(ANIM_WALK)
	if cached_run_speed < 0.0:
		cached_run_speed = _measure_animation_travel_speed(ANIM_RUN)
	if cached_walk_speed > 0.0:
		move_speed = cached_walk_speed
	if cached_run_speed > 0.0:
		run_speed = cached_run_speed


func _measure_animation_travel_speed(animation_name: String) -> float:
	if not anim_player.has_animation(animation_name):
		return 0.0
	var animation := anim_player.get_animation(animation_name)
	if animation.length <= 0.0:
		return 0.0
	var left_foot := hitbox_skeleton.find_bone("mixamorig5_LeftFoot")
	var right_foot := hitbox_skeleton.find_bone("mixamorig5_RightFoot")
	if left_foot == -1 or right_foot == -1:
		return 0.0

	var key_times: Array[float] = [0.0, animation.length]
	for track_index in animation.get_track_count():
		for key_index in animation.track_get_key_count(track_index):
			var key_time := animation.track_get_key_time(track_index, key_index)
			if not key_times.has(key_time):
				key_times.append(key_time)
	key_times.sort()

	var left_min := INF
	var left_max := -INF
	var right_min := INF
	var right_max := -INF
	anim_player.play(animation_name)
	for sample_time: float in key_times:
		anim_player.seek(sample_time, true)
		hitbox_skeleton.force_update_all_bone_transforms()
		var left_z := hitbox_skeleton.get_bone_global_pose(left_foot).origin.z
		var right_z := hitbox_skeleton.get_bone_global_pose(right_foot).origin.z
		left_min = minf(left_min, left_z)
		left_max = maxf(left_max, left_z)
		right_min = minf(right_min, right_z)
		right_max = maxf(right_max, right_z)
	anim_player.stop()
	var stride_length := ((left_max - left_min) + (right_max - right_min)) * 0.5
	return stride_length / animation.length


func _measure_attack_impact_time() -> float:
	if not anim_player or not hitbox_skeleton or not anim_player.has_animation(ANIM_ATTACK):
		return 0.0
	var animation := anim_player.get_animation(ANIM_ATTACK)
	var hips := hitbox_skeleton.find_bone("mixamorig5_Hips")
	var left_hand := hitbox_skeleton.find_bone("mixamorig5_LeftHand")
	var right_hand := hitbox_skeleton.find_bone("mixamorig5_RightHand")
	if hips == -1 or left_hand == -1 or right_hand == -1:
		return 0.0

	var key_times: Array[float] = [0.0]
	for track_index in animation.get_track_count():
		for key_index in animation.track_get_key_count(track_index):
			var key_time: float = animation.track_get_key_time(track_index, key_index)
			if not key_times.has(key_time):
				key_times.append(key_time)
	key_times.sort()

	anim_player.play(ANIM_ATTACK)
	anim_player.seek(0.0, true)
	hitbox_skeleton.force_update_all_bone_transforms()
	var hip_position := hitbox_skeleton.get_bone_global_pose(hips).origin
	var initial_left_hand := hitbox_skeleton.get_bone_global_pose(left_hand).origin - hip_position
	var initial_right_hand := hitbox_skeleton.get_bone_global_pose(right_hand).origin - hip_position
	var impact_time := 0.0
	var largest_hand_motion := 0.0
	for key_time: float in key_times:
		anim_player.seek(key_time, true)
		hitbox_skeleton.force_update_all_bone_transforms()
		hip_position = hitbox_skeleton.get_bone_global_pose(hips).origin
		var left_motion := (hitbox_skeleton.get_bone_global_pose(left_hand).origin - hip_position).distance_to(initial_left_hand)
		var right_motion := (hitbox_skeleton.get_bone_global_pose(right_hand).origin - hip_position).distance_to(initial_right_hand)
		var hand_motion := maxf(left_motion, right_motion)
		if hand_motion > largest_hand_motion:
			largest_hand_motion = hand_motion
			impact_time = key_time
	anim_player.stop()
	return impact_time


func _connect_animation_finished() -> void:
	if anim_player and not anim_player.animation_finished.is_connected(_on_animation_finished):
		anim_player.animation_finished.connect(_on_animation_finished)


func _find_player() -> Node3D:
	var nearest: Node3D = null
	var nearest_distance := INF
	for candidate in get_tree().get_nodes_in_group("player"):
		if not candidate is Node3D:
			continue
		var candidate_state: Variant = candidate.get("player_state")
		if candidate_state != null and int(candidate_state) != 0:
			continue
		var nav_map := get_world_3d().navigation_map
		if NavigationServer3D.map_get_iteration_id(nav_map) > 0:
			var path := NavigationServer3D.map_get_path(nav_map, global_position, (candidate as Node3D).global_position, true)
			if path.size() < 2 or path[path.size() - 1].distance_to((candidate as Node3D).global_position) > 6.0:
				continue
		var distance := global_position.distance_squared_to((candidate as Node3D).global_position)
		if distance < nearest_distance:
			nearest = candidate as Node3D
			nearest_distance = distance
	return nearest


func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_anim_player(child)
		if found:
			return found
	return null


func _configure_navigation_avoidance() -> void:
	nav_agent.avoidance_enabled = true
	nav_agent.radius = 0.34 * body_scale
	nav_agent.neighbor_distance = 3.0
	nav_agent.max_neighbors = 8
	nav_agent.time_horizon_agents = 1.0
	nav_agent.max_speed = maxf(move_speed, run_speed) * chase_speed_multiplier * behind_player_speed_multiplier
	if not nav_agent.velocity_computed.is_connected(_on_avoidance_velocity_computed):
		nav_agent.velocity_computed.connect(_on_avoidance_velocity_computed)


func _on_avoidance_velocity_computed(safe_velocity: Vector3) -> void:
	avoidance_velocity = safe_velocity


func _update_stuck_detection(delta: float) -> void:
	if state not in [State.WANDER, State.CHASE, State.SEARCH] or velocity.length_squared() < 0.01:
		last_progress_position = global_position
		stuck_check_timer = STUCK_CHECK_INTERVAL
		return
	stuck_check_timer -= delta
	if stuck_check_timer > 0.0:
		return
	var horizontal_progress := Vector2(global_position.x, global_position.z).distance_to(Vector2(last_progress_position.x, last_progress_position.z))
	if horizontal_progress < STUCK_MIN_PROGRESS:
		stuck_attempts += 1
		nav_target_timer = 0.0
		if stuck_attempts >= STUCK_REPATH_ATTEMPTS:
			stuck_attempts = 0
			stuck_detected.emit(self)
	else:
		stuck_attempts = 0
	last_progress_position = global_position
	stuck_check_timer = STUCK_CHECK_INTERVAL


func activate_from_pool(position: Vector3, target: Node3D, runner: bool, starts_aggressive: bool) -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	global_position = position
	network_position = self.position
	network_rotation = rotation
	player = target
	is_running = runner
	is_dead = false
	hp = max_hp
	attack_timer = 0.0
	attack_sequence += 1
	spawn_origin = position
	last_known_player_position = target.global_position
	wander_target_timer = 0.0
	stuck_attempts = 0
	stuck_check_timer = STUCK_CHECK_INTERVAL
	last_progress_position = position
	_reenable_hitboxes()
	set_physics_process(true)
	_change_state(State.CHASE if starts_aggressive else State.WANDER)


func deactivate_to_pool() -> void:
	attack_sequence += 1
	velocity = Vector3.ZERO
	set_physics_process(false)
	_disable_hitboxes()
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


func _reenable_hitboxes() -> void:
	for area in find_children("*", "Area3D", true, false):
		var hitbox := area as Area3D
		hitbox.monitorable = true
	for shape in find_children("*", "CollisionShape3D", true, false):
		var collision_shape := shape as CollisionShape3D
		collision_shape.disabled = false


func _disable_hitboxes() -> void:
	for area in find_children("*", "Area3D", true, false):
		var hitbox := area as Area3D
		hitbox.monitoring = false
		hitbox.monitorable = false
	for shape in find_children("*", "CollisionShape3D", true, false):
		var collision_shape := shape as CollisionShape3D
		collision_shape.disabled = true


func _attach_hitboxes_to_skeleton() -> void:
	hitbox_skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	if not hitbox_skeleton:
		push_error("Zombie sem Skeleton3D; hitboxes animadas nao foram configuradas.")
		return

	for shape_name: String in HITBOX_BONES:
		var collision_shape := find_child(shape_name, true, false) as CollisionShape3D
		if not collision_shape:
			push_error("Zombie sem a hitbox obrigatoria %s." % shape_name)
			continue
		var source_area := collision_shape.get_parent() as Area3D
		var bone_name: String = HITBOX_BONES[shape_name]
		var bone_index := hitbox_skeleton.find_bone(bone_name)
		if bone_index == -1:
			push_error("Zombie sem o osso obrigatorio %s." % bone_name)
			continue
		var convex_shape := collision_shape.shape as ConvexPolygonShape3D
		if not convex_shape:
			push_error("Hitbox %s precisa preservar uma ConvexPolygonShape3D." % shape_name)
			continue
		var rest_bone_global := hitbox_skeleton.global_transform * hitbox_skeleton.get_bone_global_rest(bone_index)
		var shape_global := collision_shape.global_transform
		var original_world_points := PackedVector3Array()
		var bone_local_points := PackedVector3Array()
		for point: Vector3 in convex_shape.points:
			var world_point := shape_global * point
			original_world_points.append(world_point)
			bone_local_points.append(rest_bone_global.affine_inverse() * world_point)
		var bone_local_shape := ConvexPolygonShape3D.new()
		bone_local_shape.points = bone_local_points

		var animated_area := Area3D.new()
		animated_area.name = "%sAnimated_%s" % [source_area.name, shape_name]
		animated_area.collision_layer = source_area.collision_layer
		animated_area.collision_mask = source_area.collision_mask
		animated_area.monitoring = source_area.monitoring
		animated_area.monitorable = source_area.monitorable
		animated_area.script = source_area.script
		add_child(animated_area)
		animated_area.global_transform = rest_bone_global
		collision_shape.reparent(animated_area, false)
		collision_shape.transform = Transform3D.IDENTITY
		collision_shape.shape = bone_local_shape
		var rest_conversion_error := 0.0
		for point_index in bone_local_points.size():
			var restored_world_point := rest_bone_global * bone_local_points[point_index]
			rest_conversion_error = maxf(rest_conversion_error, restored_world_point.distance_to(original_world_points[point_index]))
		animated_hitboxes.append({
			"area": animated_area,
			"bone_index": bone_index,
			"shape_name": shape_name,
			"rest_conversion_error": rest_conversion_error,
		})

	for source_name in [&"HeadHitbox", &"TorsoHitbox", &"LimbHitbox"]:
		var source_area := get_node_or_null(NodePath(String(source_name))) as Area3D
		if source_area and source_area.get_child_count() == 0:
			source_area.queue_free()
	_update_animated_hitboxes()


func _update_animated_hitboxes() -> void:
	if not hitbox_skeleton or animated_hitboxes.is_empty():
		return
	for binding: Dictionary in animated_hitboxes:
		var area := binding["area"] as Area3D
		if not is_instance_valid(area):
			continue
		var bone_index: int = binding["bone_index"]
		var animated_bone_pose := hitbox_skeleton.get_bone_global_pose(bone_index)
		area.global_transform = hitbox_skeleton.global_transform * animated_bone_pose


func _add_debug_visuals() -> void:
	for collision_shape in find_children("CollisionShape3D*", "CollisionShape3D", true, false):
		var shape := collision_shape as CollisionShape3D
		if not shape.shape:
			continue
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = shape.shape.get_debug_mesh()
		var material := StandardMaterial3D.new()
		var parent_name := String(shape.get_parent().name)
		if parent_name.begins_with("HeadHitboxAnimated"):
			material.albedo_color = Color(1.0, 0.1, 0.1, 0.35)
		elif parent_name.begins_with("TorsoHitboxAnimated"):
			material.albedo_color = Color(0.1, 1.0, 0.1, 0.35)
		elif parent_name.begins_with("LimbHitboxAnimated"):
			material.albedo_color = Color(0.1, 0.3, 1.0, 0.35)
		else:
			material.albedo_color = Color(0.7, 0.7, 0.7, 0.2)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh_instance.material_override = material
		shape.add_child(mesh_instance)


func _unused_add_debug_visuals() -> void:
	# Visualizar hitboxes de combate
	var hitbox_colors := {
		"HeadHitbox": Color(1.0, 0.0, 0.0, 0.35),
		"TorsoHitbox": Color(0.0, 1.0, 0.0, 0.35),
		"LimbHitbox": Color(0.0, 0.0, 1.0, 0.35),
	}
	for hitbox_name in hitbox_colors:
		var hitbox := find_child(hitbox_name, true, false) as Area3D
		if hitbox:
			_create_debug_mesh(hitbox, hitbox_colors[hitbox_name])

	# Visualizar colisor de cápsula principal (cinza)
	var main_col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if main_col:
		_create_debug_mesh_for_shape(main_col, Color(0.5, 0.5, 0.5, 0.15))


func _create_debug_mesh(parent_node: Node3D, color: Color) -> void:
	for child in parent_node.get_children():
		if child is CollisionShape3D:
			_create_debug_mesh_for_shape(child, color)


func _create_debug_mesh_for_shape(col_shape: CollisionShape3D, color: Color) -> void:
	var shape: Shape3D = col_shape.shape
	if not shape:
		return
	var mesh_instance := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	if shape is BoxShape3D:
		var box_mesh := BoxMesh.new()
		box_mesh.size = shape.size
		mesh_instance.mesh = box_mesh
	elif shape is CapsuleShape3D:
		var cap_mesh := CapsuleMesh.new()
		cap_mesh.radius = shape.radius
		cap_mesh.height = shape.height
		mesh_instance.mesh = cap_mesh
	elif shape is ConvexPolygonShape3D:
		var min_v := Vector3(999.0, 999.0, 999.0)
		var max_v := Vector3(-999.0, -999.0, -999.0)
		for p in shape.points:
			min_v.x = minf(min_v.x, p.x)
			min_v.y = minf(min_v.y, p.y)
			min_v.z = minf(min_v.z, p.z)
			max_v.x = maxf(max_v.x, p.x)
			max_v.y = maxf(max_v.y, p.y)
			max_v.z = maxf(max_v.z, p.z)
		var box_mesh := BoxMesh.new()
		box_mesh.size = max_v - min_v
		mesh_instance.mesh = box_mesh
		mesh_instance.position = (min_v + max_v) / 2.0

	if mesh_instance.mesh:
		mesh_instance.material_override = material
		col_shape.add_child(mesh_instance)


func _handle_headshot_visual() -> void:
	var skeleton := find_child("Skeleton3D", true, false) as Skeleton3D
	if not skeleton:
		push_warning("Zombie headshot sem Skeleton3D para efeito visual.")
		return
	var head_bone := skeleton.find_bone("mixamorig5_Head")
	if head_bone == -1:
		push_warning("Zombie headshot sem bone mixamorig5_Head.")
		return
	_spawn_headshot_blood(skeleton.global_transform * skeleton.get_bone_global_pose(head_bone).origin)


func _spawn_headshot_blood(position: Vector3) -> void:
	var blood := CPUParticles3D.new()
	blood.emitting = false
	blood.one_shot = true
	blood.explosiveness = 1.0
	blood.amount = 25
	blood.direction = Vector3.UP
	blood.spread = 180.0
	blood.initial_velocity_min = 2.0
	blood.initial_velocity_max = 6.0
	blood.scale_amount_min = 0.03
	blood.scale_amount_max = 0.1
	var mesh := BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.0, 0.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	blood.mesh = mesh
	add_child(blood)
	blood.global_position = position
	blood.emitting = true


func _on_animation_finished(anim_name: StringName) -> void:
	if is_dead:
		return
	if String(anim_name) == ANIM_ATTACK:
		match state:
			State.CHASE:
				_play_move_anim()
			State.ATTACK:
				_play_anim(ANIM_IDLE)
