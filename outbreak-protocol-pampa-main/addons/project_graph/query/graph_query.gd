@tool
class_name PG_GraphQuery
extends RefCounted

## Camada de consulta sobre o ProjectGraph.
## Todos os métodos são estáticos e recebem o grafo como primeiro argumento.


## Encontra todos os arquivos que DEPENDEM de um dado arquivo.
## Ex: "Quais scripts/cenas dependem de character.tscn?"
static func find_dependents(graph: PG_GraphModel.ProjectGraph, file_path: String) -> Array[Dictionary]:
	var results : Array[Dictionary] = []
	var target_ids := _get_ids_for_file(graph, file_path)

	for edge in graph.edges:
		if edge.to_id in target_ids:
			var from_node := graph.get_node_by_id(edge.from_id)
			if from_node and from_node.file_path != file_path:
				results.append({
					"file":     from_node.file_path,
					"node_id":  from_node.id,
					"node_name": from_node.name,
					"relation": edge.relation,
					"metadata": edge.metadata,
				})

	return _deduplicate_results(results)


## Encontra todas as dependências de um dado arquivo.
## Ex: "De quais arquivos character.gd depende?"
static func find_dependencies(graph: PG_GraphModel.ProjectGraph, file_path: String) -> Array[Dictionary]:
	var results : Array[Dictionary] = []
	var source_ids := _get_ids_for_file(graph, file_path)

	for edge in graph.edges:
		if edge.from_id in source_ids:
			var to_node := graph.get_node_by_id(edge.to_id)
			if to_node and to_node.file_path != file_path:
				results.append({
					"file":     to_node.file_path,
					"node_id":  to_node.id,
					"node_name": to_node.name,
					"relation": edge.relation,
					"metadata": edge.metadata,
				})

	return _deduplicate_results(results)


## Encontra onde um sinal é conectado/emitido.
## Ex: "Onde zombie_died é conectado?"
static func find_signal_connections(graph: PG_GraphModel.ProjectGraph, signal_name: String) -> Array[Dictionary]:
	var results : Array[Dictionary] = []

	for edge in graph.edges:
		var is_signal_edge := edge.relation in [
			"connects_signal", "emits_signal", "scene_connects_signal", "has_signal"
		]
		if not is_signal_edge:
			continue

		# Checa se o nome do sinal aparece no ID do target ou nos metadados.
		var matches := false
		if edge.to_id.ends_with("::%s" % signal_name):
			matches = true
		elif edge.metadata.get("signal", "") == signal_name:
			matches = true
		elif edge.to_id.contains(signal_name):
			matches = true

		if matches:
			var from_node := graph.get_node_by_id(edge.from_id)
			var to_node   := graph.get_node_by_id(edge.to_id)
			results.append({
				"from_file":   from_node.file_path if from_node else "",
				"from_id":     edge.from_id,
				"to_id":       edge.to_id,
				"relation":    edge.relation,
				"signal_name": signal_name,
				"metadata":    edge.metadata,
			})

	return results


## Encontra quais scripts chamam ou referenciam uma função específica.
## Nota: Limitado a matches baseados em nome de função (sem type-checking).
static func find_function_callers(graph: PG_GraphModel.ProjectGraph, func_name: String) -> Array[Dictionary]:
	var results : Array[Dictionary] = []

	# Encontra o nó da função.
	var func_nodes : Array = []
	for id in graph.nodes:
		var node := graph.nodes[id] as PG_GraphModel.GraphNode
		if node.type == "function" and node.name == func_name:
			func_nodes.append(node)

	# Busca arestas que apontam para essa função.
	for fn in func_nodes:
		for edge in graph.edges:
			if edge.to_id == fn.id and edge.relation == "calls_function":
				var caller := graph.get_node_by_id(edge.from_id)
				results.append({
					"caller_file": caller.file_path if caller else "",
					"caller_id":   edge.from_id,
					"function":    func_name,
					"defined_in":  fn.file_path,
					"metadata":    edge.metadata,
				})

	# Busca em conexões de sinais onde o método chamado é func_name.
	for edge in graph.edges:
		if edge.relation == "scene_connects_signal":
			if edge.metadata.get("method", "") == func_name:
				var from_node := graph.get_node_by_id(edge.from_id)
				results.append({
					"caller_file": from_node.file_path if from_node else "",
					"caller_id":   edge.from_id,
					"function":    func_name,
					"defined_in":  "(via signal connection)",
					"relation":    "scene_connects_signal",
					"metadata":    edge.metadata,
				})

	return results


## Análise de IMPACTO transitiva: quais arquivos serão afetados
## se alterar um dado arquivo? Faz BFS nos dependentes.
static func find_impact(graph: PG_GraphModel.ProjectGraph, file_path: String) -> Array[String]:
	var impacted : Dictionary = {}  # file_path -> true
	var queue : Array[String] = [file_path]
	var visited : Dictionary = {}

	while queue.size() > 0:
		var current := queue.pop_front() as String
		if current in visited:
			continue
		visited[current] = true

		var dependents := find_dependents(graph, current)
		for dep in dependents:
			var dep_file : String = dep.get("file", "")
			if dep_file.is_empty() or dep_file in visited:
				continue
			impacted[dep_file] = true
			queue.append(dep_file)

	var result : Array[String] = []
	for f in impacted:
		result.append(f)
	result.sort()
	return result


