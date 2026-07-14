extends Control

var player: CharacterBody3D = null
var catalog: Dictionary = {}
var snapshot: Dictionary = {}
var weapon_buttons: Dictionary = {}
var upgrade_buttons: Dictionary = {}
var selected_weapon_slot := 0

@onready var scrap_label: Label = $Center/Panel/Margin/Root/Header/ScrapLabel
@onready var weapon_selector: OptionButton = $Center/Panel/Margin/Root/SelectorRow/WeaponSelector
@onready var armor_button: Button = $Center/Panel/Margin/Root/Tabs/Suprimentos/ArmorButton
@onready var medkit_button: Button = $Center/Panel/Margin/Root/Tabs/Suprimentos/MedkitButton
@onready var ammo_button: Button = $Center/Panel/Margin/Root/Tabs/Suprimentos/AmmoButton
@onready var status_label: Label = $Center/Panel/Margin/Root/StatusLabel


func _ready() -> void:
	visible = false
	weapon_buttons = {
		1: $Center/Panel/Margin/Root/Tabs/Arsenal/List/SMG45Button,
		2: $Center/Panel/Margin/Root/Tabs/Arsenal/List/AKButton,
		3: $Center/Panel/Margin/Root/Tabs/Arsenal/List/LMG63Button,
		4: $Center/Panel/Margin/Root/Tabs/Arsenal/List/SawnoffButton,
	}
	upgrade_buttons = {
		"damage": $Center/Panel/Margin/Root/Tabs/Melhorias/DamageButton,
		"fast_reload": $Center/Panel/Margin/Root/Tabs/Melhorias/FastReloadButton,
		"extended_mag": $Center/Panel/Margin/Root/Tabs/Melhorias/ExtendedMagButton,
		"rapid_fire": $Center/Panel/Margin/Root/Tabs/Melhorias/RapidFireButton,
	}
	weapon_selector.item_selected.connect(_on_weapon_selected)
	for slot: int in weapon_buttons:
		(weapon_buttons[slot] as Button).pressed.connect(_purchase.bind("weapon", slot))
	armor_button.pressed.connect(_purchase.bind("armor", -1))
	medkit_button.pressed.connect(_purchase.bind("medkit", -1))
	ammo_button.pressed.connect(_purchase_selected.bind("ammo"))
	for upgrade_id: String in upgrade_buttons:
		(upgrade_buttons[upgrade_id] as Button).pressed.connect(_purchase_selected.bind(upgrade_id))


func set_player(value: CharacterBody3D) -> void:
	player = value
	catalog = player.call("get_shop_catalog") as Dictionary
	if not player.shop_state_changed.is_connected(_on_shop_state_changed):
		player.shop_state_changed.connect(_on_shop_state_changed)
	if not player.shop_feedback.is_connected(_on_shop_feedback):
		player.shop_feedback.connect(_on_shop_feedback)
	_on_shop_state_changed(player.call("get_shop_snapshot") as Dictionary)


func _input(event: InputEvent) -> void:
	if not player or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if visible and key_event.physical_keycode == KEY_ESCAPE:
		close_shop()
		get_viewport().set_input_as_handled()


func open_shop() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	player.call("set_shop_open", true)
	_on_shop_state_changed(player.call("get_shop_snapshot") as Dictionary)
	status_label.text = "Crie ou melhore um item. ESC fecha a bancada."


func close_shop() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if player:
		player.call("set_shop_open", false)


func _on_shop_state_changed(value: Dictionary) -> void:
	snapshot = value.duplicate(true)
	if not is_node_ready():
		return
	scrap_label.text = "SUCATA %d" % int(snapshot.get("scrap", 0))
	_refresh_weapon_selector()
	_refresh_arsenal()
	_refresh_supplies()
	_refresh_upgrades()


func _refresh_weapon_selector() -> void:
	var previous_slot := selected_weapon_slot
	weapon_selector.clear()
	var owned := snapshot.get("owned", []) as Array
	var names := catalog.get("weapon_names", []) as Array
	for slot in owned.size():
		if bool(owned[slot]) and slot != 5:
			weapon_selector.add_item(String(names[slot]), slot)
	var selected_index := 0
	for index in weapon_selector.item_count:
		if weapon_selector.get_item_id(index) == previous_slot:
			selected_index = index
			break
	weapon_selector.select(selected_index)
	if weapon_selector.item_count > 0:
		selected_weapon_slot = weapon_selector.get_item_id(selected_index)


