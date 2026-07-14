extends AudioStreamPlayer

@export var restart_on_finished := true


func _ready() -> void:
	if restart_on_finished and not finished.is_connected(_restart_stream):
		finished.connect(_restart_stream)


func _restart_stream() -> void:
	if restart_on_finished and is_inside_tree() and stream:
		play()
