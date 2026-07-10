@tool
class_name PG_GraphModel
extends RefCounted

## Modelo de dados central do ProjectGraph.
## Define GraphNode, GraphEdge e o container ProjectGraph.
## Todas as entidades usam IDs string no formato "tipo::caminho::nome".


# ─── Tipos de nó ───────────────────────────────────────────────────────────────

enum NodeType {
	SCENE,
	SCRIPT,
	RESOURCE,
	NODE,
	FUNCTION,
	SIGNAL_DEF,
	VARIABLE,
	CONSTANT,
	CLASS,
	GROUP,
}

const NODE_TYPE_NAMES := {
	NodeType.SCENE:      "scene",
	NodeType.SCRIPT:     "script",
	NodeType.RESOURCE:   "resource",
	NodeType.NODE:       "node",
	NodeType.FUNCTION:   "function",
	NodeType.SIGNAL_DEF: "signal_def",
	NodeType.VARIABLE:   "variable",
	NodeType.CONSTANT:   "constant",
	NodeType.CLASS:      "class",
	NodeType.GROUP:      "group",
}

const NODE_TYPE_FROM_NAME := {
	"scene":      NodeType.SCENE,
	"script":     NodeType.SCRIPT,
	"resource":   NodeType.RESOURCE,
	"node":       NodeType.NODE,
	"function":   NodeType.FUNCTION,
	"signal_def": NodeType.SIGNAL_DEF,
	"variable":   NodeType.VARIABLE,
	"constant":   NodeType.CONSTANT,
	"class":      NodeType.CLASS,
	"group":      NodeType.GROUP,
}


# ─── Tipos de relação (aresta) ─────────────────────────────────────────────────

enum Relation {
	HAS_SCRIPT,
	HAS_NODE,
	EXTENDS,
	PRELOADS,
	CALLS_FUNCTION,
	EMITS_SIGNAL,
	CONNECTS_SIGNAL,
	EXPORTS_VAR,
	USES_RESOURCE,
	INSTANCES_SCENE,
	BELONGS_TO_GROUP,
	HAS_FUNCTION,
	HAS_SIGNAL,
	HAS_VARIABLE,
	HAS_CONSTANT,
	SCENE_CONNECTS_SIGNAL,
}

const RELATION_NAMES := {
	Relation.HAS_SCRIPT:             "has_script",
	Relation.HAS_NODE:               "has_node",
	Relation.EXTENDS:                "extends",
	Relation.PRELOADS:               "preloads",
	Relation.CALLS_FUNCTION:         "calls_function",
	Relation.EMITS_SIGNAL:           "emits_signal",
	Relation.CONNECTS_SIGNAL:        "connects_signal",
	Relation.EXPORTS_VAR:            "exports_var",
	Relation.USES_RESOURCE:          "uses_resource",
	Relation.INSTANCES_SCENE:        "instances_scene",
	Relation.BELONGS_TO_GROUP:       "belongs_to_group",
	Relation.HAS_FUNCTION:           "has_function",
	Relation.HAS_SIGNAL:             "has_signal",
	Relation.HAS_VARIABLE:           "has_variable",
	Relation.HAS_CONSTANT:           "has_constant",
	Relation.SCENE_CONNECTS_SIGNAL:  "scene_connects_signal",
}

const RELATION_FROM_NAME := {
	"has_script":             Relation.HAS_SCRIPT,
	"has_node":               Relation.HAS_NODE,
	"extends":                Relation.EXTENDS,
	"preloads":               Relation.PRELOADS,
	"calls_function":         Relation.CALLS_FUNCTION,
	"emits_signal":           Relation.EMITS_SIGNAL,
	"connects_signal":        Relation.CONNECTS_SIGNAL,
	"exports_var":            Relation.EXPORTS_VAR,
	"uses_resource":          Relation.USES_RESOURCE,
	"instances_scene":        Relation.INSTANCES_SCENE,
	"belongs_to_group":       Relation.BELONGS_TO_GROUP,
	"has_function":           Relation.HAS_FUNCTION,
	"has_signal":             Relation.HAS_SIGNAL,
	"has_variable":           Relation.HAS_VARIABLE,
	"has_constant":           Relation.HAS_CONSTANT,
	"scene_connects_signal":  Relation.SCENE_CONNECTS_SIGNAL,
}


# ─── GraphNode ─────────────────────────────────────────────────────────────────

## Representa qualquer entidade do projeto: cena, script, nó, função, sinal, etc.
class GraphNode extends RefCounted:
	var id        : String     ## Ex: "scene::res://src/scenes/character.tscn"
	var type      : String     ## Ex: "scene", "function", "signal_def"
	var name      : String     ## Nome legível
	var file_path : String     ## Caminho do arquivo de origem
	var metadata  : Dictionary ## Dados extras (tipo Godot, valor export, linha, etc.)

	func _init(p_id := "", p_type := "", p_name := "", p_file := "", p_meta := {}) -> void:
		id        = p_id
		type      = p_type
		name      = p_name
		file_path = p_file
		metadata  = p_meta

	func to_dict() -> Dictionary:
		return {
			"id":        id,
			"type":      type,
			"name":      name,
			"file_path": file_path,
			"metadata":  metadata,
		}

	static func from_dict(d: Dictionary) -> GraphNode:
		return GraphNode.new(
			d.get("id", ""),
			d.get("type", ""),
			d.get("name", ""),
			d.get("file_path", ""),
			d.get("metadata", {}),
		)


