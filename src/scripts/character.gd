extends CharacterBody3D

signal health_changed(current_hp: float, maximum_hp: float)
signal shop_state_changed(snapshot: Dictionary)
signal shop_feedback(message: String)

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
const NETWORK_FIRE_INTERVAL := [0.16, 0.075, 0.10, 0.10, 0.35, 0.45]
const WEAPON_NAMES := ["C19", "SMG45", "AK", "LMG63", "Sawnoff", "Faca"]
const WEAPON_PRICES := [0, 1800, 3200, 5000, 2400, 0]
const WEAPON_AMMO_TYPES := ["9mm", "9mm", "rifle", "rifle", "shell", "none"]
const BASE_MAGAZINE_CAPACITIES := [19, 30, 30, 100, 2, 0]
const DAMAGE_MULTIPLIERS := [1.0, 1.15, 1.30, 1.50]
const DAMAGE_UPGRADE_COSTS := [[600, 1200, 2400], [750, 1500, 3000], [900, 1800, 3600], [1200, 2400, 4800], [800, 1600, 3200], [0, 0, 0]]
const FAST_RELOAD_COSTS := [900, 1100, 1350, 1800, 1200, 0]
const EXTENDED_MAG_COSTS := [1100, 1400, 1650, 2400, 1500, 0]
const RAPID_FIRE_COSTS := [1300, 1700, 1950, 2600, 1700, 0]
const AMMO_PACKS := {
	"9mm": {"amount": 60, "maximum": 240, "cost": 250},
	"rifle": {"amount": 120, "maximum": 600, "cost": 450},
	"shell": {"amount": 16, "maximum": 64, "cost": 350},
}
const STARTING_SCRAP := 250
const ARMOR_MAX := 100.0
const ARMOR_COST_PER_POINT := 12
const MEDKIT_COST := 450
const MEDKIT_MAX := 3
const MEDKIT_HEAL := 50.0
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
var server_ammo := {"9mm": 240, "rifle": 600, "shell": 64, "none": 0}
var scrap := STARTING_SCRAP
var fragments := 0
var armor := 0.0
var medkits := 0
var owned_weapon_slots: Array[bool] = [true, false, false, false, false, true]
var weapon_upgrades: Dictionary = {}
var max_hp := 100.0
var hp := 100.0
var mouse_sensitivity := 0.002
var flashlight_enabled := false
var active_perks: Array[String] = []
var nearby_interactable: Node3D = null
var nearby_interactables: Array[Node3D] = []
var insta_kill_timer := 0.0
var shop_open := false
var soldier_anim_player: AnimationPlayer = null
var soldier_current_anim := ""
var soldier_default_transform := Transform3D.IDENTITY
var remote_last_position := Vector3.ZERO
var footstep_timer := 0.0
var solo_death_pending := false
var downed_overlay: ColorRect = null
var downed_status_label: Label = null
var revive_prompt_panel: PanelContainer = null
var revive_prompt_label: Label = null
var revive_progress_bar: ProgressBar = null
var scoreboard_player_list: Label = null

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
@onready var interaction_prompt: PanelContainer = $CrosshairLayer/InteractionPrompt
@onready var interaction_prompt_label: Label = $CrosshairLayer/InteractionPrompt/PromptLabel
@onready var footstep_audio: AudioStreamPlayer3D = $FootstepAudio
@onready var damage_audio: AudioStreamPlayer3D = $DamageAudio
@onready var death_audio: AudioStreamPlayer3D = $DeathAudio


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
	_apply_shop_state_to_local_systems()
	_create_downed_hud()
	_create_scoreboard()

	if is_local_player:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		var menu_controller_script := preload("res://src/scripts/menu_controller.gd")
		var menu_controller := menu_controller_script.new()
		menu_layer.add_child(menu_controller)
		var shop_scene := preload("res://src/scenes/shop_menu.tscn")
		var shop_menu := shop_scene.instantiate()
		menu_layer.add_child(shop_menu)
		shop_menu.call("set_player", self)
		_emit_shop_state()
	_update_interaction_prompt()


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
		elif event.physical_keycode == KEY_H:
			request_use_medkit()
		else:
			var slot := WEAPON_SLOT_KEYS.find(event.physical_keycode)
			if slot != -1:
				fps_hands.take_weapon(slot)
	elif event is InputEventKey and not event.pressed and event.physical_keycode == KEY_TAB:
		_set_scoreboard_visible(false)


