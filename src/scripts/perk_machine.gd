extends StaticBody3D

## PerkMachine — Pilar físico e interativo que concede vantagens em troca de pontos.

@export var perk_id : String = "juggernog"
@export var perk_name : String = "Juggernog"
@export var cost : int = 2500
@export var machine_color : Color = Color.RED

var player_in_area : Node3D = null


func _ready() -> void:
	# 1. Criação do visual do pilar (MeshInstance3D com BoxMesh)
	var mesh_inst := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.8, 1.8, 0.8)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = machine_color
	mat.roughness = 0.4
	mat.emission_enabled = true
	mat.emission = machine_color * 0.25
	box_mesh.material = mat
	mesh_inst.mesh = box_mesh
	mesh_inst.position.y = 0.9 # Metade da altura para apoiar no chão
	add_child(mesh_inst)

	# 2. Criação da colisão física para o jogador não atravessar
	var col_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.8, 1.8, 0.8)
	col_shape.shape = box_shape
	col_shape.position.y = 0.9
	add_child(col_shape)

	# 3. Area3D para detectar a proximidade do jogador
	var area := Area3D.new()
	# Usa as detecções padrão de física
	area.collision_mask = 1
	area.collision_layer = 0
	
	var area_col := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 2.2
	area_col.shape = sphere_shape
	area_col.position.y = 0.9
	area.add_child(area_col)
	add_child(area)

	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_area = body
		if body.has_method("register_interactable"):
			body.register_interactable(self)


func _on_body_exited(body: Node3D) -> void:
	if body == player_in_area:
		if player_in_area.has_method("unregister_interactable"):
			player_in_area.unregister_interactable(self)
		player_in_area = null
