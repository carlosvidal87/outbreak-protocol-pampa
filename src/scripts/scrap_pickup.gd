extends Node3D

@export var scrap_value := 50:
	set(value):
		scrap_value = maxi(value, 0)
		if is_node_ready():
			_refresh_visual()
@export var lifespan_seconds := 30.0
@export var blink_duration := 8.0
@export var attraction_radius := 3.5
@export var collection_radius := 1.5
@export var attraction_speed := 8.0
@export var common_color := Color(0.72, 0.48, 0.22, 1.0)
@export var uncommon_color := Color(0.95, 0.66, 0.22, 1.0)
@export var rare_color := Color(0.36, 0.78, 1.0, 1.0)
@export var jackpot_color := Color(0.78, 0.38, 1.0, 1.0)

var collected := false
var remaining_lifetime := 30.0
var animation_time := 0.0
var visual_base_position := Vector3.ZERO
var visual_base_scale := Vector3.ONE

@onready var visual_root: Node3D = $VisualRoot
@onready var pickup_light: OmniLight3D = $VisualRoot/PickupLight
@onready var pickup_area: Area3D = $PickupArea


func _ready() -> void:
	remaining_lifetime = lifespan_seconds
	visual_base_position = visual_root.position
	visual_base_scale = visual_root.scale
	_refresh_visual()


func _process(delta: float) -> void:
	animation_time += delta
	remaining_lifetime -= delta
	visual_root.position.y = visual_base_position.y + sin(animation_time * 3.5) * 0.12
	visual_root.rotate_y(delta * 1.5)
	if remaining_lifetime <= blink_duration:
		var frequency := 15.0 if remaining_lifetime <= 3.0 else 7.0
		visual_root.visible = fmod(animation_time * frequency, 2.0) < 1.0
	else:
		visual_root.visible = true
	if remaining_lifetime <= 0.0 and _is_server_authority():
		queue_free()


func _physics_process(delta: float) -> void:
	if collected or not _is_server_authority():
		return
	var target := _find_nearest_collectable_player()
	if not target:
		return
	var distance := global_position.distance_to(target.global_position)
	if distance <= collection_radius:
		_collect_for(target)
		return
	if distance <= attraction_radius and _has_line_of_sight(target):
		global_position = global_position.move_toward(target.global_position, attraction_speed * delta)


func add_scrap(amount: int) -> bool:
	if amount <= 0 or collected or not _is_server_authority():
		return false
	_apply_synced_state(scrap_value + amount)
	if multiplayer.multiplayer_peer and multiplayer.is_server():
		_apply_synced_state.rpc(scrap_value)
	return true


func reset_lifetime() -> void:
	remaining_lifetime = lifespan_seconds
	animation_time = 0.0
	visual_root.visible = true


@rpc("authority", "call_remote", "reliable")
func _apply_synced_state(value: int) -> void:
	scrap_value = value
	reset_lifetime()


func _on_pickup_area_body_entered(body: Node3D) -> void:
	if collected or not _is_server_authority() or not _is_collectable_player(body):
		return
	_collect_for(body)


func _collect_for(player: Node3D) -> void:
	if collected or not _is_collectable_player(player):
		return
	collected = true
	pickup_area.set_deferred("monitoring", false)
	var accepted := bool(player.call("collect_scrap", scrap_value))
	if not accepted:
		collected = false
		pickup_area.set_deferred("monitoring", true)
		return
	queue_free()


func _find_nearest_collectable_player() -> Node3D:
	var nearest: Node3D = null
	var nearest_distance := attraction_radius + 0.001
	for candidate in get_tree().get_nodes_in_group("player"):
		if not candidate is Node3D or not _is_collectable_player(candidate as Node3D):
			continue
		var distance := global_position.distance_to((candidate as Node3D).global_position)
		if distance < nearest_distance:
			nearest = candidate as Node3D
			nearest_distance = distance
	return nearest


func _is_collectable_player(body: Node3D) -> bool:
	if not body.is_in_group("player") or not body.has_method("collect_scrap"):
		return false
	var state: Variant = body.get("player_state")
	return state == null or int(state) == 0


func _has_line_of_sight(target: Node3D) -> bool:
	var from := global_position + Vector3.UP * 0.25
	var to := target.global_position + Vector3.UP * 0.8
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _refresh_visual() -> void:
	if not visual_root or not pickup_light:
		return
	var tier_color := common_color
	var tier_scale := 1.0
	if scrap_value >= 250:
		tier_color = jackpot_color
		tier_scale = 1.35
	elif scrap_value >= 125:
		tier_color = rare_color
		tier_scale = 1.2
	elif scrap_value >= 75:
		tier_color = uncommon_color
		tier_scale = 1.08
	visual_root.scale = visual_base_scale * tier_scale
	pickup_light.light_color = tier_color
	for child in visual_root.get_children():
		if child is MeshInstance3D:
			var mesh := child as MeshInstance3D
			var material := mesh.material_override as StandardMaterial3D
			if material:
				material.albedo_color = tier_color
				material.emission = tier_color * 1.4


func _is_server_authority() -> bool:
	return not multiplayer.multiplayer_peer or multiplayer.is_server()
