extends SceneTree

const OUTPUT_PATH := "res://zombie-hitbox-validation.log"
const ZOMBIE_SCENE := preload("res://assets/characters/Zombies/zombie.tscn")


func _initialize() -> void:
	var zombie := ZOMBIE_SCENE.instantiate()
	root.add_child(zombie)
	await physics_frame
	await process_frame

	var skeleton := zombie.find_child("Skeleton3D", true, false) as Skeleton3D
	var animation_player := zombie.find_child("AnimationPlayer", true, false) as AnimationPlayer
	animation_player.play("walk")
	animation_player.advance(0.0)
	skeleton.force_update_all_bone_transforms()
	zombie._update_animated_hitboxes()
	var before := _capture(zombie, skeleton)

	animation_player.advance(0.55)
	skeleton.force_update_all_bone_transforms()
	zombie._update_animated_hitboxes()
	var after := _capture(zombie, skeleton)

	var lines: PackedStringArray = []
	var moved_count := 0
	var aligned_count := 0
	for shape_name: String in before:
		var first: Dictionary = before[shape_name]
		var second: Dictionary = after[shape_name]
		var area_movement: float = first["area"].distance_to(second["area"])
		var bone_movement: float = first["bone"].distance_to(second["bone"])
		if area_movement > 0.001:
			moved_count += 1
		var follows_bone: bool = second["area"].distance_to(second["bone"]) <= 0.001
		var conversion_error := _conversion_error_for(zombie, shape_name)
		var preserves_authored_shape: bool = conversion_error <= 0.001
		if follows_bone and preserves_authored_shape:
			aligned_count += 1
		lines.append("%s area_delta=%.6f bone_delta=%.6f bone_error=%.6f conversion_error=%.6f" % [shape_name, area_movement, bone_movement, second["area"].distance_to(second["bone"]), conversion_error])
	lines.append("LOCOMOTION walk_speed=%.6f run_speed=%.6f" % [zombie.move_speed, zombie.run_speed])
	lines.append("RESULT moved=%d aligned=%d total=%d" % [moved_count, aligned_count, before.size()])

	var output := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	output.store_string("\n".join(lines))
	output.close()
	var locomotion_valid: bool = zombie.move_speed > 0.0 and zombie.run_speed > 0.0
	quit(0 if moved_count == before.size() and aligned_count == before.size() and locomotion_valid else 1)


func _capture(zombie: Node, skeleton: Skeleton3D) -> Dictionary:
	var result := {}
	for shape_name: String in zombie.HITBOX_BONES:
		var shape := zombie.find_child(shape_name, true, false) as CollisionShape3D
		var area := shape.get_parent() as Area3D
		var bone_name: String = zombie.HITBOX_BONES[shape_name]
		var bone_index := skeleton.find_bone(bone_name)
		result[shape_name] = {
			"area": area.global_position,
			"bone": (skeleton.global_transform * skeleton.get_bone_global_pose(bone_index)).origin,
		}
	return result


func _conversion_error_for(zombie: Node, shape_name: String) -> float:
	for binding: Dictionary in zombie.animated_hitboxes:
		if binding["shape_name"] == shape_name:
			return binding["rest_conversion_error"]
	return INF
