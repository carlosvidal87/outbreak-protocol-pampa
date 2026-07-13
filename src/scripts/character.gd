extends CharacterBody3D

signal health_changed(current_hp: float, maximum_hp: float)

enum PlayerState { ALIVE, DOWNED, SPECTATING }
enum SoldierAnimState {
	IDLE,
	WALK_FORWARD,
	WALK_BACKWARD,
	WALK_LEFT,
	WALK_RIGHT,
	WALK_FORWARD_LEFT,
	WALK_FORWARD_RIGHT,
	WALK_BACKWARD_LEFT,
	WALK_BACKWARD_RIGHT,
	RUN_FORWARD,
	RUN_BACKWARD,
	RUN_LEFT,
	RUN_RIGHT,
	RUN_FORWARD_LEFT,
	RUN_FORWARD_RIGHT,
	RUN_BACKWARD_LEFT,
	RUN_BACKWARD_RIGHT,
	JUMP,
}

const SoldierVisualHelper = preload("res://src/scripts/soldier_visual_helper.gd")

const WALK_SPEED := 5.0
const SPRINT_SPEED := 8.0
const JUMP_HEIGHT := 1.05
const JUMP_TIME_TO_APEX := 0.38
const STEP_HEIGHT := 0.45
const STEP_FORWARD_DISTANCE := 0.55
const STEP_DOWN_DISTANCE := 0.8
const PLAYER_CAMERA_FAR := 600.0
const SOLDIER_ANIM_LIBRARY := "pistol"
const SOLDIER_PISTOL_ANIMS := {
	"idle": "res://assets/characters/Soldier/Pistol Animation/pistol idle.fbx",
	"walk_forward": "res://assets/characters/Soldier/Pistol Animation/pistol walk.fbx",
	"walk_backward": "res://assets/characters/Soldier/Pistol Animation/pistol walk backward.fbx",
	"walk_left": "res://assets/characters/Soldier/Pistol Animation/pistol strafe.fbx",
	"walk_right": "res://assets/characters/Soldier/Pistol Animation/pistol strafe (2).fbx",
	"walk_forward_left": "res://assets/characters/Soldier/Pistol Animation/pistol walk arc.fbx",
	"walk_forward_right": "res://assets/characters/Soldier/Pistol Animation/pistol walk arc (2).fbx",
	"walk_backward_left": "res://assets/characters/Soldier/Pistol Animation/pistol walk backward arc.fbx",
	"walk_backward_right": "res://assets/characters/Soldier/Pistol Animation/pistol walk backward arc (2).fbx",
	"run_forward": "res://assets/characters/Soldier/Pistol Animation/pistol run.fbx",
	"run_backward": "res://assets/characters/Soldier/Pistol Animation/pistol run backward.fbx",
	"run_left": "res://assets/characters/Soldier/Pistol Animation/pistol strafe.fbx",
	"run_right": "res://assets/characters/Soldier/Pistol Animation/pistol strafe (2).fbx",
	"run_forward_left": "res://assets/characters/Soldier/Pistol Animation/pistol run arc.fbx",
	"run_forward_right": "res://assets/characters/Soldier/Pistol Animation/pistol run arc (2).fbx",
	"run_backward_left": "res://assets/characters/Soldier/Pistol Animation/pistol run backward arc.fbx",
	"run_backward_right": "res://assets/characters/Soldier/Pistol Animation/pistol run backward arc (2).fbx",
	"jump": "res://assets/characters/Soldier/Pistol Animation/pistol jump.fbx"
}
const SOLDIER_ANIM_NAMES := [
	"idle",
	"walk_forward", "walk_backward", "walk_left", "walk_right",
	"walk_forward_left", "walk_forward_right", "walk_backward_left", "walk_backward_right",
	"run_forward", "run_backward", "run_left", "run_right",
	"run_forward_left", "run_forward_right", "run_backward_left", "run_backward_right",
	"jump",
]
const WEAPON_SLOT_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6]
const MAX_AMMO_VALUES := {"9mm": 240, "rifle": 600, "shell": 64, "none": 0}
const NETWORK_WEAPON_DAMAGE := [25.0, 20.0, 35.0, 30.0, 20.0, 70.0]
const NETWORK_WEAPON_RANGE := [50.0, 50.0, 100.0, 80.0, 10.0, 3.0]
const NETWORK_MELEE_DAMAGE := 100.0
const NETWORK_MELEE_RANGE := 3.0
const NETWORK_FIRE_INTERVAL := [0.16, 0.075, 0.10, 0.10, 0.0, 0.45]
const NETWORK_INTERPOLATION_SPEED := 12.0
const NETWORK_SNAP_DISTANCE := 8.0
const REVIVE_RANGE := 2.5
const REVIVE_DURATION := 4.0

@export var is_local_player := true

var network_peer_id := 1
var player_display_name := "Jogador"
var local_input_blocked := false
var network_position := Vector3.ZERO
var network_rotation := Vector3.ZERO
var network_camera_rotation := Vector3.ZERO
var network_animation_state := SoldierAnimState.IDLE
var network_animation_speed := 1.0
var network_animation_phase := 0.0
var network_animation_airborne := false
var player_state := PlayerState.ALIVE
var downed_remaining := 0.0
var revive_target_peer_id := 0
var revive_progress := 0.0
var last_server_shot_ms := -10000
var equipped_weapon_index := 0
var validated_shot_weapon := -1
var validated_shot_hits_remaining := 0
var validated_shot_expires_ms := 0
var validated_attack_is_melee := false
var server_magazines := [19, 30, 30, 100, 2, 0]
var server_ammo := {"9mm": 240, "rifle": 600, "shell": 64}
var points := 500
var max_hp := 100.0
var hp := 100.0
var mouse_sensitivity := 0.002
var flashlight_enabled := false
var active_perks: Array[String] = []
var nearby_interactable: Node3D = null
var insta_kill_timer := 0.0
var double_points_timer := 0.0
var soldier_anim_player: AnimationPlayer = null
var soldier_current_anim := ""
var soldier_default_transform := Transform3D.IDENTITY
var remote_last_position := Vector3.ZERO
var downed_overlay: ColorRect = null
var downed_status_label: Label = null
var revive_prompt_panel: PanelContainer = null
var revive_prompt_label: Label = null
var revive_progress_bar: ProgressBar = null

