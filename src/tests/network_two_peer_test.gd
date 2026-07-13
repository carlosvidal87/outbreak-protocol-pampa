extends Node

const PORT := 17001

var test_address := "127.0.0.1"


func _ready() -> void:
	var role := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("role="):
			role = argument.trim_prefix("role=")
		elif argument.begins_with("address="):
			test_address = argument.trim_prefix("address=")
	if role == "host":
		_run_host()
	elif role == "client":
		_run_client()
	else:
		_fail("Informe role=host ou role=client.")


func _run_host() -> void:
	if NetworkManager.host_game("Host", PORT, 4) != OK:
		_fail("Host nao abriu a sessao.")
		return
	var deadline := Time.get_ticks_msec() + 10000
	while NetworkManager.players.size() < 2 and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.1).timeout
	if NetworkManager.players.size() != 2:
		_fail("Cliente nao apareceu no lobby do host.")
		return
	print("[TWO PEER TEST] Host recebeu cliente e sincronizou o lobby.")
	await get_tree().create_timer(0.5).timeout
	NetworkManager.leave_session("")
	get_tree().quit(0)


func _run_client() -> void:
	if NetworkManager.join_game(test_address, "Cliente", PORT) != OK:
		_fail("Cliente nao iniciou conexao.")
		return
	var deadline := Time.get_ticks_msec() + 10000
	while NetworkManager.players.size() < 2 and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.1).timeout
	if NetworkManager.players.size() != 2:
		_fail("Lobby sincronizado nao chegou ao cliente.")
		return
	print("[TWO PEER TEST] Cliente conectou por %s e recebeu os dois jogadores." % test_address)
	NetworkManager.leave_session("")
	get_tree().quit(0)


func _fail(message: String) -> void:
	NetworkManager.leave_session("")
	push_error("[TWO PEER TEST] %s" % message)
	get_tree().quit(1)
