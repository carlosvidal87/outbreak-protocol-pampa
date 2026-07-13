extends SceneTree

const MAP_SCENE := "res://src/scenes/map_xandy_content.tscn"
const SCREENSHOT_PATH := "user://xandy_forest_verification.png"


func _initialize() -> void:
	call_deferred("_verify")


func _verify() -> void:
	var packed_map := load(MAP_SCENE) as PackedScene
	if not packed_map:
		push_error("Falha ao carregar o mapa")
		quit(1)
		return
	var map := packed_map.instantiate() as Node3D
	root.add_child(map)
	await process_frame
	var forest := map.get_node_or_null("Arvores") as Node3D
	if not forest:
		push_error("Instancia Arvores nao encontrada")
		quit(1)
		return
	var batches: Array[MultiMeshInstance3D] = []
	_collect_batches(forest, batches)
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(forest, meshes)
	var total_instances := 0
	for batch in batches:
		if batch.multimesh:
			total_instances += batch.multimesh.instance_count
	print("[FOREST VERIFY] batches=%d instances=%d meshes=%d visible=%s" % [
		batches.size(), total_instances, meshes.size(), forest.visible
	])
	if meshes.is_empty() and (batches.is_empty() or total_instances <= 0):
		push_error("A floresta nao possui geometria visual")
		quit(1)
		return
	var camera := Camera3D.new()
	map.add_child(camera)
	camera.current = true
	camera.far = 5000.0
	var target := meshes[0].global_position + Vector3(0, 30, 0) if not meshes.is_empty() else forest.global_position + Vector3(0, 45, 0)
	camera.global_position = target + Vector3(110, 70, 150)
	camera.look_at(target, Vector3.UP)
	for frame in range(8):
		await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	var image := root.get_texture().get_image()
	var save_error := image.save_png(SCREENSHOT_PATH)
	if save_error != OK:
		push_error("Falha ao salvar screenshot: %s" % error_string(save_error))
		quit(1)
		return
	print("[FOREST VERIFY] screenshot=%s size=%s" % [SCREENSHOT_PATH, image.get_size()])
	quit(0)


func _collect_batches(node: Node, output: Array[MultiMeshInstance3D]) -> void:
	if node is MultiMeshInstance3D:
		output.append(node as MultiMeshInstance3D)
	for child in node.get_children():
		_collect_batches(child, output)


func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		output.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, output)