# ─── GraphEdge ─────────────────────────────────────────────────────────────────

## Relação direcionada entre dois nós do grafo.
class GraphEdge extends RefCounted:
	var from_id  : String     ## ID do nó de origem
	var to_id    : String     ## ID do nó destino
	var relation : String     ## Tipo da relação (ex: "has_script", "preloads")
	var metadata : Dictionary ## Dados extras (linha do código, etc.)

	func _init(p_from := "", p_to := "", p_rel := "", p_meta := {}) -> void:
		from_id  = p_from
		to_id    = p_to
		relation = p_rel
		metadata = p_meta

	func to_dict() -> Dictionary:
		return {
			"from_id":  from_id,
			"to_id":    to_id,
			"relation": relation,
			"metadata": metadata,
		}

	static func from_dict(d: Dictionary) -> GraphEdge:
		return GraphEdge.new(
			d.get("from_id", ""),
			d.get("to_id", ""),
			d.get("relation", ""),
			d.get("metadata", {}),
		)


# ─── ProjectGraph (container principal) ────────────────────────────────────────

## Container principal que armazena todos os nós e arestas do projeto.
class ProjectGraph extends RefCounted:
	var nodes       : Dictionary = {}   ## id -> GraphNode
	var edges       : Array      = []   ## Array[GraphEdge]
	var file_hashes : Dictionary = {}   ## file_path -> md5 hash string

	## Adiciona um nó ao grafo. Se já existir, atualiza.
	func add_node(node: GraphNode) -> void:
		nodes[node.id] = node

	## Adiciona uma aresta ao grafo (sem duplicatas exatas).
	func add_edge(edge: GraphEdge) -> void:
		for e in edges:
			if e.from_id == edge.from_id and e.to_id == edge.to_id and e.relation == edge.relation:
				return
		edges.append(edge)

	## Remove todos os nós e arestas associados a um arquivo.
	func remove_by_file(file_path: String) -> void:
		var ids_to_remove : Array[String] = []
		for id in nodes:
			if nodes[id].file_path == file_path:
				ids_to_remove.append(id)
		for id in ids_to_remove:
			nodes.erase(id)
		# Remove arestas que referenciam nós removidos.
		var new_edges : Array = []
		for e in edges:
			if e.from_id not in ids_to_remove and e.to_id not in ids_to_remove:
				new_edges.append(e)
		edges = new_edges

	## Busca um nó por ID.
	func get_node_by_id(id: String) -> GraphNode:
		return nodes.get(id)

	## Busca todas as arestas saindo de um nó.
	func get_edges_from(id: String) -> Array:
		var result : Array = []
		for e in edges:
			if e.from_id == id:
				result.append(e)
		return result

	## Busca todas as arestas chegando em um nó.
	func get_edges_to(id: String) -> Array:
		var result : Array = []
		for e in edges:
			if e.to_id == id:
				result.append(e)
		return result

	## Busca arestas por tipo de relação.
	func get_edges_by_relation(relation: String) -> Array:
		var result : Array = []
		for e in edges:
			if e.relation == relation:
				result.append(e)
		return result

	## Busca nós por tipo.
	func get_nodes_by_type(type: String) -> Array:
		var result : Array = []
		for id in nodes:
			if nodes[id].type == type:
				result.append(nodes[id])
		return result

	## Busca nós por file_path.
	func get_nodes_by_file(file_path: String) -> Array:
		var result : Array = []
		for id in nodes:
			if nodes[id].file_path == file_path:
				result.append(nodes[id])
		return result

	## Serializa o grafo inteiro para Dictionary (pronto para JSON).
	func to_dict() -> Dictionary:
		var nodes_arr := []
		for id in nodes:
			nodes_arr.append(nodes[id].to_dict())
		var edges_arr := []
		for e in edges:
			edges_arr.append(e.to_dict())
		return {
			"version":     1,
			"nodes":       nodes_arr,
			"edges":       edges_arr,
			"file_hashes": file_hashes,
		}

	## Reconstrói o grafo a partir de um Dictionary (vindo de JSON).
	static func from_dict(d: Dictionary) -> ProjectGraph:
		var pg := ProjectGraph.new()
		for nd in d.get("nodes", []):
			var node := GraphNode.from_dict(nd)
			pg.nodes[node.id] = node
		for ed in d.get("edges", []):
			pg.edges.append(GraphEdge.from_dict(ed))
		pg.file_hashes = d.get("file_hashes", {})
		return pg

	func get_stats() -> Dictionary:
		var type_counts := {}
		for id in nodes:
			var t : String = nodes[id].type
			type_counts[t] = type_counts.get(t, 0) + 1
		var rel_counts := {}
		for e in edges:
			rel_counts[e.relation] = rel_counts.get(e.relation, 0) + 1
		return {
			"total_nodes":    nodes.size(),
			"total_edges":    edges.size(),
			"total_files":    file_hashes.size(),
			"nodes_by_type":  type_counts,
			"edges_by_relation": rel_counts,
		}
