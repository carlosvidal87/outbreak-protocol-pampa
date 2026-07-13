extends Node

const EXPECTED_WEAPONS := ["fps-c19", "fps-smg45", "fps-ak", "fps-lmg63", "fps-sawnoff", "fps-knife"]

@onready var player: CharacterBody3D = $CharacterBody3D


func _ready() -> void:
	var fps_hands: Node3D = player.get_node("Camera3D/FPSHands")
	for slot in range(EXPECTED_WEAPONS.size()):
		fps_hands.take_weapon(slot)
		await get_tree().create_timer(2.0).timeout
		if not fps_hands.weapon or fps_hands.weapon.name != EXPECTED_WEAPONS[slot]:
			push_error("[FPS HANDS TEST] Slot %d esperado=%s atual=%s" % [
				slot + 1,
				EXPECTED_WEAPONS[slot],
				fps_hands.weapon.name if fps_hands.weapon else "null"
			])
			get_tree().quit(2)
			return
		if not fps_hands.animation or not fps_hands.state_machine:
			push_error("[FPS HANDS TEST] %s sem AnimationTree funcional." % EXPECTED_WEAPONS[slot])
			get_tree().quit(3)
			return
		var max_magazine: int = fps_hands.max_magazine
		var magazine_before: int = fps_hands.magazine
		fps_hands.state_machine.travel("fire")
		await _wait_for_idle(fps_hands, 3.0)
		if max_magazine > 0 and fps_hands.magazine != magazine_before - 1:
			push_error("[FPS HANDS TEST] %s nao consumiu municao ao disparar." % EXPECTED_WEAPONS[slot])
			get_tree().quit(4)
			return
		if max_magazine > 0:
			var reload_name: StringName = &"reload_full" if "reload_full" in fps_hands.animation.get_animation_list() else &"reload"
			var reload_animation: Animation = fps_hands.animation.get_animation(reload_name)
			var reload_timeout: float = reload_animation.length + 2.0 if reload_animation else 10.0
			print("[FPS HANDS TEST] %s recarga=%s duracao=%.2fs" % [EXPECTED_WEAPONS[slot], reload_name, reload_animation.length if reload_animation else -1.0])
			fps_hands.reload()
			await _wait_for_idle(fps_hands, reload_timeout)
			if fps_hands.magazine != max_magazine:
				push_error("[FPS HANDS TEST] %s nao concluiu a recarga. estado=%s pente=%d/%d reserva=%d" % [
					EXPECTED_WEAPONS[slot],
					fps_hands.state_machine.get_current_node(),
					fps_hands.magazine,
					max_magazine,
					fps_hands.inventory["ammo"][fps_hands.weapon.get_meta("ammo_type", "none")]
				])
				get_tree().quit(5)
				return
		print("[FPS HANDS TEST] Slot %d: %s OK" % [slot + 1, fps_hands.weapon.name])
	print("[FPS HANDS TEST] Todas as seis armas carregaram e alternaram corretamente.")
	get_tree().quit(0)


func _wait_for_idle(fps_hands: Node3D, timeout: float) -> void:
	var elapsed := 0.0
	var action_started := false
	while elapsed < timeout:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if not fps_hands.state_machine:
			continue
		var current_state: StringName = fps_hands.state_machine.get_current_node()
		if current_state != &"idle":
			action_started = true
		elif action_started:
			return