func _process(delta: float) -> void:
	_lock_soldier_visual_transform()
	_update_footstep_audio(delta)
	if is_local_player:
		_refresh_nearby_interactable()
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
	if weapon_index != equipped_weapon_index or not _is_weapon_owned(weapon_index):
		return
	var now := Time.get_ticks_msec()
	var minimum_interval_ms := roundi(_get_weapon_fire_interval(weapon_index) * 1000.0)
	if now - last_server_shot_ms < minimum_interval_ms:
		return
	if weapon_index != 5:
		if int(server_magazines[weapon_index]) <= 0:
			return
		server_magazines[weapon_index] = int(server_magazines[weapon_index]) - 1
	last_server_shot_ms = now
	validated_shot_weapon = weapon_index
	validated_shot_hits_remaining = 8 if weapon_index == 4 else 1
	# Mantem o token valido durante a latencia de ida e volta sem liberar dano extra.
	validated_shot_expires_ms = now + 750
	validated_attack_is_melee = false


@rpc("any_peer", "call_local", "reliable", 1)
func _request_melee(weapon_index: int) -> void:
	if not multiplayer.is_server() or player_state != PlayerState.ALIVE or not _sender_owns_character():
		return
	if weapon_index != 5 or weapon_index != equipped_weapon_index or not _is_weapon_owned(weapon_index):
		return
	var now := Time.get_ticks_msec()
	var minimum_interval_ms := roundi(_get_weapon_fire_interval(weapon_index) * 1000.0)
	if now - last_server_shot_ms < minimum_interval_ms:
		return
	last_server_shot_ms = now
	validated_shot_weapon = weapon_index
	validated_shot_hits_remaining = 1
	validated_shot_expires_ms = now + 500
	validated_attack_is_melee = true


@rpc("any_peer", "call_local", "reliable", 1)
func _request_reload(weapon_index: int) -> void:
	if not multiplayer.is_server() or player_state != PlayerState.ALIVE or not _sender_owns_character():
		return
	if weapon_index != equipped_weapon_index or not _is_weapon_owned(weapon_index) or weapon_index == 5:
		return
	var needed := _get_magazine_capacity(weapon_index) - int(server_magazines[weapon_index])
	if needed <= 0:
		return
	var ammo_type: String = WEAPON_AMMO_TYPES[weapon_index]
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
		var slot := clampi(index, 0, WEAPON_SLOT_KEYS.size() - 1)
		if _is_weapon_owned(slot):
			equipped_weapon_index = slot


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
	if sender != network_peer_id or not _is_weapon_owned(weapon_index):
		return
	var expected_damage: float = NETWORK_MELEE_DAMAGE if validated_attack_is_melee else _get_weapon_damage(weapon_index)
	if not is_equal_approx(base_damage, expected_damage):
		return
	var collider := get_node_or_null(collider_path) as Node3D
	var allowed_range: float = NETWORK_MELEE_RANGE if validated_attack_is_melee else float(NETWORK_WEAPON_RANGE[weapon_index])
	if not collider or collider.is_in_group("player") or global_position.distance_to(point) > allowed_range + 2.0:
		return
	if point.distance_to(collider.global_position) > 6.0:
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
	var immune_to_insta_kill_value: Variant = target.get("immune_to_insta_kill")
	var target_ignores_insta_kill := immune_to_insta_kill_value != null and bool(immune_to_insta_kill_value)
	if insta_kill_timer > 0.0 and not target_ignores_insta_kill:
		final_damage = 999999.0
	target.call("take_damage", final_damage, is_headshot)
	if was_dead:
		return
	var is_kill := bool(target.get("is_dead")) or float(target.get("hp")) <= 0.0
	if multiplayer.multiplayer_peer and multiplayer.is_server() and network_peer_id != 1:
		_confirm_hitmarker.rpc_id(network_peer_id, is_headshot, is_kill)
	elif is_local_player:
		hitmarker.call("show_hit", is_headshot, is_kill)


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
	var remaining_damage := maxf(amount, 0.0)
	if armor > 0.0:
		var absorbed := minf(armor, remaining_damage)
		armor -= absorbed
		remaining_damage -= absorbed
		_update_equipment_hud()
	var took_health_damage := remaining_damage > 0.0
	_set_health(hp - remaining_damage)
	var lethal_hit := hp <= 0.0
	if took_health_damage:
		_play_player_hit_audio(lethal_hit)
	if hp <= 0.0:
		if multiplayer.multiplayer_peer:
			_enter_downed()
		else:
			_start_solo_death_reload()
	if multiplayer.multiplayer_peer and multiplayer.is_server() and network_peer_id != 1 and network_peer_id in multiplayer.get_peers():
		_receive_authoritative_damage.rpc_id(network_peer_id, hp, armor, player_state, downed_remaining, took_health_damage, lethal_hit)


