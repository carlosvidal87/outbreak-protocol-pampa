extends Node

const DIRECTOR_SCRIPT := preload("res://src/scripts/zombie_director.gd")
const PICKUP_SCENE := preload("res://src/scenes/scrap_pickup.tscn")


class FakeCollector:
	extends CharacterBody3D
	var player_state := 0
	var scrap := 0

	func _ready() -> void:
		add_to_group("player")

	func collect_scrap(amount: int) -> bool:
		if player_state != 0 or amount <= 0:
			return false
		scrap += amount
		return true


func _ready() -> void:
	var director := DIRECTOR_SCRIPT.new() as Node3D
	add_child(director)
	if director.get("spawn_timer"):
		(director.get("spawn_timer") as Timer).stop()

	var rolls := [0.0, 0.599999, 0.60, 0.849999, 0.85, 0.969999, 0.97, 0.999999]
	var expected := [50, 50, 75, 75, 125, 125, 250, 250]
	for index in rolls.size():
		if int(director.call("_roll_scrap_value", rolls[index])) != expected[index]:
			_fail("Faixa de sorteio incorreta no indice %d." % index)
			return
	var expected_average := 50.0 * 0.60 + 75.0 * 0.25 + 125.0 * 0.12 + 250.0 * 0.03
	if not is_equal_approx(expected_average, 71.25):
		_fail("Media teorica de sucata incorreta.")
		return

	var dying_zombie := director.call("_take_from_pool") as Node3D
	dying_zombie.global_position = Vector3(100.0, 0.0, 0.0)
	dying_zombie.call("take_damage", 999999.0)
	await get_tree().process_frame
	var pickups := director.get("active_scrap_pickups") as Array
	if pickups.size() != 1 or not (pickups[0] as Node).has_node("VisualRoot/PickupLight") or not (pickups[0] as Node).has_node("PickupArea/CollisionShape3D"):
		_fail("A morte do zumbi nao criou um pickup editavel completo.")
		return

	for existing_pickup in pickups.duplicate():
		(existing_pickup as Node).queue_free()
	await get_tree().process_frame
	var recycled_zombie := director.call("_take_from_pool") as Node3D
	(director.get("active_zombies") as Array).append(recycled_zombie)
	director.call("_recycle_zombie", recycled_zombie)
	if not (director.get("active_scrap_pickups") as Array).is_empty():
		_fail("Reciclar um zumbi sem morte gerou sucata.")
		return
	for index in 65:
		director.call("_spawn_scrap_pickup", Vector3(100.0 + index * 0.25, 0.0, 0.0), 50)
	pickups = director.get("active_scrap_pickups") as Array
	var total_value := 0
	for existing_pickup in pickups:
		total_value += int((existing_pickup as Node).get("scrap_value"))
	if pickups.size() != 64 or total_value != 3250:
		_fail("Limite ou consolidacao de pickups falhou: quantidade=%d total=%d." % [pickups.size(), total_value])
		return

	var pickup := PICKUP_SCENE.instantiate() as Node3D
	pickup.set("scrap_value", 125)
	add_child(pickup)
	var first := FakeCollector.new()
	var second := FakeCollector.new()
	add_child(first)
	add_child(second)
	pickup.call("_on_pickup_area_body_entered", first)
	pickup.call("_on_pickup_area_body_entered", second)
	if first.scrap != 125 or second.scrap != 0:
		_fail("Dois jogadores receberam o mesmo pickup.")
		return

	var downed_pickup := PICKUP_SCENE.instantiate() as Node3D
	add_child(downed_pickup)
	second.player_state = 1
	downed_pickup.call("_on_pickup_area_body_entered", second)
	if bool(downed_pickup.get("collected")) or second.scrap != 0:
		_fail("Jogador caido coletou um pickup.")
		return

	var expiring_pickup := PICKUP_SCENE.instantiate() as Node3D
	expiring_pickup.set("lifespan_seconds", 0.02)
	expiring_pickup.position = Vector3(1000.0, 0.0, 0.0)
	add_child(expiring_pickup)
	await get_tree().create_timer(0.06).timeout
	if is_instance_valid(expiring_pickup):
		_fail("Pickup nao expirou no tempo configurado.")
		return

	print("[SCRAP DROP TEST] Sorteio, cena, limite, consolidacao e coleta confirmados.")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("[SCRAP DROP TEST] %s" % message)
	get_tree().quit(1)
