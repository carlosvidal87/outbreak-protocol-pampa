extends Area3D

@export var prompt_text := "APERTE E PARA ABRIR A CRIAÇÃO DE ITENS"


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func get_interaction_prompt() -> String:
	return prompt_text


func interact_local(player: CharacterBody3D) -> void:
	if player and player.has_method("open_crafting_menu"):
		player.call("open_crafting_menu", self)


func _on_body_entered(body: Node3D) -> void:
	if not _is_local_player(body):
		return
	if body.has_method("register_interactable"):
		body.call("register_interactable", self)


func _on_body_exited(body: Node3D) -> void:
	if body.has_method("unregister_interactable"):
		body.call("unregister_interactable", self)


func _is_local_player(body: Node3D) -> bool:
	return body.is_in_group("player") and bool(body.get("is_local_player"))