@rpc("any_peer", "call_remote", "reliable", 2)
func _receive_authoritative_damage(authoritative_hp: float, authoritative_armor: float, authoritative_state: int, authoritative_downed_time: float, play_hit_audio: bool, play_death_audio: bool) -> void:
	if not multiplayer.multiplayer_peer or multiplayer.get_remote_sender_id() != 1 or not is_local_player:
		return
	player_state = authoritative_state
	downed_remaining = authoritative_downed_time
	armor = clampf(authoritative_armor, 0.0, ARMOR_MAX)
	_set_health(authoritative_hp)
	_update_equipment_hud()
	_update_downed_hud()
	if play_hit_audio:
		_play_player_hit_audio(play_death_audio)


func _play_player_hit_audio(lethal: bool) -> void:
	if lethal:
		damage_audio.stop()
		death_audio.play()
	else:
		damage_audio.pitch_scale = randf_range(0.96, 1.04)
		damage_audio.play()


func _start_solo_death_reload() -> void:
	if solo_death_pending:
		return
	solo_death_pending = true
	player_state = PlayerState.SPECTATING
	velocity = Vector3.ZERO
	var delay := 1.8
	if death_audio.stream:
		delay = maxf(death_audio.stream.get_length(), 0.25)
	get_tree().create_timer(delay).timeout.connect(_reload_after_solo_death)


func _reload_after_solo_death() -> void:
	if is_inside_tree():
		get_tree().reload_current_scene()


func _update_footstep_audio(delta: float) -> void:
	var moving := network_animation_state >= SoldierAnimState.WALK_FORWARD and network_animation_state <= SoldierAnimState.RUN_BACKWARD_RIGHT
	if player_state != PlayerState.ALIVE or local_input_blocked or network_animation_airborne or not moving:
		footstep_timer = 0.0
		return
	footstep_timer -= delta
	if footstep_timer > 0.0:
		return
	var running := network_animation_state >= SoldierAnimState.RUN_FORWARD
	footstep_audio.pitch_scale = randf_range(0.94, 1.06) * (1.04 if running else 1.0)
	footstep_audio.play()
	var base_interval := 0.30 if running else 0.44
	footstep_timer = base_interval / maxf(network_animation_speed, 0.75)


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
	var sender := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and sender not in [0, 1]:
		return
	if not multiplayer.is_server() and sender != 1:
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
	scoreboard_player_list = list
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
	if not is_instance_valid(scoreboard_player_list):
		scoreboard_player_list = scoreboard.find_child("PlayerList", true, false) as Label
	if not scoreboard_player_list:
		return
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
			var player_fragments := int(player_node.get("fragments")) if player_node else 0
			lines.append("%s%s    %d HP    %s    %d FRAGMENTOS" % [String(data.get("name", "Jogador")), host_tag, health, status, player_fragments])
	else:
		lines.append("Jogador    %d HP    %s    %d FRAGMENTOS" % [roundi(hp), _player_state_label(player_state), fragments])
	scoreboard_player_list.text = "\n\n".join(lines)


