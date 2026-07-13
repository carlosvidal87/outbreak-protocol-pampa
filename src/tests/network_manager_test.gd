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
	NetworkManager.set_ready(true)
	if not bool(NetworkManager.players[1]["ready"]):
		_fail("Estado PRONTO do host nao foi aplicado.")
		return
	var lobby := load("res://src/scenes/multiplayer_lobby.tscn") as PackedScene
	if not lobby or not lobby.instantiate():
		_fail("Cena de lobby nao pode ser instanciada.")
		return
	NetworkManager.leave_session("")
	print("[NETWORK TEST] ENet, IPv4, host, lobby e pronto confirmados.")
	get_tree().quit(0)


func _fail(message: String) -> void:
	NetworkManager.leave_session("")
	push_error("[NETWORK TEST] %s" % message)
	get_tree().quit(1)