@onready var camera: Camera3D = $Camera3D
@onready var soldier_model: Node3D = $Ch35_nonPBR
@onready var flashlight: SpotLight3D = $Camera3D/Flashlight
@onready var flashlight_fill: OmniLight3D = $Camera3D/FlashlightFill
@onready var fps_hands: Node3D = $Camera3D/FPSHands
@onready var menu_layer: CanvasLayer = $MenuLayer
@onready var crosshair: Control = $CrosshairLayer/Crosshair
@onready var hitmarker: Control = $CrosshairLayer/Hitmarker
@onready var ammo_counter: Control = $CrosshairLayer/AmmoCounter
@onready var health_hud: Control = $CrosshairLayer/HealthHUD


func _ready() -> void:
	if multiplayer.multiplayer_peer != null:
		is_local_player = is_multiplayer_authority()

	floor_max_angle = deg_to_rad(55.0)
	floor_snap_length = 0.45
	camera.far = PLAYER_CAMERA_FAR
	camera.current = is_local_player
	add_to_group("player")
	soldier_default_transform = soldier_model.transform
	remote_last_position = global_position
	network_position = position
	network_rotation = rotation
	network_camera_rotation = camera.rotation
	_setup_soldier_animations()
	_configure_fps_hands()
	set_flashlight_enabled(false)
	_apply_local_player_visibility()
	_set_health(hp)
	_create_downed_hud()
	_create_scoreboard()

	if is_local_player:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		var menu_controller_script := preload("res://src/scripts/menu_controller.gd")
		var menu_controller := menu_controller_script.new()
		menu_layer.add_child(menu_controller)


func _configure_fps_hands() -> void:
	fps_hands.camera = camera
	fps_hands.node_recoil_x = camera
	fps_hands.node_recoil_y = self
	fps_hands.collision_mask = 5
	fps_hands.FireRayCast.collision_mask = 5
	fps_hands.MeleeRayCast.collision_mask = 5
	fps_hands.FireRayCast.add_exception(self)
	fps_hands.MeleeRayCast.add_exception(self)
	crosshair.set_weapon(fps_hands.weapon)
	if not fps_hands.give_damage.is_connected(_on_fps_hands_give_damage):
		fps_hands.give_damage.connect(_on_fps_hands_give_damage)
	if not fps_hands.aiming.is_connected(crosshair.set_aiming):
		fps_hands.aiming.connect(crosshair.set_aiming)
	if not fps_hands.firing.is_connected(crosshair.kick):
		fps_hands.firing.connect(crosshair.kick)
	if not fps_hands.firing.is_connected(_on_local_weapon_fired):
		fps_hands.firing.connect(_on_local_weapon_fired)
	if not fps_hands.meleeing.is_connected(_on_local_melee):
		fps_hands.meleeing.connect(_on_local_melee)
	if not fps_hands.reloading.is_connected(_on_local_weapon_reload):
		fps_hands.reloading.connect(_on_local_weapon_reload)
	if not fps_hands.taking_weapon.is_connected(_on_fps_hands_weapon_taken):
		fps_hands.taking_weapon.connect(_on_fps_hands_weapon_taken)
	if not fps_hands.update_ammo.is_connected(ammo_counter.update_ammo):
		fps_hands.update_ammo.connect(ammo_counter.update_ammo)
	fps_hands.visible = is_local_player
	hitmarker.visible = is_local_player
	ammo_counter.visible = is_local_player
	fps_hands.set_process_input(is_local_player)
	fps_hands.set_process(is_local_player)
	fps_hands.set_physics_process(is_local_player)


func _unhandled_input(event: InputEvent) -> void:
	if not is_local_player or local_input_blocked:
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x, -PI / 2.0, PI / 2.0)
	elif event is InputEventMouseButton and event.pressed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_TAB:
			_set_scoreboard_visible(true)
		elif event.physical_keycode == KEY_F:
			set_flashlight_enabled(not flashlight_enabled)
		elif event.physical_keycode == KEY_E and nearby_interactable:
			_interact_with(nearby_interactable)
		else:
			var slot := WEAPON_SLOT_KEYS.find(event.physical_keycode)
			if slot != -1:
				fps_hands.take_weapon(slot)
	elif event is InputEventKey and not event.pressed and event.physical_keycode == KEY_TAB:
		_set_scoreboard_visible(false)


func _process(delta: float) -> void:
	_lock_soldier_visual_transform()
	if is_local_player:
		crosshair.set_movement_speed(Vector2(velocity.x, velocity.z).length())
		_update_downed_hud()
		_update_revive_input()
		_update_revive_hud()
		_update_scoreboard()
	else:
		_interpolate_remote_transform(delta)
		_apply_remote_soldier_animation()
		remote_last_position = global_position
	if flashlight.visible != flashlight_enabled:
		_apply_flashlight_visual(flashlight_enabled)
	if multiplayer.multiplayer_peer and multiplayer.is_server():
		_update_server_downed(delta)
		_update_server_revive(delta)