func _player_state_label(value: int) -> String:
	match value:
		PlayerState.DOWNED:
			return "CAIDO"
		PlayerState.SPECTATING:
			return "ESPECTADOR"
		_:
			return "ATIVO"


func get_shop_catalog() -> Dictionary:
	return {
		"weapon_names": WEAPON_NAMES.duplicate(),
		"weapon_prices": WEAPON_PRICES.duplicate(),
		"damage_costs": DAMAGE_UPGRADE_COSTS.duplicate(true),
		"fast_reload_costs": FAST_RELOAD_COSTS.duplicate(),
		"extended_mag_costs": EXTENDED_MAG_COSTS.duplicate(),
		"rapid_fire_costs": RAPID_FIRE_COSTS.duplicate(),
		"ammo_packs": AMMO_PACKS.duplicate(true),
		"medkit_cost": MEDKIT_COST,
		"medkit_max": MEDKIT_MAX,
		"armor_max": ARMOR_MAX,
		"armor_cost_per_point": ARMOR_COST_PER_POINT,
	}


func get_shop_snapshot() -> Dictionary:
	if is_local_player and fps_hands:
		server_ammo = (fps_hands.inventory["ammo"] as Dictionary).duplicate(true)
	return {
		"scrap": scrap,
		"armor": armor,
		"medkits": medkits,
		"owned": owned_weapon_slots.duplicate(),
		"upgrades": weapon_upgrades.duplicate(true),
		"ammo": server_ammo.duplicate(true),
		"hp": hp,
		"max_hp": max_hp,
		"equipped_slot": equipped_weapon_index,
	}


func set_shop_open(enabled: bool) -> void:
	if not is_local_player:
		return
	shop_open = enabled
	local_input_blocked = enabled
	fps_hands.call("set_combat_enabled", not enabled)
	crosshair.visible = not enabled
	hitmarker.visible = not enabled
	ammo_counter.visible = not enabled
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if enabled else Input.MOUSE_MODE_CAPTURED)
	_update_interaction_prompt()


func open_crafting_menu(source: Node3D) -> void:
	if not is_local_player or player_state != PlayerState.ALIVE or source != nearby_interactable:
		return
	var crafting_menu := menu_layer.get_node_or_null("ShopMenu") as Control
	if crafting_menu and crafting_menu.has_method("open_shop"):
		crafting_menu.call("open_shop")


func request_shop_purchase(purchase_type: String, slot: int = -1) -> void:
	if not is_local_player or player_state != PlayerState.ALIVE:
		return
	if multiplayer.multiplayer_peer and not multiplayer.is_server():
		_request_shop_purchase.rpc_id(1, purchase_type, slot)
		return
	var message := _apply_shop_purchase(purchase_type, slot)
	_sync_shop_state(message)


@rpc("any_peer", "call_local", "reliable")
func _request_shop_purchase(purchase_type: String, slot: int) -> void:
	if not multiplayer.is_server() or not _sender_owns_character() or player_state != PlayerState.ALIVE:
		return
	var message := _apply_shop_purchase(purchase_type, slot)
	_sync_shop_state(message)


func request_use_medkit() -> void:
	if not is_local_player or player_state != PlayerState.ALIVE:
		return
	if multiplayer.multiplayer_peer and not multiplayer.is_server():
		_request_use_medkit.rpc_id(1)
		return
	var message := _apply_medkit()
	_sync_shop_state(message)


