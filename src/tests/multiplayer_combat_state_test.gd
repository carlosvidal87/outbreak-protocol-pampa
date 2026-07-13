extends Node3D

const CHARACTER_SCENE := preload("res://src/scenes/character.tscn")


func _ready() -> void:
	if NetworkManager.host_game("Host", 17002, 4) != OK:
		_fail("Nao foi possivel abrir peer de teste.")
		return
	var reviver := CHARACTER_SCENE.instantiate() as CharacterBody3D
	reviver.name = "1"
	reviver.network_peer_id = 1
	add_child(reviver)
	var downed := CHARACTER_SCENE.instantiate() as CharacterBody3D
	downed.name = "2"
	downed.network_peer_id = 2
	downed.position = Vector3(1.0, 0.0, 0.0)
	add_child(downed)
	await get_tree().physics_frame

	downed.take_damage(100.0)
	if downed.player_state != downed.PlayerState.DOWNED or not is_equal_approx(downed.downed_remaining, 45.0):
		_fail("Jogador nao entrou em DOWNED por 45 segundos.")
		return
	downed.call("_update_downed_hud")
	var downed_overlay := downed.get("downed_overlay") as ColorRect
	var downed_label := downed.get("downed_status_label") as Label
	if not downed_overlay or not downed_overlay.visible or not downed_label.text.contains("VOCE ESTA MORRENDO"):
		_fail("Tela vermelha de jogador morrendo nao apareceu.")
		return
	reviver.call("_update_revive_hud")
	var revive_prompt := reviver.get("revive_prompt_panel") as PanelContainer
	var revive_label := reviver.get("revive_prompt_label") as Label
	if not revive_prompt or not revive_prompt.visible or not revive_label.text.contains("[E]"):
		_fail("Aviso de proximidade para reanimar nao apareceu.")
		return
	reviver.revive_target_peer_id = 2
	reviver.revive_progress = 2.0
	reviver.call("_update_revive_hud")
	var revive_bar := reviver.get("revive_progress_bar") as ProgressBar
	if not revive_bar or not revive_bar.visible or not is_equal_approx(revive_bar.value, 2.0):
		_fail("Barra de progresso da reanimacao nao apareceu.")
		return
	reviver.call("_update_server_revive", 4.1)
	if downed.player_state != downed.PlayerState.ALIVE or not is_equal_approx(downed.hp, 40.0):
		_fail("Reviver nao restaurou o jogador com 40 HP.")
		return
	var hp_before: float = float(downed.hp)
	reviver.call("_apply_weapon_damage", downed, 999.0)
	if not is_equal_approx(downed.hp, hp_before):
		_fail("Friendly fire causou dano.")
		return
	NetworkManager.leave_session("")
	print("[MULTIPLAYER COMBAT TEST] Downed, revive e friendly fire confirmados.")
	get_tree().quit(0)


func _fail(message: String) -> void:
	NetworkManager.leave_session("")
	push_error("[MULTIPLAYER COMBAT TEST] %s" % message)
	get_tree().quit(1)
