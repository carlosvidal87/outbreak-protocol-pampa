extends Node3D

const MAP_CONTENT_SCENE := preload("res://src/scenes/map_xandy_content.tscn")
const ZOMBIE_SCENE := preload("res://assets/characters/Zombies/zombie.tscn")
const BOSS_SCENE := preload("res://src/scenes/boss.tscn")
const DIRECTOR_SCRIPT := preload("res://src/scripts/zombie_director.gd")
const FRAGMENT_POSITION := Vector3(-4.176285, -14.107647, -226.36276)


func _ready() -> void:
	var map_content := MAP_CONTENT_SCENE.instantiate()
	add_child(map_content)
	for _frame in range(4):
		await get_tree().physics_frame
	var failures: PackedStringArray = []

	var ground_query := PhysicsRayQueryParameters3D.create(FRAGMENT_POSITION + Vector3.UP * 8.0, FRAGMENT_POSITION + Vector3.DOWN * 8.0)
	ground_query.collision_mask = 1
	ground_query.collide_with_areas = false
	var ground_hit := get_world_3d().direct_space_state.intersect_ray(ground_query)
	if ground_hit.is_empty():
		failures.append("O piso industrial nao possui colisao sob o Fragmento 2.")
	else:
		var ground_position: Vector3 = ground_hit["position"]
		var ground_normal: Vector3 = ground_hit["normal"]
		print("[INDUSTRIAL NAV TEST] ground=%s normal=%s collider=%s" % [ground_position, ground_normal, ground_hit.get("collider")])
		if ground_normal.dot(Vector3.UP) < 0.85:
			failures.append("A colisao sob o Fragmento 2 nao e um piso caminhavel.")

	var player := Node3D.new()
	player.name = "IndustrialTestPlayer"
	player.global_position = FRAGMENT_POSITION
	player.add_to_group("player")
	add_child(player)

	var director := DIRECTOR_SCRIPT.new() as Node3D
	add_child(director)
	await get_tree().physics_frame
	var spawn_timer := director.get("spawn_timer") as Timer
	if spawn_timer:
		spawn_timer.stop()
	var zombie_spawn: Vector3 = director.call("_find_spawn_position", player)
	print("[INDUSTRIAL NAV TEST] zombie_spawn=%s" % zombie_spawn)
	if zombie_spawn == Vector3.INF:
		failures.append("O diretor nao encontrou spawn fisico para zumbi na fabrica.")
	director.set("boss_spawn_origin", FRAGMENT_POSITION)
	var boss_spawn: Vector3 = director.call("_find_boss_spawn_position", player)
	print("[INDUSTRIAL NAV TEST] boss_spawn=%s" % boss_spawn)
	if boss_spawn == Vector3.INF:
		failures.append("O diretor nao encontrou spawn fisico para o boss na fabrica.")

	var zombie := ZOMBIE_SCENE.instantiate() as CharacterBody3D
	zombie.global_position = FRAGMENT_POSITION + Vector3(10.0, 0.0, 0.0)
	add_child(zombie)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var selected_player: Node3D = zombie.call("_find_player")
	if selected_player != player:
		failures.append("O zumbi ignorou o jogador dentro da area industrial sem NavMesh.")
	else:
		zombie.call("activate_from_pool", zombie.global_position, player, true, true)
		zombie.call("_update_navigation_target", 1.0, player.global_position)
		var zombie_direction: Vector3 = zombie.call("_get_chase_direction")
		if zombie_direction.length_squared() <= 0.01:
			failures.append("O zumbi nao gerou direcao de perseguicao industrial.")
		var zombie_distance_before := Vector2(zombie.global_position.x, zombie.global_position.z).distance_to(Vector2(player.global_position.x, player.global_position.z))
		for _frame in range(30):
			await get_tree().physics_frame
		var zombie_distance_after := Vector2(zombie.global_position.x, zombie.global_position.z).distance_to(Vector2(player.global_position.x, player.global_position.z))
		print("[INDUSTRIAL NAV TEST] zombie_distance_before=%.3f after=%.3f" % [zombie_distance_before, zombie_distance_after])
		if zombie_distance_after >= zombie_distance_before - 0.5:
			failures.append("O zumbi gerou direcao, mas nao transitou pelo piso industrial.")

	var boss := BOSS_SCENE.instantiate() as CharacterBody3D
	boss.testing_skip_intro = true
	boss.global_position = FRAGMENT_POSITION + Vector3(-16.0, 0.0, 0.0)
	add_child(boss)
	await get_tree().physics_frame
	boss.target = player
	var boss_direction: Vector3 = boss.call("_get_chase_direction")
	if boss_direction.length_squared() <= 0.01:
		failures.append("O boss nao gerou direcao de perseguicao industrial.")
	var boss_distance_before := Vector2(boss.global_position.x, boss.global_position.z).distance_to(Vector2(player.global_position.x, player.global_position.z))
	for _frame in range(30):
		await get_tree().physics_frame
	var boss_distance_after := Vector2(boss.global_position.x, boss.global_position.z).distance_to(Vector2(player.global_position.x, player.global_position.z))
	print("[INDUSTRIAL NAV TEST] boss_distance_before=%.3f after=%.3f" % [boss_distance_before, boss_distance_after])
	if boss_distance_after >= boss_distance_before - 0.5:
		failures.append("O boss gerou direcao, mas nao transitou pelo piso industrial.")

	if not failures.is_empty():
		for failure: String in failures:
			push_error("[INDUSTRIAL NAV TEST] %s" % failure)
		get_tree().quit(1)
		return
	print("[INDUSTRIAL NAV TEST] Piso, spawns e perseguicao de zumbi e boss confirmados.")
	get_tree().quit(0)
