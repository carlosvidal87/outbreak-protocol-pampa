@tool
class_name PG_Indexer
extends RefCounted

## Orquestrador de indexação do projeto.
## Varre o diretório res:// recursivamente, chama o parser apropriado
## para cada arquivo, e monta/atualiza o ProjectGraph.

## Extensões de arquivo que indexamos.
const INDEXABLE_EXTENSIONS := [".tscn", ".scn", ".gd"]

## Diretórios ignorados durante a varredura.
const SKIP_DIRS := ["addons/project_graph", ".godot", ".git", ".import"]


## Resultado de uma operação de indexação.
class IndexReport extends RefCounted:
	var files_scanned   : int = 0
	var files_changed   : int = 0
	var files_removed   : int = 0
	var nodes_total     : int = 0
	var edges_total     : int = 0
	var elapsed_ms      : float = 0.0
	var errors          : Array[String] = []

	func to_string_report() -> String:
		var lines := PackedStringArray([
			"╔══════════════════════════════════════╗",
			"║     ProjectGraph — Index Report      ║",
			"╠══════════════════════════════════════╣",
			"║ Arquivos varridos:  %4d             ║" % files_scanned,
			"║ Arquivos alterados: %4d             ║" % files_changed,
			"║ Arquivos removidos: %4d             ║" % files_removed,
			"║ Nós no grafo:      %4d             ║" % nodes_total,
			"║ Arestas no grafo:  %4d             ║" % edges_total,
			"║ Tempo total:     %7.1f ms          ║" % elapsed_ms,
		])
		if errors.size() > 0:
			lines.append("║ Erros:             %4d             ║" % errors.size())
		lines.append("╚══════════════════════════════════════╝")
		return "\n".join(lines)


## Indexação COMPLETA do projeto. Varre todos os arquivos.
static func full_index(graph: PG_GraphModel.ProjectGraph) -> IndexReport:
	var report := IndexReport.new()
	var start := Time.get_ticks_msec()

	# Limpa o grafo atual.
	graph.nodes.clear()
	graph.edges.clear()
	graph.file_hashes.clear()

	# Descobre todos os arquivos indexáveis.
	var files := _scan_directory("res://")
	report.files_scanned = files.size()

	for file_path in files:
		var err := _index_file(graph, file_path, report)
		if err != OK:
			report.errors.append("Erro ao indexar: %s" % file_path)
		report.files_changed += 1

	report.nodes_total = graph.nodes.size()
	report.edges_total = graph.edges.size()
	report.elapsed_ms  = Time.get_ticks_msec() - start

	# Salva o cache.
	PG_GraphStore.save_graph(graph)

	print("[ProjectGraph] Full index complete.")
	print(report.to_string_report())

	return report


## Indexação INCREMENTAL de um arquivo específico.
## Recalcula hash; se mudou, remove dados antigos e re-parseia.
static func incremental_index(graph: PG_GraphModel.ProjectGraph, file_path: String) -> IndexReport:
	var report := IndexReport.new()
	var start := Time.get_ticks_msec()
	report.files_scanned = 1

	# Verifica se o arquivo existe.
	if not FileAccess.file_exists(file_path):
		# Arquivo foi removido — limpa do grafo.
		graph.remove_by_file(file_path)
		graph.file_hashes.erase(file_path)
		report.files_removed = 1
		report.nodes_total = graph.nodes.size()
		report.edges_total = graph.edges.size()
		report.elapsed_ms  = Time.get_ticks_msec() - start
		PG_GraphStore.save_graph(graph)
		print("[ProjectGraph] Arquivo removido do índice: %s" % file_path)
		return report

	# Verifica se o arquivo é de uma extensão indexável.
	var ext := file_path.get_extension()
	if ("." + ext) not in INDEXABLE_EXTENSIONS:
		report.elapsed_ms = Time.get_ticks_msec() - start
		return report

	# Verifica se o arquivo realmente mudou via hash.
	var new_hash := PG_GraphStore.get_file_hash(file_path)
	var old_hash : String = graph.file_hashes.get(file_path, "")
	if new_hash == old_hash and not old_hash.is_empty():
		# Nenhuma mudança.
		report.nodes_total = graph.nodes.size()
		report.edges_total = graph.edges.size()
		report.elapsed_ms  = Time.get_ticks_msec() - start
		return report

	# Arquivo mudou — remove dados antigos e re-indexa.
	graph.remove_by_file(file_path)
	var err := _index_file(graph, file_path, report)
	if err != OK:
		report.errors.append("Erro ao reindexar: %s" % file_path)
	report.files_changed = 1

	report.nodes_total = graph.nodes.size()
	report.edges_total = graph.edges.size()
	report.elapsed_ms  = Time.get_ticks_msec() - start

	PG_GraphStore.save_graph(graph)

	print("[ProjectGraph] Reindexado: %s (%.1f ms, %d nós, %d arestas)" % [
		file_path, report.elapsed_ms, report.nodes_total, report.edges_total
	])

	return report


