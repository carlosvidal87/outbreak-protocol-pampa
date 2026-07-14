extends CharacterBody3D

const IndustrialZone := preload("res://src/scripts/industrial_zone.gd")

signal boss_died

const BASE_HP := 12000.0
const EXTRA_PLAYER_HP_RATIO := 0.60
const WALK_SPEED := 4.2
const RUN_SPEED := 8.0
const ENRAGE_MULTIPLIER := 1.30
const ENRAGE_THRESHOLD := 0.35
const TARGET_UPDATE_INTERVAL := 0.15
const NAVIGATION_UPDATE_INTERVAL := 0.12
const ATTACK_RECOVERY := 0.80
const MAX_ATTACK_RANGE := 8.5
const NETWORK_INTERPOLATION_SPEED := 12.0
const NETWORK_SNAP_DISTANCE := 14.0
const DEATH_CLEANUP_DELAY := 6.0
const OBSTACLE_PROBE_DISTANCE := 5.0
const OBSTACLE_PROBE_ANGLES := [0.0, -35.0, 35.0, -70.0, 70.0, -110.0, 110.0]

const ANIMATIONS := {
	"idle": "st_idle_battle",
	"walk": "st_walk",
	"run": "st_run",
	"attack1": "st_attack1",
	"attack2": "st_attack2",
	"attack3": "st_attack3",
	"bite": "st_bite",
	"hit1": "st_hit1",
	"hit2": "st_hit2",
	"roar": "st_roar",
	"death": "st_death",
}
const HITBOX_BONES := {
	"HeadHitbox": "head_05",
	"TorsoHitbox": "chest_00",
	"LeftArmHitbox": "arm.L_08",
	"RightArmHitbox": "arm.R_016",
	"LeftLegHitbox": "thigh.L_024",
	"RightLegHitbox": "thigh.R_029",
}
const ATTACK_DATA := {
	"attack1": {"damage": 40.0, "range": 6.5, "impact": 0.62},
	"attack2": {"damage": 50.0, "range": 7.0, "impact": 0.72},
	"attack3": {"damage": 70.0, "range": 8.5, "impact": 0.82},
	"bite": {"damage": 85.0, "range": 5.5, "impact": 0.78},
}

@export var max_hp := BASE_HP
@export var hp := BASE_HP
@export var immune_to_insta_kill := true
@export var enraged := false
@export var visual_state := "idle"
@export var network_position := Vector3.ZERO
@export var network_rotation := Vector3.ZERO
@export_range(1.0, 10.0, 0.1) var walk_speed := WALK_SPEED
@export_range(1.0, 14.0, 0.1) var run_speed := RUN_SPEED
@export_range(2.0, 16.0, 0.1) var walk_distance := 12.0
@export_range(0.1, 1.0, 0.05) var hit_reaction_chance := 0.18

var is_dead := false
var invulnerable := true
var target: Node3D = null
var target_update_timer := 0.0
var navigation_update_timer := 0.0
var attack_cooldown := 0.0
var attack_sequence := 0
var attacking := false
var hit_reacting := false
var intro_finished := false
var visual_state_applied := ""
var animation_player: AnimationPlayer = null
var skeleton: Skeleton3D = null
var animated_hitboxes: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var testing_skip_intro := false
var idle_audio_delay := 0.0

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var idle_audio: AudioStreamPlayer3D = $IdleAudio
@onready var attack_audio: AudioStreamPlayer3D = $AttackAudio
@onready var death_audio: AudioStreamPlayer3D = $DeathAudio
@onready var movement_audio: AudioStreamPlayer3D = $MovementAudio
@onready var run_audio: AudioStreamPlayer3D = $RunAudio
@onready var battle_music: AudioStreamPlayer = $BattleMusic