@rpc("any_peer", "call_local", "reliable")
func _request_use_medkit() -> void:
	if not multiplayer.is_server() or not _sender_owns_character():
		return
	var message := _apply_medkit()
	_sync_shop_state(message)


func _apply_shop_purchase(purchase_type: String, slot: int) -> String:
	match purchase_type:
		"weapon":
			if slot <= 0 or slot >= 5:
				return "Arma invalida."
			if _is_weapon_owned(slot):
				return "%s ja foi adquirida." % WEAPON_NAMES[slot]
			var weapon_cost: int = WEAPON_PRICES[slot]
			if not _spend_scrap(weapon_cost):
				return "Sucata insuficiente."
			owned_weapon_slots[slot] = true
			equipped_weapon_index = slot
			return "%s adquirida." % WEAPON_NAMES[slot]
		"armor":
			var missing_armor := ARMOR_MAX - armor
			if missing_armor <= 0.0:
				return "O colete ja esta completo."
			var armor_cost := ceili(missing_armor) * ARMOR_COST_PER_POINT
			if not _spend_scrap(armor_cost):
				return "Sucata insuficiente."
			armor = ARMOR_MAX
			return "Colete equipado e reparado."
		"medkit":
			if medkits >= MEDKIT_MAX:
				return "Voce ja carrega 3 kits de cura."
			if not _spend_scrap(MEDKIT_COST):
				return "Sucata insuficiente."
			medkits += 1
			return "Kit de cura guardado. Use H para consumir."
		"ammo":
			return _purchase_ammo(slot)
		"damage", "fast_reload", "extended_mag", "rapid_fire":
			return _purchase_upgrade(purchase_type, slot)
		_:
			return "Compra invalida."


func _purchase_ammo(slot: int) -> String:
	if not _is_weapon_owned(slot) or slot == 5:
		return "Selecione uma arma de fogo adquirida."
	var ammo_type: String = WEAPON_AMMO_TYPES[slot]
	var pack := AMMO_PACKS.get(ammo_type, {}) as Dictionary
	if pack.is_empty():
		return "Esta arma nao usa municao compravel."
	var current := int(server_ammo.get(ammo_type, 0))
	var maximum := int(pack["maximum"])
	if current >= maximum:
		return "A reserva de %s ja esta cheia." % ammo_type
	if not _spend_scrap(int(pack["cost"])):
		return "Sucata insuficiente."
	server_ammo[ammo_type] = mini(current + int(pack["amount"]), maximum)
	return "Pacote de municao %s adquirido." % ammo_type


func _purchase_upgrade(upgrade_id: String, slot: int) -> String:
	if not _is_weapon_owned(slot) or slot == 5:
		return "Selecione uma arma de fogo adquirida."
	var upgrades := _get_upgrade_state(slot)
	var cost := 0
	match upgrade_id:
		"damage":
			var level := int(upgrades["damage_level"])
			if level >= 3:
				return "Dano ja esta no nivel maximo."
			cost = int(DAMAGE_UPGRADE_COSTS[slot][level])
			if not _spend_scrap(cost):
				return "Sucata insuficiente."
			upgrades["damage_level"] = level + 1
		"fast_reload":
			if bool(upgrades["fast_reload"]):
				return "Carregamento rapido ja adquirido."
			cost = int(FAST_RELOAD_COSTS[slot])
			if not _spend_scrap(cost):
				return "Sucata insuficiente."
			upgrades["fast_reload"] = true
		"extended_mag":
			if bool(upgrades["extended_mag"]):
				return "Carregador estendido ja adquirido."
			cost = int(EXTENDED_MAG_COSTS[slot])
			if not _spend_scrap(cost):
				return "Sucata insuficiente."
			upgrades["extended_mag"] = true
		"rapid_fire":
			if bool(upgrades["rapid_fire"]):
				return "Rapid fire ja adquirido."
			cost = int(RAPID_FIRE_COSTS[slot])
			if not _spend_scrap(cost):
				return "Sucata insuficiente."
			upgrades["rapid_fire"] = true
	weapon_upgrades[slot] = upgrades
	return "Melhoria aplicada em %s." % WEAPON_NAMES[slot]


