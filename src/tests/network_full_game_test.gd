extends Node

const PORT := 17003

class FullGameObserver:
	extends Node
	var role := ""
	var deadline := 0
	var last_report := 0
	var gameplay_started := false
	var movement_started_ms := 0
	var initial_remote_position := Vector3.ZERO
	var last_remote_position := Vector3.ZERO
	var maximum_remote_step := 0.0
	var hitmarker_sent := false
	var hitmarker_received := false
	var damage_sent := false
	var damage_received := false
	var pause_verified := false
	var animation_verified := false
	var tracked_zombie: Node3D = null
	var zombie_initial_position := Vector3.ZERO
	var zombie_last_position := Vector3.ZERO
	var zombie_maximum_step := 0.0
	var zombie_samples := 0
	var zombie_tracking_settled := false
	var zombie_pause_verified := false
	var downed_sent := false
	var downed_seen := false
	var revive_ui_verified := false
	var revive_completed := false

	func _process(delta: float) -> void:
		var now := Time.get_ticks_msec()
		if now >= deadline:
			push_error("[FULL GAME TEST][%s] Timeout. scene=%s players=%d state=%d" % [role, _scene_name(), get_tree().get_nodes_in_group("player").size(), NetworkManager.state])
			get_tree().quit(1)
			return
		if now - last_report >= 2000:
			last_report = now
			var player_nodes := get_tree().get_nodes_in_group("player")
			var player_names := PackedStringArray()
			for player in player_nodes:
				player_names.append("%s(auth=%d local=%s)" % [player.name, player.get_multiplayer_authority(), player.get("is_local_player")])
			print("[FULL GAME TEST][%s] scene=%s players=%s lobby=%s state=%d" % [role, _scene_name(), player_names, NetworkManager.get_alive_peer_ids(), NetworkManager.state])
		var scene := get_tree().current_scene
		if not scene or scene.name != "Node3D":
			return
		var local_players := get_tree().get_nodes_in_group("player").filter(func(player: Node) -> bool: return bool(player.get("is_local_player")))
		if local_players.size() != 1:
			return
		var local_player := local_players[0] as Node3D
		var camera := local_player.get_node_or_null("Camera3D") as Camera3D
		if not camera or not camera.current:
			return
		if get_tree().get_nodes_in_group("player").size() != 2:
			return
		if not gameplay_started:
			gameplay_started = true
			movement_started_ms = now
			print("[FULL GAME TEST][%s] MAP_OK local=%s camera=%s position=%s" % [role, local_player.name, camera.current, local_player.global_position])
			if role == "client":
				local_player.set_physics_process(false)
			else:
				var remote := _get_remote_player()
				initial_remote_position = remote.position
				last_remote_position = remote.position
		if role == "client":
			_run_client_gameplay(local_player, delta, now)
		else:
			_run_host_gameplay(local_player, now)

	func _run_client_gameplay(local_player: Node3D, delta: float, now: int) -> void:
		if now - movement_started_ms < 1400:
			local_player.position.x += 4.0 * delta
			local_player.set("network_animation_state", local_player.SoldierAnimState.WALK_RIGHT)
			local_player.set("network_animation_speed", 1.0)
			local_player.set("network_animation_phase", fmod(float(now - movement_started_ms) / 1000.0, 1.0))
			local_player.set("network_animation_airborne", false)
			local_player.call("_publish_network_transform")
		var marker := local_player.get_node("CrosshairLayer/Hitmarker")
		if float(marker.get("_time_left")) > 0.0 and not hitmarker_received:
			hitmarker_received = true
			print("[FULL GAME TEST][client] HITMARKER_OK confirmado pelo host")
		if float(local_player.get("hp")) <= 90.0 and not damage_received:
			damage_received = true
			print("[FULL GAME TEST][client] REMOTE_DAMAGE_OK hp=%.1f" % float(local_player.get("hp")))
		if int(local_player.get("player_state")) == local_player.PlayerState.DOWNED and not downed_seen:
			var overlay := local_player.get("downed_overlay") as ColorRect
			var status_label := local_player.get("downed_status_label") as Label
			if not overlay or not overlay.visible or not status_label.text.contains("VOCE ESTA MORRENDO"):
				push_error("[FULL GAME TEST][client] HUD de jogador morrendo nao apareceu.")
				get_tree().quit(1)
				return
			downed_seen = true
			print("[FULL GAME TEST][client] DOWNED_HUD_OK tela vermelha e texto branco")
		if downed_seen and int(local_player.get("player_state")) == local_player.PlayerState.ALIVE and is_equal_approx(float(local_player.get("hp")), 40.0) and not revive_completed:
			revive_completed = true
			print("[FULL GAME TEST][client] REVIVE_COMPLETED_OK hp=40")
		_sample_client_zombie()
		if hitmarker_received and damage_received and revive_completed and zombie_samples >= 20 and tracked_zombie and tracked_zombie.position.distance_to(zombie_initial_position) >= 0.35:
			if zombie_maximum_step >= 0.16:
				push_error("[FULL GAME TEST][client] Zombie remoto travado. max_step=%.3f" % zombie_maximum_step)
				get_tree().quit(1)
				return
			print("[FULL GAME TEST][client] ZOMBIE_SMOOTHING_OK traveled=%.3f max_step=%.3f" % [tracked_zombie.position.distance_to(zombie_initial_position), zombie_maximum_step])
			NetworkManager.leave_session("")
			get_tree().quit(0)

	func _run_host_gameplay(local_player: Node3D, _now: int) -> void:
		var remote := _get_remote_player()
		if not pause_verified:
			var menu_layer := local_player.get_node("MenuLayer")
			var menu_controller := menu_layer.get_child(0)
			menu_controller.call("pause_game")
			if get_tree().paused or not bool(local_player.get("local_input_blocked")):
				push_error("[FULL GAME TEST][host] Pause multiplayer congelou o servidor ou nao bloqueou o input local.")
				get_tree().quit(1)
				return
			pause_verified = true
			print("[FULL GAME TEST][host] LOCAL_PAUSE_OK arvore continua ativa")
		if not damage_sent:
			remote.call("take_damage", 10.0)
			damage_sent = true
		_track_host_zombie(remote)
		if _now - movement_started_ms < 500:
			initial_remote_position = remote.position
			last_remote_position = remote.position
			maximum_remote_step = 0.0
			return
		var step := remote.position.distance_to(last_remote_position)
		maximum_remote_step = maxf(maximum_remote_step, step)
		last_remote_position = remote.position
		var traveled := remote.position.distance_to(initial_remote_position)
		if traveled >= 2.5 and not hitmarker_sent:
			if maximum_remote_step >= 0.12:
				push_error("[FULL GAME TEST][host] Movimento remoto travado. max_step=%.3f" % maximum_remote_step)
				get_tree().quit(1)
				return
			if not _verify_remote_animation(remote):
				get_tree().quit(1)
				return
			hitmarker_sent = true
			var remote_peer_id := int(remote.get("network_peer_id"))
			remote.rpc_id(remote_peer_id, "_confirm_hitmarker", false, false)
			print("[FULL GAME TEST][host] SMOOTHING_OK traveled=%.3f max_step=%.3f" % [traveled, maximum_remote_step])
		if hitmarker_sent and NetworkManager.players.size() == 1:
			NetworkManager.leave_session("")
			get_tree().quit(0)
		if hitmarker_sent and zombie_pause_verified:
			_run_host_revive_test(local_player, remote)

	func _track_host_zombie(remote: Node3D) -> void:
		if not tracked_zombie:
			for candidate in get_tree().get_nodes_in_group("zombies"):
				if candidate.visible and not bool(candidate.get("is_dead")):
					tracked_zombie = candidate as Node3D
					tracked_zombie.set("player", remote)
					tracked_zombie.call("_change_state", tracked_zombie.State.CHASE)
					zombie_initial_position = tracked_zombie.position
					zombie_last_position = tracked_zombie.position
					break
		elif not zombie_pause_verified and tracked_zombie.position.distance_to(zombie_initial_position) >= 0.35:
			var local_player: Node3D = get_tree().get_nodes_in_group("player").filter(func(player: Node) -> bool: return bool(player.get("is_local_player")))[0] as Node3D
			var menu_controller: Node = local_player.get_node("MenuLayer").get_child(0)
			menu_controller.call("resume_game")
			zombie_pause_verified = true
			print("[FULL GAME TEST][host] ZOMBIE_DURING_PAUSE_OK traveled=%.3f" % tracked_zombie.position.distance_to(zombie_initial_position))

	func _verify_remote_animation(remote: Node3D) -> bool:
		var animation_player := remote.get("soldier_anim_player") as AnimationPlayer
		if int(remote.get("network_animation_state")) != remote.SoldierAnimState.WALK_RIGHT:
			push_error("[FULL GAME TEST][host] Estado direcional remoto nao foi sincronizado.")
			return false
		if not animation_player or animation_player.current_animation != "pistol/walk_right":
			push_error("[FULL GAME TEST][host] Animacao remota incorreta: %s" % (animation_player.current_animation if animation_player else "null"))
			return false
		var length := animation_player.current_animation_length
		var local_phase := animation_player.current_animation_position / maxf(length, 0.001)
		var target_phase := float(remote.get("network_animation_phase"))
		var phase_error := absf(local_phase - target_phase)
		phase_error = minf(phase_error, 1.0 - phase_error)
		if phase_error > 0.12:
			push_error("[FULL GAME TEST][host] Fase remota fora do limite: %.3f" % phase_error)
			return false
		animation_verified = true
		print("[FULL GAME TEST][host] ANIMATION_SYNC_OK state=walk_right phase_error=%.3f" % phase_error)
		return true

	func _run_host_revive_test(local_player: Node3D, remote: Node3D) -> void:
		if not downed_sent:
			local_player.global_position = remote.global_position + Vector3(1.0, 0.0, 0.0)
			remote.call("take_damage", 100.0)
			var press := InputEventKey.new()
			press.keycode = KEY_E
			press.physical_keycode = KEY_E
			press.pressed = true
			Input.parse_input_event(press)
			downed_sent = true
			return
		if not revive_ui_verified and float(local_player.get("revive_progress")) >= 0.2:
			var panel := local_player.get("revive_prompt_panel") as PanelContainer
			var label := local_player.get("revive_prompt_label") as Label
			var bar := local_player.get("revive_progress_bar") as ProgressBar
			if not panel or not panel.visible or not label.text.contains("REANIMANDO") or not bar or not bar.visible or bar.value <= 0.0:
				push_error("[FULL GAME TEST][host] Prompt ou progresso de revive nao apareceu.")
				get_tree().quit(1)
				return
			revive_ui_verified = true
			print("[FULL GAME TEST][host] REVIVE_PROGRESS_HUD_OK progress=%.2f" % bar.value)
		if revive_ui_verified and int(remote.get("player_state")) == remote.PlayerState.ALIVE and is_equal_approx(float(remote.get("hp")), 40.0):
			var release := InputEventKey.new()
			release.keycode = KEY_E
			release.physical_keycode = KEY_E
			release.pressed = false
			Input.parse_input_event(release)

	func _sample_client_zombie() -> void:
		if not tracked_zombie:
			for candidate in get_tree().get_nodes_in_group("zombies"):
				if candidate.visible and not bool(candidate.get("is_dead")):
					tracked_zombie = candidate as Node3D
					zombie_initial_position = tracked_zombie.position
					zombie_last_position = tracked_zombie.position
					return
			return
		var network_target: Vector3 = tracked_zombie.get("network_position") as Vector3
		var distance_to_target := tracked_zombie.position.distance_to(network_target)
		if not zombie_tracking_settled:
			zombie_last_position = tracked_zombie.position
			if distance_to_target <= 0.5:
				zombie_tracking_settled = true
				zombie_initial_position = tracked_zombie.position
				zombie_maximum_step = 0.0
				zombie_samples = 0
			return
		var step := tracked_zombie.position.distance_to(zombie_last_position)
		# Ativacao/reciclagem do pool usa snap fora da camera. Reinicie a medicao
		# para nao confundir a troca de ponto com engasgo durante a caminhada.
		if step >= 5.0:
			zombie_tracking_settled = false
			zombie_last_position = tracked_zombie.position
			zombie_maximum_step = 0.0
			zombie_samples = 0
			return
		zombie_maximum_step = maxf(zombie_maximum_step, step)
		zombie_last_position = tracked_zombie.position
		zombie_samples += 1

	func _get_remote_player() -> Node3D:
		for player in get_tree().get_nodes_in_group("player"):
			if not bool(player.get("is_local_player")):
				return player as Node3D
		return null

	func _scene_name() -> String:
		return get_tree().current_scene.name if get_tree().current_scene else "null"


