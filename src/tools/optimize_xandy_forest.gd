extends SceneTree

const SOURCE_PATH := "res://Assets_Scenes/arvores.tscn"
const OUTPUT_PATH := "res://Assets_Scenes/arvores_optimized.tscn"


func _initialize() -> void:
	var source_scene := load(SOURCE_PATH) as PackedScene
	if not source_scene:
		push_error("Nao foi possivel carregar %s" % SOURCE_PATH)
		quit(1)
		return
	var source := source_scene.instantiate() as Node3D
	root.add_child(source)
	var mesh_nodes: Array[MeshInstance3D] = []
	_collect_meshes(source, mesh_nodes)
	var groups: Dictionary = {}
	for mesh_node in mesh_nodes:
		if not mesh_node.mesh:
			continue
		var key := _mesh_group_key(mesh_node)
		if not groups.has(key):
			groups[key] = {"sample": mesh_node, "transforms": []}
		var relative_transform := _transform_relative_to_root(mesh_node, source)
		(groups[key]["transforms"] as Array).append(relative_transform)

	var optimized := Node3D.new()
	optimized.name = "ArvoresOptimized"
	var group_index := 0
	var total_instances := 0
	for key: String in groups:
		var group: Dictionary = groups[key]
		var sample := group["sample"] as MeshInstance3D
		var transforms := group["transforms"] as Array
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = _mesh_with_surface_overrides(sample)
		multimesh.instance_count = transforms.size()
		for index in range(transforms.size()):
			multimesh.set_instance_transform(index, transforms[index] as Transform3D)
		var instance := MultiMeshInstance3D.new()
		instance.name = "TreeBatch%d" % group_index
		var group_bounds := _calculate_group_aabb(multimesh.mesh, transforms).grow(2.0)
		multimesh.custom_aabb = group_bounds
		instance.multimesh = multimesh
		instance.custom_aabb = group_bounds
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		optimized.add_child(instance)
		instance.owner = optimized
		group_index += 1
		total_instances += transforms.size()

	var packed := PackedScene.new()
	var pack_error := packed.pack(optimized)
	if pack_error != OK:
		push_error("Falha ao empacotar floresta: %s" % error_string(pack_error))
		quit(1)
		return
	var save_error := ResourceSaver.save(packed, OUTPUT_PATH)
	if save_error != OK:
		push_error("Falha ao salvar floresta: %s" % error_string(save_error))
		quit(1)
		return
	print("[FOREST OPTIMIZER] %d meshes agrupadas em %d MultiMeshes." % [total_instances, group_index])
	source.queue_free()
	optimized.queue_free()
	quit(0)


func _transform_relative_to_root(node: Node3D, root_node: Node3D) -> Transform3D:
	var relative := node.transform
	var parent := node.get_parent() as Node3D
	while parent and parent != root_node:
		relative = parent.transform * relative
		parent = parent.get_parent() as Node3D
	return relative


func _calculate_group_aabb(mesh: Mesh, transforms: Array) -> AABB:
	var mesh_bounds := mesh.get_aabb()
	var result := AABB()
	var has_point := false
	var corners := [
		Vector3(mesh_bounds.position.x, mesh_bounds.position.y, mesh_bounds.position.z),
		Vector3(mesh_bounds.end.x, mesh_bounds.position.y, mesh_bounds.position.z),
		Vector3(mesh_bounds.position.x, mesh_bounds.end.y, mesh_bounds.position.z),
		Vector3(mesh_bounds.end.x, mesh_bounds.end.y, mesh_bounds.position.z),
		Vector3(mesh_bounds.position.x, mesh_bounds.position.y, mesh_bounds.end.z),
		Vector3(mesh_bounds.end.x, mesh_bounds.position.y, mesh_bounds.end.z),
		Vector3(mesh_bounds.position.x, mesh_bounds.end.y, mesh_bounds.end.z),
		Vector3(mesh_bounds.end.x, mesh_bounds.end.y, mesh_bounds.end.z),
	]
	for value in transforms:
		var tree_transform: Transform3D = value
		for corner in corners:
			var transformed_corner: Vector3 = tree_transform * (corner as Vector3)
			if not has_point:
				result = AABB(transformed_corner, Vector3.ZERO)
				has_point = true
			else:
				result = result.expand(transformed_corner)
	return result


func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		output.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, output)


func _mesh_group_key(mesh_node: MeshInstance3D) -> String:
	var parts := PackedStringArray([str(mesh_node.mesh.get_rid())])
	for surface_index in range(mesh_node.mesh.get_surface_count()):
		var material := mesh_node.get_surface_override_material(surface_index)
		parts.append(str(material.get_rid()) if material else "none")
	return ":".join(parts)


func _mesh_with_surface_overrides(mesh_node: MeshInstance3D) -> Mesh:
	var has_override := false
	for surface_index in range(mesh_node.mesh.get_surface_count()):
		if mesh_node.get_surface_override_material(surface_index):
			has_override = true
			break
	if not has_override or not mesh_node.mesh is ArrayMesh:
		return mesh_node.mesh
	var duplicated := mesh_node.mesh.duplicate(true) as ArrayMesh
	for surface_index in range(duplicated.get_surface_count()):
		var material := mesh_node.get_surface_override_material(surface_index)
		if material:
			duplicated.surface_set_material(surface_index, material)
	return duplicated