func _ready() -> void:
	add_to_group("boss")
	add_to_group("enemies")
	floor_max_angle = deg_to_rad(55.0)
	floor_snap_length = 1.2
	network_position = position
	network_rotation = rotation
	rng.randomize()
	idle_audio_delay = rng.randf_range(7.0, 12.0)
	animation_player = _find_animation_player(self)
	skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	_configure_animation_loops()
	_bind_hitboxes_to_bones()
	_set_attack_areas_enabled(false)
	_configure_navigation()
	set_physics_process(_is_server_authority())
	if _is_server_authority():
		if testing_skip_intro:
			invulnerable = false
			intro_finished = true
			_set_visual_state("idle")
		else:
			_start_intro()
	else:
		_play_visual_state()


func setup_for_players(living_player_count: int) -> void:
	var player_count := maxi(living_player_count, 1)
	max_hp = BASE_HP * (1.0 + EXTRA_PLAYER_HP_RATIO * float(player_count - 1))
	hp = max_hp


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_publish_network_transform()
	if not intro_finished:
		velocity = Vector3.ZERO
		return
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	target_update_timer -= delta
	if target_update_timer <= 0.0 or not _is_valid_target(target):
		target = _find_nearest_living_player()
		target_update_timer = TARGET_UPDATE_INTERVAL
	if not target:
		velocity = Vector3.ZERO
		_set_visual_state("idle")
		move_and_slide()
		return
	if attacking:
		velocity = Vector3.ZERO
		_face_target(delta)
		move_and_slide()
		return
	if hit_reacting:
		velocity = Vector3.ZERO
		_face_target(delta)
		move_and_slide()
		return
	var distance := _horizontal_distance_to(target.global_position)
	if attack_cooldown <= 0.0 and distance <= MAX_ATTACK_RANGE:
		_start_attack(_choose_attack(distance))
		return
	_update_navigation_target(delta)
	_move_toward_target(delta, distance)
	move_and_slide()
	_publish_network_transform()


func _process(delta: float) -> void:
	_update_animated_hitboxes()
	_update_audio(delta)
	if not _is_server_authority():
		_interpolate_network_transform(delta)
		if visual_state_applied != visual_state:
			_play_visual_state()


func take_damage(amount: float, _is_headshot: bool = false) -> void:
	if not _is_server_authority() or is_dead or invulnerable or amount <= 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	if not enraged and hp <= max_hp * ENRAGE_THRESHOLD:
		enraged = true
	if hp <= 0.0:
		_die()
		return
	if not attacking and not hit_reacting and rng.randf() <= hit_reaction_chance:
		hit_reacting = true
		_set_visual_state("hit1" if rng.randf() < 0.5 else "hit2")
		get_tree().create_timer(0.45).timeout.connect(_resume_locomotion_after_hit)


func _start_intro() -> void:
	invulnerable = true
	intro_finished = false
	_set_visual_state("roar")
	var duration := _get_animation_length("roar", 5.0)
	get_tree().create_timer(duration).timeout.connect(_finish_intro)


func _finish_intro() -> void:
	if is_dead:
		return
	invulnerable = false
	intro_finished = true
	attack_cooldown = 0.5
	_set_visual_state("idle")


func _choose_attack(distance: float) -> String:
	if distance <= 5.5 and rng.randf() < 0.35:
		return "bite"
	var roll := rng.randf()
	if distance > 7.0 or roll > 0.68:
		return "attack3"
	if roll > 0.34:
		return "attack2"
	return "attack1"


func _start_attack(attack_name: String) -> void:
	if attacking or not ATTACK_DATA.has(attack_name):
		return
	attacking = true
	velocity = Vector3.ZERO
	attack_sequence += 1
	var sequence := attack_sequence
	_set_visual_state(attack_name)
	var data: Dictionary = ATTACK_DATA[attack_name]
	var speed_multiplier := ENRAGE_MULTIPLIER if enraged else 1.0
	get_tree().create_timer(float(data["impact"]) / speed_multiplier).timeout.connect(_open_attack_window.bind(attack_name, sequence))
	var animation_duration := _get_animation_length(attack_name, 1.67)
	get_tree().create_timer(animation_duration).timeout.connect(_finish_attack.bind(sequence))


