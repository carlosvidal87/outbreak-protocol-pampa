extends Node

const BOSS_SCENE := preload("res://src/scenes/boss.tscn")


class FakePlayer:
	extends CharacterBody3D
	var player_state := 0
	var damage_taken := 0.0
	var network_peer_id := 1

	func _ready() -> void:
		add_to_group("player")

	func take_damage(amount: float) -> void:
		damage_taken += amount


func _ready() -> void:
	var near_player := FakePlayer.new()
	near_player.name = "NearPlayer"
	near_player.position = Vector3(20.0, 0.0, 0.0)
	add_child(near_player)
	var far_player := FakePlayer.new()
	far_player.name = "FarPlayer"
	far_player.position = Vector3(30.0, 0.0, 0.0)
	add_child(far_player)
	var boss := BOSS_SCENE.instantiate() as CharacterBody3D
	boss.set("testing_skip_intro", true)
	boss.call("setup_for_players", 1)
	if not is_equal_approx(float(boss.get("max_hp")), 12000.0):
		_fail("Vida para um jogador incorreta.")
		return
	boss.call("setup_for_players", 4)
	if not is_equal_approx(float(boss.get("max_hp")), 33600.0):
		_fail("Vida para quatro jogadores incorreta.")
		return
	if not bool(boss.get("immune_to_insta_kill")):
		_fail("Boss nao esta marcado como imune a insta_kill.")
		return
	add_child(boss)
	await get_tree().process_frame
	var model_root := boss.get_node("ModelRoot") as Node3D
	if not model_root.scale.is_equal_approx(Vector3(3.6, 3.6, 3.6)):
		_fail("O boss nao recebeu o aumento visual de 50 por cento.")
		return
	var body_shape := (boss.get_node("BodyCollision") as CollisionShape3D).shape as CapsuleShape3D
	if not is_equal_approx(body_shape.height, 9.225) or not is_equal_approx(body_shape.radius, 1.725):
		_fail("A colisao fisica nao acompanhou o aumento de 50 por cento.")
		return
	if not is_equal_approx(float(boss.get("run_speed")), 8.0) or not is_equal_approx(float(boss.get("walk_speed")), 4.2):
		_fail("As velocidades avassaladoras do boss nao foram aplicadas.")
		return
	if boss.call("_find_nearest_living_player") != near_player:
		_fail("A IA nao selecionou o jogador vivo mais proximo.")
		return
	boss.set("target", near_player)
	var chase_direction := boss.call("_get_chase_direction") as Vector3
	var direct_to_player := (near_player.global_position - boss.global_position).normalized()
	if chase_direction.dot(direct_to_player) < 0.99:
		_fail("Sem rota valida, o boss nao perseguiu diretamente o jogador.")
		return
	var corrected_direction := boss.call("_select_forward_chase_direction", Vector3.RIGHT, Vector3.LEFT) as Vector3
	if corrected_direction.dot(Vector3.RIGHT) < 0.99:
		_fail("Uma rota apontando para longe nao foi rejeitada pela IA.")
		return
	var initial_distance := Vector2(boss.global_position.x, boss.global_position.z).distance_to(Vector2(near_player.global_position.x, near_player.global_position.z))
	for _frame in 12:
		await get_tree().physics_frame
	var chased_distance := Vector2(boss.global_position.x, boss.global_position.z).distance_to(Vector2(near_player.global_position.x, near_player.global_position.z))
	if chased_distance >= initial_distance - 1.0:
		_fail("O CharacterBody3D nao reduziu de fato a distancia ate o jogador.")
		return
	boss.global_position = Vector3.ZERO
	boss.velocity = Vector3.ZERO
	near_player.global_position = Vector3(6.0, 0.0, 0.0)
	far_player.global_position = Vector3(12.0, 0.0, 0.0)
	var hit_count := int(boss.call("_apply_proximity_attack", "attack1"))
	if hit_count != 1 or not is_equal_approx(near_player.damage_taken, 40.0) or far_player.damage_taken > 0.0:
		_fail("O ataque por distancia nao acertou somente o jogador dentro do alcance.")
		return
	near_player.player_state = 1
	if boss.call("_find_nearest_living_player") != far_player:
		_fail("A IA nao trocou para outro jogador vivo quando o alvo caiu.")
		return
	boss.call("_apply_proximity_attack", "attack3")
	if not is_equal_approx(near_player.damage_taken, 40.0):
		_fail("O ataque atingiu um jogador caido.")
		return
	near_player.player_state = 0
	near_player.damage_taken = 0.0
	boss.set("attack_cooldown", 0.0)
	boss.call("_start_attack", "attack2")
	await get_tree().create_timer(0.85).timeout
	if not is_equal_approx(near_player.damage_taken, 50.0):
		_fail("A janela de impacto da animacao nao aplicou o dano por proximidade.")
		return
	await get_tree().create_timer(1.0).timeout
	var expected_multipliers := {
		"HeadHitbox": 1.5,
		"TorsoHitbox": 1.0,
		"LeftArmHitbox": 0.65,
		"RightArmHitbox": 0.65,
		"LeftLegHitbox": 0.65,
		"RightLegHitbox": 0.65,
	}
	for hitbox_name: String in expected_multipliers:
		var hitbox := boss.get_node_or_null("DamageHitboxes/%s" % hitbox_name)
		if hitbox == null or not hitbox.has_method("get_damage_multiplier"):
			_fail("Hitbox ausente: %s." % hitbox_name)
			return
		if not is_equal_approx(float(hitbox.call("get_damage_multiplier")), float(expected_multipliers[hitbox_name])):
			_fail("Multiplicador incorreto em %s." % hitbox_name)
			return
	for node_path: String in ["AttackAreas/SwipeArea", "AttackAreas/SlamArea", "AttackAreas/BiteArea", "NetworkSynchronizer"]:
		if not boss.has_node(node_path):
			_fail("No obrigatorio ausente: %s." % node_path)
			return
	print("[BOSS INTEGRATION TEST] Escala, perseguicao, dano por distancia, vida e hitboxes confirmados.")
	boss.queue_free()
	near_player.queue_free()
	far_player.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("[BOSS INTEGRATION TEST] %s" % message)
	get_tree().quit(1)
