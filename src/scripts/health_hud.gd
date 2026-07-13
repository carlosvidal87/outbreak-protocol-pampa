extends Control

@onready var health_bar: ProgressBar = $Panel/HealthBar
@onready var health_value: Label = $Panel/HealthValue


func set_health(new_current_hp: float, new_max_hp: float) -> void:
	var maximum := maxf(new_max_hp, 1.0)
	var current := clampf(new_current_hp, 0.0, maximum)
	health_bar.max_value = maximum
	health_bar.value = current
	health_value.text = "%d / %d" % [roundi(current), roundi(maximum)]
