@tool
class_name PG_SceneParser
extends RefCounted

## Parser de cenas (.tscn / .scn) usando SceneState API.
## Extrai nós, tipos, scripts anexados, cenas instanciadas,
## recursos externos e conexões de sinais — sem instanciar a cena.


## Resultado do parsing de uma cena.
class SceneParseResult extends RefCounted:
	var nodes : Array = []  ## Array[PG_GraphModel.GraphNode]
	var edges : Array = []  ## Array[PG_GraphModel.GraphEdge]


## Parseia uma cena e retorna nós + arestas para o grafo.
static func parse(scene_path: String) -> SceneParseResult:
	var result := SceneParseResult.new()

	# ── Nó raiz: a cena em si ──────────────────────────────────────────────
	var scene_id := "scene::%s" % scene_path
	result.nodes.append(PG_GraphModel.GraphNode.new(
		scene_id,
		"scene",
		scene_path.get_file(),
		scene_path,
		{}
	))

	# ── Parse via texto bruto para ext_resources ───────────────────────────
	# O SceneState não expõe diretamente os ext_resource como lista,
	# então extraímos os paths via regex no texto do arquivo.
	var ext_resources := _parse_ext_resources(scene_path)

	for ext in ext_resources:
		var ext_path : String = ext["path"]
		var ext_type : String = ext["type"]

		if ext_type == "Script":
			var script_id := "script::%s" % ext_path
			result.edges.append(PG_GraphModel.GraphEdge.new(
				scene_id, script_id, "has_script",
				{"ext_type": ext_type}
			))
		elif ext_type == "PackedScene":
			var inst_id := "scene::%s" % ext_path
			result.edges.append(PG_GraphModel.GraphEdge.new(
				scene_id, inst_id, "instances_scene",
				{"ext_type": ext_type}
			))
		else:
			# Texture2D, Material, AudioStream, etc.
			var res_id := "resource::%s" % ext_path
			result.nodes.append(PG_GraphModel.GraphNode.new(
				res_id, "resource", ext_path.get_file(), ext_path,
				{"resource_type": ext_type}
			))
			result.edges.append(PG_GraphModel.GraphEdge.new(
				scene_id, res_id, "uses_resource",
				{"ext_type": ext_type}
			))

	# ── Parse via SceneState para nós e conexões ──────────────────────────
	var packed : PackedScene = load(scene_path) as PackedScene
	if not packed:
		push_warning("[ProjectGraph] Não foi possível carregar cena: %s" % scene_path)
		return result

	var state := packed.get_state()

	# Nós da cena.
	for i in range(state.get_node_count()):
		var node_name := state.get_node_name(i)
		var node_type := state.get_node_type(i)
		var node_path := state.get_node_path(i)
		var node_id   := "node::%s::%s" % [scene_path, str(node_path)]

		var node_meta := {
			"godot_type": node_type,
			"node_path":  str(node_path),
		}

		# Verifica se este nó é uma instância de cena externa.
		var instance_scene := state.get_node_instance(i)
		if instance_scene:
			node_meta["instance_of"] = instance_scene.resource_path

		# Propriedades do nó (script, etc.).
		for p in range(state.get_node_property_count(i)):
			var prop_name  := state.get_node_property_name(i, p)
			var prop_value  = state.get_node_property_value(i, p)
			if prop_name == "script" and prop_value is Script:
				node_meta["script_path"] = prop_value.resource_path
				result.edges.append(PG_GraphModel.GraphEdge.new(
					node_id,
					"script::%s" % prop_value.resource_path,
					"has_script",
					{"node_path": str(node_path)}
				))

		result.nodes.append(PG_GraphModel.GraphNode.new(
			node_id, "node", node_name, scene_path, node_meta
		))
		result.edges.append(PG_GraphModel.GraphEdge.new(
			scene_id, node_id, "has_node", {}
		))

	# Conexões de sinais na cena.
	for i in range(state.get_connection_count()):
		var signal_name := state.get_connection_signal(i)
		var source_path := state.get_connection_source(i)
		var target_path := state.get_connection_target(i)
		var method_name := state.get_connection_method(i)

		var source_id := "node::%s::%s" % [scene_path, str(source_path)]
		var target_id := "node::%s::%s" % [scene_path, str(target_path)]

		result.edges.append(PG_GraphModel.GraphEdge.new(
			source_id, target_id, "scene_connects_signal",
			{
				"signal":  signal_name,
				"method":  method_name,
				"source_path": str(source_path),
				"target_path": str(target_path),
			}
		))

	return result


## Extrai ext_resources do texto bruto de um .tscn.
## Retorna Array[Dictionary] com keys: "id", "type", "uid", "path".
static func _parse_ext_resources(scene_path: String) -> Array:
	var resources := []

	var file := FileAccess.open(scene_path, FileAccess.READ)
	if not file:
		return resources

	# Regex: [ext_resource type="..." uid="..." path="..." id="..."]
	var regex := RegEx.new()
	regex.compile('\\[ext_resource\\s+type="([^"]*)"\\s+(?:uid="([^"]*)"\\s+)?path="([^"]*)"\\s+id="([^"]*)"\\]')

	while file.get_position() < file.get_length():
		var line := file.get_line()
		# Otimização: para de ler após a seção de recursos.
		if line.begins_with("[node") or line.begins_with("[sub_resource"):
			# Continua — sub_resources podem vir antes de ext_resources em format=4.
			if line.begins_with("[node"):
				break

		var m := regex.search(line)
		if m:
			resources.append({
				"type": m.get_string(1),
				"uid":  m.get_string(2),
				"path": m.get_string(3),
				"id":   m.get_string(4),
			})

	file.close()
	return resources
