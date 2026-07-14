extends Area3D

@export_range(0.1, 3.0, 0.05) var damage_multiplier := 1.0


func get_damage_multiplier() -> float:
	return damage_multiplier