func _on_fps_hands_weapon_taken() -> void:
	crosshair.set_weapon(fps_hands.weapon)
	equipped_weapon_index = fps_hands.weapon_index
	if multiplayer.multiplayer_peer and not multiplayer.is_server():
		_request_weapon_equipped.rpc_id(1, equipped_weapon_index)


func _on_local_weapon_fired() -> void:
	if multiplayer.multiplayer_peer and not multiplayer.is_server():
		_request_fire.rpc_id(1, fps_hands.weapon_index)


func _on_local_melee() -> void:
	if multiplayer.multiplayer_peer and not multiplayer.is_server():
		_request_melee.rpc_id(1, fps_hands.weapon_index)


func _on_local_weapon_reload() -> void:
	if multiplayer.multiplayer_peer and not multiplayer.is_server():
		_request_reload.rpc_id(1, fps_hands.weapon_index)


@rpc("any_peer", "call_local", "reliable", 1)
func _request_fire(weapon_index: int) -> void:
	if not multiplayer.is_server() or player_state != PlayerState.ALIVE or not _sender_owns_character():
		return
	if weapon_index != equipped_weapon_index or weapon_index < 0 or weapon_index >= NETWORK_WEAPON_DAMAGE.size():
		return
	var now := Time.get_ticks_msec()
	var minimum_interval_ms := roundi(NETWORK_FIRE_INTERVAL[weapon_index] * 1000.0)
	if now - last_server_shot_ms < minimum_interval_ms:
		return
	if weapon_index != 5:
		if int(server_magazines[weapon_index]) <= 0:
			return
		server_magazines[weapon_index] = int(server_magazines[weapon_index]) - 1
	last_server_shot_ms = now
	validated_shot_weapon = weapon_index
	validated_shot_hits_remaining = 8 if weapon_index == 4 else 1
	validated_shot_expires_ms = now + 350
	validated_attack_is_melee = false


@rpc("any_peer", "call_local", "reliable", 1)
func _request_melee(weapon_index: int) -> void:
	if not multiplayer.is_server() or player_state != PlayerState.ALIVE or not _sender_owns_character():
		return
	if weapon_index != equipped_weapon_index or weapon_index < 0 or weapon_index >= NETWORK_WEAPON_DAMAGE.size():
		return
	validated_shot_weapon = weapon_index
	validated_shot_hits_remaining = 1
	validated_shot_expires_ms = Time.get_ticks_msec() + 500
	validated_attack_is_melee = true


@rpc("any_peer", "call_local", "reliable", 1)
func _request_reload(weapon_index: int) -> void:
	if not multiplayer.is_server() or not _sender_owns_character() or weapon_index < 0 or weapon_index >= server_magazines.size() - 1:
		return
	var capacities := [19, 30, 30, 100, 2]
	var ammo_types := ["9mm", "9mm", "rifle", "rifle", "shell"]
	var needed := int(capacities[weapon_index]) - int(server_magazines[weapon_index])
	var ammo_type: String = ammo_types[weapon_index]
	var supplied := mini(needed, int(server_ammo[ammo_type]))
	server_magazines[weapon_index] = int(server_magazines[weapon_index]) + supplied
	server_ammo[ammo_type] = int(server_ammo[ammo_type]) - supplied


