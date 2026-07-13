extends Node

const CHARACTER_SCENE := preload("res://src/scenes/character.tscn")

@export var players_path: NodePath = ^"../Players"
@export var spawner_path: NodePath = ^"../PlayerSpawner"
@export var spawn_points_path: NodePath = ^"../PlayerSpawnPoints"

@onready var players_root: Node3D = get_node(players_path)
@onready var player_spawner: MultiplayerSpawner = get_node(spawner_path)
@onready var spawn_points: Node3D = get_node(spawn_points_path)


func _ready() -> void:
	player_spawner.spawn_function = _spawn_player
	if NetworkManager.state in [NetworkManager.SessionState.LOADING, NetworkManager.SessionState.PLAYING]:
		NetworkManager.mark_playing()
		NetworkManager.player_left.connect(_remove_player)
		if multiplayer.is_server():
			for peer_id: int in NetworkManager.get_alive_peer_ids():
				player_spawner.spawn(_make_spawn_data(peer_id))
	else:
		var solo_player := _spawn_player({"peer_id": 1, "position": _get_spawn_position(0), "player_name": "Jogador"})
		players_root.add_child(solo_player)


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
