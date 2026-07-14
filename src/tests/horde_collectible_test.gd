extends Node

const DIRECTOR_SCRIPT := preload("res://src/scripts/zombie_director.gd")
const COLLECTIBLE_SCENE := preload("res://src/scenes/fragmento.tscn")
const FRAGMENTO_2_SCENE := preload("res://src/scenes/fragmento_2.tscn")


class FakePlayer:
	extends CharacterBody3D
	var player_state := 0
	var fragments := 0

	func _ready() -> void:
		add_to_group("player")

	func collect_fragment() -> bool:
		if player_state != 0:
			return false
		fragments += 1
		return true


class FakeGameSession:
	extends Node

	func is_multiplayer_world_ready() -> bool:
		return true


func _ready() -> void:
	var game_session := FakeGameSession.new()
	game_session.name = "GameSession"
	add_child(game_session)
	var director := DIRECTOR_SCRIPT.new() as Node3D
	add_child(director)
	var spawn_timer := director.get("spawn_timer") as Timer
	if spawn_timer:
		spawn_timer.stop()

	var player := FakePlayer.new()
	add_child(player)
	if get_tree().get_first_node_in_group("zombie_director") != director:
		_fail("O ZombieDirector nao foi registrado no grupo esperado.")
		return
	if not player.is_in_group("player"):
		_fail("O jogador de teste nao foi registrado no grupo player.")
		return
	if not bool(director.call("_is_server_authority")):
		_fail("O teste nao possui autoridade de servidor: peer=%s servidor=%s." % [multiplayer.multiplayer_peer, multiplayer.is_server()])
		return
	if not bool(director.call("_is_multiplayer_world_ready")):
		_fail("O mundo foi considerado indisponivel para iniciar a horda.")
		return
	var debug_fragmento_2 := FRAGMENTO_2_SCENE.instantiate() as Node3D
	add_child(debug_fragmento_2)
	director.call("_debug_unlock_fragmento_2", 1)
	if not bool(debug_fragmento_2.get("available")):
		_fail("O atalho P nao consegue liberar o Fragmento 2 para teste.")
		return
	remove_child(debug_fragmento_2)
	debug_fragmento_2.free()
	director.call("_debug_unlock_fragmento_2", 1)
	var spawned_debug_fragment := director.get_node_or_null("DebugFragmento2") as Node3D
	if spawned_debug_fragment == null or not bool(spawned_debug_fragment.get("available")):
		_fail("O atalho P nao criou um Fragmento 2 quando o mapa estava sem uma instancia.")
		return
	director.remove_child(spawned_debug_fragment)
	spawned_debug_fragment.free()
	var fragmento_2 := FRAGMENTO_2_SCENE.instantiate() as Node3D
	add_child(fragmento_2)
	if bool(fragmento_2.get("available")) or fragmento_2.get_node("VisualRoot").visible:
		_fail("O Fragmento 2 apareceu antes das tres coletas comuns.")
		return

	var first := COLLECTIBLE_SCENE.instantiate() as Node3D
	add_child(first)
	if not _has_editable_scene_nodes(first):
		_fail("A cena nao possui todos os nos visuais e de colisao editaveis.")
		return
	if not bool(first.call("_is_living_player", player)):
		_fail("O Fragmento nao reconheceu um jogador vivo valido.")
		return
	player.player_state = 1
	first.call("_on_pickup_area_body_entered", player)
	if bool(first.get("collected")):
		_fail("Jogador caido coletou o artefato.")
		return
	player.player_state = 0
	first.call("_on_pickup_area_body_entered", player)
	first.call("_on_pickup_area_body_entered", player)

	var second := COLLECTIBLE_SCENE.instantiate() as Node3D
	var third := COLLECTIBLE_SCENE.instantiate() as Node3D
	var fourth := COLLECTIBLE_SCENE.instantiate() as Node3D
	add_child(second)
	add_child(third)
	add_child(fourth)
	second.call("_on_pickup_area_body_entered", player)
	third.call("_on_pickup_area_body_entered", player)
	fourth.call("_on_pickup_area_body_entered", player)

	if not bool(first.get("collected")) or not bool(second.get("collected")) or not bool(third.get("collected")):
		_fail("Coletas validas: primeira=%s segunda=%s terceira=%s hordas=%d fragmentos=%d." % [
			bool(first.get("collected")),
			bool(second.get("collected")),
			bool(third.get("collected")),
			int(director.get("collectible_hordes_started")),
			player.fragments,
		])
		return
	if bool(fourth.get("collected")):
		_fail("Uma quarta coleta foi aceita apos concluir a progressao.")
		return
	var jobs := director.get("collectible_horde_jobs") as Array
	var expected := [24, 36, 50]
	if jobs.size() != expected.size():
		_fail("Quantidade incorreta de trabalhos de horda: %d." % jobs.size())
		return
	for index in expected.size():
		var job := jobs[index] as Dictionary
		if int(job["total"]) != expected[index]:
			_fail("Progressao incorreta na horda %d." % (index + 1))
			return
		var planned_runners := 0
		for runner: bool in (job["runner_plan"] as Array):
			if runner:
				planned_runners += 1
		if planned_runners != roundi(float(expected[index]) * 0.90):
			_fail("A horda %d nao planejou exatamente 90 por cento de corredores." % (index + 1))
			return
	if int(director.get("collectible_hordes_started")) != 3:
		_fail("A mesma instancia ativou a progressao mais de uma vez.")
		return
	if not bool(fragmento_2.get("available")) or not fragmento_2.get_node("VisualRoot").visible:
		_fail("O Fragmento 2 nao apareceu depois da terceira coleta.")
		return
	fragmento_2.call("_on_pickup_area_body_entered", player)
	if not bool(fragmento_2.get("collected")) or player.fragments != 4:
		_fail("O jogador nao recebeu o Fragmento 2.")
		return
	if not bool(director.get("boss_battle_requested")) or not bool(director.get("boss_battle_active")):
		_fail("O Fragmento 2 nao iniciou a batalha do boss.")
		return
	if not is_equal_approx(float(director.get("population_multiplier")), 1.75):
		_fail("A batalha do boss nao elevou a populacao de zumbis para 1,75x.")
		return
	if spawn_timer and not is_equal_approx(spawn_timer.wait_time, 0.30):
		_fail("A batalha do boss nao reduziu o intervalo de spawn para 0,30 segundo.")
		return
	if float(director.get("boss_countdown_remaining")) <= 0.0:
		_fail("A contagem regressiva do boss nao foi iniciada.")
		return
	if (director.get("collectible_horde_jobs") as Array).size() != 3:
		_fail("O Fragmento 2 criou uma quarta horda.")
		return

	print("[HORDE COLLECTIBLE TEST] Fragmento 2, desbloqueio e progressao 24/36/50 confirmados.")
	get_tree().quit(0)


func _has_editable_scene_nodes(collectible: Node) -> bool:
	return collectible.has_node("VisualRoot/FloatingArtifact/Core") \
		and collectible.has_node("VisualRoot/FloatingArtifact/OuterRing") \
		and collectible.has_node("VisualRoot/FloatingArtifact/Particles") \
		and collectible.has_node("VisualRoot/ArtifactLight") \
		and collectible.has_node("AnimationPlayer") \
		and collectible.has_node("PickupArea/CollisionShape3D") \
		and collectible.has_node("NetworkSynchronizer")


func _fail(message: String) -> void:
	push_error("[HORDE COLLECTIBLE TEST] %s" % message)
	get_tree().quit(1)