@rpc("any_peer", "call_local", "reliable")
func _request_weapon_equipped(index: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	if sender == network_peer_id:
		equipped_weapon_index = clampi(index, 0, WEAPON_SLOT_KEYS.size() - 1)


func _sender_owns_character() -> bool:
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	return sender == network_peer_id


func _physics_process(delta: float) -> void:
	if not is_local_player:
		_lock_soldier_visual_transform()
		return
	if player_state != PlayerState.ALIVE:
		velocity = Vector3.ZERO
		return
	if local_input_blocked:
		velocity = Vector3.ZERO
		_update_soldier_animation(Vector2.ZERO, false)
		_publish_network_transform()
		return

	insta_kill_timer = maxf(insta_kill_timer - delta, 0.0)
	double_points_timer = maxf(double_points_timer - delta, 0.0)

	if not is_on_floor():
		velocity.y -= _get_jump_gravity() * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = _get_jump_velocity()

	var is_sprinting := Input.is_action_pressed("sprint")
	var speed := SPRINT_SPEED if is_sprinting else WALK_SPEED
	var input_dir := Input.get_vector("a", "d", "w", "s")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	var stepped_up := false
	if direction and is_on_floor():
		stepped_up = _try_step_up(direction, speed, delta)
	if not stepped_up:
		move_and_slide()
	_update_soldier_animation(input_dir, is_sprinting)
	_publish_network_transform()
	_lock_soldier_visual_transform()


func _on_fps_hands_give_damage(collider: Node3D, base_damage: float, _point: Vector3) -> void:
	if multiplayer.multiplayer_peer and not multiplayer.is_server():
		var predicted_multiplier := 1.0
		if collider.has_method("get_damage_multiplier"):
			predicted_multiplier = float(collider.call("get_damage_multiplier"))
		hitmarker.call("show_hit", predicted_multiplier > 1.0, false)
		_request_weapon_damage.rpc_id(1, collider.get_path(), base_damage, _point, fps_hands.weapon_index)
		return
	_apply_weapon_damage(collider, base_damage)


@rpc("any_peer", "call_local", "reliable", 1)
func _request_weapon_damage(collider_path: NodePath, base_damage: float, point: Vector3, weapon_index: int) -> void:
	if not multiplayer.is_server() or player_state != PlayerState.ALIVE:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	if sender != network_peer_id or weapon_index < 0 or weapon_index >= NETWORK_WEAPON_DAMAGE.size():
		return
	var expected_damage: float = NETWORK_MELEE_DAMAGE if validated_attack_is_melee else float(NETWORK_WEAPON_DAMAGE[weapon_index])
	if not is_equal_approx(base_damage, expected_damage):
		return
	var collider := get_node_or_null(collider_path) as Node3D
	var allowed_range: float = NETWORK_MELEE_RANGE if validated_attack_is_melee else float(NETWORK_WEAPON_RANGE[weapon_index])
	if not collider or collider.is_in_group("player") or global_position.distance_to(point) > allowed_range + 2.0:
		return
	var now := Time.get_ticks_msec()
	if weapon_index != validated_shot_weapon or validated_shot_hits_remaining <= 0 or now > validated_shot_expires_ms:
		return
	validated_shot_hits_remaining -= 1
	validated_attack_is_melee = false
	_apply_weapon_damage(collider, base_damage)


func _apply_weapon_damage(collider: Node3D, base_damage: float) -> void:
	if collider.is_in_group("player"):
		return
	var multiplier := 1.0
	var is_headshot := false
	if collider.has_method("get_damage_multiplier"):
		multiplier = float(collider.call("get_damage_multiplier"))
		is_headshot = multiplier > 1.0

	show_notification("Hit: " + collider.name + " | Mult: " + str(multiplier))

	var target := _resolve_damageable(collider)
	if not target:
		return
	var was_dead := bool(target.get("is_dead"))
	var final_damage := base_damage * multiplier
	if active_perks.has("double_tap"):
		final_damage *= 2.0
	if insta_kill_timer > 0.0:
		final_damage = 999999.0
	target.call("take_damage", final_damage, is_headshot)
	if was_dead:
		return
	var is_kill := bool(target.get("is_dead")) or float(target.get("hp")) <= 0.0
	if multiplayer.multiplayer_peer and multiplayer.is_server() and network_peer_id != 1:
		_confirm_hitmarker.rpc_id(network_peer_id, is_headshot, is_kill)
	elif is_local_player:
		hitmarker.call("show_hit", is_headshot, is_kill)
	_add_points(10)
	if is_kill:
		_add_points(90 if is_headshot else 50)


@rpc("any_peer", "call_remote", "reliable", 1)
func _confirm_hitmarker(is_headshot: bool, is_kill: bool) -> void:
	if not multiplayer.multiplayer_peer or multiplayer.get_remote_sender_id() != 1 or not is_local_player:
		return
	hitmarker.call("show_hit", is_headshot, is_kill)


func _publish_network_transform() -> void:
	if not multiplayer.multiplayer_peer or not is_local_player:
		return
	network_position = position
	network_rotation = rotation
	network_camera_rotation = camera.rotation


func _interpolate_remote_transform(delta: float) -> void:
	if not multiplayer.multiplayer_peer or is_local_player:
		return
	if position.distance_to(network_position) > NETWORK_SNAP_DISTANCE:
		position = network_position
	else:
		var weight := 1.0 - exp(-NETWORK_INTERPOLATION_SPEED * delta)
		position = position.lerp(network_position, weight)
		rotation.x = lerp_angle(rotation.x, network_rotation.x, weight)
		rotation.y = lerp_angle(rotation.y, network_rotation.y, weight)
		rotation.z = lerp_angle(rotation.z, network_rotation.z, weight)
		camera.rotation.x = lerp_angle(camera.rotation.x, network_camera_rotation.x, weight)
		camera.rotation.y = lerp_angle(camera.rotation.y, network_camera_rotation.y, weight)
		camera.rotation.z = lerp_angle(camera.rotation.z, network_camera_rotation.z, weight)


func _resolve_damageable(collider: Node) -> Node:
	var current := collider
	while current:
		if current.has_method("take_damage"):
			return current
		current = current.get_parent()
	return null


func _add_points(amount: int) -> void:
	points += amount * (2 if double_points_timer > 0.0 else 1)


func _setup_soldier_animations() -> void:
	soldier_anim_player = SoldierVisualHelper.setup_pistol_animation_library(
		soldier_model,
		SOLDIER_PISTOL_ANIMS,
		SOLDIER_ANIM_LIBRARY
	)
	_play_soldier_animation("idle")


func _update_soldier_animation(input_dir: Vector2, is_sprinting: bool) -> void:
	if not soldier_anim_player:
		return
	network_animation_airborne = not is_on_floor()
	network_animation_state = _select_soldier_animation_state(input_dir, is_sprinting, network_animation_airborne)
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if network_animation_state == SoldierAnimState.IDLE or network_animation_state == SoldierAnimState.JUMP:
		network_animation_speed = 1.0
	else:
		var reference_speed := SPRINT_SPEED if is_sprinting else WALK_SPEED
		network_animation_speed = clampf(horizontal_speed / reference_speed, 0.75, 1.35)
	_play_soldier_animation(SOLDIER_ANIM_NAMES[network_animation_state], network_animation_speed)
	_capture_soldier_animation_phase()


func _select_soldier_animation_state(input_dir: Vector2, is_sprinting: bool, airborne: bool) -> int:
	if airborne:
		return SoldierAnimState.JUMP
	if input_dir.length_squared() < 0.01:
		return SoldierAnimState.IDLE

	var horizontal := 0
	if input_dir.x < -0.35:
		horizontal = -1
	elif input_dir.x > 0.35:
		horizontal = 1
	var vertical := 0
	if input_dir.y < -0.35:
		vertical = -1
	elif input_dir.y > 0.35:
		vertical = 1

	var walk_state := SoldierAnimState.WALK_FORWARD
	if vertical < 0 and horizontal < 0:
		walk_state = SoldierAnimState.WALK_FORWARD_LEFT
	elif vertical < 0 and horizontal > 0:
		walk_state = SoldierAnimState.WALK_FORWARD_RIGHT
	elif vertical > 0 and horizontal < 0:
		walk_state = SoldierAnimState.WALK_BACKWARD_LEFT
	elif vertical > 0 and horizontal > 0:
		walk_state = SoldierAnimState.WALK_BACKWARD_RIGHT
	elif vertical > 0:
		walk_state = SoldierAnimState.WALK_BACKWARD
	elif horizontal < 0:
		walk_state = SoldierAnimState.WALK_LEFT
	elif horizontal > 0:
		walk_state = SoldierAnimState.WALK_RIGHT
	return walk_state + (SoldierAnimState.RUN_FORWARD - SoldierAnimState.WALK_FORWARD) if is_sprinting else walk_state


func _play_soldier_animation(state: String, playback_speed := 1.0) -> void:
	if not soldier_anim_player:
		return
	var animation_name := "%s/%s" % [SOLDIER_ANIM_LIBRARY, state]
	if soldier_anim_player.has_animation(animation_name) and soldier_current_anim != state:
		soldier_current_anim = state
		soldier_anim_player.play(animation_name, 0.15)
	soldier_anim_player.speed_scale = playback_speed


func _capture_soldier_animation_phase() -> void:
	if not soldier_anim_player or soldier_anim_player.current_animation_length <= 0.0:
		network_animation_phase = 0.0
		return
	network_animation_phase = clampf(
		soldier_anim_player.current_animation_position / soldier_anim_player.current_animation_length,
		0.0,
		1.0
	)


func _apply_remote_soldier_animation() -> void:
	if not soldier_anim_player:
		return
	var state := clampi(network_animation_state, SoldierAnimState.IDLE, SoldierAnimState.JUMP)
	var state_name: String = SOLDIER_ANIM_NAMES[state]
	_play_soldier_animation(state_name, network_animation_speed)
	var length := soldier_anim_player.current_animation_length
	if length <= 0.0:
		return
	var local_phase := clampf(soldier_anim_player.current_animation_position / length, 0.0, 1.0)
	var phase_error := absf(local_phase - network_animation_phase)
	if state != SoldierAnimState.JUMP:
		phase_error = minf(phase_error, 1.0 - phase_error)
	if phase_error > 0.12:
		soldier_anim_player.seek(network_animation_phase * length, true)


func _lock_soldier_visual_transform() -> void:
	if soldier_model:
		soldier_model.transform = soldier_default_transform


func _apply_local_player_visibility() -> void:
	camera.current = is_local_player
	soldier_model.visible = not is_local_player
	fps_hands.visible = is_local_player
	menu_layer.visible = is_local_player
	ammo_counter.visible = is_local_player
	health_hud.visible = is_local_player


func _try_step_up(direction: Vector3, speed: float, delta: float) -> bool:
	var horizontal_dir := Vector3(direction.x, 0.0, direction.z)
	if horizontal_dir.length_squared() < 0.001:
		return false
	horizontal_dir = horizontal_dir.normalized()
	var forward_motion := horizontal_dir * minf(speed * delta, STEP_FORWARD_DISTANCE)
	if not test_move(global_transform, forward_motion):
		return false
	var raised_transform := global_transform.translated(Vector3.UP * STEP_HEIGHT)
	if test_move(raised_transform, forward_motion):
		return false
	global_transform = raised_transform
	move_and_collide(forward_motion)
	_snap_down_after_step()
	velocity.y = 0.0
	return true


func _snap_down_after_step() -> void:
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 0.2,
		global_position + Vector3.DOWN * (STEP_HEIGHT + STEP_DOWN_DISTANCE)
	)
	query.collision_mask = collision_mask
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var hit_position: Vector3 = hit["position"]
		global_position.y = hit_position.y + 0.05


