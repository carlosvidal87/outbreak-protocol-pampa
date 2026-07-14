extends Node

signal player_joined(peer_id: int, player_name: String)
signal player_left(peer_id: int)
signal connection_failed(message: String)
signal server_disconnected(message: String)
signal lobby_changed(players: Dictionary)
signal game_started
signal map_readiness_changed(ready_peer_ids: Array[int])

enum SessionState { OFFLINE, CONNECTING, LOBBY, LOADING, PLAYING, ENDING }

const DEFAULT_PORT := 7000
const DEFAULT_MAX_PLAYERS := 4
## Bump this value whenever RPC signatures or replicated gameplay state change.
## Host and guests must run exports made from the same protocol version.
const NETWORK_PROTOCOL_VERSION := 20260714
const LOBBY_SCENE := "res://src/scenes/multiplayer_lobby.tscn"
const LOADING_SCENE := "res://src/scenes/loading_screen.tscn"
const MENU_SCENE := "res://src/scenes/main_menu.tscn"

var state := SessionState.OFFLINE
var players: Dictionary = {}
var local_player_name := "Jogador"
var last_message := ""
var max_players := DEFAULT_MAX_PLAYERS
var connection_attempt := 0
var map_ready_peers: Dictionary = {}
var server_ready_peer_ids: Array[int] = []
var server_missing_peer_ids: Array[int] = []
var debug_map_ready_delay_seconds := 0.0


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func host_game(player_name: String, port: int = DEFAULT_PORT, session_max_players: int = DEFAULT_MAX_PLAYERS) -> Error:
	leave_session("")
	local_player_name = _sanitize_name(player_name)
	max_players = clampi(session_max_players, 1, DEFAULT_MAX_PLAYERS)
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, max_players - 1)
	if error != OK:
		_fail_connection("Nao foi possivel abrir a porta UDP %d." % port)
		return error
	multiplayer.multiplayer_peer = peer
	state = SessionState.LOBBY
	players = {1: {
		"name": local_player_name,
		"ready": false,
		"host": true,
		"protocol": NETWORK_PROTOCOL_VERSION,
	}}
	print("[NET] Servidor ENet aberto em UDP %d, interfaces %s." % [port, get_local_radmin_candidates()])
	_emit_lobby_changed()
	return OK


func join_game(address: String, player_name: String, port: int = DEFAULT_PORT) -> Error:
	if not _is_valid_ipv4(address):
		_fail_connection("IPv4 invalido. Use o endereco exibido pelo Radmin VPN.")
		return ERR_INVALID_PARAMETER
	leave_session("")
	local_player_name = _sanitize_name(player_name)
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address.strip_edges(), port)
	if error != OK:
		_fail_connection("Nao foi possivel iniciar a conexao com %s:%d." % [address, port])
		return error
	multiplayer.multiplayer_peer = peer
	state = SessionState.CONNECTING
	print("[NET] Conectando a %s:%d por ENet/UDP." % [address.strip_edges(), port])
	connection_attempt += 1
	var attempt := connection_attempt
	get_tree().create_timer(20.0).timeout.connect(func() -> void:
		if state == SessionState.CONNECTING and attempt == connection_attempt:
			leave_session("Tempo de conexao esgotado. Verifique Radmin, IPv4 e firewall UDP 7000.")
			connection_failed.emit(last_message)
	)
	return OK


func leave_session(reason: String = "") -> void:
	connection_attempt += 1
	last_message = reason
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	players.clear()
	map_ready_peers.clear()
	server_ready_peer_ids.clear()
	server_missing_peer_ids.clear()
	state = SessionState.OFFLINE


func set_ready(ready: bool) -> void:
	if state != SessionState.LOBBY:
		return
	if multiplayer.is_server():
		_set_player_ready(multiplayer.get_unique_id(), ready)
	else:
		_request_ready.rpc_id(1, ready)


func start_game() -> bool:
	if not multiplayer.is_server() or state != SessionState.LOBBY or players.is_empty():
		return false
	for data: Dictionary in players.values():
		if not bool(data.get("ready", false)):
			return false
	map_ready_peers.clear()
	state = SessionState.LOADING
	_broadcast_map_readiness()
	_begin_game.rpc()
	return true


