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
	if not is_equal_approx(float(constants.get("CALM_RUNNER_RATIO", 0.0)), 0.15):
		_fail("A fase controlada precisa manter 15 por cento de corredores.")
		return
	if not is_equal_approx(float(constants.get("CALM_RUNNER_DURATION", 0.0)), 120.0) or not is_equal_approx(float(constants.get("PRESSURE_RUNNER_DURATION", 0.0)), 60.0):
		_fail("O ciclo de corredores precisa usar dois minutos controlados e um minuto de pressao.")
		return
	if constants.get("COLLECTIBLE_HORDE_SIZES", []) != [24, 36, 50]:
		_fail("As hordas dos fragmentos azuis nao foram dobradas.")
		return
	if not is_equal_approx(float(director.call("_get_current_normal_runner_ratio")), 0.15):
		_fail("A partida nao iniciou na fase controlada.")
		return
	director.set("match_elapsed", 119.99)
	if not is_equal_approx(float(director.call("_get_current_normal_runner_ratio")), 0.15):
		_fail("A fase controlada terminou antes dos dois minutos.")
		return
	var transition_zombie := ZOMBIE_SCENE.instantiate() as CharacterBody3D
	add_child(transition_zombie)
	await get_tree().physics_frame
	transition_zombie.set("is_running", true)
	var active_zombies: Array = director.get("active_zombies")
	active_zombies.append(transition_zombie)
	director.set("active_zombies", active_zombies)
	director.call("_update_time_difficulty", 0.01)
	if int(director.get("difficulty_stage")) != 1 or not is_equal_approx(float(director.get("current_health_multiplier")), 1.25):
		_fail("A vida nao aumentou 25 por cento aos dois minutos.")
		return
	if not is_equal_approx(float(director.call("_get_current_normal_runner_ratio")), 0.45):
		_fail("A fase de pressao nao iniciou aos dois minutos.")
		return
	if not bool(transition_zombie.get("is_running")):
		_fail("A troca de fase alterou um corredor que ja estava ativo.")
		return
	director.set("match_elapsed", 179.99)
	if not is_equal_approx(float(director.call("_get_current_normal_runner_ratio")), 0.45):
		_fail("A fase de pressao terminou antes de completar um minuto.")
		return
	director.set("match_elapsed", 180.0)
	if not is_equal_approx(float(director.call("_get_current_normal_runner_ratio")), 0.15):
		_fail("O ciclo nao retornou a fase controlada aos tres minutos.")
		return
	director.set("match_elapsed", 300.0)
	if not is_equal_approx(float(director.call("_get_current_normal_runner_ratio")), 0.45):
		_fail("O segundo ciclo nao voltou a fase de pressao aos cinco minutos.")
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