func _apply_medkit() -> String:
	if player_state != PlayerState.ALIVE:
		return "Nao e possivel usar o kit agora."
	if medkits <= 0:
		return "Nenhum kit de cura disponivel."
	if hp >= max_hp:
		return "Sua vida ja esta cheia."
	medkits -= 1
	_set_health(minf(hp + MEDKIT_HEAL, max_hp))
	return "Kit usado: 50 HP restaurados."


func _spend_scrap(cost: int) -> bool:
	if cost < 0 or scrap < cost:
		return false
	scrap -= cost
	return true


func collect_scrap(amount: int) -> bool:
	if amount <= 0 or player_state != PlayerState.ALIVE:
		return false
	if multiplayer.multiplayer_peer and not multiplayer.is_server():
		return false
	scrap += amount
	_sync_shop_state("+%d SUCATA" % amount)
	return true


func _get_upgrade_state(slot: int) -> Dictionary:
	var upgrades := (weapon_upgrades.get(slot, {}) as Dictionary).duplicate(true)
	upgrades["damage_level"] = clampi(int(upgrades.get("damage_level", 0)), 0, 3)
	upgrades["fast_reload"] = bool(upgrades.get("fast_reload", false))
	upgrades["extended_mag"] = bool(upgrades.get("extended_mag", false))
	upgrades["rapid_fire"] = bool(upgrades.get("rapid_fire", false))
	return upgrades


func _is_weapon_owned(slot: int) -> bool:
	return slot >= 0 and slot < owned_weapon_slots.size() and owned_weapon_slots[slot]


func _get_weapon_damage(slot: int) -> float:
	if slot < 0 or slot >= NETWORK_WEAPON_DAMAGE.size():
		return 0.0
	var level := int(_get_upgrade_state(slot)["damage_level"])
	return float(NETWORK_WEAPON_DAMAGE[slot]) * float(DAMAGE_MULTIPLIERS[level])


func _get_weapon_fire_interval(slot: int) -> float:
	if slot < 0 or slot >= NETWORK_FIRE_INTERVAL.size():
		return 999.0
	var interval := float(NETWORK_FIRE_INTERVAL[slot])
	if bool(_get_upgrade_state(slot)["rapid_fire"]):
		interval *= 0.8
	return interval


func _get_magazine_capacity(slot: int) -> int:
	if slot < 0 or slot >= BASE_MAGAZINE_CAPACITIES.size():
		return 0
	var capacity := int(BASE_MAGAZINE_CAPACITIES[slot])
	if bool(_get_upgrade_state(slot)["extended_mag"]) and capacity > 0:
		capacity = 4 if slot == 4 else ceili(float(capacity) * 1.5)
	return capacity


func _sync_shop_state(message: String = "") -> void:
	if multiplayer.multiplayer_peer and multiplayer.is_server() and network_peer_id != 1:
		_receive_shop_state.rpc_id(network_peer_id, get_shop_snapshot(), message)
	else:
		_apply_shop_state_to_local_systems()
		_emit_shop_state()
		if not message.is_empty():
			shop_feedback.emit(message)
			_show_scrap_gain_if_needed(message)


@rpc("any_peer", "call_remote", "reliable")
func _receive_shop_state(snapshot: Dictionary, message: String) -> void:
	if not multiplayer.multiplayer_peer or multiplayer.get_remote_sender_id() != 1 or not is_local_player:
		return
	scrap = int(snapshot.get("scrap", scrap))
	armor = float(snapshot.get("armor", armor))
	medkits = int(snapshot.get("medkits", medkits))
	var received_owned := snapshot.get("owned", owned_weapon_slots) as Array
	for slot in owned_weapon_slots.size():
		owned_weapon_slots[slot] = slot < received_owned.size() and bool(received_owned[slot])
	weapon_upgrades = (snapshot.get("upgrades", {}) as Dictionary).duplicate(true)
	server_ammo = (snapshot.get("ammo", server_ammo) as Dictionary).duplicate(true)
	equipped_weapon_index = clampi(int(snapshot.get("equipped_slot", equipped_weapon_index)), 0, WEAPON_SLOT_KEYS.size() - 1)
	_set_health(float(snapshot.get("hp", hp)))
	_apply_shop_state_to_local_systems()
	_emit_shop_state()
	if not message.is_empty():
		shop_feedback.emit(message)
		_show_scrap_gain_if_needed(message)


