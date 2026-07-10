@tool
extends VBoxContainer

## Lógica da UI do painel bottom-dock do ProjectGraph.
## Conecta botões, executa queries via PG_GraphQuery e popula a Tree.

# ─── Referências à UI ──────────────────────────────────────────────────────────

var _reindex_btn    : Button
var _status_label   : Label
var _stats_label    : Label
var _query_type     : OptionButton
var _query_input    : LineEdit
var _query_btn      : Button
var _result_tree    : Tree
var _detail_panel   : RichTextLabel

# ─── Referência ao grafo (injetada pelo plugin) ───────────────────────────────

var graph : PG_GraphModel.ProjectGraph = null

# ─── Tipos de consulta ────────────────────────────────────────────────────────

enum QueryType {
	FILE_SUMMARY,
	DEPENDENTS,
	DEPENDENCIES,
	IMPACT,
	SIGNAL_CONNECTIONS,
	FUNCTION_CALLERS,
	SEARCH_BY_NAME,
	SEARCH_BY_TYPE,
	FIND_PATH,
	STATS,
}

const QUERY_LABELS := [
	"Resumo do arquivo",
	"Dependentes (quem usa)",
	"Dependências (quem ele usa)",
	"Impacto (transitivo)",
	"Conexões de sinal",
	"Chamadores de função",
	"Busca por nome",
	"Busca por tipo",
	"Caminho entre A → B",
	"Estatísticas gerais",
]

const QUERY_PLACEHOLDERS := [
	"res://src/scripts/character.gd",
	"res://src/scenes/zombie.tscn",
	"res://src/scripts/character.gd",
	"res://src/scenes/zombie.tscn",
	"zombie_died",
	"take_damage",
	"zombie",
	"function | signal_def | scene | script | variable | group",
	"res://src/scripts/character.gd -> res://src/scripts/spawner.gd",
	"(sem entrada necessária)",
]


func _ready() -> void:
	_reindex_btn  = $Toolbar/ReindexButton
	_status_label = $Toolbar/StatusLabel
	_stats_label  = $Toolbar/StatsLabel
	_query_type   = $QueryBar/QueryTypeOption
	_query_input  = $QueryBar/QueryInput
	_query_btn    = $QueryBar/QueryButton
	_result_tree  = $ContentSplit/ResultTree
	_detail_panel = $ContentSplit/DetailPanel

	# Popula dropdown de tipos de consulta.
	_query_type.clear()
	for i in range(QUERY_LABELS.size()):
		_query_type.add_item(QUERY_LABELS[i], i)

	# Conecta sinais.
	_reindex_btn.pressed.connect(_on_reindex_pressed)
	_query_btn.pressed.connect(_on_query_pressed)
	_query_input.text_submitted.connect(_on_query_submitted)
	_query_type.item_selected.connect(_on_query_type_changed)
	_result_tree.item_selected.connect(_on_tree_item_selected)

	_update_placeholder()


func _on_query_type_changed(_idx: int) -> void:
	_update_placeholder()


func _update_placeholder() -> void:
	var idx := _query_type.selected
	if idx >= 0 and idx < QUERY_PLACEHOLDERS.size():
		_query_input.placeholder_text = QUERY_PLACEHOLDERS[idx]


func update_stats() -> void:
	if not graph:
		_stats_label.text = "Sem dados"
		return
	var stats := PG_GraphQuery.get_stats(graph)
	_stats_label.text = "%d nós | %d arestas | %d arquivos" % [
		stats.get("total_nodes", 0),
		stats.get("total_edges", 0),
		stats.get("total_files", 0),
	]


func set_status(text: String) -> void:
	if _status_label:
		_status_label.text = text


# ─── Reindex ───────────────────────────────────────────────────────────────────

signal reindex_requested

func _on_reindex_pressed() -> void:
	reindex_requested.emit()


# ─── Execução de Consulta ──────────────────────────────────────────────────────

func _on_query_submitted(_text: String) -> void:
	_execute_query()

func _on_query_pressed() -> void:
	_execute_query()


func _execute_query() -> void:
	if not graph:
		set_status("Erro: grafo não carregado. Clique em Reindex All.")
		return

	var query_text := _query_input.text.strip_edges()
	var query_idx  := _query_type.selected

	_result_tree.clear()
	_detail_panel.text = ""
	var root := _result_tree.create_item()

	match query_idx:
		QueryType.FILE_SUMMARY:
			_query_file_summary(root, query_text)
		QueryType.DEPENDENTS:
			_query_dependents(root, query_text)
		QueryType.DEPENDENCIES:
			_query_dependencies(root, query_text)
		QueryType.IMPACT:
			_query_impact(root, query_text)
		QueryType.SIGNAL_CONNECTIONS:
			_query_signals(root, query_text)
		QueryType.FUNCTION_CALLERS:
			_query_function_callers(root, query_text)
		QueryType.SEARCH_BY_NAME:
			_query_search_name(root, query_text)
		QueryType.SEARCH_BY_TYPE:
			_query_search_type(root, query_text)
		QueryType.FIND_PATH:
			_query_find_path(root, query_text)
		QueryType.STATS:
			_query_stats(root)

	set_status("Consulta concluída.")


