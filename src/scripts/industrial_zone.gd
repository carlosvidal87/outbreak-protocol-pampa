class_name IndustrialZone
extends RefCounted

# Limites do piso principal da fabrica, com margem interna para evitar a parede do mapa.
const MIN_X := -88.0
const MAX_X := 66.0
const MIN_Z := -344.0
const MAX_Z := -198.0
const FLOOR_Y := -14.24
const FLOOR_HEIGHT_TOLERANCE := 1.0


static func contains(world_position: Vector3, margin: float = 0.0) -> bool:
	return (
		world_position.x >= MIN_X - margin
		and world_position.x <= MAX_X + margin
		and world_position.z >= MIN_Z - margin
		and world_position.z <= MAX_Z + margin
	)


static func contains_strict(world_position: Vector3, inset: float = 0.0) -> bool:
	return (
		world_position.x >= MIN_X + inset
		and world_position.x <= MAX_X - inset
		and world_position.z >= MIN_Z + inset
		and world_position.z <= MAX_Z - inset
	)


static func is_floor_height(height: float) -> bool:
	return absf(height - FLOOR_Y) <= FLOOR_HEIGHT_TOLERANCE
