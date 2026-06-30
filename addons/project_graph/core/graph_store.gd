@tool
class_name PG_GraphStore
extends RefCounted

## Persistência do grafo em JSON.
## Salva/carrega o ProjectGraph inteiro em disco e fornece utilitário de hash MD5.

const CACHE_DIR  := "res://addons/project_graph/.cache"
const CACHE_PATH := "res://addons/project_graph/.cache/graph_index.json"


## Salva o grafo em disco como JSON.
static func save_graph(graph: PG_GraphModel.ProjectGraph) -> Error:
	# Garante que o diretório de cache existe.
	if not DirAccess.dir_exists_absolute(CACHE_DIR):
		var err := DirAccess.make_dir_recursive_absolute(CACHE_DIR)
		if err != OK:
			push_error("[ProjectGraph] Erro ao criar diretório de cache: %s" % error_string(err))
			return err

	var data := graph.to_dict()
	var json_string := JSON.stringify(data, "\t")

	var file := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if not file:
		var err := FileAccess.get_open_error()
		push_error("[ProjectGraph] Erro ao abrir arquivo de cache para escrita: %s" % error_string(err))
		return err

	file.store_string(json_string)
	file.close()
	return OK


## Carrega o grafo do disco. Retorna null se não existir ou houver erro.
static func load_graph() -> PG_GraphModel.ProjectGraph:
	if not FileAccess.file_exists(CACHE_PATH):
		return null

	var file := FileAccess.open(CACHE_PATH, FileAccess.READ)
	if not file:
		push_error("[ProjectGraph] Erro ao abrir arquivo de cache para leitura.")
		return null

	var content := file.get_as_text()
	file.close()

	if content.is_empty():
		return null

	var json := JSON.new()
	var parse_err := json.parse(content)
	if parse_err != OK:
		push_error("[ProjectGraph] Erro ao parsear JSON do cache: %s" % json.get_error_message())
		return null

	var data = json.data
	if data is not Dictionary:
		push_error("[ProjectGraph] Cache JSON inválido: root não é Dictionary.")
		return null

	return PG_GraphModel.ProjectGraph.from_dict(data)


## Calcula o hash MD5 de um arquivo. Retorna "" se o arquivo não existir.
static func get_file_hash(file_path: String) -> String:
	if not FileAccess.file_exists(file_path):
		return ""
	return FileAccess.get_md5(file_path)


## Verifica se o cache existe.
static func cache_exists() -> bool:
	return FileAccess.file_exists(CACHE_PATH)


## Remove o cache do disco.
static func clear_cache() -> Error:
	if FileAccess.file_exists(CACHE_PATH):
		return DirAccess.remove_absolute(CACHE_PATH)
	return OK