## Busca nós do grafo por tipo (scene, script, function, etc.).
static func find_nodes_by_type(graph: PG_GraphModel.ProjectGraph, type: String) -> Array[Dictionary]:
	var results : Array[Dictionary] = []
	for id in graph.nodes:
		var node := graph.nodes[id] as PG_GraphModel.GraphNode
		if node.type == type:
			results.append(node.to_dict())
	return results


## Busca nós por nome (substring, case-insensitive).
static func find_nodes_by_name(graph: PG_GraphModel.ProjectGraph, pattern: String) -> Array[Dictionary]:
	var results : Array[Dictionary] = []
	var lower_pattern := pattern.to_lower()
	for id in graph.nodes:
		var node := graph.nodes[id] as PG_GraphModel.GraphNode
		if node.name.to_lower().contains(lower_pattern) or node.id.to_lower().contains(lower_pattern):
			results.append(node.to_dict())
	return results


## BFS para encontrar caminhos de dependência entre dois IDs ou file_paths.
static func find_path(graph: PG_GraphModel.ProjectGraph, from_str: String, to_str: String) -> Array[Array]:
	# Resolve IDs.
	var from_ids := _resolve_ids(graph, from_str)
	var to_ids   := _resolve_ids(graph, to_str)

	if from_ids.is_empty() or to_ids.is_empty():
		return []

	# Build adjacency list (bidirectional).
	var adj : Dictionary = {}
	for edge in graph.edges:
		if edge.from_id not in adj:
			adj[edge.from_id] = []
		adj[edge.from_id].append({"to": edge.to_id, "relation": edge.relation})

	# BFS de cada from_id.
	var all_paths : Array[Array] = []
	for start_id in from_ids:
		var queue : Array = [[start_id]]  # Array de paths (cada path = Array[String])
		var visited : Dictionary = {}

		while queue.size() > 0 and all_paths.size() < 5:  # Limita a 5 caminhos.
			var path : Array = queue.pop_front()
			var current : String = path[path.size() - 1]

			if current in to_ids:
				all_paths.append(path.duplicate())
				continue

			if current in visited:
				continue
			visited[current] = true

			if current in adj:
				for neighbor in adj[current]:
					if neighbor["to"] not in visited:
						var new_path := path.duplicate()
						new_path.append(neighbor["to"])
						queue.append(new_path)

	return all_paths


## Gera um resumo completo de um arquivo: nós, funções, sinais, deps.
static func get_file_summary(graph: PG_GraphModel.ProjectGraph, file_path: String) -> Dictionary:
	var file_nodes := graph.get_nodes_by_file(file_path)

	var functions   : Array = []
	var signals     : Array = []
	var variables   : Array = []
	var constants   : Array = []
	var scene_nodes : Array = []
	var extends_val := ""
	var class_val   := ""

	for node in file_nodes:
		var n := node as PG_GraphModel.GraphNode
		match n.type:
			"function":   functions.append(n.to_dict())
			"signal_def": signals.append(n.to_dict())
			"variable":   variables.append(n.to_dict())
			"constant":   constants.append(n.to_dict())
			"node":       scene_nodes.append(n.to_dict())
			"script":
				extends_val = n.metadata.get("extends", "")
				class_val   = n.metadata.get("class_name", "")

	var deps := find_dependencies(graph, file_path)
	var dependents := find_dependents(graph, file_path)

	return {
		"file_path":    file_path,
		"extends":      extends_val,
		"class_name":   class_val,
		"functions":    functions,
		"signals":      signals,
		"variables":    variables,
		"constants":    constants,
		"scene_nodes":  scene_nodes,
		"dependencies": deps,
		"dependents":   dependents,
	}


## Estatísticas gerais do grafo.
static func get_stats(graph: PG_GraphModel.ProjectGraph) -> Dictionary:
	return graph.get_stats()


# ─── Helpers internos ──────────────────────────────────────────────────────────

## Retorna todos os IDs de nós associados a um file_path.
static func _get_ids_for_file(graph: PG_GraphModel.ProjectGraph, file_path: String) -> Array:
	var ids : Array = []
	for id in graph.nodes:
		if graph.nodes[id].file_path == file_path:
			ids.append(id)
	# Também inclui IDs "padrão" derivados do path.
	ids.append("scene::%s" % file_path)
	ids.append("script::%s" % file_path)
	ids.append("resource::%s" % file_path)
	return ids


## Resolve uma string (pode ser file_path ou ID) para IDs concretos no grafo.
static func _resolve_ids(graph: PG_GraphModel.ProjectGraph, input: String) -> Array:
	# Se é um ID exato existente.
	if input in graph.nodes:
		return [input]
	# Se é um file_path.
	var ids := _get_ids_for_file(graph, input)
	var existing : Array = []
	for id in ids:
		if id in graph.nodes:
			existing.append(id)
	if existing.size() > 0:
		return existing
	# Busca por substring.
	var matches : Array = []
	for id in graph.nodes:
		if id.contains(input):
			matches.append(id)
	return matches


## Remove duplicatas de resultados (por file_path).
static func _deduplicate_results(results: Array[Dictionary]) -> Array[Dictionary]:
	var seen : Dictionary = {}
	var deduped : Array[Dictionary] = []
	for r in results:
		var key := "%s::%s" % [r.get("file", r.get("from_file", "")), r.get("relation", "")]
		if key not in seen:
			seen[key] = true
			deduped.append(r)
	return deduped
