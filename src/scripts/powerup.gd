extends Node3D

## Powerup — Item flutuante, rotativo e brilhante que concede bônus temporários ou instantâneos.

@export var type : String = "max_ammo" # max_ammo, insta_kill, double_points, nuke

var time := 0.0
var lifespan := 30.0
var is_blinking := false
var mesh_inst : MeshInstance3D = null


func _ready() -> void:
	name = "Powerup_" + type.capitalize()

	# Configura a cor baseada no tipo
	var powerup_color := Color.GREEN
	match type:
		"max_ammo":      powerup_color = Color(0.1, 0.9, 0.1)  # Verde brilhante
		"insta_kill":    powerup_color = Color(0.9, 0.1, 0.1)  # Vermelho
		"double_points": powerup_color = Color(0.9, 0.8, 0.1)  # Amarelo/Dourado
		"nuke":          powerup_color = Color(0.9, 0.4, 0.0)  # Laranja
		"instant_money": powerup_color = Color(0.1, 0.6, 0.1)  # Verde escuro

	# 1. Criação do visual do item (MeshInstance3D com BoxMesh rotacionado para parecer um losango/joia)
	mesh_inst = MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.4, 0.4, 0.4)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = powerup_color
	mat.roughness = 0.2
	mat.emission_enabled = true
	mat.emission = powerup_color * 1.5 # Emite luz forte (efeito neon)
	box_mesh.material = mat
	mesh_inst.mesh = box_mesh
	mesh_inst.position.y = 0.5
	# Rotaciona para dar um aspecto geométrico premium (losango)
	mesh_inst.rotation = Vector3(PI / 4.0, 0.0, PI / 4.0)
	add_child(mesh_inst)

	# 2. Criação de uma luz brilhante (OmniLight3D)
	var light := OmniLight3D.new()
	light.light_color = powerup_color
	light.light_energy = 3.0
	light.omni_range = 3.0
	light.position.y = 0.5
	add_child(light)

	# 3. Area3D para detecção de colisão do player
	var area := Area3D.new()
	area.collision_mask = 1
	area.collision_layer = 0
	
	var area_col := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 1.2
	area_col.shape = sphere_shape
	area_col.position.y = 0.5
	area.add_child(area_col)
	add_child(area)

	area.body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	time += delta
	lifespan -= delta

	# Efeito de flutuar e rotacionar
	if mesh_inst:
		mesh_inst.position.y = 0.5 + sin(time * 3.5) * 0.12
		mesh_inst.rotate_y(delta * 1.5)

	# Piscar no final da vida útil (últimos 8 segundos)
	if lifespan <= 8.0:
		is_blinking = true
		# Pisca mais rápido conforme chega perto de sumir
		var frequency := 15.0 if lifespan <= 3.0 else 7.0
		visible = fmod(time * frequency, 2.0) < 1.0

	# Destrói o item se expirar
	if lifespan <= 0.0:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.has_method("collect_powerup"):
			body.collect_powerup(type)
		queue_free()
