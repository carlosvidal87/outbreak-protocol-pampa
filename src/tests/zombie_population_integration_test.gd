extends Node

const MAP_SCENE := preload("res://src/scenes/node_3d.tscn")


func _ready() -> void:
	var map := MAP_SCENE.instantiate()
	map.use_external_loading_screen = true
	add_child(map)
	await map.startup_ready
	var director := map.get_node("ZombieDirector")
	var target_population: int = director.call("_get_target_population")
	var deadline := Time.get_ticks_msec() + 30000
	while director.active_zombies.size() < target_population and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.5).timeout

	var active_count: int = director.active_zombies.size()
	var runner_count: int = 0
	for zombie in director.active_zombies:
		if zombie.is_running:
			runner_count += 1
	var runner_fraction: float = float(runner_count) / maxf(active_count, 1.0)
	var total_instances: int = director.active_zombies.size() + director.pooled_zombies.size()
	var recycled_zombie: Node3D = director.active_zombies[0]
	var recycled_id: int = recycled_zombie.get_instance_id()
	var recycle_position: Vector3 = recycled_zombie.global_position
	director.call("_recycle_zombie", recycled_zombie)
	var player := map.get_tree().get_first_node_in_group("player") as Node3D
	director.call("_activate_zombie", recycle_position, player)
	var pool_reused: bool = director.active_zombies.any(func(zombie: Node3D) -> bool: return zombie.get_instance_id() == recycled_id)
	var process_time_total := 0.0
	for _sample in 120:
		await get_tree().process_frame
		process_time_total += Performance.get_monitor(Performance.TIME_PROCESS)
	var average_process_ms := (process_time_total / 120.0) * 1000.0
	var population_valid: bool = active_count >= director.minimum_population and active_count <= director.maximum_population
	var runner_valid: bool = runner_count == roundi(active_count * director.runner_ratio)
	var pool_valid: bool = total_instances <= director.maximum_population and pool_reused
	var valid: bool = population_valid and runner_valid and pool_valid

	var output := FileAccess.open("res://zombie-population-integration.log", FileAccess.WRITE)
	output.store_string("active=%d runners=%d ratio=%.3f instances=%d avg_process_ms=%.3f valid=%s" % [active_count, runner_count, runner_fraction, total_instances, average_process_ms, valid])
	output.close()
	get_tree().quit(0 if valid else 1)
