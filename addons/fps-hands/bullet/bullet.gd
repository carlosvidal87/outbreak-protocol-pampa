extends Node3D

signal collision(obj:Node3D, damage:float, point:Vector3, collision_normal:Vector3)

var speed : float = 50.0
var damage : float = 10.0
var distance : float = 30.0 # aka range
var collision_mask : int = 1
var direction := Vector3(0, 0, -speed)
var gravity := ProjectSettings.get_setting("physics/3d/default_gravity_vector")
var collided := false
var shooter: CollisionObject3D

@onready var origin := global_position
@onready var raycast : RayCast3D = $RayCast3D

func _ready() -> void:
	raycast.collision_mask = collision_mask
	raycast.collide_with_areas = true
	raycast.add_exception($Area3D)
	$Area3D.collision_mask = collision_mask
	$Area3D.monitorable = false
	if shooter:
		raycast.add_exception(shooter)

func collide(collider:Node3D) -> void:
	if collided: return
	collided = true
	#process_mode = Node.PROCESS_MODE_DISABLED
	damage -= damage/distance*global_position.distance_to(origin)

	if raycast.is_colliding():
		collision.emit(collider, damage, raycast.get_collision_point(), raycast.get_collision_normal())
	else:
		collision.emit(collider, damage, global_position, -global_transform.basis.z.normalized())

	queue_free()

func _physics_process(delta: float) -> void:
	if collided:
		return
	raycast.force_raycast_update()
	if raycast.is_colliding():
		collide(raycast.get_collider())
	else:
		direction += gravity * (delta * 2.0)
		position += transform.basis * direction * delta
		if global_position.distance_to(origin) >= distance:
			queue_free()

func _on_area_3d_body_entered(body: Node3D) -> void:
	if shooter and (body == shooter or shooter.is_ancestor_of(body)):
		return
	collide(body)


func _on_area_3d_area_entered(area: Area3D) -> void:
	if shooter and (area == shooter or shooter.is_ancestor_of(area)):
		return
	collide(area)
