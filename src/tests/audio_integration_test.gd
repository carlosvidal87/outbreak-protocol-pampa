extends SceneTree

const REQUIRED_AUDIO := [
	"res://assets/sounds/Anda Grama.mp3",
	"res://assets/sounds/Attack Zombie.wav",
	"res://assets/sounds/Dano Player.wav",
	"res://assets/sounds/Idle Zombie.wav",
	"res://assets/sounds/Morte Player.wav",
	"res://assets/sounds/Morte Zombie.wav",
	"res://assets/sounds/Run Zombie.wav",
	"res://assets/sounds/musica menu.mp3",
	"res://assets/sounds/horror_sfx_vol_1 (1)/Ambient/Ambient Wind (5).mp3",
	"res://assets/sounds/horror_sfx_vol_1 (1)/Ambient/Concrete Footsteps/Andar Monstro.mp3",
	"res://assets/sounds/horror_sfx_vol_1 (1)/Boss Battle.wav",
	"res://assets/sounds/horror_sfx_vol_1 (1)/Sons Monstro/Monster Attack.mp3",
	"res://assets/sounds/horror_sfx_vol_1 (1)/Sons Monstro/Monster Death.mp3",
	"res://assets/sounds/horror_sfx_vol_1 (1)/Sons Monstro/Monster Idle.mp3",
	"res://assets/sounds/horror_sfx_vol_1 (1)/Sons Monstro/Monster Running.mp3",
]
const SCENE_AUDIO_NODES := {
	"res://src/scenes/main_menu.tscn": ["MenuMusic"],
	"res://src/scenes/node_3d.tscn": ["AmbientWind"],
	"res://src/scenes/character.tscn": ["FootstepAudio", "DamageAudio", "DeathAudio"],
	"res://src/scenes/zombie.tscn": ["IdleVoiceAudio", "AttackAudio", "DeathAudio", "RunAudio"],
	"res://src/scenes/boss.tscn": ["IdleAudio", "AttackAudio", "DeathAudio", "MovementAudio", "RunAudio", "BattleMusic"],
}


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	for audio_path: String in REQUIRED_AUDIO:
		var stream := load(audio_path) as AudioStream
		if not stream or stream.get_length() <= 0.0:
			_fail("Audio ausente ou vazio: %s" % audio_path)
			return
	for scene_path: String in SCENE_AUDIO_NODES:
		var scene_text := FileAccess.get_file_as_string(scene_path)
		if scene_text.is_empty():
			_fail("Cena de audio nao pode ser lida: %s" % scene_path)
			return
		for node_name: String in SCENE_AUDIO_NODES[scene_path]:
			if not scene_text.contains("[node name=\"%s\"" % node_name):
				_fail("%s nao possui o no editavel %s." % [scene_path, node_name])
				return
	var zombie_script := load("res://src/scripts/zombie.gd") as Script
	var constants := zombie_script.get_script_constant_map()
	var idle_segments: Array = constants.get("IDLE_VOICE_SEGMENTS", [])
	if idle_segments.size() != 5:
		_fail("Idle Zombie.wav precisa usar cinco trechos isolados.")
		return
	print("AUDIO_INTEGRATION_TEST: PASS")
	quit(0)


func _fail(message: String) -> void:
	push_error("AUDIO_INTEGRATION_TEST: %s" % message)
	quit(1)