func _query_file_summary(root: TreeItem, file_path: String) -> void:
	var summary := PG_GraphQuery.get_file_summary(graph, file_path)
	if summary.get("functions", []).is_empty() and summary.get("scene_nodes", []).is_empty():
		_add_tree_item(root, "⚠ Nenhum dado encontrado para: %s" % file_path)
		return

	if not summary["extends"].is_empty():
		_add_tree_item(root, "📦 extends: %s" % summary["extends"])
	if not summary["class_name"].is_empty():
		_add_tree_item(root, "🏷️ class_name: %s" % summary["class_name"])

	if summary["functions"].size() > 0:
		var funcs_item := _add_tree_item(root, "⚙ Funções (%d)" % summary["functions"].size())
		for f in summary["functions"]:
			_add_tree_item(funcs_item, "%s(%s)  [L%s]" % [f["name"], f["metadata"].get("args", ""), str(f["metadata"].get("line", "?"))], f)

	if summary["signals"].size() > 0:
		var sigs_item := _add_tree_item(root, "📡 Sinais (%d)" % summary["signals"].size())
		for s in summary["signals"]:
			_add_tree_item(sigs_item, s["name"], s)

	if summary["variables"].size() > 0:
		var vars_item := _add_tree_item(root, "📝 Variáveis (%d)" % summary["variables"].size())
		for v in summary["variables"]:
			var prefix := "⬆" if v["metadata"].get("exported", false) else "•"
			_add_tree_item(vars_item, "%s %s  [L%s]" % [prefix, v["name"], str(v["metadata"].get("line", "?"))], v)

	if summary["constants"].size() > 0:
		var consts_item := _add_tree_item(root, "🔒 Constantes (%d)" % summary["constants"].size())
		for c in summary["constants"]:
			_add_tree_item(consts_item, c["name"], c)

	if summary["scene_nodes"].size() > 0:
		var nodes_item := _add_tree_item(root, "🌳 Nós da cena (%d)" % summary["scene_nodes"].size())
		for n in summary["scene_nodes"]:
			_add_tree_item(nodes_item, "%s [%s]" % [n["name"], n["metadata"].get("godot_type", "?")], n)

	if summary["dependencies"].size() > 0:
		var deps_item := _add_tree_item(root, "⬇ Dependências (%d)" % summary["dependencies"].size())
		for d in summary["dependencies"]:
			_add_tree_item(deps_item, "%s (%s)" % [d.get("file", "?"), d.get("relation", "?")])

	if summary["dependents"].size() > 0:
		var depts_item := _add_tree_item(root, "⬆ Dependentes (%d)" % summary["dependents"].size())
		for d in summary["dependents"]:
			_add_tree_item(depts_item, "%s (%s)" % [d.get("file", "?"), d.get("relation", "?")])


func _query_dependents(root: TreeItem, file_path: String) -> void:
	var results := PG_GraphQuery.find_dependents(graph, file_path)
	if results.is_empty():
		_add_tree_item(root, "Nenhum dependente encontrado para: %s" % file_path)
		return
	_add_tree_item(root, "📋 %d dependentes de %s:" % [results.size(), file_path.get_file()])
	for r in results:
		_add_tree_item(root, "  %s — %s" % [r.get("file", "?"), r.get("relation", "?")])


func _query_dependencies(root: TreeItem, file_path: String) -> void:
	var results := PG_GraphQuery.find_dependencies(graph, file_path)
	if results.is_empty():
		_add_tree_item(root, "Nenhuma dependência encontrada para: %s" % file_path)
		return
	_add_tree_item(root, "📋 %d dependências de %s:" % [results.size(), file_path.get_file()])
	for r in results:
		_add_tree_item(root, "  %s — %s" % [r.get("file", "?"), r.get("relation", "?")])


func _query_impact(root: TreeItem, file_path: String) -> void:
	var results := PG_GraphQuery.find_impact(graph, file_path)
	if results.is_empty():
		_add_tree_item(root, "Nenhum impacto detectado para: %s" % file_path)
		return
	_add_tree_item(root, "💥 %d arquivos impactados por %s:" % [results.size(), file_path.get_file()])
	for r in results:
		_add_tree_item(root, "  %s" % r)


func _query_signals(root: TreeItem, signal_name: String) -> void:
	var results := PG_GraphQuery.find_signal_connections(graph, signal_name)
	if results.is_empty():
		_add_tree_item(root, "Nenhuma conexão encontrada para sinal: %s" % signal_name)
		return
	_add_tree_item(root, "📡 %d conexões de '%s':" % [results.size(), signal_name])
	for r in results:
		_add_tree_item(root, "  [%s] %s → %s" % [r.get("relation", "?"), r.get("from_id", "?").get_file(), r.get("to_id", "?")])


