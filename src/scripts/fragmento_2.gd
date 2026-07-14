extends Node3D

@export var available := false:
	set(value):
		if available == value:
			return
		available = value
		if is_node_ready():
			_apply_state()
@export var collected := false:
	set(value):
		if collected == value:
			return
		collected = value
		if is_node_ready():
			_apply_state()
@export var consume_animation := &"consume"

var collection_locked := false

@onready var visual_root: Node3D = $VisualRoot
@onready var pickup_area: Area3D = $PickupArea
@onready var collision_shape: CollisionShape3D = $PickupArea/CollisionShape3D
@onready var particles: GPUParticles3D = $VisualRoot/FloatingArtifact/Particles
@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	animation_player.animation_finished.connect(_on_animation_finished)
	if _is_server_authority():
		var director: Node = get_tree().get_first_node_in_group("zombie_director")
		if director and int(director.get("collectible_hordes_started")) >= 3:
			available = true
	_apply_state()


func unlock() -> void:
	if not _is_server_authority() or collected:
		return
	available = true


func _on_pickup_area_body_entered(body: Node3D) -> void:
	if not available or collected or collection_locked or not _is_server_authority():
		return
	if not _is_living_player(body) or not body.has_method("collect_fragment"):
		return
	collection_locked = true
	if not bool(body.call("collect_fragment")):
		collection_locked = false
		return
	collected = true
	var director: Node = get_tree().get_first_node_in_group("zombie_director")
	if director and director.has_method("request_boss_battle"):
		director.call("request_boss_battle", global_position, body)


func _is_living_player(body: Node3D) -> bool:
	if not body.is_in_group("player"):
		return false
	var player_state: Variant = body.get("player_state")
	return player_state == null or int(player_state) == 0


func _apply_state() -> void:
	if not pickup_area or not collision_shape or not visual_root or not animation_player:
		return
	var can_collect := available and not collected
	pickup_area.set_deferred("monitoring", _is_server_authority() and can_collect)
	collision_shape.set_deferred("disabled", not can_collect)
	if not available:
		visual_root.visible = false
		particles.emitting = false
		return
	if not collected:
		collection_locked = false
		visual_root.visible = true
		particles.emitting = true
		if animation_player.has_animation(&"float"):
			animation_player.play(&"float")
		return
	collection_locked = true
	particles.emitting = false
	if animation_player.has_animation(consume_animation):
		animation_player.play(consume_animation)
	else:
		visual_root.visible = false


func _on_animation_finished(animation_name: StringName) -> void:
	if collected and animation_name == consume_animation:
		visual_root.visible = false


func _is_server_authority() -> bool:
	return not multiplayer.multiplayer_peer or multiplayer.is_server()