func _open_attack_window(attack_name: String, sequence: int) -> void:
	if is_dead or not attacking or sequence != attack_sequence:
		return
	_apply_proximity_attack(attack_name)


func _apply_proximity_attack(attack_name: String) -> int:
	if not _is_server_authority() or not ATTACK_DATA.has(attack_name):
		return 0
	var data: Dictionary = ATTACK_DATA[attack_name]
	var attack_range := float(data["range"])
	var damage := float(data["damage"])
	var hit_count := 0
	for candidate in get_tree().get_nodes_in_group("player"):
		if not candidate is Node3D or not _is_valid_target(candidate as Node3D):
			continue
		if _horizontal_distance_to((candidate as Node3D).global_position) > attack_range:
			continue
		if candidate.has_method("take_damage"):
			candidate.call("take_damage", damage)
			hit_count += 1
	return hit_count


func _finish_attack(sequence: int) -> void:
	if is_dead or sequence != attack_sequence:
		return
	attacking = false
	var speed_multiplier := ENRAGE_MULTIPLIER if enraged else 1.0
	attack_cooldown = ATTACK_RECOVERY / speed_multiplier
	_set_visual_state("idle")


func _resume_locomotion_after_hit() -> void:
	if is_dead or attacking:
		return
	hit_reacting = false
	_set_visual_state("idle")


func _move_toward_target(delta: float, distance: float) -> void:
	var direction := _get_chase_direction()
	if direction.length_squared() < 0.01:
		velocity.x = 0.0
		velocity.z = 0.0
		_set_visual_state("idle")
		return
	direction = direction.normalized()
	if IndustrialZone.contains(global_position, 10.0):
		direction = _steer_around_industrial_obstacle(direction)
	var base_speed := walk_speed if distance <= walk_distance else run_speed
	var speed_multiplier := ENRAGE_MULTIPLIER if enraged else 1.0
	var desired_velocity := direction * base_speed * speed_multiplier
	velocity.x = desired_velocity.x
	velocity.z = desired_velocity.z
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	_face_direction(direction, delta)
	_set_visual_state("walk" if distance <= walk_distance else "run")


func _steer_around_industrial_obstacle(desired_direction: Vector3) -> Vector3:
	for angle_degrees: float in OBSTACLE_PROBE_ANGLES:
		var candidate := desired_direction.rotated(Vector3.UP, deg_to_rad(angle_degrees)).normalized()
		if not _boss_direction_hits_obstacle(candidate):
			return candidate
	return -desired_direction


func _boss_direction_hits_obstacle(direction: Vector3) -> bool:
	for height: float in [1.2, 4.2, 7.2]:
		var origin := global_position + Vector3.UP * height
		var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * OBSTACLE_PROBE_DISTANCE)
		query.collision_mask = 1
		query.collide_with_areas = false
		query.exclude = [get_rid()]
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			return true
	return false


func _get_chase_direction() -> Vector3:
	if not target:
		return Vector3.ZERO
	var direct_direction := target.global_position - global_position
	direct_direction.y = 0.0
	if direct_direction.length_squared() < 0.01:
		return Vector3.ZERO
	direct_direction = direct_direction.normalized()
	if IndustrialZone.contains(global_position, 10.0):
		return direct_direction
	var nav_map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(nav_map) == 0 or navigation_agent.is_navigation_finished():
		return direct_direction
	var next_position := navigation_agent.get_next_path_position()
	var navigation_direction := next_position - global_position
	navigation_direction.y = 0.0
	if navigation_direction.length_squared() < 0.01:
		return direct_direction
	navigation_direction = navigation_direction.normalized()
	return _select_forward_chase_direction(direct_direction, navigation_direction)


func _select_forward_chase_direction(direct_direction: Vector3, navigation_direction: Vector3) -> Vector3:
	var direct := direct_direction.normalized()
	var navigation := navigation_direction.normalized()
	if navigation.dot(direct) > 0.05:
		return navigation
	return direct


