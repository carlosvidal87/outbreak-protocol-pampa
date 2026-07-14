extends Node

const CHARACTER_SCENE := preload("res://src/scenes/character.tscn")
const WORKBENCH_INTERACTION_SCENE := preload("res://src/scenes/workbench_interaction.tscn")


func _ready() -> void:
	var player := CHARACTER_SCENE.instantiate() as CharacterBody3D
	add_child(player)
	await get_tree().process_frame
	var shop_menu := player.get_node_or_null("MenuLayer/ShopMenu") as Control
	if not shop_menu or not shop_menu.has_node("Center/Panel/Margin/Root/Tabs/Arsenal/List/SMG45Button"):
		_fail("A loja precisa existir como arvore editavel na cena do Godot.")
		return
	var l_key := InputEventKey.new()
	l_key.physical_keycode = KEY_L
	l_key.pressed = true
	shop_menu.call("_input", l_key)
	if shop_menu.visible:
		_fail("A tecla L ainda abriu a bancada sem proximidade.")
		return
	var workbench_interaction := WORKBENCH_INTERACTION_SCENE.instantiate() as Area3D
	add_child(workbench_interaction)
	workbench_interaction.global_position = player.global_position
	workbench_interaction.call("_on_body_entered", player)
	var prompt := player.get_node("CrosshairLayer/InteractionPrompt") as PanelContainer
	if player.get("nearby_interactable") != workbench_interaction or not prompt.visible:
		_fail("A proximidade da workbench nao exibiu o aviso de interacao.")
		return
	var fps_hands: Node3D = player.get_node("Camera3D/FPSHands")
	var magazine_before_menu := int(fps_hands.get("magazine"))
	player.call("_interact_with", workbench_interaction)
	if not shop_menu.visible:
		_fail("A tecla E simulada nao abriu a criacao de itens pela workbench.")
		return
	if bool(fps_hands.get("combat_enabled")) or not bool(player.get("local_input_blocked")):
		_fail("Abrir a loja nao bloqueou os controles de combate.")
		return
	fps_hands.call("_on_animation_tree_animation_started", &"fire")
	if int(fps_hands.get("magazine")) != magazine_before_menu:
		_fail("A arma disparou enquanto a loja estava aberta.")
		return
	shop_menu.call("close_shop")
	if not bool(fps_hands.get("combat_enabled")):
		_fail("Fechar a loja nao reativou os controles de combate.")
		return
	workbench_interaction.call("_on_body_exited", player)
	if prompt.visible or player.get("nearby_interactable") != null:
		_fail("O aviso permaneceu visivel depois de sair da workbench.")
		return
	workbench_interaction.queue_free()

	if int(player.get("scrap")) != 250:
		_fail("Saldo inicial de sucata incorreto.")
		return
	if not bool(player.call("collect_scrap", 50)) or int(player.get("scrap")) != 300:
		_fail("Coleta de sucata valida nao atualizou o saldo.")
		return
	player.set("player_state", 1)
	if bool(player.call("collect_scrap", 50)) or int(player.get("scrap")) != 300:
		_fail("Jogador caido conseguiu coletar sucata.")
		return
	player.set("player_state", 0)
	player.set("scrap", 100000)
	player.call("_emit_shop_state")
	var owned := player.get("owned_weapon_slots") as Array
	if owned != [true, false, false, false, false, true]:
		_fail("Inventario inicial incorreto: %s" % [owned])
		return

	player.call("request_shop_purchase", "weapon", 1)
	if not bool((player.get("owned_weapon_slots") as Array)[1]) or int(player.get("scrap")) != 98200:
		_fail("Compra da SMG45 nao desbloqueou a arma ou cobrou valor incorreto.")
		return
	player.call("request_shop_purchase", "weapon", 1)
	if int(player.get("scrap")) != 98200:
		_fail("Compra duplicada descontou sucata.")
		return

	player.call("request_shop_purchase", "armor", -1)
	if not is_equal_approx(float(player.get("armor")), 100.0) or int(player.get("scrap")) != 97000:
		_fail("Colete nao foi equipado por 1.200 sucatas.")
		return
	player.call("take_damage", 40.0)
	var scrap_before_repair := int(player.get("scrap"))
	player.call("request_shop_purchase", "armor", -1)
	if not is_equal_approx(float(player.get("armor")), 100.0) or int(player.get("scrap")) != scrap_before_repair - 480:
		_fail("Reparo parcial do colete nao cobrou 12 sucatas por ponto.")
		return
	player.call("take_damage", 125.0)
	if not is_equal_approx(float(player.get("armor")), 0.0) or not is_equal_approx(float(player.get("hp")), 75.0):
		_fail("Colete nao absorveu 100 de dano antes da vida.")
		return

	for _kit in 3:
		player.call("request_shop_purchase", "medkit", -1)
	var scrap_after_kits := int(player.get("scrap"))
	player.call("request_shop_purchase", "medkit", -1)
	if int(player.get("medkits")) != 3 or int(player.get("scrap")) != scrap_after_kits:
		_fail("Limite de kits ou bloqueio da quarta compra falhou.")
		return
	player.call("request_use_medkit")
	if int(player.get("medkits")) != 2 or not is_equal_approx(float(player.get("hp")), 100.0):
		_fail("Kit nao restaurou 50 HP ou nao consumiu uma unidade.")
		return

	# Comprar dano depois da recarga rapida nao pode reaplicar nem acelerar a
	# timeline novamente.
	player.call("request_shop_purchase", "fast_reload", 1)
	player.call("request_shop_purchase", "damage", 1)
	if not is_equal_approx(float(player.call("_get_weapon_damage", 1)), 23.0):
		_fail("Dano nivel 1 da SMG45 deveria ser 23.")
		return
	player.call("request_shop_purchase", "damage", 1)
	if not is_equal_approx(float(player.call("_get_weapon_damage", 1)), 26.0):
		_fail("Dano nivel 2 da SMG45 deveria ser 26.")
		return
	player.call("request_shop_purchase", "damage", 1)
	player.call("request_shop_purchase", "extended_mag", 1)
	player.call("request_shop_purchase", "rapid_fire", 1)
	if not is_equal_approx(float(player.call("_get_weapon_damage", 1)), 30.0):
		_fail("Dano nivel 3 da SMG45 deveria ser 30.")
		return
	if int(player.call("_get_magazine_capacity", 1)) != 45:
		_fail("Carregador estendido da SMG45 deveria ter 45 tiros.")
		return
	if not is_equal_approx(float(player.call("_get_weapon_fire_interval", 1)), 0.06):
		_fail("Rapid fire da SMG45 deveria reduzir o intervalo para 0,06s.")
		return

	player.set("server_ammo", {"9mm": 100, "rifle": 600, "shell": 64, "none": 0})
	var before_ammo_purchase := int(player.get("scrap"))
	player.call("request_shop_purchase", "ammo", 1)
	var ammo := player.get("server_ammo") as Dictionary
	if int(ammo["9mm"]) != 160 or int(player.get("scrap")) != before_ammo_purchase - 250:
		_fail("Pacote de 9mm nao adicionou 60 por 250 sucatas.")
		return

	await get_tree().create_timer(2.0).timeout
	if int(fps_hands.get("weapon_index")) != 1:
		_fail("A SMG45 comprada nao foi equipada.")
		return
	var animation_tree := fps_hands.get("animation") as AnimationTree
	var reload_node := animation_tree.tree_root.get_node("reload_full") as AnimationNodeAnimation
	if not reload_node or not is_equal_approx(reload_node.timeline_length, 0.96):
		_fail("Carregamento rapido deveria reduzir 1,60s para 0,96s (40%%). atual=%s" % [reload_node.timeline_length if reload_node else -1.0])
		return
	var reload_audio := fps_hands.get("reload_audio_player") as AudioStreamPlayer3D
	fps_hands.call("_on_animation_tree_animation_started", &"reload_full")
	if not reload_audio or not is_equal_approx(reload_audio.pitch_scale, 1.0 / 0.6):
		_fail("Som de recarga rapida nao acompanhou a velocidade da animacao.")
		return
	fps_hands.call("_set_reload_audio_speed", false)

	player.call("request_shop_purchase", "weapon", 4)
	player.call("request_shop_purchase", "extended_mag", 4)
	if int(player.call("_get_magazine_capacity", 4)) != 4:
		_fail("Carregador estendido da Sawnoff deveria ter 4 cartuchos.")
		return

	print("[SHOP ECONOMY TEST] Armas, sucata, colete, kits, municao e melhorias confirmados.")
	player.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("[SHOP ECONOMY TEST] %s" % message)
	get_tree().quit(1)
