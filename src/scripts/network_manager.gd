extends Node

signal player_joined(peer_id: int, player_name: String)
signal player_left(peer_id: int)
signal connection_failed(message: String)
signal server_disconnected(message: String)
signal lobby_changed(players: Dictionary)
signal game_started

enum SessionState { OFFLINE, CONNECTING, LOBBY, LOADING, PLAYING, ENDING }

const DEFAULT_PORT := 7000
const DEFAULT_MAX_PLAYERS := 4
const LOBBY_SCENE := "res://src/scenes/multiplayer_lobby.tscn"
const LOADING_SCENE := "res://src/scenes/loading_screen.tscn"
const MENU_SCENE := "res://src/scenes/main_menu.tscn"

var state := SessionState.OFFLINE
var players: Dictionary = {}
var local_player_name := "Jogador"
var last_message := ""
var max_players := DEFAULT_MAX_PLAYERS
var connection_attempt := 0


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
	players = {1: {"name": local_player_name, "ready": false, "host": true}}
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
	connection_attempt += 1
	var attempt := connection_attempt
	get_tree().create_timer(10.0).timeout.connect(func() -> void:
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
	state = SessionState.LOADING
	_begin_game.rpc()
	return true


func mark_playing() -> void:
	state = SessionState.PLAYING


func get_local_radmin_candidates() -> PackedStringArray:
	var result := PackedStringArray()
	for address in IP.get_local_addresses():
		if _is_valid_ipv4(address) and not address.begins_with("127.") and not address.begins_with("169.254."):
			result.append(address)
	return result


func get_alive_peer_ids() -> Array[int]:
	var ids: Array[int] = []
	for peer_id: int in players:
		ids.append(peer_id)
	return ids


@rpc("any_peer", "reliable")
func _register_player(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if state != SessionState.LOBBY or players.size() >= max_players:
		_reject_connection.rpc_id(sender, "A partida ja comecou ou o servidor esta cheio.")
		multiplayer.multiplayer_peer.disconnect_peer(sender)
		return
	players[sender] = {"name": _sanitize_name(player_name), "ready": false, "host": false}
	player_joined.emit(sender, String(players[sender]["name"]))
	_emit_lobby_changed()


@rpc("any_peer", "reliable")
func _request_ready(ready: bool) -> void:
	if multiplayer.is_server():
		_set_player_ready(multiplayer.get_remote_sender_id(), ready)


@rpc("authority", "call_local", "reliable")
func _sync_lobby(snapshot: Dictionary) -> void:
	players = snapshot.duplicate(true)
	state = SessionState.LOBBY
	lobby_changed.emit(players.duplicate(true))


@rpc("authority", "call_local", "reliable")
func _begin_game() -> void:
	state = SessionState.LOADING
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


func _emit_lobby_changed() -> void:
	lobby_changed.emit(players.duplicate(true))
	if multiplayer.is_server():
		_sync_lobby.rpc(players)


func _on_connected_to_server() -> void:
	connection_attempt += 1
	state = SessionState.LOBBY
	_register_player.rpc_id(1, local_player_name)


func _on_connection_failed() -> void:
	leave_session("Falha ao conectar. Verifique o IPv4 do Radmin e o firewall UDP 7000.")
	connection_failed.emit(last_message)


func _on_server_disconnected() -> void:
	var message := "O host desconectou. A sessao foi encerrada."
	leave_session(message)
	server_disconnected.emit(message)
	get_tree().change_scene_to_file(MENU_SCENE)


func _on_peer_disconnected(peer_id: int) -> void:
	if players.erase(peer_id):
		player_left.emit(peer_id)
		_emit_lobby_changed()


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