func _show_scrap_gain_if_needed(message: String) -> void:
	if not message.begins_with("+") or not message.ends_with(" SUCATA"):
		return
	show_notification(message)
	if health_hud and health_hud.has_method("show_scrap_gain"):
		health_hud.call("show_scrap_gain", message)


func collect_fragment() -> bool:
	if multiplayer.multiplayer_peer and not multiplayer.is_server():
		return false
	if player_state != PlayerState.ALIVE:
		return false
	fragments += 1
	return true


func _apply_shop_state_to_local_systems() -> void:
	if not fps_hands:
		return
	fps_hands.call("set_owned_weapon_slots", owned_weapon_slots)
	for slot in WEAPON_SLOT_KEYS.size():
		fps_hands.call("set_weapon_upgrades", slot, _get_upgrade_state(slot))
	server_ammo["none"] = 0
	fps_hands.inventory["ammo"] = server_ammo.duplicate(true)
	if _is_weapon_owned(equipped_weapon_index):
		fps_hands.call("take_weapon", equipped_weapon_index)
	_update_equipment_hud()


func _emit_shop_state() -> void:
	_update_equipment_hud()
	shop_state_changed.emit(get_shop_snapshot())


func _update_equipment_hud() -> void:
	if not health_hud:
		return
	if health_hud.has_method("set_armor"):
		health_hud.call("set_armor", armor, ARMOR_MAX)
	if health_hud.has_method("set_equipment"):
		health_hud.call("set_equipment", scrap, medkits, MEDKIT_MAX)


func register_interactable(node: Node3D) -> void:
	if not is_instance_valid(node) or nearby_interactables.has(node):
		return
	nearby_interactables.append(node)
	_refresh_nearby_interactable()


func unregister_interactable(node: Node3D) -> void:
	nearby_interactables.erase(node)
	_refresh_nearby_interactable()


func _refresh_nearby_interactable() -> void:
	for candidate in nearby_interactables.duplicate():
		if not is_instance_valid(candidate) or not candidate.is_inside_tree():
			nearby_interactables.erase(candidate)
	nearby_interactable = null
	var nearest_distance := INF
	for candidate in nearby_interactables:
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearby_interactable = candidate
			nearest_distance = distance
	_update_interaction_prompt()


func _update_interaction_prompt() -> void:
	if not interaction_prompt or not interaction_prompt_label:
		return
	var should_show := is_local_player and player_state == PlayerState.ALIVE and not shop_open and is_instance_valid(nearby_interactable)
	interaction_prompt.visible = should_show
	if not should_show:
		return
	if nearby_interactable.has_method("get_interaction_prompt"):
		interaction_prompt_label.text = String(nearby_interactable.call("get_interaction_prompt"))
	else:
		interaction_prompt_label.text = "APERTE E PARA INTERAGIR"


func _interact_with(obj: Node3D) -> void:
	if obj.has_method("interact_local"):
		obj.call("interact_local", self)
		return
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
	show_notification("Maquinas de perk estao desativadas nesta economia.")


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
		"nuke":
			for zombie in get_tree().get_nodes_in_group("zombies"):
				if zombie.has_method("take_damage") and not bool(zombie.get("is_dead")):
					zombie.call("take_damage", 999999.0)


func show_notification(message: String) -> void:
	print("[PLAYER] %s" % message)