func _horizontal_distance_to(world_position: Vector3) -> float:
	return Vector2(global_position.x, global_position.z).distance_to(Vector2(world_position.x, world_position.z))


func _update_navigation_target(delta: float) -> void:
	navigation_update_timer -= delta
	if navigation_update_timer > 0.0 or not target:
		return
	var nav_map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(nav_map) > 0:
		navigation_agent.target_position = NavigationServer3D.map_get_closest_point(nav_map, target.global_position)
	navigation_update_timer = NAVIGATION_UPDATE_INTERVAL


func _find_nearest_living_player() -> Node3D:
	var nearest: Node3D = null
	var nearest_distance := INF
	for candidate in get_tree().get_nodes_in_group("player"):
		if not candidate is Node3D or not _is_valid_target(candidate as Node3D):
			continue
		var distance := global_position.distance_squared_to((candidate as Node3D).global_position)
		if distance < nearest_distance:
			nearest = candidate as Node3D
			nearest_distance = distance
	return nearest


func _is_valid_target(candidate: Node3D) -> bool:
	if candidate == null or not is_instance_valid(candidate) or not candidate.is_inside_tree() or not candidate.is_in_group("player"):
		return false
	var player_state: Variant = candidate.get("player_state")
	return player_state == null or int(player_state) == 0


func _die() -> void:
	is_dead = true
	invulnerable = true
	attacking = false
	hit_reacting = false
	attack_sequence += 1
	velocity = Vector3.ZERO
	_set_attack_areas_enabled(false)
	_disable_damage_hitboxes()
	_set_visual_state("death")
	boss_died.emit()
	get_tree().create_timer(DEATH_CLEANUP_DELAY).timeout.connect(queue_free)


func _set_visual_state(new_state: String) -> void:
	if visual_state == new_state and visual_state_applied == new_state:
		return
	visual_state = new_state
	_play_visual_state()


func _play_visual_state() -> void:
	visual_state_applied = visual_state
	_play_state_feedback()
	if not animation_player:
		return
	var animation_name := _resolve_animation(String(ANIMATIONS.get(visual_state, ANIMATIONS["idle"])))
	if animation_name.is_empty():
		return
	var speed := ENRAGE_MULTIPLIER if enraged and visual_state in ["walk", "run", "attack1", "attack2", "attack3", "bite"] else 1.0
	animation_player.speed_scale = speed
	if animation_player.current_animation != animation_name:
		animation_player.play(animation_name, 0.12)


func _play_state_feedback() -> void:
	match visual_state:
		"roar":
			$SpawnVFX.restart()
			idle_audio.play()
		"attack1", "attack2", "attack3", "bite":
			attack_audio.play()
		"death":
			battle_music.stop()
			idle_audio.stop()
			movement_audio.stop()
			run_audio.stop()
			death_audio.play()


func _update_audio(delta: float) -> void:
	if is_dead:
		return
	if not battle_music.playing:
		battle_music.play()
	var moving := visual_state in ["walk", "run"]
	if moving:
		if not movement_audio.playing:
			movement_audio.play()
	else:
		movement_audio.stop()
	if visual_state == "run":
		if not run_audio.playing:
			run_audio.play()
	else:
		run_audio.stop()
	if visual_state == "idle":
		idle_audio_delay -= delta
		if idle_audio_delay <= 0.0 and not idle_audio.playing:
			idle_audio.pitch_scale = rng.randf_range(0.96, 1.04)
			idle_audio.play()
			idle_audio_delay = rng.randf_range(9.0, 15.0)
	elif visual_state != "roar":
		idle_audio.stop()


func _resolve_animation(required_name: String) -> StringName:
	if not animation_player:
		return &""
	var direct := StringName(required_name)
	if animation_player.has_animation(direct):
		return direct
	for candidate in animation_player.get_animation_list():
		var text := String(candidate)
		if text.ends_with("/" + required_name) or text.ends_with(required_name):
			return candidate
	return &""


