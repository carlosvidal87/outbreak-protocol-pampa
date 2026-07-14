extends Node3D

@export var collected := false:
	set(value):
		if collected == value:
			return
		collected = value
		if is_node_ready():
			_apply_collected_state()
@export var consume_animation := &"consume"

var collection_locked := false

@onready var visual_root: Node3D = $VisualRoot
@onready var pickup_area: Area3D = $PickupArea
@onready var collision_shape: CollisionShape3D = $PickupArea/CollisionShape3D
@onready var particles: GPUParticles3D = $VisualRoot/FloatingArtifact/Particles
@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	animation_player.animation_finished.connect(_on_animation_finished)
	_apply_collected_state()


func _on_pickup_area_body_entered(body: Node3D) -> void:
	if collection_locked or collected or not _is_server_authority() or not _is_living_player(body):
		return
	if not body.has_method("collect_fragment"):
		return
	collection_locked = true
	var director: Node = get_tree().get_first_node_in_group("zombie_director")
	var accepted: bool = director != null and director.has_method("request_collectible_horde") and bool(
		director.call("request_collectible_horde", global_position, self)
	)
	if not accepted:
		collection_locked = false
		return
	if not bool(body.call("collect_fragment")):
		push_error("O Fragmento iniciou a horda, mas o jogador rejeitou a coleta.")
	collected = true


func _is_living_player(body: Node3D) -> bool:
	if not body.is_in_group("player"):
		return false
	var player_state: Variant = body.get("player_state")
	return player_state == null or int(player_state) == 0


func _apply_collected_state() -> void:
	if not pickup_area or not collision_shape or not visual_root or not animation_player:
		return
	pickup_area.set_deferred("monitoring", _is_server_authority() and not collected)
	collision_shape.set_deferred("disabled", collected)
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