func mark_playing() -> void:
	if state == SessionState.PLAYING:
		return
	state = SessionState.PLAYING
	print("[NET] Peer %d entrou em PLAYING." % multiplayer.get_unique_id())


func report_map_ready() -> void:
	if not multiplayer.multiplayer_peer:
		return
	if multiplayer.is_server():
		_set_map_ready(multiplayer.get_unique_id())
	else:
		_report_map_ready.rpc_id(1)


func are_all_map_peers_ready() -> bool:
	if players.is_empty():
		return false
	for peer_id: int in players:
		if not map_ready_peers.has(peer_id):
			return false
	return true


func is_protocol_compatible(protocol_version: int) -> bool:
	return protocol_version == NETWORK_PROTOCOL_VERSION


func get_local_radmin_candidates() -> PackedStringArray:
	var radmin_addresses := PackedStringArray()
	var other_addresses := PackedStringArray()
	for address in IP.get_local_addresses():
		if _is_valid_ipv4(address) and not address.begins_with("127.") and not address.begins_with("169.254."):
			if address.begins_with("26."):
				radmin_addresses.append(address)
			else:
				other_addresses.append(address)
	radmin_addresses.append_array(other_addresses)
	var result := radmin_addresses
	return result


func get_alive_peer_ids() -> Array[int]:
	var ids: Array[int] = []
	for peer_id: int in players:
		ids.append(peer_id)
	return ids


@rpc("any_peer", "reliable")
func _register_player(player_name: String, protocol_version: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if not is_protocol_compatible(protocol_version):
		_reject_peer(sender, "Versao de jogo incompativel. Host e convidado precisam usar o mesmo executavel.")
		return
	if state != SessionState.LOBBY or players.size() >= max_players:
		_reject_peer(sender, "A partida ja comecou ou o servidor esta cheio.")
		return
	players[sender] = {
		"name": _sanitize_name(player_name),
		"ready": false,
		"host": false,
		"protocol": protocol_version,
	}
	player_joined.emit(sender, String(players[sender]["name"]))
	_emit_lobby_changed()


@rpc("any_peer", "reliable")
func _request_ready(ready: bool) -> void:
	if multiplayer.is_server():
		_set_player_ready(multiplayer.get_remote_sender_id(), ready)


@rpc("any_peer", "reliable")
func _report_map_ready() -> void:
	if not multiplayer.is_server() or state not in [SessionState.LOADING, SessionState.PLAYING]:
		return
	var sender := multiplayer.get_remote_sender_id()
	if players.has(sender):
		_set_map_ready(sender)


@rpc("authority", "call_local", "reliable")
func _sync_lobby(snapshot: Dictionary, authoritative_state: int) -> void:
	players = snapshot.duplicate(true)
	state = clampi(authoritative_state, SessionState.OFFLINE, SessionState.ENDING)
	lobby_changed.emit(players.duplicate(true))


@rpc("authority", "call_local", "reliable")
func _sync_map_readiness(ready_peer_ids: Array[int], missing_peer_ids: Array[int]) -> void:
	server_ready_peer_ids = ready_peer_ids.duplicate()
	server_missing_peer_ids = missing_peer_ids.duplicate()
	print("[NET] Peer %d recebeu prontidao: prontos=%s faltando=%s" % [multiplayer.get_unique_id(), server_ready_peer_ids, server_missing_peer_ids])
	map_readiness_changed.emit(server_ready_peer_ids.duplicate())


@rpc("authority", "call_local", "reliable")
func _begin_game() -> void:
	state = SessionState.LOADING
	print("[NET] Peer %d iniciou o carregamento do mapa." % multiplayer.get_unique_id())
	game_started.emit()
	get_tree().change_scene_to_file(LOADING_SCENE)


@rpc("authority", "reliable")
func _reject_connection(message: String) -> void:
	leave_session(message)
	connection_failed.emit(message)


func _set_player_ready(peer_id: int, ready: bool) -> void:
	if not players.has(peer_id):
		return
	players[peer_id]["ready"] = ready
	_emit_lobby_changed()


func _set_map_ready(peer_id: int) -> void:
	if not players.has(peer_id) or map_ready_peers.has(peer_id):
		return
	map_ready_peers[peer_id] = true
	_broadcast_map_readiness()


func get_missing_map_ready_peer_ids() -> Array[int]:
	var missing_ids: Array[int] = []
	for peer_id: int in players:
		if not map_ready_peers.has(peer_id):
			missing_ids.append(peer_id)
	missing_ids.sort()
	return missing_ids


func get_server_missing_map_ready_peer_ids() -> Array[int]:
	if multiplayer.multiplayer_peer and not multiplayer.is_server():
		return server_missing_peer_ids.duplicate()
	return get_missing_map_ready_peer_ids()


func get_loading_wait_description() -> String:
	var missing_ids := get_server_missing_map_ready_peer_ids()
	if missing_ids.is_empty():
		return "AGUARDANDO PERSONAGEM"
	var names: PackedStringArray = []
	for peer_id in missing_ids:
		var player_data: Dictionary = players.get(peer_id, {})
		names.append(String(player_data.get("name", "Peer %d" % peer_id)))
	return "AGUARDANDO: %s" % ", ".join(names)


func _broadcast_map_readiness() -> void:
	if not multiplayer.is_server():
		return
	var ready_ids: Array[int] = []
	for ready_peer_id: int in map_ready_peers:
		if players.has(ready_peer_id):
			ready_ids.append(ready_peer_id)
	ready_ids.sort()
	var missing_ids := get_missing_map_ready_peer_ids()
	print("[NET] Mapa pronto em %s. Aguardando peers: %s" % [ready_ids, missing_ids])
	_sync_map_readiness.rpc(ready_ids, missing_ids)


func _reject_peer(peer_id: int, message: String) -> void:
	_reject_connection.rpc_id(peer_id, message)
	_disconnect_rejected_peer_later(peer_id)


func _disconnect_rejected_peer_later(peer_id: int) -> void:
	await get_tree().create_timer(0.35).timeout
	if not multiplayer.multiplayer_peer or not multiplayer.is_server():
		return
	if multiplayer.get_peers().has(peer_id):
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)