func _get_animation_length(state_name: String, fallback: float) -> float:
	if not animation_player:
		return fallback
	var resolved := _resolve_animation(String(ANIMATIONS.get(state_name, "")))
	if resolved.is_empty():
		return fallback
	return animation_player.get_animation(resolved).length / (ENRAGE_MULTIPLIER if enraged else 1.0)


func _configure_animation_loops() -> void:
	if not animation_player:
		push_error("Boss sem AnimationPlayer no modelo nightmare_creature_4.glb.")
		return
	for state_name in ["idle", "walk", "run"]:
		var resolved := _resolve_animation(String(ANIMATIONS[state_name]))
		if not resolved.is_empty():
			animation_player.get_animation(resolved).loop_mode = Animation.LOOP_LINEAR
	for state_name in ["attack1", "attack2", "attack3", "bite", "hit1", "hit2", "roar", "death"]:
		var resolved := _resolve_animation(String(ANIMATIONS[state_name]))
		if not resolved.is_empty():
			animation_player.get_animation(resolved).loop_mode = Animation.LOOP_NONE


func _bind_hitboxes_to_bones() -> void:
	if not skeleton:
		push_error("Boss sem Skeleton3D; hitboxes nao podem acompanhar os ossos.")
		return
	for hitbox_name: String in HITBOX_BONES:
		var area := get_node_or_null("DamageHitboxes/%s" % hitbox_name) as Area3D
		var bone_name: String = HITBOX_BONES[hitbox_name]
		var bone_index := skeleton.find_bone(bone_name)
		if not area or bone_index < 0:
			push_error("Boss sem hitbox %s ou osso %s." % [hitbox_name, bone_name])
			continue
		var bone_global := skeleton.global_transform * skeleton.get_bone_global_pose(bone_index)
		animated_hitboxes.append({
			"area": area,
			"bone_index": bone_index,
			"offset": bone_global.affine_inverse() * area.global_transform,
		})


func _update_animated_hitboxes() -> void:
	if not skeleton:
		return
	for binding: Dictionary in animated_hitboxes:
		var area := binding["area"] as Area3D
		if not is_instance_valid(area):
			continue
		var bone_global := skeleton.global_transform * skeleton.get_bone_global_pose(int(binding["bone_index"]))
		area.global_transform = bone_global * (binding["offset"] as Transform3D)


func _disable_damage_hitboxes() -> void:
	for child in $DamageHitboxes.get_children():
		if child is Area3D:
			(child as Area3D).monitorable = false


func _set_attack_areas_enabled(enabled: bool) -> void:
	for child in $AttackAreas.get_children():
		if child is Area3D:
			(child as Area3D).monitoring = enabled


func _configure_navigation() -> void:
	navigation_agent.avoidance_enabled = false
	navigation_agent.radius = 1.75
	navigation_agent.neighbor_distance = 10.0
	navigation_agent.max_neighbors = 16
	navigation_agent.path_height_offset = 0.0
	navigation_agent.max_speed = run_speed * ENRAGE_MULTIPLIER


func _face_target(delta: float) -> void:
	if not target:
		return
	var direction := target.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		_face_direction(direction.normalized(), delta)


func _face_direction(direction: Vector3, delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 6.0 * delta)


func _publish_network_transform() -> void:
	if _is_server_authority():
		network_position = position
		network_rotation = rotation


func _interpolate_network_transform(delta: float) -> void:
	if position.distance_to(network_position) > NETWORK_SNAP_DISTANCE:
		position = network_position
		rotation = network_rotation
		return
	var weight := 1.0 - exp(-NETWORK_INTERPOLATION_SPEED * delta)
	position = position.lerp(network_position, weight)
	rotation.y = lerp_angle(rotation.y, network_rotation.y, weight)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null


func _is_server_authority() -> bool:
	return not multiplayer.multiplayer_peer or multiplayer.is_server()
