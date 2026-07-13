extends Node3D

const ZOMBIE_SCENE := preload("res://assets/characters/Zombies/zombie.tscn")
const REQUIRED_ANIMATIONS := ["idle", "walk", "run", "attack", "die"]

@onready var target: Node3D = $FakePlayer

var death_signal_received := false


func _ready() -> void:
	await get_tree().physics_frame
	await _test_scene_contract()
	await _test_damage_and_death()
	await _test_state_machine()
	await _test_attack_damage()
	print("[ZOMBIE TEST] Cena, animacoes, dano, ataque e morte confirmados.")
	get_tree().quit(0)


func _test_scene_contract() -> void:
	var zombie := ZOMBIE_SCENE.instantiate()
	add_child(zombie)
	await get_tree().physics_frame
	await get_tree().physics_frame

	if not zombie is CharacterBody3D:
		_fail("A raiz do zombie nao e CharacterBody3D.")
		return
	if not zombie.has_node("NavigationAgent3D"):
		_fail("Zombie sem NavigationAgent3D como filho direto.")
		return
	if not zombie.has_node("CollisionShape3D"):
		_fail("Zombie sem CollisionShape3D principal.")
		return
	var combat_hitboxes := zombie.find_children("*Animated*", "Area3D", true, false)
	if combat_hitboxes.size() != 9:
		_fail("Zombie sem as 9 hitboxes animadas obrigatorias. total=%d" % combat_hitboxes.size())
		return

	var anim_player: AnimationPlayer = zombie.get("anim_player")
	if not anim_player:
		_fail("Zombie nao encontrou AnimationPlayer.")
		return
	for anim_name in REQUIRED_ANIMATIONS:
		if not anim_player.has_animation(anim_name):
			_fail("Zombie sem animacao obrigatoria: %s" % anim_name)
			return

	var head_hitbox: Area3D = null
	var limb_hitbox: Area3D = null
	for hitbox in combat_hitboxes:
		if hitbox.has_method("get_damage_multiplier"):
			var multiplier := float(hitbox.call("get_damage_multiplier"))
			if multiplier > 1.0:
				head_hitbox = hitbox
			elif multiplier < 1.0:
				limb_hitbox = hitbox
	if not head_hitbox or float(head_hitbox.call("get_damage_multiplier")) <= 1.0:
		_fail("HeadHitbox nao aplica multiplicador de headshot.")
		return

	if not limb_hitbox or float(limb_hitbox.call("get_damage_multiplier")) >= 1.0:
		_fail("LimbHitbox nao reduz dano de membros.")
		return

	zombie.queue_free()


func _test_damage_and_death() -> void:
	var zombie := ZOMBIE_SCENE.instantiate()
	add_child(zombie)
	await get_tree().physics_frame
	await get_tree().physics_frame

	zombie.take_damage(25.0)
	if not is_equal_approx(float(zombie.get("hp")), 75.0):
		_fail("Zombie nao reduziu HP corretamente. hp=%s" % zombie.get("hp"))
		return

	death_signal_received = false
	zombie.zombie_died.connect(func(_pos: Vector3) -> void:
		death_signal_received = true
	)
	zombie.take_damage(999.0, true)
	await get_tree().physics_frame
	if not death_signal_received:
		_fail("Zombie nao emitiu zombie_died ao morrer.")
		return
	if not bool(zombie.get("is_dead")):
		_fail("Zombie morreu sem marcar is_dead.")
		return


func _test_attack_damage() -> void:
	var zombie := ZOMBIE_SCENE.instantiate()
	add_child(zombie)
	zombie.global_position = target.global_position + Vector3(0.0, 0.0, 1.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	zombie.set("player", target)
	zombie.call("_change_state", zombie.State.ATTACK)
	zombie.set_physics_process(false)

	var damage_before := float(target.get("damage_taken"))
	zombie.call("_do_attack")
	var impact_delay: float = zombie.get("attack_impact_delay")
	await get_tree().create_timer(impact_delay + 0.05).timeout
	if float(target.get("damage_taken")) <= damage_before:
		_fail("Zombie atacou sem aplicar dano ao player falso.")
		return
	zombie.queue_free()


func _test_state_machine() -> void:
	var zombie := ZOMBIE_SCENE.instantiate()
	add_child(zombie)
	await get_tree().physics_frame
	zombie.call("activate_from_pool", target.global_position + Vector3(0.0, 0.0, 10.0), target, false, false)
	if not is_equal_approx(zombie.scale.x, zombie.body_scale):
		_fail("Zombie nao aplicou o aumento uniforme de escala.")
		return
	if zombie.call("get_state_name") != &"WANDER":
		_fail("Zombie nao iniciou em WANDER.")
		return
	zombie.call("_update_perception")
	if zombie.call("get_state_name") != &"CHASE":
		_fail("Zombie nao transitou WANDER -> CHASE ao detectar o jogador.")
		return
	var behind_speed: float = zombie.call("_get_chase_speed")
	if not is_equal_approx(behind_speed, zombie.move_speed * zombie.chase_speed_multiplier * zombie.behind_player_speed_multiplier):
		_fail("Zombie atras do jogador nao recebeu aceleracao.")
		return
	zombie.global_position = target.global_position + Vector3(0.0, 0.0, -10.0)
	var front_speed: float = zombie.call("_get_chase_speed")
	if not is_equal_approx(front_speed, zombie.move_speed * zombie.chase_speed_multiplier):
		_fail("Zombie na frente recebeu aceleracao traseira indevida.")
		return
	zombie.global_position = target.global_position + Vector3(0.0, 0.0, 1.0)
	zombie.call("_physics_process", 0.016)
	if zombie.call("get_state_name") != &"ATTACK":
		_fail("Zombie nao transitou CHASE -> ATTACK no alcance.")
		return
	zombie.call("_change_state", zombie.State.SEARCH)
	target.global_position = Vector3(100.0, 0.0, 100.0)
	zombie.call("_physics_process", zombie.SEARCH_DURATION + 0.1)
	if zombie.call("get_state_name") != &"WANDER":
		_fail("Zombie nao transitou SEARCH -> WANDER.")
		return
	target.global_position = Vector3.ZERO
	zombie.queue_free()


func _fail(message: String) -> void:
	push_error("[ZOMBIE TEST] %s" % message)
	get_tree().quit(1)
