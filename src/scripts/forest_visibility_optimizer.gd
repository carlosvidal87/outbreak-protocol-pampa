extends Node3D

@export_category("Forest Optimization")
@export_range(200.0, 3000.0, 25.0) var tree_visibility_distance := 1200.0
@export_range(0.0, 300.0, 10.0) var visibility_fade_margin := 120.0
@export var disable_distant_shadows := false


func _ready() -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(self, meshes)
	for mesh in meshes:
		mesh.visibility_range_end = tree_visibility_distance
		mesh.visibility_range_end_margin = visibility_fade_margin
		mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if disable_distant_shadows:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	print("[FOREST] %d malhas visuais ativas com distancia %.0fm." % [
		meshes.size(), tree_visibility_distance
	])


func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		output.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, output)
