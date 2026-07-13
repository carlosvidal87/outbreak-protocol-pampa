extends Node3D

var damage_taken := 0.0


func _ready() -> void:
	add_to_group("player")


func take_damage(amount: float) -> void:
	damage_taken += amount
