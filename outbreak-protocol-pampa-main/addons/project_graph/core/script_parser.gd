@tool
class_name PG_ScriptParser
extends RefCounted

## Parser de scripts GDScript via regex.
## Extrai: extends, class_name, signals, functions, variables, constants,
## exports, preloads, connect/emit de sinais, groups.


## Resultado do parsing de um script.
class ScriptParseResult extends RefCounted:
	var nodes : Array = []  ## Array[PG_GraphModel.GraphNode]
	var edges : Array = []  ## Array[PG_GraphModel.GraphEdge]


# ─── Regexes pré-compiladas ───────────────────────────────────────────────────

static var _rx_extends         : RegEx
static var _rx_class_name      : RegEx
static var _rx_signal           : RegEx
static var _rx_func             : RegEx
static var _rx_export_var      : RegEx
static var _rx_onready_var     : RegEx
static var _rx_var              : RegEx
static var _rx_const            : RegEx
static var _rx_preload          : RegEx
static var _rx_load             : RegEx
static var _rx_connect          : RegEx
static var _rx_emit             : RegEx
static var _rx_emit_method     : RegEx
static var _rx_add_group       : RegEx
static var _rx_get_group       : RegEx
static var _rx_call_func       : RegEx
static var _initialized        := false


static func _ensure_init() -> void:
	if _initialized:
		return
	_initialized = true

	_rx_extends     = RegEx.new()
	_rx_extends.compile('^extends\\s+([\\w\\.]+|"[^"]*")')

	_rx_class_name  = RegEx.new()
	_rx_class_name.compile('^class_name\\s+(\\w+)')

	_rx_signal      = RegEx.new()
	_rx_signal.compile('^signal\\s+(\\w+)')

	_rx_func        = RegEx.new()
	_rx_func.compile('^func\\s+(\\w+)\\s*\\(([^)]*)\\)')

	_rx_export_var  = RegEx.new()
	_rx_export_var.compile('^@export[^\\n]*var\\s+(\\w+)')

	_rx_onready_var = RegEx.new()
	_rx_onready_var.compile('^@onready\\s+var\\s+(\\w+)\\s*(?::.*)?=\\s*\\$"?([^"\\n]+)"?')

	_rx_var         = RegEx.new()
	_rx_var.compile('^var\\s+(\\w+)')

	_rx_const       = RegEx.new()
	_rx_const.compile('^const\\s+(\\w+)')

	_rx_preload     = RegEx.new()
	_rx_preload.compile('preload\\s*\\(\\s*"([^"]+)"\\s*\\)')

	_rx_load        = RegEx.new()
	_rx_load.compile('(?<!pre)load\\s*\\(\\s*"([^"]+)"\\s*\\)')

	_rx_connect     = RegEx.new()
	_rx_connect.compile('(\\w+)\\.connect\\s*\\(\\s*([^)]+)\\)')

	_rx_emit        = RegEx.new()
	_rx_emit.compile('(\\w+)\\.emit\\s*\\(')

	_rx_emit_method = RegEx.new()
	_rx_emit_method.compile('emit_signal\\s*\\(\\s*"(\\w+)"')

	_rx_add_group   = RegEx.new()
	_rx_add_group.compile('add_to_group\\s*\\(\\s*"(\\w+)"')

	_rx_get_group   = RegEx.new()
	_rx_get_group.compile('get_nodes_in_group\\s*\\(\\s*"(\\w+)"')

	_rx_call_func   = RegEx.new()
	_rx_call_func.compile('\\.(\\w+)\\s*\\(')


