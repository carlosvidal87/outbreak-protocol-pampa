extends Node

const WEAPONS := {
	"C19": [preload("res://addons/fps-hands/fps-c19/fps-c19.tscn"), 25.0, 19],
	"SMG45": [preload("res://addons/fps-hands/fps-smg45/fps-smg45.tscn"), 20.0, 30],
	"AK": [preload("res://addons/fps-hands/fps-ak/fps-ak.tscn"), 35.0, 30],
	"LMG63": [preload("res://addons/fps-hands/fps-lmg63/fps-lmg63.tscn"), 30.0, 100],
	"Sawnoff": [preload("res://addons/fps-hands/fps-sawnoff/fps-sawnoff.tscn"), 160.0, 2],
	"Knife": [preload("res://addons/fps-hands/fps-knife/fps-knife.tscn"), 70.0, 0],
}


func _ready() -> void:
	for weapon_name: String in WEAPONS:
		var expected: Array = WEAPONS[weapon_name]
		var weapon := (expected[0] as PackedScene).instantiate() as Node3D
		if not weapon:
			_fail("Nao foi possivel instanciar %s." % weapon_name)
			return
		add_child(weapon)
		if not is_equal_approx(float(weapon.get_meta("damage", -1.0)), float(expected[1])):
			_fail("Dano incorreto em %s." % weapon_name)
			return
		if int(weapon.get_meta("max_magazine", 0)) != int(expected[2]):
			_fail("Carregador incorreto em %s." % weapon_name)
			return
		weapon.queue_free()

	var shotgun := (WEAPONS["Sawnoff"][0] as PackedScene).instantiate() as Node3D
	if int(shotgun.get_meta("bullet_count", 0)) != 8:
		_fail("A doze precisa disparar exatamente 8 pellets.")
		return
	if not is_equal_approx(float(shotgun.get_meta("damage")) / 8.0, 20.0):
		_fail("Cada pellet da doze precisa receber 20 de dano base.")
		return
	shotgun.queue_free()

	var smg := (WEAPONS["SMG45"][0] as PackedScene).instantiate() as Node3D
	var smg_tree := smg.get_node("AnimationTree") as AnimationTree
	var smg_fire := smg_tree.tree_root.get_node("fire") as AnimationNodeAnimation
	if not is_equal_approx(smg_fire.timeline_length, 0.087):
		_fail("Cadencia da SMG nao recebeu o aumento planejado.")
		return
	smg.queue_free()

	var lmg := (WEAPONS["LMG63"][0] as PackedScene).instantiate() as Node3D
	var lmg_tree := lmg.get_node("AnimationTree") as AnimationTree
	var lmg_take := lmg_tree.tree_root.get_node("take") as AnimationNodeAnimation
	if not is_equal_approx(lmg_take.timeline_length, 1.5):
		_fail("Saque da LMG nao esta configurado para 1,5 segundo.")
		return
	lmg.queue_free()

	print("[WEAPON BALANCE TEST] Danos, carregadores, pellets, cadencia e saque confirmados.")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("[WEAPON BALANCE TEST] %s" % message)
	get_tree().quit(1)