func _refresh_arsenal() -> void:
	var owned := snapshot.get("owned", []) as Array
	var names := catalog.get("weapon_names", []) as Array
	var prices := catalog.get("weapon_prices", []) as Array
	for slot: int in weapon_buttons:
		var button := weapon_buttons[slot] as Button
		var acquired := slot < owned.size() and bool(owned[slot])
		button.text = "%s    %s" % [String(names[slot]), "ADQUIRIDA" if acquired else "%d SUCATAS" % int(prices[slot])]
		button.disabled = acquired


func _refresh_supplies() -> void:
	var current_armor := float(snapshot.get("armor", 0.0))
	var armor_max := float(catalog.get("armor_max", 100.0))
	var missing := maxf(armor_max - current_armor, 0.0)
	var armor_cost := ceili(missing) * int(catalog.get("armor_cost_per_point", 12))
	armor_button.text = "COLETE / REPARO    %.0f/%.0f    %d SUCATAS" % [current_armor, armor_max, armor_cost]
	armor_button.disabled = missing <= 0.0
	var kits := int(snapshot.get("medkits", 0))
	var kit_max := int(catalog.get("medkit_max", 3))
	medkit_button.text = "KIT DE CURA    %d/%d    %d SUCATAS" % [kits, kit_max, int(catalog.get("medkit_cost", 450))]
	medkit_button.disabled = kits >= kit_max
	var ammo_types := ["9mm", "9mm", "rifle", "rifle", "shell", "none"]
	var ammo_type: String = ammo_types[selected_weapon_slot]
	var packs := catalog.get("ammo_packs", {}) as Dictionary
	var pack := packs.get(ammo_type, {}) as Dictionary
	var ammo := snapshot.get("ammo", {}) as Dictionary
	if pack.is_empty():
		ammo_button.text = "MUNICAO    INDISPONIVEL"
		ammo_button.disabled = true
	else:
		var current := int(ammo.get(ammo_type, 0))
		var maximum := int(pack["maximum"])
		ammo_button.text = "MUNICAO %s    %d/%d    +%d POR %d SUCATAS" % [ammo_type.to_upper(), current, maximum, int(pack["amount"]), int(pack["cost"])]
		ammo_button.disabled = current >= maximum


func _refresh_upgrades() -> void:
	var all_upgrades := snapshot.get("upgrades", {}) as Dictionary
	var upgrades := all_upgrades.get(selected_weapon_slot, {}) as Dictionary
	var level := int(upgrades.get("damage_level", 0))
	var damage_costs := catalog.get("damage_costs", []) as Array
	var damage_button := upgrade_buttons["damage"] as Button
	if level >= 3:
		damage_button.text = "AUMENTO DE DANO    NIVEL 3/3    MAXIMO"
		damage_button.disabled = true
	else:
		var weapon_costs := damage_costs[selected_weapon_slot] as Array
		damage_button.text = "AUMENTO DE DANO    NIVEL %d -> %d    %d SUCATAS" % [level, level + 1, int(weapon_costs[level])]
		damage_button.disabled = false
	_refresh_binary_upgrade("fast_reload", "CARREGAMENTO RAPIDO (-40% TEMPO)", "fast_reload_costs", upgrades)
	_refresh_binary_upgrade("extended_mag", "CARREGADOR ESTENDIDO (+50%)", "extended_mag_costs", upgrades)
	_refresh_binary_upgrade("rapid_fire", "RAPID FIRE (+25% CADENCIA)", "rapid_fire_costs", upgrades)


func _refresh_binary_upgrade(upgrade_id: String, title: String, cost_key: String, upgrades: Dictionary) -> void:
	var button := upgrade_buttons[upgrade_id] as Button
	var acquired := bool(upgrades.get(upgrade_id, false))
	var costs := catalog.get(cost_key, []) as Array
	button.text = "%s    %s" % [title, "ADQUIRIDA" if acquired else "%d SUCATAS" % int(costs[selected_weapon_slot])]
	button.disabled = acquired


func _on_weapon_selected(index: int) -> void:
	selected_weapon_slot = weapon_selector.get_item_id(index)
	_refresh_supplies()
	_refresh_upgrades()


func _purchase(purchase_type: String, slot: int) -> void:
	if player:
		player.call("request_shop_purchase", purchase_type, slot)


func _purchase_selected(purchase_type: String) -> void:
	_purchase(purchase_type, selected_weapon_slot)


func _on_shop_feedback(message: String) -> void:
	status_label.text = message