## Parseia um script GDScript e retorna nós + arestas.
static func parse(script_path: String) -> ScriptParseResult:
	_ensure_init()

	var result := ScriptParseResult.new()

	var file := FileAccess.open(script_path, FileAccess.READ)
	if not file:
		push_warning("[ProjectGraph] Não foi possível abrir script: %s" % script_path)
		return result

	var content := file.get_as_text()
	file.close()

	var lines := content.split("\n")

	# ── Nó do script ───────────────────────────────────────────────────────
	var script_id := "script::%s" % script_path
	result.nodes.append(PG_GraphModel.GraphNode.new(
		script_id, "script", script_path.get_file(), script_path, {}
	))

	# Tracking para sinais declarados (para resolver emit).
	var declared_signals : Array[String] = []
	# Tracking para nomes de variáveis que guardam sinais.
	var signal_vars : Dictionary = {}

	for line_idx in range(lines.size()):
		var raw_line : String = lines[line_idx]
		var line := raw_line.strip_edges()
		var line_num := line_idx + 1

		# Ignora comentários.
		if line.begins_with("#"):
			continue

		# ── extends ────────────────────────────────────────────────────────
		var m := _rx_extends.search(line)
		if m:
			var extends_target := m.get_string(1).replace('"', '')
			result.nodes[0].metadata["extends"] = extends_target
			# Se for um path de arquivo.
			if extends_target.begins_with("res://"):
				result.edges.append(PG_GraphModel.GraphEdge.new(
					script_id, "script::%s" % extends_target, "extends",
					{"line": line_num}
				))
			else:
				result.edges.append(PG_GraphModel.GraphEdge.new(
					script_id, "class::%s" % extends_target, "extends",
					{"line": line_num}
				))
			continue

		# ── class_name ─────────────────────────────────────────────────────
		m = _rx_class_name.search(line)
		if m:
			var cname := m.get_string(1)
			var class_id := "class::%s" % cname
			result.nodes.append(PG_GraphModel.GraphNode.new(
				class_id, "class", cname, script_path,
				{"line": line_num}
			))
			result.nodes[0].metadata["class_name"] = cname
			continue

		# ── signal ─────────────────────────────────────────────────────────
		m = _rx_signal.search(line)
		if m:
			var sig_name := m.get_string(1)
			declared_signals.append(sig_name)
			var sig_id := "signal_def::%s::%s" % [script_path, sig_name]
			result.nodes.append(PG_GraphModel.GraphNode.new(
				sig_id, "signal_def", sig_name, script_path,
				{"line": line_num}
			))
			result.edges.append(PG_GraphModel.GraphEdge.new(
				script_id, sig_id, "has_signal",
				{"line": line_num}
			))
			continue

		# ── func ───────────────────────────────────────────────────────────
		m = _rx_func.search(line)
		if m:
			var func_name := m.get_string(1)
			var func_args := m.get_string(2).strip_edges()
			var func_id := "func::%s::%s" % [script_path, func_name]
			result.nodes.append(PG_GraphModel.GraphNode.new(
				func_id, "function", func_name, script_path,
				{"line": line_num, "args": func_args}
			))
			result.edges.append(PG_GraphModel.GraphEdge.new(
				script_id, func_id, "has_function",
				{"line": line_num}
			))
			continue

		# ── @export var ────────────────────────────────────────────────────
		m = _rx_export_var.search(line)
		if m:
			var var_name := m.get_string(1)
			var var_id := "var::%s::%s" % [script_path, var_name]
			result.nodes.append(PG_GraphModel.GraphNode.new(
				var_id, "variable", var_name, script_path,
				{"line": line_num, "exported": true}
			))
			result.edges.append(PG_GraphModel.GraphEdge.new(
				script_id, var_id, "exports_var",
				{"line": line_num}
			))
			continue

		# ── @onready var (captura referência a nó $) ───────────────────────
		m = _rx_onready_var.search(line)
		if m:
			var var_name  := m.get_string(1)
			var node_ref  := m.get_string(2).strip_edges()
			var var_id := "var::%s::%s" % [script_path, var_name]
			result.nodes.append(PG_GraphModel.GraphNode.new(
				var_id, "variable", var_name, script_path,
				{"line": line_num, "onready": true, "node_ref": node_ref}
			))
			result.edges.append(PG_GraphModel.GraphEdge.new(
				script_id, var_id, "has_variable",
				{"line": line_num}
			))
			continue

		# ── const ──────────────────────────────────────────────────────────
		m = _rx_const.search(line)
		if m:
			var const_name := m.get_string(1)
			var const_id := "const::%s::%s" % [script_path, const_name]
			result.nodes.append(PG_GraphModel.GraphNode.new(
				const_id, "constant", const_name, script_path,
				{"line": line_num}
			))
			result.edges.append(PG_GraphModel.GraphEdge.new(
				script_id, const_id, "has_constant",
				{"line": line_num}
			))
			continue

		# ── var (simples, sem export/onready) ──────────────────────────────
		m = _rx_var.search(line)
		if m:
			var var_name := m.get_string(1)
			var var_id := "var::%s::%s" % [script_path, var_name]
			result.nodes.append(PG_GraphModel.GraphNode.new(
				var_id, "variable", var_name, script_path,
				{"line": line_num}
			))
			result.edges.append(PG_GraphModel.GraphEdge.new(
				script_id, var_id, "has_variable",
				{"line": line_num}
			))
			# Não faz continue — a linha pode conter preload/load.

		# ── preload / load ─────────────────────────────────────────────────
		for rx in [_rx_preload, _rx_load]:
			var matches := rx.search_all(line)
			for match in matches:
				var res_path := match.get_string(1)
				if res_path.ends_with(".gd"):
					result.edges.append(PG_GraphModel.GraphEdge.new(
						script_id, "script::%s" % res_path, "preloads",
						{"line": line_num}
					))
				elif res_path.ends_with(".tscn") or res_path.ends_with(".scn"):
					result.edges.append(PG_GraphModel.GraphEdge.new(
						script_id, "scene::%s" % res_path, "preloads",
						{"line": line_num}
					))
				else:
					var res_id := "resource::%s" % res_path
					result.nodes.append(PG_GraphModel.GraphNode.new(
						res_id, "resource", res_path.get_file(), res_path,
						{"line": line_num}
					))
					result.edges.append(PG_GraphModel.GraphEdge.new(
						script_id, res_id, "preloads",
						{"line": line_num}
					))

		# ── .connect() ─────────────────────────────────────────────────────
		m = _rx_connect.search(line)
		if m:
			var sig_name := m.get_string(1)
			var callable_str := m.get_string(2).strip_edges()
			result.edges.append(PG_GraphModel.GraphEdge.new(
				script_id,
				"signal_def::%s" % sig_name,
				"connects_signal",
				{"line": line_num, "signal": sig_name, "callable": callable_str}
			))

		# ── .emit() e emit_signal() ────────────────────────────────────────
		m = _rx_emit.search(line)
		if m:
			var sig_name := m.get_string(1)
			result.edges.append(PG_GraphModel.GraphEdge.new(
				script_id,
				"signal_def::%s::%s" % [script_path, sig_name],
				"emits_signal",
				{"line": line_num, "signal": sig_name}
			))

		m = _rx_emit_method.search(line)
		if m:
			var sig_name := m.get_string(1)
			result.edges.append(PG_GraphModel.GraphEdge.new(
				script_id,
				"signal_def::%s::%s" % [script_path, sig_name],
				"emits_signal",
				{"line": line_num, "signal": sig_name}
			))

		# ── add_to_group ───────────────────────────────────────────────────
		m = _rx_add_group.search(line)
		if m:
			var group_name := m.get_string(1)
			var group_id := "group::%s" % group_name
			result.nodes.append(PG_GraphModel.GraphNode.new(
				group_id, "group", group_name, script_path,
				{"line": line_num}
			))
			result.edges.append(PG_GraphModel.GraphEdge.new(
				script_id, group_id, "belongs_to_group",
				{"line": line_num}
			))

		# ── get_nodes_in_group ─────────────────────────────────────────────
		m = _rx_get_group.search(line)
		if m:
			var group_name := m.get_string(1)
			var group_id := "group::%s" % group_name
			result.nodes.append(PG_GraphModel.GraphNode.new(
				group_id, "group", group_name, script_path, {}
			))
			result.edges.append(PG_GraphModel.GraphEdge.new(
				script_id, group_id, "uses_resource",
				{"line": line_num, "usage": "get_nodes_in_group"}
			))

	return result
