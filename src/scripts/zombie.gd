extends CharacterBody3D

# ia basica do zumbi

signal zombie_died(death_position: Vector3)

# stats base
const BASE_HP := 100.0
const BASE_SPEED := 2.0
const ATTACK_RANGE := 2.0
const ATTACK_DAMAGE := 10.0
const ATTACK_COOLDOWN := 1.5
const HEADSHOT_MULT := 1.5
const NAV_TARGET_UPDATE_INTERVAL := 0.25
const TERRAIN_FLOOR_SNAP := 0.6

enum State {CHASE, ATTACK, DEATH}

# stats atuais
var max_hp := BASE_HP
var move_speed := BASE_SPEED
var is_running := false

var state := State.CHASE
var hp := BASE_HP
var attack_timer := 0.0
var nav_target_timer := 0.0
var is_dead := false
var player: Node3D = null
var anim_player: AnimationPlayer = null

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D


func _ready() -> void:
	add_to_group("zombies")
	add_to_group("enemies")
	floor_max_angle = deg_to_rad(55.0)
	floor_snap_length = TERRAIN_FLOOR_SNAP
	
	# Diminui em 10% o tamanho e hitbox
	scale = Vector3(0.9, 0.9, 0.9)
	
	anim_player = _find_anim_player(self )

	set_physics_process(false)
	await get_tree().physics_frame
	player = _find_player()
	nav_target_timer = randf() * NAV_TARGET_UPDATE_INTERVAL
	set_physics_process(true)

	if anim_player:
		anim_player.animation_finished.connect(_on_animation_finished)

	_play_move_anim()


func _physics_process(delta: float) -> void:
	if is_dead or not player or not is_inside_tree():
		return

	# Gravidade via CharacterBody3D.
	if not is_on_floor():
		velocity.y += get_gravity().y * delta

	var dist_sq := global_position.distance_squared_to(player.global_position)
	var attack_range_sq := ATTACK_RANGE * ATTACK_RANGE

	match state:
		State.CHASE:
			nav_target_timer -= delta
			if nav_target_timer <= 0.0:
				var nav_map := get_world_3d().navigation_map
				nav_agent.target_position = NavigationServer3D.map_get_closest_point(nav_map, player.global_position)
				nav_target_timer = NAV_TARGET_UPDATE_INTERVAL

			if dist_sq <= attack_range_sq:
				_change_state(State.ATTACK)
			else:
				var dir := _get_chase_direction()
				if dir.length_squared() > 0.001:
					dir = dir.normalized()
					velocity.x = dir.x * move_speed
					velocity.z = dir.z * move_speed
					_face_direction(dir, delta)
				else:
					velocity.x = 0.0
					velocity.z = 0.0

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

	move_and_slide()


# vira o zumbi pra direcao correta
func _face_direction(dir: Vector3, delta: float) -> void:
	var target_angle := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, target_angle, 10.0 * delta)


func _get_chase_direction() -> Vector3:
	if not nav_agent.is_navigation_finished():
		var next := nav_agent.get_next_path_position()
		var nav_dir := next - global_position
		nav_dir.y = 0.0
		if nav_dir.length_squared() > 0.001:
			return nav_dir

	var direct_dir := player.global_position - global_position
	direct_dir.y = 0.0
	return direct_dir


func _face_player(delta: float) -> void:
	if not player:
		return
	var dir := player.global_position - global_position
	dir.y = 0.0
	if dir.length_squared() < 0.001:
		return
	_face_direction(dir.normalized(), delta)


func _do_attack() -> void:
	_play_anim("attack-melee-right")
	if not player or global_position.distance_to(player.global_position) > ATTACK_RANGE * 2.0:
		return
	if player.has_method("take_damage"):
		player.take_damage(ATTACK_DAMAGE)


func take_damage(amount: float, is_headshot: bool = false) -> void:
	if is_dead:
		return
	hp -= amount
	if hp <= 0.0:
		_die(is_headshot)
		return
	_play_anim("hit")


func _die(is_headshot: bool = false) -> void:
	is_dead = true
	state = State.DEATH
	set_physics_process(false)
	_play_anim("die")
	
	if is_headshot:
		var head = get_node_or_null("Model/torso/head")
		if head:
			head.visible = false
			
			var blood = CPUParticles3D.new()
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
			var mesh = BoxMesh.new()
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.7, 0.0, 0.0)
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mesh.material = mat
			blood.mesh = mesh
			
			add_child(blood)
			blood.global_position = head.global_position
			blood.emitting = true
			
	zombie_died.emit(global_position)
	get_tree().create_timer(2.5).timeout.connect(queue_free)


func _change_state(new_state: State) -> void:
	state = new_state
	match state:
		State.CHASE: _play_move_anim()
		State.ATTACK: attack_timer = 0.0


# escolhe anim de walk ou corre
func _play_move_anim() -> void:
	if is_running:
		_play_anim("sprint")
	else:
		_play_anim("walk")


func _find_player() -> Node3D:
	var group := get_tree().get_nodes_in_group("player")
	if group.size() > 0:
		return group[0] as Node3D
	return null


func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_anim_player(child)
		if found:
			return found
	return null


# evita tocar animacao por cima
func _play_anim(anim_name: String) -> void:
	if not anim_player or not anim_player.has_animation(anim_name):
		# Fallback: se sprint não existir, tenta walk
		if anim_name == "sprint" and anim_player and anim_player.has_animation("walk"):
			anim_name = "walk"
		else:
			return
	if anim_name in ["walk", "sprint"]:
		anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	if anim_player.current_animation != anim_name:
		anim_player.play(anim_name)


func _on_animation_finished(anim_name: String) -> void:
	if is_dead:
		return
	if anim_name in ["hit", "attack-melee-right"]:
		match state:
			State.CHASE: _play_move_anim()
