extends Node3D

const ZOMBIE_SCENE := preload("res://assets/characters/Zombies/zombie.tscn")


func _ready() -> void:
	var director_script := load("res://src/scripts/zombie_director.gd") as Script
	var constants: Dictionary = director_script.get_script_constant_map()
	var director := director_script.new() as Node3D
	add_child(director)
	await get_tree().process_frame
	var spawn_timer := director.get("spawn_timer") as Timer
	if spawn_timer:
		spawn_timer.stop()
	if int(director.get("minimum_population")) != 32 or int(director.get("maximum_population")) != 40:
		_fail("A nova populacao normal precisa ficar entre 32 e 40.")
		return
	if not is_equal_approx(float(director.get("runner_ratio")), 0.45) or not is_equal_approx(float(director.get("aggressive_spawn_ratio")), 0.85):
		_fail("Proporcao normal de corredores ou agressividade incorreta.")
		return
	if not is_equal_approx(float(constants.get("DANGER_RUNNER_RATIO", 0.0)), 0.90):
		_fail("Hordas e boss battle precisam ter 90 por cento de corredores.")
		return
	if constants.get("COLLECTIBLE_HORDE_SIZES", []) != [24, 36, 50]:
		_fail("As hordas dos fragmentos azuis nao foram dobradas.")
		return
	director.call("_update_time_difficulty", 120.0)
	if int(director.get("difficulty_stage")) != 1 or not is_equal_approx(float(director.get("current_health_multiplier")), 1.25):
		_fail("A vida nao aumentou 25 por cento aos dois minutos.")
		return
	director.call("_update_time_difficulty", 120.0 * 20.0)
	if not is_equal_approx(float(director.get("current_health_multiplier")), 4.0):
		_fail("O teto balanceado de vida em 4x nao foi respeitado.")
		return
	var zombie := ZOMBIE_SCENE.instantiate() as CharacterBody3D
	add_child(zombie)
	await get_tree().physics_frame
	zombie.call("set_difficulty", 1.5, 1.12)
	if not is_equal_approx(float(zombie.get("max_hp")), 150.0):
		_fail("O multiplicador de vida nao chegou ao zumbi.")
		return
	var special_run_speed := float(zombie.get("run_speed"))
	if special_run_speed < 5.0 or special_run_speed > 5.3:
		_fail("O corredor especial saiu da faixa rapida e controlavel. speed=%s" % special_run_speed)
		return
	var maximum_chase_speed := special_run_speed * float(zombie.get("chase_speed_multiplier")) * float(zombie.get("behind_player_speed_multiplier"))
	if maximum_chase_speed > 6.6:
		_fail("Os multiplicadores voltaram a produzir velocidade absurda. speed=%s" % maximum_chase_speed)
		return
	zombie.set("is_running", true)
	zombie.call("_update_locomotion_playback", maximum_chase_speed)
	var animation_player := zombie.get("anim_player") as AnimationPlayer
	if not animation_player or animation_player.speed_scale > 1.251:
		_fail("A animacao do corredor ultrapassou o limite natural. scale=%s" % (animation_player.speed_scale if animation_player else -1.0))
		return
	var network_scene := FileAccess.get_file_as_string("res://assets/characters/Zombies/zombie.tscn")
	if not network_scene.contains("NodePath(\".:max_hp\")") or not network_scene.contains("NodePath(\".:run_speed\")"):
		_fail("Vida e velocidade escaladas nao foram registradas para replicacao multiplayer.")
		return
	print("[ZOMBIE DIFFICULTY TEST] Populacao, perseguicao, vida progressiva e corredores rapidos confirmados.")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("[ZOMBIE DIFFICULTY TEST] %s" % message)
	get_tree().quit(1)