func _ready() -> void:
	var role := ""
	var address := "127.0.0.1"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("role="):
			role = argument.trim_prefix("role=")
		elif argument.begins_with("address="):
			address = argument.trim_prefix("address=")
	var observer := FullGameObserver.new()
	observer.role = role
	observer.deadline = Time.get_ticks_msec() + 35000
	get_tree().root.add_child.call_deferred(observer)
	if role == "host":
		await _run_host()
	elif role == "client":
		await _run_client(address)
	else:
		push_error("[FULL GAME TEST] role ausente")
		get_tree().quit(1)


func _run_host() -> void:
	if NetworkManager.host_game("Host", PORT, 4) != OK:
		get_tree().quit(1)
		return
	while NetworkManager.players.size() < 2:
		await get_tree().create_timer(0.1).timeout
	NetworkManager.set_ready(true)
	while NetworkManager.players.values().any(func(data: Dictionary) -> bool: return not bool(data.get("ready", false))):
		await get_tree().create_timer(0.1).timeout
	print("[FULL GAME TEST][host] iniciando mapa")
	NetworkManager.start_game()


func _run_client(address: String) -> void:
	if NetworkManager.join_game(address, "Cliente", PORT) != OK:
		get_tree().quit(1)
		return
	while NetworkManager.players.size() < 2:
		await get_tree().create_timer(0.1).timeout
	NetworkManager.set_ready(true)
	print("[FULL GAME TEST][client] pronto")
