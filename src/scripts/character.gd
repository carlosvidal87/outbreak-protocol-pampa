extends CharacterBody3D

# script principal do jogador

const SoldierVisualHelper = preload("res://src/scripts/soldier_visual_helper.gd")

const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_HEIGHT := 1.05
const JUMP_TIME_TO_APEX := 0.38
const STEP_HEIGHT := 0.45
const STEP_FORWARD_DISTANCE := 0.55
const STEP_DOWN_DISTANCE := 0.8
const PLAYER_CAMERA_FAR := 600.0
const BOB_FREQ = 2.0
const BOB_AMP = 0.05
const RECOIL_RETURN = 15.0
const MAX_HP = 100.0
const SOLDIER_ANIM_LIBRARY = "pistol"
const SOLDIER_PISTOL_ANIMS = {
	"idle": "res://assets/characters/Soldier/Pistol Animation/pistol idle.fbx",
	"walk": "res://assets/characters/Soldier/Pistol Animation/pistol walk.fbx",
	"run": "res://assets/characters/Soldier/Pistol Animation/pistol run.fbx",
	"strafe": "res://assets/characters/Soldier/Pistol Animation/pistol strafe.fbx",
	"jump": "res://assets/characters/Soldier/Pistol Animation/pistol jump.fbx"
}
const SOLDIER_RIGHT_HAND_BONE = "mixamorig:RightHand"
const THIRD_PERSON_PISTOL_PATH = "res://assets/weapons/blaster-a.glb"
const THIRD_PERSON_PISTOL_OFFSET = Vector3(0.08, 0.02, -0.03)
const THIRD_PERSON_PISTOL_ROTATION = Vector3(0.0, PI / 2.0, PI / 2.0)
const THIRD_PERSON_PISTOL_SCALE = Vector3(1.0, 1.0, 1.0)

# configs das armas

const WEAPONS = {
	"blaster-a": {
		"name": "Pistola Base",
		"damage": 24.0,
		"headshot_mult": 3.0,
		"fire_rate": 0.35,
		"mag_size": 15,
		"max_ammo": 90,
		"recoil_amount": 0.08,
		"cost": 0,
		"model_path": "res://assets/weapons/blaster-a.glb",
		"sound_shoot": preload("res://assets/sounds/pistol-shot.mp3"),
		"sound_shoot_offset": 0.15,
		"sound_shoot_db": -10.0,
		"sound_reload": preload("res://assets/sounds/pistol-reload.mp3"),
		"sound_reload_db": -8.0
	},
	"blaster-d": {
		"name": "Assault Rifle",
		"damage": 120.0,
		"headshot_mult": 4.0,
		"fire_rate": 0.1,
		"mag_size": 30,
		"max_ammo": 240,
		"recoil_amount": 0.05,
		"cost": 1000,
		"model_path": "res://assets/weapons/blaster-d.glb",
		"sound_shoot": preload("res://assets/sounds/assalt-shot.mp3"),
		"sound_shoot_offset": 0.08,
		"sound_shoot_db": 4.0,
		"sound_reload": preload("res://assets/sounds/assalt-reload.mp3"),
		"sound_reload_db": -4.0
	},
	"blaster-h": {
		"name": "Shotgun",
		"damage": 900.0,
		"headshot_mult": 2.0,
		"fire_rate": 0.8,
		"mag_size": 8,
		"max_ammo": 48,
		"recoil_amount": 0.2,
		"cost": 1500,
		"model_path": "res://assets/weapons/blaster-h.glb",
		"sound_shoot": preload("res://assets/sounds/shotgun-shot.mp3"),
		"sound_shoot_db": -6.0,
		"sound_reload": preload("res://assets/sounds/shotgun-reload.mp3"),
		"sound_reload_db": -2.0
	}
}

var points := 500
var current_weapon_id := "blaster-a"
var unlocked_weapon_ids: Array[String] = ["blaster-a"]

# balas e armas liberadas
var inventory := {
	"blaster-a": {"mag": 15, "reserve": 90, "unlocked": true}
}

var is_reloading := false
var reload_timer := 0.0
const RELOAD_TIME := 1.5

# atributos
var max_hp := 100.0
var regen_delay := 4.0
var regen_rate := 25.0
var time_since_last_hit := 0.0

