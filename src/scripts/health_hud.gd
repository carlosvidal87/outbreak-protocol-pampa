extends Control

@onready var health_bar: ProgressBar = $Panel/HealthBar
@onready var health_value: Label = $Panel/HealthValue
@onready var armor_bar: ProgressBar = $Panel/ArmorBar
@onready var armor_value: Label = $Panel/ArmorValue
@onready var scrap_value: Label = $Panel/ScrapValue
@onready var medkit_value: Label = $Panel/MedkitValue
@onready var scrap_gain: Label = $ScrapGain

var scrap_gain_tween: Tween = null
var scrap_gain_base_y := 0.0


func _ready() -> void:
	scrap_gain_base_y = scrap_gain.position.y


func set_health(new_current_hp: float, new_max_hp: float) -> void:
	var maximum := maxf(new_max_hp, 1.0)
	var current := clampf(new_current_hp, 0.0, maximum)
	health_bar.max_value = maximum
	health_bar.value = current
	health_value.text = "%d / %d" % [roundi(current), roundi(maximum)]


func set_armor(current_armor: float, maximum_armor: float) -> void:
	var maximum := maxf(maximum_armor, 1.0)
	var current := clampf(current_armor, 0.0, maximum)
	armor_bar.max_value = maximum
	armor_bar.value = current
	armor_value.text = str(roundi(current))


func set_equipment(scrap: int, medkits: int, medkit_max: int) -> void:
	scrap_value.text = "SUCATA %d" % scrap
	medkit_value.text = "KIT %d/%d" % [medkits, medkit_max]


func show_scrap_gain(message: String) -> void:
	if scrap_gain_tween and scrap_gain_tween.is_valid():
		scrap_gain_tween.kill()
	scrap_gain.text = message
	scrap_gain.visible = true
	scrap_gain.modulate = Color.WHITE
	scrap_gain.position.y = scrap_gain_base_y
	scrap_gain_tween = create_tween()
	scrap_gain_tween.tween_interval(0.8)
	scrap_gain_tween.tween_property(scrap_gain, "position:y", scrap_gain_base_y - 12.0, 0.45)
	scrap_gain_tween.parallel().tween_property(scrap_gain, "modulate:a", 0.0, 0.45)
	scrap_gain_tween.tween_callback(func() -> void: scrap_gain.visible = false)