## Verifica se há arquivos novos ou removidos comparado ao cache.
## Retorna array de paths que precisam de reindexação.
static func detect_changes(graph: PG_GraphModel.ProjectGraph) -> Dictionary:
	var current_files := _scan_directory("res://")
	var current_set := {}
	for f in current_files:
		current_set[f] = true

	var cached_set := {}
	for f in graph.file_hashes:
		cached_set[f] = true

	var added   : Array[String] = []
	var removed : Array[String] = []
	var changed : Array[String] = []

	# Novos ou modificados.
	for f in current_files:
		if f not in cached_set:
			added.append(f)
		else:
			var new_hash := PG_GraphStore.get_file_hash(f)
			if new_hash != graph.file_hashes.get(f, ""):
				changed.append(f)

	# Removidos.
	for f in cached_set:
		if f not in current_set:
			removed.append(f)

	return {
		"added":   added,
		"removed": removed,
		"changed": changed,
	}


# ─── Internos ─────────────────────────────────────────────────────────────────

## Indexa um único arquivo e adiciona resultados ao grafo.
static func _index_file(graph: PG_GraphModel.ProjectGraph, file_path: String, report: IndexReport) -> Error:
	# Calcula e armazena hash.
	var hash := PG_GraphStore.get_file_hash(file_path)
	graph.file_hashes[file_path] = hash

	var ext := file_path.get_extension()

	if ext == "tscn" or ext == "scn":
		var parse_result := PG_SceneParser.parse(file_path)
		for node in parse_result.nodes:
			graph.add_node(node)
		for edge in parse_result.edges:
			graph.add_edge(edge)

	elif ext == "gd":
		var parse_result := PG_ScriptParser.parse(file_path)
		for node in parse_result.nodes:
			graph.add_node(node)
		for edge in parse_result.edges:
			graph.add_edge(edge)

	return OK


## Varre res:// recursivamente e retorna todos os caminhos indexáveis.
static func _scan_directory(path: String) -> Array[String]:
	var result : Array[String] = []

	var dir := DirAccess.open(path)
	if not dir:
		return result

	# Listar subdiretórios.
	dir.list_dir_begin()
	var item := dir.get_next()
	while item != "":
		if dir.current_is_dir():
			if not _should_skip(item, path):
				var sub_path := path.path_join(item)
				result.append_array(_scan_directory(sub_path))
		else:
			var ext := item.get_extension()
			if ("." + ext) in INDEXABLE_EXTENSIONS:
				result.append(path.path_join(item))
		item = dir.get_next()
	dir.list_dir_end()

	return result


## Verifica se um diretório deve ser ignorado.
static func _should_skip(dir_name: String, parent_path: String) -> bool:
	# Ignora diretórios ocultos.
	if dir_name.begins_with("."):
		return true
	# Ignora diretórios na lista de skip.
	var relative := parent_path.path_join(dir_name)
	# Normaliza: remove "res://" para comparação.
	var clean := relative.replace("res://", "")
	for skip in SKIP_DIRS:
		if clean.begins_with(skip) or clean == skip:
			return true
	return false
