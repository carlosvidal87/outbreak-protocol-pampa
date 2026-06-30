@tool
extends EditorPlugin

## ProjectGraph — EditorPlugin principal.
## Registra o painel bottom-dock, conecta sinais do editor para
## reindexação automática, e expõe o grafo para consultas.

var _graph : PG_GraphModel.ProjectGraph = null
var _panel : Control = null
var _panel_button : Button = null  ## Retornado por add_control_to_bottom_panel.


func _get_plugin_name() -> String:
	return "ProjectGraph"


func _enter_tree() -> void:
	print("[ProjectGraph] Plugin ativado.")

	# Carrega grafo do cache ou cria um novo.
	_graph = PG_GraphStore.load_graph()
	if _graph == null:
		_graph = PG_GraphModel.ProjectGraph.new()
		print("[ProjectGraph] Nenhum cache encontrado. Use 'Reindex All' para indexar o projeto.")
	else:
		print("[ProjectGraph] Cache carregado: %d nós, %d arestas." % [
			_graph.nodes.size(), _graph.edges.size()
		])

	# Instancia a UI do painel.
	var panel_scene := preload("res://addons/project_graph/ui/graph_panel.tscn")
	_panel = panel_scene.instantiate()
	_panel.graph = _graph

	# Registra no bottom dock do editor.
	_panel_button = add_control_to_bottom_panel(_panel, "ProjectGraph")

	# Conecta sinais do editor.
	resource_saved.connect(_on_resource_saved)

	var efs := EditorInterface.get_resource_filesystem()
	if efs:
		efs.filesystem_changed.connect(_on_filesystem_changed)

	# Conecta sinal da UI.
	_panel.reindex_requested.connect(_on_reindex_requested)

	# Atualiza stats na UI.
	_panel.update_stats()
	if _graph.nodes.size() > 0:
		_panel.set_status("ProjectGraph — Cache carregado. %d nós, %d arestas." % [
			_graph.nodes.size(), _graph.edges.size()
		])


func _exit_tree() -> void:
	print("[ProjectGraph] Plugin desativado.")

	# Salva o grafo atual.
	if _graph:
		PG_GraphStore.save_graph(_graph)

	# Remove painel do editor.
	if _panel:
		remove_control_from_bottom_panel(_panel)
		_panel.queue_free()
		_panel = null

	# Desconecta sinais.
	if resource_saved.is_connected(_on_resource_saved):
		resource_saved.disconnect(_on_resource_saved)

	var efs := EditorInterface.get_resource_filesystem()
	if efs and efs.filesystem_changed.is_connected(_on_filesystem_changed):
		efs.filesystem_changed.disconnect(_on_filesystem_changed)


# ─── Handlers de Eventos ──────────────────────────────────────────────────────

## Chamado quando um recurso é salvo no editor.
func _on_resource_saved(resource: Resource) -> void:
	if not _graph:
		return

	var path := resource.resource_path
	if path.is_empty():
		return

	# Ignora arquivos do próprio plugin.
	if path.begins_with("res://addons/project_graph"):
		return

	# Verifica se é um tipo indexável.
	var ext := path.get_extension()
	if ext in ["tscn", "scn", "gd"]:
		print("[ProjectGraph] Recurso salvo, reindexando: %s" % path)
		var report := PG_Indexer.incremental_index(_graph, path)
		_panel.graph = _graph
		_panel.update_stats()
		_panel.set_status("Reindexado: %s (%.1f ms)" % [path.get_file(), report.elapsed_ms])


## Chamado quando o filesystem do editor muda (arquivos adicionados/removidos).
func _on_filesystem_changed() -> void:
	if not _graph:
		return

	var changes := PG_Indexer.detect_changes(_graph)
	var added   : Array = changes.get("added", [])
	var removed : Array = changes.get("removed", [])
	var changed : Array = changes.get("changed", [])

	var total_changes := added.size() + removed.size() + changed.size()
	if total_changes == 0:
		return

	print("[ProjectGraph] Mudanças detectadas: +%d -%d ~%d" % [added.size(), removed.size(), changed.size()])

	# Para muitas mudanças, faz full reindex.
	if total_changes > 20:
		_on_reindex_requested()
		return

	# Processa mudanças incrementalmente.
	for path in removed:
		_graph.remove_by_file(path)
		_graph.file_hashes.erase(path)

	for path in added + changed:
		PG_Indexer.incremental_index(_graph, path)

	_panel.graph = _graph
	_panel.update_stats()
	_panel.set_status("Atualizado: +%d -%d ~%d arquivos." % [added.size(), removed.size(), changed.size()])


## Chamado quando o botão "Reindex All" é pressionado na UI.
func _on_reindex_requested() -> void:
	_panel.set_status("Indexando projeto...")
	var report := PG_Indexer.full_index(_graph)
	_panel.graph = _graph
	_panel.update_stats()
	_panel.set_status(
		"Indexação completa: %d arquivos, %d nós, %d arestas (%.1f ms)" % [
			report.files_scanned, report.nodes_total, report.edges_total, report.elapsed_ms
		]
	)