func _get_jump_velocity() -> float:
	return (2.0 * JUMP_HEIGHT) / JUMP_TIME_TO_APEX


func _get_jump_gravity() -> float:
	return (2.0 * JUMP_HEIGHT) / (JUMP_TIME_TO_APEX * JUMP_TIME_TO_APEX)


func set_flashlight_enabled(enabled: bool) -> void:
	if multiplayer.multiplayer_peer and is_local_player and not multiplayer.is_server():
		_request_flashlight.rpc_id(1, enabled)
	flashlight_enabled = enabled
	_apply_flashlight_visual(enabled)


@rpc("any_peer", "call_local", "reliable")
func _request_flashlight(enabled: bool) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	if sender == network_peer_id:
		flashlight_enabled = enabled
		_apply_flashlight_visual(enabled)


func _apply_flashlight_visual(enabled: bool) -> void:
	flashlight.visible = enabled
	flashlight.light_color = Color(1.0, 0.94, 0.82, 1.0)
	flashlight.light_energy = 10.5 if enabled else 0.0
	flashlight.spot_range = 72.0
	flashlight.spot_angle = 42.0
	flashlight.spot_attenuation = 0.55
	flashlight.light_specular = 0.35
	flashlight.shadow_bias = 0.045
	flashlight.shadow_enabled = enabled and bool(GraphicsSettings.get_setting("quality.flashlight_shadows", false))
	flashlight_fill.visible = enabled
	flashlight_fill.light_energy = 1.15 if enabled else 0.0