func _query_function_callers(root: TreeItem, func_name: String) -> void:
	var results := PG_GraphQuery.find_function_callers(graph, func_name)
	if results.is_empty():
		_add_tree_item(root, "Nenhum chamador encontrado para: %s()" % func_name)
		return
	_add_tree_item(root, "⚙ %d referências a %s():" % [results.size(), func_name])
	for r in results:
		_add_tree_item(root, "  %s → definido em %s" % [r.get("caller_file", "?").get_file(), r.get("defined_in", "?")])


func _query_search_name(root: TreeItem, pattern: String) -> void:
	var results := PG_GraphQuery.find_nodes_by_name(graph, pattern)
	if results.is_empty():
		_add_tree_item(root, "Nenhum nó encontrado com: '%s'" % pattern)
		return
	_add_tree_item(root, "🔍 %d resultados para '%s':" % [results.size(), pattern])
	for r in results:
		_add_tree_item(root, "  [%s] %s (%s)" % [r.get("type", "?"), r.get("name", "?"), r.get("file_path", "?").get_file()], r)


func _query_search_type(root: TreeItem, type: String) -> void:
	var results := PG_GraphQuery.find_nodes_by_type(graph, type)
	if results.is_empty():
		_add_tree_item(root, "Nenhum nó do tipo '%s'" % type)
		return
	_add_tree_item(root, "🏷️ %d nós do tipo '%s':" % [results.size(), type])
	for r in results:
		_add_tree_item(root, "  %s (%s)" % [r.get("name", "?"), r.get("file_path", "?").get_file()], r)


func _query_find_path(root: TreeItem, query_text: String) -> void:
	var parts := query_text.split("->")
	if parts.size() < 2:
		parts = query_text.split("→")
	if parts.size() < 2:
		_add_tree_item(root, "⚠ Formato esperado: 'res://a.gd -> res://b.gd'")
		return
	var from := parts[0].strip_edges()
	var to   := parts[1].strip_edges()
	var paths := PG_GraphQuery.find_path(graph, from, to)
	if paths.is_empty():
		_add_tree_item(root, "Nenhum caminho encontrado de %s até %s" % [from.get_file(), to.get_file()])
		return
	_add_tree_item(root, "🛤️ %d caminhos de %s → %s:" % [paths.size(), from.get_file(), to.get_file()])
	for i in range(paths.size()):
		var path : Array = paths[i]
		var path_item := _add_tree_item(root, "Caminho %d (%d passos):" % [i + 1, path.size()])
		for step in path:
			_add_tree_item(path_item, "  → %s" % step)


func _query_stats(root: TreeItem) -> void:
	var stats := PG_GraphQuery.get_stats(graph)
	_add_tree_item(root, "📊 Estatísticas do Grafo")
	_add_tree_item(root, "  Total de nós: %d" % stats.get("total_nodes", 0))
	_add_tree_item(root, "  Total de arestas: %d" % stats.get("total_edges", 0))
	_add_tree_item(root, "  Total de arquivos: %d" % stats.get("total_files", 0))

	var by_type : Dictionary = stats.get("nodes_by_type", {})
	if by_type.size() > 0:
		var type_item := _add_tree_item(root, "  Nós por tipo:")
		for t in by_type:
			_add_tree_item(type_item, "    %s: %d" % [t, by_type[t]])

	var by_rel : Dictionary = stats.get("edges_by_relation", {})
	if by_rel.size() > 0:
		var rel_item := _add_tree_item(root, "  Arestas por relação:")
		for r in by_rel:
			_add_tree_item(rel_item, "    %s: %d" % [r, by_rel[r]])


# ─── Tree Helpers ──────────────────────────────────────────────────────────────

func _add_tree_item(parent: TreeItem, text: String, metadata = null) -> TreeItem:
	var item := _result_tree.create_item(parent)
	item.set_text(0, text)
	if metadata != null:
		item.set_metadata(0, metadata)
	return item


func _on_tree_item_selected() -> void:
	var selected := _result_tree.get_selected()
	if not selected:
		return

	var meta = selected.get_metadata(0)
	if meta == null or meta is not Dictionary:
		_detail_panel.text = "[color=#888888]Sem detalhes adicionais.[/color]"
		return

	var lines := PackedStringArray()
	lines.append("[b]Detalhes do Nó[/b]\n")
	for key in meta:
		var val = meta[key]
		if val is Dictionary:
			lines.append("[color=#aaaaff]%s:[/color]" % key)
			for k in val:
				lines.append("  %s: %s" % [k, str(val[k])])
		else:
			lines.append("[color=#aaaaff]%s:[/color] %s" % [key, str(val)])
	_detail_panel.text = "\n".join(lines)
