extends Node

signal map_completion_changed(completed: bool)
signal local_gameplay_ready

const CHARACTER_SCENE := preload("res://src/scenes/character.tscn")

@export var players_path: NodePath = ^"../Players"
@export var spawner_path: NodePath = ^"../PlayerSpawner"
@export var spawn_points_path: NodePath = ^"../PlayerSpawnPoints"

@onready var players_root: Node3D = get_node(players_path)
@onready var player_spawner: MultiplayerSpawner = get_node(spawner_path)
@onready var spawn_points: Node3D = get_node(spawn_points_path)

var multiplayer_world_ready := false
var players_spawned := false
var map_completed := false
var startup_complete := false
var local_gameplay_is_ready := false
var readiness_retry_elapsed := 0.0


func _ready() -> void:
	add_to_group("game_session")
	set_process(false)
	player_spawner.spawn_function = _spawn_player
	var gameplay_root := get_parent()
	if gameplay_root.has_signal("startup_ready"):
		await gameplay_root.startup_ready
	startup_complete = true
	if NetworkManager.state in [NetworkManager.SessionState.LOADING, NetworkManager.SessionState.PLAYING]:
		if not NetworkManager.player_left.is_connected(_remove_player):
			NetworkManager.player_left.connect(_remove_player)
		if not NetworkManager.map_readiness_changed.is_connected(_on_map_readiness_changed):
			NetworkManager.map_readiness_changed.connect(_on_map_readiness_changed)
		if NetworkManager.debug_map_ready_delay_seconds > 0.0:
			await get_tree().create_timer(NetworkManager.debug_map_ready_delay_seconds).timeout
		if NetworkManager.state in [NetworkManager.SessionState.LOADING, NetworkManager.SessionState.PLAYING]:
			NetworkManager.report_map_ready()
			_try_start_multiplayer_world()
		set_process(true)
	else:
		var solo_player := _spawn_player({"peer_id": 1, "position": _get_spawn_position(0), "player_name": "Jogador"})
		players_root.add_child(solo_player)
		players_spawned = true
		_mark_local_gameplay_ready()


func _process(delta: float) -> void:
	if not startup_complete or local_gameplay_is_ready:
		return
	readiness_retry_elapsed += delta
	if readiness_retry_elapsed >= 1.0:
		readiness_retry_elapsed = 0.0
		if NetworkManager.state in [NetworkManager.SessionState.LOADING, NetworkManager.SessionState.PLAYING]:
			NetworkManager.report_map_ready()
			_try_start_multiplayer_world()
	_refresh_local_gameplay_ready()


func is_multiplayer_world_ready() -> bool:
	return multiplayer_world_ready


func is_local_gameplay_ready() -> bool:
	return local_gameplay_is_ready


func complete_map() -> void:
	if map_completed or (multiplayer.multiplayer_peer and not multiplayer.is_server()):
		return
	if multiplayer.multiplayer_peer:
		_set_map_completed.rpc()
	else:
		_set_map_completed()


@rpc("authority", "call_local", "reliable")
func _set_map_completed() -> void:
	if map_completed:
		return
	map_completed = true
	map_completion_changed.emit(true)


func _on_map_readiness_changed(_ready_peer_ids: Array[int]) -> void:
	_try_start_multiplayer_world()


func _try_start_multiplayer_world() -> void:
	if players_spawned or not multiplayer.is_server() or not NetworkManager.are_all_map_peers_ready():
		return
	players_spawned = true
	for peer_id: int in NetworkManager.get_alive_peer_ids():
		player_spawner.spawn(_make_spawn_data(peer_id))
	multiplayer_world_ready = true
	print("[NET] Servidor criou %d jogadores." % NetworkManager.get_alive_peer_ids().size())
	call_deferred("_refresh_local_gameplay_ready")


func _refresh_local_gameplay_ready() -> void:
	if local_gameplay_is_ready:
		return
	var local_peer_id := multiplayer.get_unique_id() if multiplayer.multiplayer_peer else 1
	var local_player := players_root.get_node_or_null(str(local_peer_id)) as CharacterBody3D
	if not local_player or not local_player.is_node_ready() or not bool(local_player.get("is_local_player")):
		return
	var local_camera := local_player.get_node_or_null("Camera3D") as Camera3D
	if not local_camera or not local_camera.current:
		return
	_mark_local_gameplay_ready()


func _mark_local_gameplay_ready() -> void:
	if local_gameplay_is_ready:
		return
	local_gameplay_is_ready = true
	multiplayer_world_ready = true
	if multiplayer.multiplayer_peer:
		NetworkManager.mark_playing()
	print("[NET] Gameplay local pronto no peer %d." % (multiplayer.get_unique_id() if multiplayer.multiplayer_peer else 1))
	local_gameplay_ready.emit()


func _make_spawn_data(peer_id: int) -> Dictionary:
	var ids := NetworkManager.get_alive_peer_ids()
	ids.sort()
	var index := maxi(ids.find(peer_id), 0)
	var data: Dictionary = NetworkManager.players.get(peer_id, {})
	return {
		"peer_id": peer_id,
		"position": _get_spawn_position(index),
		"player_name": String(data.get("name", "Jogador")),
	}


func _spawn_player(data: Variant) -> Node:
	var spawn_data := data as Dictionary
	var peer_id := int(spawn_data.get("peer_id", 1))
	var player := CHARACTER_SCENE.instantiate() as CharacterBody3D
	player.name = str(peer_id)
	player.position = spawn_data.get("position", Vector3.ZERO)
	player.set("network_peer_id", peer_id)
	player.set("player_display_name", String(spawn_data.get("player_name", "Jogador")))
	player.set_multiplayer_authority(peer_id)
	var movement_sync := player.get_node_or_null("MovementSynchronizer") as MultiplayerSynchronizer
	if movement_sync:
		movement_sync.set_multiplayer_authority(peer_id)
	var state_sync := player.get_node_or_null("StateSynchronizer") as MultiplayerSynchronizer
	if state_sync:
		state_sync.set_multiplayer_authority(1)
	return player


func _get_spawn_position(index: int) -> Vector3:
	var points := spawn_points.get_children()
	if points.is_empty():
		return Vector3(-12.82, -1.08, -46.29)
	return (points[index % points.size()] as Node3D).position


func _remove_player(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var player := players_root.get_node_or_null(str(peer_id))
	if player:
		player.queue_free()