func take_damage(amount: float) -> void:
	if player_state != PlayerState.ALIVE:
		return
	if multiplayer.multiplayer_peer and not multiplayer.is_server():
		return
	_set_health(hp - maxf(amount, 0.0))
	if hp <= 0.0:
		if multiplayer.multiplayer_peer:
			_enter_downed()
		else:
			get_tree().reload_current_scene()
	if multiplayer.multiplayer_peer and multiplayer.is_server() and network_peer_id != 1 and network_peer_id in multiplayer.get_peers():
		_receive_authoritative_damage.rpc_id(network_peer_id, hp, player_state, downed_remaining)


@rpc("any_peer", "call_remote", "reliable", 2)
func _receive_authoritative_damage(authoritative_hp: float, authoritative_state: int, authoritative_downed_time: float) -> void:
	if not multiplayer.multiplayer_peer or multiplayer.get_remote_sender_id() != 1 or not is_local_player:
		return
	player_state = authoritative_state
	downed_remaining = authoritative_downed_time
	_set_health(authoritative_hp)
	_update_downed_hud()


func _set_health(new_hp: float) -> void:
	hp = clampf(new_hp, 0.0, max_hp)
	if health_hud:
		health_hud.set_health(hp, max_hp)
	health_changed.emit(hp, max_hp)


func _enter_downed() -> void:
	player_state = PlayerState.DOWNED
	downed_remaining = 45.0
	velocity = Vector3.ZERO
	if multiplayer.is_server():
		call_deferred("_check_team_defeat")


func _update_server_downed(delta: float) -> void:
	if player_state != PlayerState.DOWNED:
		return
	downed_remaining = maxf(downed_remaining - delta, 0.0)
	if downed_remaining <= 0.0:
		player_state = PlayerState.SPECTATING
		_check_team_defeat()


func _update_revive_input() -> void:
	if not multiplayer.multiplayer_peer or player_state != PlayerState.ALIVE or not is_local_player:
		return
	if Input.is_key_pressed(KEY_E):
		var target := _find_nearest_downed_player()
		var target_id := int(target.get("network_peer_id")) if target else 0
		if target_id != revive_target_peer_id:
			revive_target_peer_id = target_id
			_request_revive.rpc_id(1, target_id, true)
	elif revive_target_peer_id != 0:
		_request_revive.rpc_id(1, revive_target_peer_id, false)
		revive_target_peer_id = 0


@rpc("any_peer", "call_local", "reliable")
func _request_revive(target_peer_id: int, active: bool) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	if sender != network_peer_id:
		return
	revive_target_peer_id = target_peer_id if active else 0
	if not active:
		revive_progress = 0.0


func _update_server_revive(delta: float) -> void:
	if player_state != PlayerState.ALIVE or revive_target_peer_id == 0:
		revive_progress = 0.0
		return
	var target := _find_player_by_peer_id(revive_target_peer_id)
	if not target or int(target.get("player_state")) != PlayerState.DOWNED or global_position.distance_to(target.global_position) > REVIVE_RANGE:
		revive_target_peer_id = 0
		revive_progress = 0.0
		return
	revive_progress += delta
	if revive_progress >= REVIVE_DURATION:
		target.call("_revive_from_server")
		revive_target_peer_id = 0
		revive_progress = 0.0


func _revive_from_server() -> void:
	if not multiplayer.is_server() or player_state != PlayerState.DOWNED:
		return
	player_state = PlayerState.ALIVE
	downed_remaining = 0.0
	_set_health(40.0)


func _find_nearest_downed_player() -> Node3D:
	var nearest: Node3D = null
	var nearest_distance := REVIVE_RANGE
	for candidate in get_tree().get_nodes_in_group("player"):
		if candidate == self or int(candidate.get("player_state")) != PlayerState.DOWNED:
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance <= nearest_distance:
			nearest = candidate as Node3D
			nearest_distance = distance
	return nearest


func _find_player_by_peer_id(peer_id: int) -> Node3D:
	for candidate in get_tree().get_nodes_in_group("player"):
		if int(candidate.get("network_peer_id")) == peer_id:
			return candidate as Node3D
	return null


func _check_team_defeat() -> void:
	if not multiplayer.multiplayer_peer or not multiplayer.is_server():
		return
	for candidate in get_tree().get_nodes_in_group("player"):
		if int(candidate.get("player_state")) == PlayerState.ALIVE:
			return
	_end_multiplayer_match.rpc("Todos os jogadores foram derrubados.")


@rpc("any_peer", "call_local", "reliable")
func _end_multiplayer_match(reason: String) -> void:
	if not multiplayer.is_server() and multiplayer.get_remote_sender_id() != 1:
		return
	NetworkManager.leave_session(reason)
	get_tree().change_scene_to_file("res://src/scenes/main_menu.tscn")


