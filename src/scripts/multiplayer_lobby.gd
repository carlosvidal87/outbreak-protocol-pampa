extends Control

const MENU_SCENE := "res://src/scenes/main_menu.tscn"

@onready var name_input: LineEdit = $Center/Panel/Margin/Content/Connection/NameInput
@onready var address_input: LineEdit = $Center/Panel/Margin/Content/Connection/AddressInput
@onready var host_button: Button = $Center/Panel/Margin/Content/Connection/Buttons/Host
@onready var join_button: Button = $Center/Panel/Margin/Content/Connection/Buttons/Join
@onready var ready_button: Button = $Center/Panel/Margin/Content/LobbyActions/Ready
@onready var start_button: Button = $Center/Panel/Margin/Content/LobbyActions/Start
@onready var players_label: Label = $Center/Panel/Margin/Content/Players
@onready var status_label: Label = $Center/Panel/Margin/Content/Status
@onready var address_label: Label = $Center/Panel/Margin/Content/HostAddress

var local_ready := false


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	host_button.pressed.connect(_host)
	join_button.pressed.connect(_join)
	ready_button.pressed.connect(_toggle_ready)
	start_button.pressed.connect(_start)
	$Center/Panel/Margin/Content/Back.pressed.connect(_back)
	NetworkManager.lobby_changed.connect(_refresh_lobby)
	NetworkManager.connection_failed.connect(_show_error)
	if NetworkManager.state == NetworkManager.SessionState.LOBBY:
		_refresh_lobby(NetworkManager.players)
	else:
		_set_lobby_controls(false)
	if not NetworkManager.last_message.is_empty():
		status_label.text = NetworkManager.last_message


func _host() -> void:
	if NetworkManager.host_game(name_input.text) == OK:
		status_label.text = "Lobby criado na porta UDP 7000."
		var candidates := NetworkManager.get_local_radmin_candidates()
		address_label.text = "IPv4 local/Radmin: %s" % (", ".join(candidates) if not candidates.is_empty() else "consulte o Radmin VPN")


func _join() -> void:
	status_label.text = "Conectando..."
	NetworkManager.join_game(address_input.text, name_input.text)


func _toggle_ready() -> void:
	local_ready = not local_ready
	NetworkManager.set_ready(local_ready)


func _start() -> void:
	if not NetworkManager.start_game():
		status_label.text = "Todos os jogadores precisam estar prontos."


func _back() -> void:
	NetworkManager.leave_session("")
	get_tree().change_scene_to_file(MENU_SCENE)


func _refresh_lobby(snapshot: Dictionary) -> void:
	_set_lobby_controls(true)
	var lines: PackedStringArray = ["JOGADORES (%d/4)" % snapshot.size()]
	for peer_id: int in snapshot:
		var data: Dictionary = snapshot[peer_id]
		var tags := PackedStringArray()
		if bool(data.get("host", false)):
			tags.append("HOST")
		tags.append("PRONTO" if bool(data.get("ready", false)) else "AGUARDANDO")
		lines.append("%s  [%s]" % [String(data.get("name", "Jogador")), " | ".join(tags)])
	players_label.text = "\n".join(lines)
	var local_id := multiplayer.get_unique_id()
	local_ready = bool(snapshot.get(local_id, {}).get("ready", false))
	ready_button.text = "CANCELAR PRONTO" if local_ready else "PRONTO"
	start_button.visible = multiplayer.is_server()
	start_button.disabled = snapshot.is_empty() or snapshot.values().any(func(data: Dictionary) -> bool: return not bool(data.get("ready", false)))
	status_label.text = "Lobby pronto. O host inicia quando todos confirmarem."


func _set_lobby_controls(enabled: bool) -> void:
	ready_button.disabled = not enabled
	start_button.visible = enabled and multiplayer.is_server()
	name_input.editable = not enabled
	address_input.editable = not enabled
	host_button.disabled = enabled
	join_button.disabled = enabled


func _show_error(message: String) -> void:
	status_label.text = message
	status_label.modulate = Color(1.0, 0.42, 0.36)
	_set_lobby_controls(false)
