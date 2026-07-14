extends Control

@onready var warning_panel: Control = $WarningPanel
@onready var countdown_label: Label = $WarningPanel/Countdown
@onready var boss_panel: Control = $BossPanel
@onready var boss_health: ProgressBar = $BossPanel/HealthBar
@onready var health_value: Label = $BossPanel/HealthValue
@onready var fury_label: Label = $BossPanel/Fury
@onready var victory_label: Label = $Victory

var local_player: Node = null


func _ready() -> void:
	local_player = get_parent().get_parent()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_visibility()


func _process(_delta: float) -> void:
	_update_visibility()
	if not visible:
		return
	var director: Node = get_tree().get_first_node_in_group("zombie_director")
	var boss: Node = get_tree().get_first_node_in_group("boss")
	var session: Node = get_tree().get_first_node_in_group("game_session")
	var countdown := 0.0
	if director:
		countdown = maxf(float(director.get("boss_countdown_remaining")), 0.0)
	warning_panel.visible = countdown > 0.0 and boss == null
	if warning_panel.visible:
		countdown_label.text = "O PESADELO DESPERTA EM %d" % ceili(countdown)
	var boss_alive := boss != null and is_instance_valid(boss) and not bool(boss.get("is_dead"))
	boss_panel.visible = boss_alive
	if boss_alive:
		var maximum := maxf(float(boss.get("max_hp")), 1.0)
		var current := clampf(float(boss.get("hp")), 0.0, maximum)
		boss_health.max_value = maximum
		boss_health.value = current
		health_value.text = "%d / %d" % [roundi(current), roundi(maximum)]
		fury_label.visible = bool(boss.get("enraged"))
	victory_label.visible = session != null and bool(session.get("map_completed"))


func _update_visibility() -> void:
	visible = local_player != null and bool(local_player.get("is_local_player"))