func _create_downed_hud() -> void:
	if not is_local_player:
		return
	downed_overlay = ColorRect.new()
	downed_overlay.name = "DownedOverlay"
	downed_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	downed_overlay.color = Color(0.42, 0.0, 0.0, 0.72)
	downed_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	downed_overlay.visible = false
	$CrosshairLayer.add_child(downed_overlay)

	var downed_vignette := ColorRect.new()
	downed_vignette.name = "DarkVignette"
	downed_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	downed_vignette.color = Color(0.08, 0.0, 0.0, 0.34)
	downed_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	downed_overlay.add_child(downed_vignette)

	downed_status_label = Label.new()
	downed_status_label.name = "DownedStatus"
	downed_status_label.anchor_left = 0.5
	downed_status_label.anchor_top = 0.5
	downed_status_label.anchor_right = 0.5
	downed_status_label.anchor_bottom = 0.5
	downed_status_label.offset_left = -330.0
	downed_status_label.offset_top = -82.0
	downed_status_label.offset_right = 330.0
	downed_status_label.offset_bottom = 82.0
	downed_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	downed_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	downed_status_label.add_theme_font_size_override("font_size", 30)
	downed_status_label.add_theme_color_override("font_color", Color.WHITE)
	downed_status_label.add_theme_color_override("font_shadow_color", Color(0.08, 0.0, 0.0, 0.9))
	downed_status_label.add_theme_constant_override("shadow_offset_x", 2)
	downed_status_label.add_theme_constant_override("shadow_offset_y", 2)
	downed_overlay.add_child(downed_status_label)

	revive_prompt_panel = PanelContainer.new()
	revive_prompt_panel.name = "RevivePrompt"
	revive_prompt_panel.anchor_left = 0.5
	revive_prompt_panel.anchor_top = 1.0
	revive_prompt_panel.anchor_right = 0.5
	revive_prompt_panel.anchor_bottom = 1.0
	revive_prompt_panel.offset_left = -235.0
	revive_prompt_panel.offset_top = -178.0
	revive_prompt_panel.offset_right = 235.0
	revive_prompt_panel.offset_bottom = -72.0
	revive_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	revive_prompt_panel.visible = false
	var prompt_style := StyleBoxFlat.new()
	prompt_style.bg_color = Color(0.025, 0.03, 0.04, 0.92)
	prompt_style.border_width_left = 2
	prompt_style.border_width_top = 2
	prompt_style.border_width_right = 2
	prompt_style.border_width_bottom = 2
	prompt_style.border_color = Color(0.86, 0.9, 0.94, 0.85)
	prompt_style.corner_radius_top_left = 7
	prompt_style.corner_radius_top_right = 7
	prompt_style.corner_radius_bottom_left = 7
	prompt_style.corner_radius_bottom_right = 7
	revive_prompt_panel.add_theme_stylebox_override("panel", prompt_style)
	$CrosshairLayer.add_child(revive_prompt_panel)

	var prompt_margin := MarginContainer.new()
	prompt_margin.add_theme_constant_override("margin_left", 18)
	prompt_margin.add_theme_constant_override("margin_top", 12)
	prompt_margin.add_theme_constant_override("margin_right", 18)
	prompt_margin.add_theme_constant_override("margin_bottom", 12)
	revive_prompt_panel.add_child(prompt_margin)
	var prompt_content := VBoxContainer.new()
	prompt_content.add_theme_constant_override("separation", 8)
	prompt_margin.add_child(prompt_content)
	revive_prompt_label = Label.new()
	revive_prompt_label.name = "PromptLabel"
	revive_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	revive_prompt_label.add_theme_font_size_override("font_size", 19)
	revive_prompt_label.add_theme_color_override("font_color", Color.WHITE)
	prompt_content.add_child(revive_prompt_label)
	revive_progress_bar = ProgressBar.new()
	revive_progress_bar.name = "ReviveProgress"
	revive_progress_bar.custom_minimum_size = Vector2(0.0, 18.0)
	revive_progress_bar.min_value = 0.0
	revive_progress_bar.max_value = REVIVE_DURATION
	revive_progress_bar.show_percentage = false
	revive_progress_bar.visible = false
	var progress_background := StyleBoxFlat.new()
	progress_background.bg_color = Color(0.12, 0.14, 0.17, 1.0)
	progress_background.corner_radius_top_left = 4
	progress_background.corner_radius_top_right = 4
	progress_background.corner_radius_bottom_left = 4
	progress_background.corner_radius_bottom_right = 4
	revive_progress_bar.add_theme_stylebox_override("background", progress_background)
	var progress_fill := StyleBoxFlat.new()
	progress_fill.bg_color = Color(0.9, 0.94, 0.97, 1.0)
	progress_fill.corner_radius_top_left = 4
	progress_fill.corner_radius_top_right = 4
	progress_fill.corner_radius_bottom_left = 4
	progress_fill.corner_radius_bottom_right = 4
	revive_progress_bar.add_theme_stylebox_override("fill", progress_fill)
	prompt_content.add_child(revive_progress_bar)


func _update_downed_hud() -> void:
	if not downed_overlay or not downed_status_label:
		return
	downed_overlay.visible = player_state != PlayerState.ALIVE
	if player_state == PlayerState.DOWNED:
		downed_overlay.color = Color(0.42, 0.0, 0.0, 0.72)
		downed_status_label.text = "VOCE ESTA MORRENDO\n%.0f SEGUNDOS\n\nAGUARDE UM ALIADO" % ceilf(downed_remaining)
	elif player_state == PlayerState.SPECTATING:
		downed_overlay.color = Color(0.18, 0.0, 0.0, 0.82)
		downed_status_label.text = "VOCE MORREU\nMODO ESPECTADOR"


func _update_revive_hud() -> void:
	if not revive_prompt_panel or not revive_prompt_label or not revive_progress_bar:
		return
	if player_state != PlayerState.ALIVE or not multiplayer.multiplayer_peer:
		revive_prompt_panel.visible = false
		return
	var target := _find_nearest_downed_player()
	if not target:
		revive_prompt_panel.visible = false
		return
	revive_prompt_panel.visible = true
	var target_name := String(target.get("player_display_name"))
	if target_name.is_empty():
		target_name = "ALIADO"
	var is_current_target := revive_target_peer_id == int(target.get("network_peer_id"))
	var is_reviving := is_current_target and (Input.is_key_pressed(KEY_E) or revive_progress > 0.0)
	revive_prompt_label.text = "REANIMANDO %s" % target_name.to_upper() if is_reviving else "SEGURE [E] PARA REANIMAR %s" % target_name.to_upper()
	revive_progress_bar.visible = is_reviving
	revive_progress_bar.value = clampf(revive_progress, 0.0, REVIVE_DURATION)


