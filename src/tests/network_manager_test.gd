extends Node


func _ready() -> void:
	NetworkManager.leave_session("")
	var invalid_result := NetworkManager.join_game("999.1.2", "Teste", 17000)
	if invalid_result != ERR_INVALID_PARAMETER:
		_fail("IPv4 invalido foi aceito.")
		return
	var host_result := NetworkManager.host_game("Host Teste", 17000, 4)
	if host_result != OK or NetworkManager.state != NetworkManager.SessionState.LOBBY:
		_fail("Nao foi possivel criar o lobby ENet.")
		return
	if NetworkManager.players.size() != 1 or String(NetworkManager.players[1]["name"]) != "Host Teste":
		_fail("Host nao foi registrado corretamente.")
		return
	if int(NetworkManager.players[1].get("protocol", -1)) != NetworkManager.NETWORK_PROTOCOL_VERSION:
		_fail("Host nao publicou a versao do protocolo multiplayer.")
		return
	if NetworkManager.is_protocol_compatible(NetworkManager.NETWORK_PROTOCOL_VERSION - 1):
		_fail("Uma versao de protocolo incompatível foi aceita.")
		return
	NetworkManager.call("_broadcast_map_readiness")
	if NetworkManager.server_missing_peer_ids != [1]:
		_fail("Snapshot inicial de carregamento nao identificou o host pendente.")
		return
	NetworkManager.call("_set_map_ready", 1)
	if NetworkManager.server_ready_peer_ids != [1] or not NetworkManager.server_missing_peer_ids.is_empty():
		_fail("Snapshot de carregamento pronto nao foi atualizado.")
		return
	NetworkManager.set_ready(true)
	if not bool(NetworkManager.players[1]["ready"]):
		_fail("Estado PRONTO do host nao foi aplicado.")
		return
	var lobby := load("res://src/scenes/multiplayer_lobby.tscn") as PackedScene
	var lobby_instance: Node = lobby.instantiate() if lobby else null
	if not lobby_instance:
		_fail("Cena de lobby nao pode ser instanciada.")
		return
	lobby_instance.free()
	NetworkManager.leave_session("")
	print("[NETWORK TEST] ENet, IPv4, host, lobby e pronto confirmados.")
	await get_tree().process_frame
	get_tree().quit(0)


func _fail(message: String) -> void:
	NetworkManager.leave_session("")
	push_error("[NETWORK TEST] %s" % message)
	get_tree().quit(1)