var active_perks: Array[String] = []
var nearby_interactable: Node3D = null

var insta_kill_timer := 0.0
var double_points_timer := 0.0
var notify_timer := 0.0

# refs hud
@onready var damage_vignette: ColorRect = $HUD/DamageVignette
@onready var interaction_label: Label = $HUD/InteractionLabel
@onready var perks_hud_label: Label = $HUD/PerksHudLabel
@onready var powerup_hud_label: Label = $HUD/PowerupHudLabel
@onready var notify_label: Label = $HUD/NotifyLabel
@onready var hp_bar: ProgressBar = $HUD/HPBar
# variaveis de estado

var mouse_sensitivity := 0.002
var t_bob := 0.0
var fire_timer := 0.0
var current_recoil := 0.0
var muzzle_flash_timer := 0.0
var hp := 100.0 # Inicializado como max_hp padrão
var hitmarker_timer := 0.0
var is_meleeing := false
var melee_timer := 0.0
const MELEE_DURATION := 0.5

var weapon_kick := Vector3.ZERO
var weapon_rot_kick := 0.0
@export var is_local_player := true
var is_third_person := false
var flashlight_enabled := false

@onready var camera: Camera3D = $Camera3D
@onready var third_person_camera_pivot: Node3D = $ThirdPersonCameraPivot
@onready var third_person_camera: Camera3D = $ThirdPersonCameraPivot/ThirdPersonCamera3D
@onready var soldier_model: Node3D = $Ch35_nonPBR
@onready var muzzle_flash: OmniLight3D = $"Camera3D/MuzzleFlash"
@onready var flashlight: SpotLight3D = $"Camera3D/Flashlight"
@onready var flashlight_fill: OmniLight3D = $"Camera3D/FlashlightFill"
@onready var raycast: RayCast3D = $"Camera3D/RayCast3D"
@onready var hitmarker: Label = $HUD/Hitmarker
@onready var hud: CanvasLayer = $HUD

# refs da arma na mao
var weapon_model: Node3D = null
var weapon_cache: Dictionary = {}
var blaster_default_pos := Vector3(0.4, -0.3, -0.8)
var blaster_default_rot := Vector3(0, 0, 0)

@onready var points_label: Label = $HUD/PointsLabel
@onready var ammo_label: Label = $HUD/AmmoLabel
@onready var shop_label: Label = $HUD/ShopLabel

var sfx_shoot_pool: Array[AudioStreamPlayer] = []
var next_shoot_player_idx := 0
var sfx_reload: AudioStreamPlayer
var hp_bar_fill_style: StyleBox = null
var soldier_anim_player: AnimationPlayer = null
var soldier_current_anim := ""
var soldier_default_transform := Transform3D.IDENTITY
var third_person_pistol: Node3D = null
var third_person_pistol_attachment: BoneAttachment3D = null

func _ready() -> void:
	for i in range(4):
		var p = AudioStreamPlayer.new()
		add_child(p)
		sfx_shoot_pool.append(p)
	
	sfx_reload = AudioStreamPlayer.new()
	add_child(sfx_reload)
	
	if multiplayer.multiplayer_peer != null:
		is_local_player = is_multiplayer_authority()

	if is_local_player:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	floor_max_angle = deg_to_rad(55.0)
	floor_snap_length = 0.45
	camera.far = PLAYER_CAMERA_FAR
	third_person_camera.far = PLAYER_CAMERA_FAR
	camera.current = true
	third_person_camera.current = false
	muzzle_flash.visible = false
	set_flashlight_enabled(false)
	add_to_group("player")
	raycast.add_exception(self )
	soldier_default_transform = soldier_model.transform
	_setup_soldier_pistol_animations()
	_setup_third_person_pistol()

	# Salva transform original da primeira arma se existir
	weapon_model = camera.get_node_or_null("blaster-a")
	if weapon_model:
		blaster_default_pos = weapon_model.position
		blaster_default_rot = weapon_model.rotation
	_cache_weapon_models()
	equip_weapon(current_weapon_id)
		
	# Reseta o inventário da arma base pra garantir
	inventory["blaster-a"]["mag"] = WEAPONS["blaster-a"]["mag_size"]
	inventory["blaster-a"]["reserve"] = WEAPONS["blaster-a"]["max_ammo"]

	if hp_bar:
		hp_bar_fill_style = hp_bar.get_theme_stylebox("fill").duplicate()
		hp_bar.add_theme_stylebox_override("fill", hp_bar_fill_style)

	_update_hud()
	_apply_player_view_mode()

	# Instancia o Menu de Início/Pausa
	if is_local_player:
		var menu_controller_script = preload("res://src/scripts/menu_controller.gd")
		var menu_controller = menu_controller_script.new()
		$HUD.add_child(menu_controller)