func _create_scoreboard() -> void:
	if not is_local_player:
		return
	var panel := PanelContainer.new()
	panel.name = "Scoreboard"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.18
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.18
	panel.offset_left = -280.0
	panel.offset_top = 0.0
	panel.offset_right = 280.0
	panel.offset_bottom = 300.0
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.025, 0.034, 0.92)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.96, 0.77, 0.19, 0.72)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)
	$CrosshairLayer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	var title := Label.new()
	title.text = "JOGADORES NA PARTIDA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.96, 0.77, 0.19))
	content.add_child(title)
	var separator := HSeparator.new()
	content.add_child(separator)
	var list := Label.new()
	list.name = "PlayerList"
	list.add_theme_font_size_override("font_size", 17)
	list.add_theme_color_override("font_color", Color(0.9, 0.92, 0.94))
	list.text = "Jogador"
	content.add_child(list)
	var hint := Label.new()
	hint.text = "Segure TAB para visualizar"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.58, 0.62, 0.67))
	content.add_child(hint)


func _set_scoreboard_visible(enabled: bool) -> void:
	var scoreboard := get_node_or_null("CrosshairLayer/Scoreboard") as Control
	if scoreboard:
		scoreboard.visible = enabled
		if enabled:
			_update_scoreboard()


func _update_scoreboard() -> void:
	var scoreboard := get_node_or_null("CrosshairLayer/Scoreboard") as Control
	if not scoreboard or not scoreboard.visible:
		return
	var list := scoreboard.get_node("MarginContainer/VBoxContainer/PlayerList") as Label
	var lines := PackedStringArray()
	if multiplayer.multiplayer_peer and not NetworkManager.players.is_empty():
		for peer_id: int in NetworkManager.players:
			var data: Dictionary = NetworkManager.players[peer_id]
			var player_node := _find_player_by_peer_id(peer_id)
			var status := "CONECTANDO"
			var health := 0
			if player_node:
				health = roundi(float(player_node.get("hp")))
				status = _player_state_label(int(player_node.get("player_state")))
			var host_tag := "  [HOST]" if bool(data.get("host", false)) else ""
			lines.append("%s%s    %d HP    %s" % [String(data.get("name", "Jogador")), host_tag, health, status])
	else:
		lines.append("Jogador    %d HP    %s" % [roundi(hp), _player_state_label(player_state)])
	list.text = "\n\n".join(lines)


func _player_state_label(value: int) -> String:
	match value:
		PlayerState.DOWNED:
			return "CAIDO"
		PlayerState.SPECTATING:
			return "ESPECTADOR"
		_:
			return "ATIVO"


func register_interactable(node: Node3D) -> void:
	nearby_interactable = node


func unregister_interactable(node: Node3D) -> void:
	if nearby_interactable == node:
		nearby_interactable = null


func _interact_with(obj: Node3D) -> void:
	if multiplayer.multiplayer_peer and not multiplayer.is_server():
		_request_interaction.rpc_id(1, obj.get_path())
		return
	_apply_interaction(obj)


@rpc("any_peer", "call_local", "reliable")
func _request_interaction(object_path: NodePath) -> void:
	if not multiplayer.is_server() or player_state != PlayerState.ALIVE:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	if sender != network_peer_id:
		return
	var obj := get_node_or_null(object_path) as Node3D
	if obj and global_position.distance_to(obj.global_position) <= 3.0:
		_apply_interaction(obj)


func _apply_interaction(obj: Node3D) -> void:
	if not ("perk_id" in obj):
		return
	var perk_id: String = obj.perk_id
	var perk_name: String = obj.perk_name
	var cost: int = obj.cost
	if active_perks.has(perk_id):
		show_notification("Voce ja tem %s." % perk_name)
	elif points >= cost:
		points -= cost
		active_perks.append(perk_id)
		if perk_id == "juggernog":
			max_hp = 250.0
			_set_health(max_hp)
		show_notification("%s adquirido." % perk_name)
	else:
		show_notification("Pontos insuficientes para %s." % perk_name)


func collect_powerup(powerup_type: String) -> void:
	if multiplayer.multiplayer_peer:
		if not multiplayer.is_server():
			return
		_apply_powerup(powerup_type)
		if network_peer_id != 1:
			_receive_powerup.rpc_id(network_peer_id, powerup_type)
		return
	_apply_powerup(powerup_type)


@rpc("any_peer", "reliable")
func _receive_powerup(powerup_type: String) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	_apply_powerup(powerup_type)


func _apply_powerup(powerup_type: String) -> void:
	match powerup_type:
		"max_ammo":
			for ammo_type in MAX_AMMO_VALUES:
				fps_hands.inventory["ammo"][ammo_type] = MAX_AMMO_VALUES[ammo_type]
			fps_hands.update_inventory()
			show_notification("MUNICAO MAXIMA")
		"insta_kill":
			insta_kill_timer = 30.0
			show_notification("BAIXAS INSTANTANEAS")
		"double_points":
			double_points_timer = 30.0
			show_notification("PONTOS DUPLOS")
		"instant_money":
			_add_points(500)
		"nuke":
			for zombie in get_tree().get_nodes_in_group("zombies"):
				if zombie.has_method("take_damage") and not bool(zombie.get("is_dead")):
					zombie.call("take_damage", 999999.0)
			_add_points(400)


func show_notification(message: String) -> void:
	print("[PLAYER] %s" % message)
