extends Node

const CHARACTER_SCENE := preload("res://src/scenes/character.tscn")


func _ready() -> void:
	var player := CHARACTER_SCENE.instantiate()
	player.is_local_player = false
	add_child(player)
	await get_tree().process_frame
	var initial_hp: float = player.hp
	player.take_damage(10.0)
	var after_damage: float = player.hp
	var hud := player.get_node("CrosshairLayer/HealthHUD")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var after_wait: float = player.hp
	var health_bar := hud.get_node("Panel/HealthBar") as ProgressBar
	var health_value := hud.get_node("Panel/HealthValue") as Label
	var valid: bool = initial_hp == 100.0 and after_damage == 90.0 and after_wait == 90.0 and health_bar.value == 90.0 and health_bar.max_value == 100.0 and health_value.text == "90 / 100"
	var output := FileAccess.open("res://player-health-hud-validation.log", FileAccess.WRITE)
	output.store_string("initial=%.1f damage=%.1f wait=%.1f hud=%.1f/%.1f label=%s valid=%s" % [initial_hp, after_damage, after_wait, health_bar.value, health_bar.max_value, health_value.text, valid])
	output.close()
	get_tree().quit(0 if valid else 1)