func _process(_delta: float) -> void:
	_lock_soldier_visual_transform()


func _update_hud() -> void:
	points_label.text = "$$$ %d" % points
	
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
		if hp_bar_fill_style is StyleBoxFlat:
			var style_fg := hp_bar_fill_style as StyleBoxFlat
			if hp < max_hp * 0.4:
				style_fg.bg_color = Color(0.8, 0.1, 0.1, 1.0)
			else:
				style_fg.bg_color = Color(0.2, 0.8, 0.2, 1.0)
	
	if is_reloading:
		ammo_label.text = "RELOADING..."
		ammo_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0, 1.0))
	else:
		var inv = inventory[current_weapon_id]
		ammo_label.text = "%d / %d" % [inv["mag"], inv["reserve"]]
		if inv["mag"] == 0:
			ammo_label.add_theme_color_override("font_color", Color(1.0, 0.0, 0.0, 1.0))
		else:
			ammo_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))

	# Atualiza a lista de perks ativos
	if perks_hud_label:
		if active_perks.is_empty():
			perks_hud_label.text = "Vantagens: nenhuma"
		else:
			var names = []
			for p in active_perks:
				names.append(p.capitalize())
			perks_hud_label.text = "Vantagens: " + " | ".join(names)


func _unhandled_input(event: InputEvent) -> void:
	if not is_local_player:
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		if is_third_person:
			third_person_camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		else:
			camera.rotate_x(-event.relative.y * mouse_sensitivity)
		_clamp_pitch()
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event is InputEventMouseButton and event.pressed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event is InputEventMouseButton and event.pressed and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_weapon(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_weapon(-1)
	
	# Menu de Compra Improvisado e Interação
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F3:
			_toggle_third_person()
		elif event.physical_keycode == KEY_F:
			set_flashlight_enabled(not flashlight_enabled)
		elif event.physical_keycode == KEY_1:
			_try_buy_weapon("blaster-d")
		elif event.physical_keycode == KEY_2:
			_try_buy_weapon("blaster-h")
		elif event.physical_keycode == KEY_V:
			_start_melee()
		elif event.physical_keycode == KEY_E:
			if nearby_interactable:
				_interact_with(nearby_interactable)


func _toggle_third_person() -> void:
	if not is_local_player:
		return

	is_third_person = not is_third_person
	_apply_player_view_mode()


func _setup_soldier_pistol_animations() -> void:
	soldier_anim_player = SoldierVisualHelper.setup_pistol_animation_library(
		soldier_model,
		SOLDIER_PISTOL_ANIMS,
		SOLDIER_ANIM_LIBRARY
	)
	if not soldier_anim_player:
		return

	_play_soldier_animation("idle")


func _setup_third_person_pistol() -> void:
	var result := SoldierVisualHelper.attach_pistol_to_hand(
		soldier_model,
		SOLDIER_RIGHT_HAND_BONE,
		THIRD_PERSON_PISTOL_PATH,
		THIRD_PERSON_PISTOL_OFFSET,
		THIRD_PERSON_PISTOL_ROTATION,
		THIRD_PERSON_PISTOL_SCALE
	)
	if not result.get("ok", false):
		return

	third_person_pistol_attachment = result["attachment"] as BoneAttachment3D
	third_person_pistol = result["pistol"] as Node3D
	_apply_player_view_mode()


func _update_soldier_animation(input_dir: Vector2, is_sprinting: bool) -> void:
	if not soldier_anim_player:
		return

	if not is_on_floor():
		_play_soldier_animation("jump")
	elif input_dir == Vector2.ZERO:
		_play_soldier_animation("idle")
	elif absf(input_dir.x) > absf(input_dir.y):
		_play_soldier_animation("strafe")
	elif is_sprinting:
		_play_soldier_animation("run")
	else:
		_play_soldier_animation("walk")


func _play_soldier_animation(state: String) -> void:
	if soldier_current_anim == state:
		return

	var anim_name := "%s/%s" % [SOLDIER_ANIM_LIBRARY, state]
	if not soldier_anim_player.has_animation(anim_name):
		return

	soldier_current_anim = state
	soldier_anim_player.play(anim_name, 0.15)


func _lock_soldier_visual_transform() -> void:
	if soldier_model:
		soldier_model.transform = soldier_default_transform


func _apply_player_view_mode() -> void:
	if is_local_player:
		camera.current = not is_third_person
		third_person_camera.current = is_third_person
		hud.visible = true
	else:
		camera.current = false
		third_person_camera.current = false
		hud.visible = false

	if soldier_model:
		soldier_model.visible = not is_local_player or is_third_person

	if weapon_model and is_instance_valid(weapon_model):
		weapon_model.visible = is_local_player and not is_third_person
	if third_person_pistol and is_instance_valid(third_person_pistol):
		third_person_pistol.visible = not is_local_player or is_third_person


func _cache_weapon_models() -> void:
	for weapon_id in WEAPONS.keys():
		var weapon_instance := camera.get_node_or_null(weapon_id) as Node3D
		if not weapon_instance:
			var packed_scene = load(WEAPONS[weapon_id]["model_path"]) as PackedScene
			if packed_scene:
				weapon_instance = packed_scene.instantiate() as Node3D
				if weapon_instance:
					weapon_instance.name = weapon_id
					camera.add_child(weapon_instance)

		if not weapon_instance:
			continue

		weapon_instance.position = blaster_default_pos
		weapon_instance.rotation = blaster_default_rot
		weapon_instance.visible = false
		weapon_cache[weapon_id] = weapon_instance


func _cycle_weapon(direction: int) -> void:
	if is_reloading or is_meleeing or unlocked_weapon_ids.size() <= 1:
		return
	var idx = unlocked_weapon_ids.find(current_weapon_id)
	if idx != -1:
		var next_idx = (idx + direction) % unlocked_weapon_ids.size()
		if next_idx < 0:
			next_idx += unlocked_weapon_ids.size()
		equip_weapon(unlocked_weapon_ids[next_idx])


func _try_buy_weapon(w_id: String) -> void:
	if is_reloading:
		return
		
	var w_data = WEAPONS[w_id]
	if inventory.has(w_id) and inventory[w_id]["unlocked"]:
		# Se já tem, e quiser comprar munição, gasta 500 (metade) se tiver
		if inventory[w_id]["reserve"] < w_data["max_ammo"]:
			var ammo_cost = int(w_data["cost"] / 2.0)
			if ammo_cost == 0: ammo_cost = 250
			if points >= ammo_cost:
				points -= ammo_cost
				inventory[w_id]["reserve"] = w_data["max_ammo"]
				print("[SHOP] Munição comprada para ", w_data["name"])
				equip_weapon(w_id)
		else:
			# Só equipa
			equip_weapon(w_id)
	else:
		# Comprar arma nova
		if points >= w_data["cost"]:
			points -= w_data["cost"]
			inventory[w_id] = {
				"mag": w_data["mag_size"],
				"reserve": w_data["max_ammo"],
				"unlocked": true
			}
			
			# Limita a 2 armas
			if not unlocked_weapon_ids.has(w_id):
				if unlocked_weapon_ids.size() >= 2:
					# Substitui a arma atual
					var current_idx = unlocked_weapon_ids.find(current_weapon_id)
					if current_idx != -1:
						var old_id = unlocked_weapon_ids[current_idx]
						inventory[old_id]["unlocked"] = false
						unlocked_weapon_ids[current_idx] = w_id
				else:
					unlocked_weapon_ids.append(w_id)
					
			print("[SHOP] Arma comprada: ", w_data["name"])
			equip_weapon(w_id)
			
	_update_hud()


func equip_weapon(weapon_id: String) -> void:
	current_weapon_id = weapon_id
	for cached_weapon_id in weapon_cache.keys():
		var cached_weapon := weapon_cache[cached_weapon_id] as Node3D
		if cached_weapon:
			cached_weapon.visible = false

	weapon_model = weapon_cache.get(weapon_id, null) as Node3D
	if weapon_model:
		weapon_model.position = blaster_default_pos
		weapon_model.rotation = blaster_default_rot
		_apply_player_view_mode()
		
	_update_hud()


func _physics_process(delta: float) -> void:
	if not is_local_player:
		_lock_soldier_visual_transform()
		_update_soldier_animation(Vector2.ZERO, false)
		return

	# regen de vida
	time_since_last_hit += delta
	if time_since_last_hit >= regen_delay and hp < max_hp:
		hp = minf(hp + regen_rate * delta, max_hp)
		_update_hud()

	if damage_vignette:
		var target_alpha = (1.0 - hp / max_hp) * 0.5
		damage_vignette.color.a = lerpf(damage_vignette.color.a, target_alpha, 4.0 * delta)

	# atualiza timers de powerup
	if insta_kill_timer > 0.0:
		insta_kill_timer = maxf(insta_kill_timer - delta, 0.0)
	if double_points_timer > 0.0:
		double_points_timer = maxf(double_points_timer - delta, 0.0)
	_update_powerup_hud()

	if notify_timer > 0.0:
		notify_timer -= delta
		if notify_timer <= 0.0 and notify_label:
			notify_label.text = ""

	var jump_gravity := _get_jump_gravity()
	if not is_on_floor():
		velocity.y -= jump_gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = _get_jump_velocity()

	var is_sprinting := Input.is_action_pressed("sprint")
	var speed := SPRINT_SPEED if is_sprinting else WALK_SPEED
	var input_dir := Input.get_vector("a", "d", "w", "s")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	var stepped_up := false
	if direction and is_on_floor():
		stepped_up = _try_step_up(direction, speed, delta)
	if not stepped_up:
		move_and_slide()
	_update_soldier_animation(input_dir, is_sprinting)
	_lock_soldier_visual_transform()

	# Arma Bobbing + Kick
	t_bob += delta * velocity.length() * float(is_on_floor())
	if weapon_model and is_instance_valid(weapon_model):
		weapon_model.position = _headbob(t_bob) + weapon_kick
		weapon_model.rotation = blaster_default_rot
		weapon_model.rotation.x += weapon_rot_kick
	
	weapon_kick = weapon_kick.lerp(Vector3.ZERO, 15.0 * delta)
	weapon_rot_kick = lerpf(weapon_rot_kick, 0.0, 12.0 * delta)

	fire_timer = maxf(fire_timer - delta, 0.0)
	
	# Controle de Recarga e Facada
	if is_meleeing:
		melee_timer -= delta
		if melee_timer <= 0.0:
			is_meleeing = false
	elif is_reloading:
		var reload_speed_mult := 2.0 if active_perks.has("speed_cola") else 1.0
		reload_timer -= delta * reload_speed_mult
		if reload_timer <= 0.0:
			_finish_reload()
	else:
		var inv = inventory[current_weapon_id]
		# Recarregar pelo input R
		if Input.is_physical_key_pressed(KEY_R) and inv["mag"] < WEAPONS[current_weapon_id]["mag_size"] and inv["reserve"] > 0:
			_start_reload()
		# Atirar
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and fire_timer == 0.0 and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			if inv["mag"] > 0:
				_shoot()
				var base_fire_rate = WEAPONS[current_weapon_id]["fire_rate"]
				fire_timer = base_fire_rate
			else:
				# Tenta atirar sem bala -> Auto reload se tiver reserva
				if inv["reserve"] > 0:
					_start_reload()

	# Retorno gradual do recoil de câmera
	if current_recoil > 0.0:
		var ret := minf(current_recoil, RECOIL_RETURN * delta)
		camera.rotate_x(-ret)
		_clamp_pitch()
		current_recoil -= ret

	_tick_flash_timer(delta)
	_tick_hitmarker_timer(delta)


func _start_melee() -> void:
	if is_meleeing or is_reloading:
		return
	is_meleeing = true
	melee_timer = MELEE_DURATION
	
	# Animação simulada de coronhada violenta
	weapon_kick = Vector3(0.0, 0.0, -0.6)
	weapon_rot_kick = -0.5
	
	# Checa acerto
	var zombies = get_tree().get_nodes_in_group("zombies")
	var closest: Node3D = null
	var min_dist := 2.5
	
	for z in zombies:
		if z.has_method("take_damage") and not z.is_dead:
			var dist = global_position.distance_to(z.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = z
				
	if closest:
		var was_dead = closest.is_dead
		closest.take_damage(150.0) # Dano instakill inicial
		_spawn_impact(closest.global_position + Vector3(0, 1.5, 0), Vector3.ZERO)
		
		if not was_dead:
			if closest.is_dead or closest.hp <= 0.0:
				_add_points(130) # Facada mata = 130 pts
			else:
				_add_points(10)


func _start_reload() -> void:
	is_reloading = true
	reload_timer = RELOAD_TIME
	_update_hud()
	
	# Efeito visual improvisado abaixando a arma
	weapon_kick.y = -0.3
	
	var w_data = WEAPONS[current_weapon_id]
	if w_data.has("sound_reload") and w_data["sound_reload"]:
		var stream: AudioStream = w_data["sound_reload"]
		if sfx_reload.stream != stream:
			sfx_reload.stream = stream
		var base_reload_volume = -8.0
		var weapon_reload_db = w_data.get("sound_reload_db", 0.0)
		sfx_reload.volume_db = base_reload_volume + weapon_reload_db
		
		# ajusta velocidade do som se tiver speed cola
		var reload_speed_mult := 2.0 if active_perks.has("speed_cola") else 1.0
		sfx_reload.pitch_scale = reload_speed_mult
		
		sfx_reload.play()
		reload_timer = stream.get_length()


func _finish_reload() -> void:
	is_reloading = false
	var inv = inventory[current_weapon_id]
	var w_data = WEAPONS[current_weapon_id]
	
	var needed = w_data["mag_size"] - inv["mag"]
	var taken = min(needed, inv["reserve"])
	inv["mag"] += taken
	inv["reserve"] -= taken
	
	_update_hud()


func _shoot() -> void:
	# Gastar bala
	inventory[current_weapon_id]["mag"] -= 1
	_update_hud()
	
	var w_data = WEAPONS[current_weapon_id]

	if w_data.has("sound_shoot") and w_data["sound_shoot"]:
		var stream: AudioStream = w_data["sound_shoot"]
		var offset = w_data.get("sound_shoot_offset", 0.0)
		var base_shoot_volume = -6.0
		var weapon_shoot_db = w_data.get("sound_shoot_db", 0.0)
		
		# escolhe um player disponivel no pool
		var p = sfx_shoot_pool[next_shoot_player_idx]
		next_shoot_player_idx = (next_shoot_player_idx + 1) % sfx_shoot_pool.size()
		
		p.stop()
		p.stream = stream
		p.volume_db = base_shoot_volume + weapon_shoot_db
		p.pitch_scale = randf_range(0.94, 1.06)
		p.play(offset)

	muzzle_flash.visible = true
	muzzle_flash_timer = 0.05

	raycast.force_raycast_update()

	# Recoil de câmera da arma atual
	var recoil = w_data["recoil_amount"]
	camera.rotate_x(recoil)
	_clamp_pitch()
	current_recoil += recoil

	# Recoil de arma
	weapon_kick = Vector3(0.0, 0.02, 0.12)
	weapon_rot_kick = 0.25

	if not raycast.is_colliding():
		return

	var collider := raycast.get_collider()

	var multiplier := 1.0
	var is_headshot := false
	
	if collider and collider.has_method("get_damage_multiplier"):
		var raw_mult = collider.get_damage_multiplier()
		if raw_mult > 1.0:
			is_headshot = true
			multiplier = w_data.get("headshot_mult", 1.5)
		else:
			multiplier = raw_mult

	var target := _resolve_damageable(collider)
	if target:
		var was_dead = target.is_dead
		
		# Aplica dano normal ou dano massivo de insta-kill
		var final_damage = w_data["damage"] * multiplier
		if active_perks.has("double_tap"):
			final_damage *= 2.0
		if insta_kill_timer > 0.0:
			final_damage = 999999.0
			
		target.take_damage(final_damage, is_headshot)
		_show_hitmarker(is_headshot)
		
		# Pontuação CoD Zombies
		if not was_dead:
			_add_points(10) # Acerto
			if target.is_dead or target.hp <= 0.0:
				if is_headshot:
					_add_points(90) # Kill bônus
				else:
					_add_points(50) # Kill bônus normal

	_spawn_impact(raycast.get_collision_point(), raycast.get_collision_normal())


func _add_points(amount: int) -> void:
	var final_amount = amount
	if double_points_timer > 0.0:
		final_amount *= 2
	points += final_amount
	_update_hud()


## Hitmarker visual — amarelo para headshot, vermelho para body.
func _show_hitmarker(is_headshot: bool) -> void:
	hitmarker.visible = true
	hitmarker_timer = 0.2 if is_headshot else 0.15
	if is_headshot:
		hitmarker.text = "✦"
		hitmarker.add_theme_color_override("font_color", Color(1.0, 0.9, 0.0, 1.0))
	else:
		hitmarker.text = "x"
		hitmarker.add_theme_color_override("font_color", Color(1.0, 0.0, 0.0, 1.0))


func _resolve_damageable(collider: Node) -> Node:
	var current := collider
	while current != null:
		if current.has_method("take_damage"):
			return current
		current = current.get_parent()
	return null


func _spawn_impact(pos: Vector3, normal: Vector3) -> void:
	var p := CPUParticles3D.new()
	get_tree().current_scene.add_child(p)
	p.global_position = pos
	if normal != Vector3.ZERO:
		p.look_at(pos + normal, Vector3.UP)
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 8
	p.lifetime = 0.3
	p.direction = Vector3(0, 1, 0)
	p.spread = 70.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 2.0
	p.gravity = Vector3(0, -5.0, 0)
	p.scale_amount_min = 0.008
	p.scale_amount_max = 0.025
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


func _headbob(time: float) -> Vector3:
	var pos := blaster_default_pos
	pos.y += sin(time * BOB_FREQ) * BOB_AMP
	pos.x += cos(time * BOB_FREQ / 2.0) * BOB_AMP
	return pos


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


func _get_jump_velocity() -> float:
	return (2.0 * JUMP_HEIGHT) / JUMP_TIME_TO_APEX


func _get_jump_gravity() -> float:
	return (2.0 * JUMP_HEIGHT) / (JUMP_TIME_TO_APEX * JUMP_TIME_TO_APEX)


func _snap_down_after_step() -> void:
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 0.2,
		global_position + Vector3.DOWN * (STEP_HEIGHT + STEP_DOWN_DISTANCE)
	)
	query.collision_mask = collision_mask
	query.collide_with_areas = false
	var excludes: Array[RID] = [get_rid()]
	query.exclude = excludes

	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return

	var hit_position: Vector3 = hit["position"]
	global_position.y = hit_position.y + 0.05


func set_flashlight_enabled(enabled: bool) -> void:
	if not flashlight:
		return
	flashlight_enabled = enabled
	flashlight.visible = enabled
	flashlight.light_color = Color(1.0, 0.94, 0.82, 1.0)
	flashlight.light_energy = 10.5 if enabled else 0.0
	flashlight.spot_range = 72.0
	flashlight.spot_angle = 42.0
	flashlight.spot_attenuation = 0.55
	flashlight.light_specular = 0.35
	flashlight.shadow_bias = 0.045
	flashlight.shadow_enabled = enabled and bool(GraphicsSettings.get_setting("quality.flashlight_shadows", false))
	if flashlight_fill:
		flashlight_fill.visible = enabled
		flashlight_fill.light_color = Color(0.95, 0.88, 0.72, 1.0)
		flashlight_fill.light_energy = 1.15 if enabled else 0.0
		flashlight_fill.omni_range = 9.0
		flashlight_fill.omni_attenuation = 1.8
		flashlight_fill.light_specular = 0.12


func _clamp_pitch() -> void:
	camera.rotation.x = clamp(camera.rotation.x, -PI / 2.0, PI / 2.0)
	third_person_camera_pivot.rotation.x = clamp(third_person_camera_pivot.rotation.x, -PI / 3.0, PI / 4.0)


func _tick_flash_timer(delta: float) -> void:
	if muzzle_flash_timer <= 0.0:
		return
	muzzle_flash_timer -= delta
	if muzzle_flash_timer <= 0.0:
		muzzle_flash.visible = false


func _tick_hitmarker_timer(delta: float) -> void:
	if hitmarker_timer <= 0.0:
		return
	hitmarker_timer -= delta
	if hitmarker_timer <= 0.0:
		hitmarker.visible = false


func take_damage(amount: float) -> void:
	hp -= amount
	hp = maxf(hp, 0.0)
	time_since_last_hit = 0.0
	_update_hud()
	
	# Efeito rápido de flash vermelho de dano na tela
	if damage_vignette:
		damage_vignette.color.a = clampf((1.0 - hp / max_hp) * 0.5 + 0.15, 0.0, 0.65)
		
	if hp <= 0.0:
		_die()


func _die() -> void:
	get_tree().reload_current_scene()


# interacoes

func register_interactable(node: Node3D) -> void:
	nearby_interactable = node
	_update_interaction_hud()


func unregister_interactable(node: Node3D) -> void:
	if nearby_interactable == node:
		nearby_interactable = null
		_update_interaction_hud()


func _interact_with(obj: Node3D) -> void:
	# Máquina de Perks
	if "perk_id" in obj:
		var perk_id: String = obj.perk_id
		var perk_name: String = obj.perk_name
		var cost: int = obj.cost
		
		if active_perks.has(perk_id):
			show_notification("Você já tem " + perk_name + "!")
			return
			
		if points >= cost:
			points -= cost
			active_perks.append(perk_id)
			show_notification(perk_name + " adquirido!")
			
			# Efeitos imediatos
			if perk_id == "juggernog":
				max_hp = 250.0
				hp = max_hp # Cura instantânea
				
			_update_hud()
			_update_interaction_hud()
		else:
			show_notification("Pontos insuficientes para " + perk_name + "!")


func collect_powerup(powerup_type: String) -> void:
	match powerup_type:
		"max_ammo":
			for w_id in inventory.keys():
				if inventory[w_id]["unlocked"]:
					inventory[w_id]["reserve"] = WEAPONS[w_id]["max_ammo"]
			show_notification("MUNIÇÃO MÁXIMA!")
			_update_hud()
			
		"insta_kill":
			insta_kill_timer = 30.0
			show_notification("BAIXAS INSTANTÂNEAS!")
			
		"double_points":
			double_points_timer = 30.0
			show_notification("PONTOS DUPLOS!")
			
		"instant_money":
			_add_points(500)
			show_notification("DINHEIRO INSTANTÂNEO!")
			
		"nuke":
			show_notification("BOMBA ATÔMICA!")
			# Mata todos os zumbis ativos
			var zombies = get_tree().get_nodes_in_group("zombies")
			for z in zombies:
				if z.has_method("take_damage") and not z.is_dead:
					z.take_damage(999999.0)
			# Bônus fixo de nuke
			_add_points(400)


func show_notification(msg: String) -> void:
	if notify_label:
		notify_label.text = msg
		notify_timer = 2.5


func _update_powerup_hud() -> void:
	if not powerup_hud_label:
		return
		
	var active_texts := []
	if insta_kill_timer > 0.0:
		active_texts.append("BAIXAS INSTANTÂNEAS: %.1fs" % insta_kill_timer)
	if double_points_timer > 0.0:
		active_texts.append("PONTOS DUPLOS: %.1fs" % double_points_timer)
		
	if active_texts.is_empty():
		powerup_hud_label.text = ""
	else:
		powerup_hud_label.text = "\n".join(active_texts)


func _update_interaction_hud() -> void:
	if not interaction_label:
		return
		
	if nearby_interactable:
		var p_name = nearby_interactable.perk_name
		var cost = nearby_interactable.cost
		var p_id = nearby_interactable.perk_id
		
		if active_perks.has(p_id):
			interaction_label.text = "[Comprado] %s" % p_name
		else:
			interaction_label.text = "Pressione [E] para comprar %s [%d pts]" % [p_name, cost]
	else:
		interaction_label.text = ""
