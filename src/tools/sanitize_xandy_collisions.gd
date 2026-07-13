extends SceneTree

const SCENES := {
	"res://assets/Farm/farm.tscn": "res://assets/Farm/farm_sanitized.tscn",
	"res://Assets_Scenes/açude.tscn": "res://Assets_Scenes/acude_sanitized.tscn",
	"res://Assets_Scenes/industrial_exterior_v_2.tscn": "res://Assets_Scenes/industrial_exterior_v_2_sanitized.tscn",
}
const MIN_COLLIDER_AXIS := 0.12


func _initialize() -> void:
	for source_path: String in SCENES:
		var packed_source := load(source_path) as PackedScene
		if not packed_source:
			push_error("Falha ao carregar %s" % source_path)
			quit(1)
			return
		var root_node := packed_source.instantiate()
		var result := {"shapes": 0, "removed_faces": 0, "disabled_shapes": 0}
		_sanitize_node(root_node, result)
		var packed_output := PackedScene.new()
		var pack_error := packed_output.pack(root_node)
		if pack_error != OK:
			push_error("Falha ao empacotar %s: %s" % [source_path, error_string(pack_error)])
			quit(1)
			return
		var output_path: String = SCENES[source_path]
		var save_error := ResourceSaver.save(packed_output, output_path)
		if save_error != OK:
			push_error("Falha ao salvar %s: %s" % [output_path, error_string(save_error)])
			quit(1)
			return
		print("[COLLISION SANITIZER] %s: %d shapes, %d faces removidas, %d shapes desativadas" % [
			output_path,
			result["shapes"],
			result["removed_faces"],
			result["disabled_shapes"],
		])
		root_node.free()
	quit(0)


func _sanitize_node(node: Node, result: Dictionary) -> void:
	if node is CollisionShape3D:
		var collision := node as CollisionShape3D
		if collision.shape is ConcavePolygonShape3D:
			_sanitize_shape(collision, result)
			if not is_instance_valid(collision):
				return
	for child in node.get_children():
		_sanitize_node(child, result)


func _sanitize_shape(collision: CollisionShape3D, result: Dictionary) -> void:
	result["shapes"] += 1
	var source_shape := collision.shape as ConcavePolygonShape3D
	var source_faces := source_shape.get_faces()
	result["removed_faces"] += int(source_faces.size() / 3)
	if source_faces.is_empty():
		_remove_collision(collision)
		result["disabled_shapes"] += 1
		return
	var bounds := AABB(source_faces[0], Vector3.ZERO)
	for point in source_faces:
		bounds = bounds.expand(point)
	if bounds.size.x < MIN_COLLIDER_AXIS or bounds.size.y < MIN_COLLIDER_AXIS or bounds.size.z < MIN_COLLIDER_AXIS:
		_remove_collision(collision)
		result["disabled_shapes"] += 1
		return
	var box := BoxShape3D.new()
	box.size = bounds.size
	collision.position += collision.basis * bounds.get_center()
	collision.shape = box


func _remove_collision(collision: CollisionShape3D) -> void:
	var parent := collision.get_parent()
	if parent:
		parent.remove_child(collision)
	collision.free()