func _emit_lobby_changed() -> void:
	lobby_changed.emit(players.duplicate(true))
	if multiplayer.is_server():
		_sync_lobby.rpc(players, state)


func _on_connected_to_server() -> void:
	connection_attempt += 1
	state = SessionState.LOBBY
	print("[NET] Conectado ao servidor como peer %d." % multiplayer.get_unique_id())
	_register_player.rpc_id(1, local_player_name, NETWORK_PROTOCOL_VERSION)


func _on_connection_failed() -> void:
	leave_session("Falha ao conectar. Verifique o IPv4 do Radmin e o firewall UDP 7000.")
	connection_failed.emit(last_message)


func _on_server_disconnected() -> void:
	var message := "O host desconectou. A sessao foi encerrada."
	print("[NET] Servidor desconectado no estado %d." % state)
	leave_session(message)
	server_disconnected.emit(message)
	get_tree().change_scene_to_file(MENU_SCENE)


func _on_peer_disconnected(peer_id: int) -> void:
	print("[NET] Peer %d desconectou no estado %d." % [peer_id, state])
	map_ready_peers.erase(peer_id)
	if players.erase(peer_id):
		player_left.emit(peer_id)
		_emit_lobby_changed()
		if multiplayer.is_server() and state in [SessionState.LOADING, SessionState.PLAYING]:
			_broadcast_map_readiness()


func _fail_connection(message: String) -> void:
	last_message = message
	state = SessionState.OFFLINE
	connection_failed.emit(message)


func _sanitize_name(value: String) -> String:
	var clean := value.strip_edges().substr(0, 20)
	return clean if not clean.is_empty() else "Jogador"


func _is_valid_ipv4(value: String) -> bool:
	var parts := value.strip_edges().split(".")
	if parts.size() != 4:
		return false
	for part in parts:
		if not part.is_valid_int():
			return false
		var number := int(part)
		if number < 0 or number > 255:
			return false
	return true
