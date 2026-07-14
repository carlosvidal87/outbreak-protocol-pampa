extends Node3D

signal startup_ready

const NAV_EXTENT := 310.0
const NAV_STEP := 6.0
const NAV_RAY_TOP := 220.0
const NAV_RAY_BOTTOM := -260.0
const NAV_SURFACE_OFFSET := 0.05
const NAV_MAX_CELL_HEIGHT_DELTA := 4.0
const NAV_BUILD_YIELD_ROWS := 4
const STARTUP_READY_FRAMES := 2
const GAMEPLAY_FADE_IN_TIME := 0.32
const PREBAKED_NAV_REGION_NAME := "TerrainNavigationRegion"
const CLOUD_LAYER_HEIGHT := 92.0
const CLOUD_LAYER_RADIUS := 270.0
const CLOUD_DRIFT_SPEED := Vector3(0.34, 0.0, -0.11)
const MOON_POSITION := Vector3(-145.0, 128.0, -185.0)
const HAZE_LAYER_HEIGHT := 2.8
const STORM_WALL_RADIUS := 285.0
const STORM_WALL_HEIGHT := 58.0
const AIR_PARTICLE_EXTENTS := Vector3(130.0, 26.0, 130.0)
const MOON_HALO_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 halo_color : source_color = vec4(0.28, 0.38, 0.72, 1.0);
uniform float alpha = 0.18;

void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	float radius = length(centered_uv) * 2.0;
	float halo = smoothstep(1.0, 0.08, radius);
	ALBEDO = halo_color.rgb;
	ALPHA = halo * alpha;
}
"""
const HAZE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D haze_noise : source_color, repeat_enable;
uniform vec4 haze_color : source_color = vec4(0.45, 0.50, 0.48, 1.0);
uniform float alpha = 0.18;
uniform float cutoff = 0.42;

void fragment() {
	float noise_value = texture(haze_noise, UV).r;
	float haze_mask = smoothstep(cutoff, 1.0, noise_value);
	float edge_fade = smoothstep(0.0, 0.18, UV.y) * smoothstep(1.0, 0.62, UV.y);
	ALBEDO = haze_color.rgb;
	ALPHA = haze_mask * edge_fade * alpha;
}
"""
const CLOUD_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D cloud_noise : source_color, repeat_enable;
uniform vec4 cloud_color : source_color = vec4(0.70, 0.74, 0.72, 1.0);
uniform float alpha = 0.44;
uniform float cutoff = 0.37;

void fragment() {
	vec2 uv = UV;
	float base_noise = texture(cloud_noise, uv * vec2(1.55, 0.72) + vec2(0.08, 0.0)).r;
	float detail_noise = texture(cloud_noise, uv * vec2(4.4, 1.35) + vec2(0.31, 0.17)).r;
	float wisp_noise = texture(cloud_noise, uv * vec2(8.0, 0.85) + vec2(0.0, 0.42)).r;
	float cloud_mask = smoothstep(cutoff, 1.0, base_noise * 0.70 + detail_noise * 0.22 + wisp_noise * 0.08);
	float edge_fade = smoothstep(0.0, 0.16, uv.x) * smoothstep(1.0, 0.84, uv.x);
	edge_fade *= smoothstep(0.0, 0.20, uv.y) * smoothstep(1.0, 0.65, uv.y);
	float shade = mix(0.70, 1.12, detail_noise);
	ALBEDO = cloud_color.rgb * shade;
	ALPHA = cloud_mask * edge_fade * alpha;
}
"""

var is_night := false
var world_environment: WorldEnvironment = null
var directional_light: DirectionalLight3D = null
var startup_fade_rect: ColorRect = null
var use_external_loading_screen := false
@export_range(0.5, 1.5, 0.05) var zone_fog_intensity := 1.0
@export_range(0.5, 1.5, 0.05) var zone_cloud_opacity := 1.0
@export_range(0.5, 1.5, 0.05) var zone_moonlight_intensity := 1.0
var cloud_root: Node3D = null
var cloud_material: ShaderMaterial = null
var storm_wall_root: Node3D = null
var storm_wall_material: ShaderMaterial = null
var moon_visual: MeshInstance3D = null
var moon_halo_visual: MeshInstance3D = null
var ground_haze_root: Node3D = null
var ground_haze_material: ShaderMaterial = null
var air_particles: GPUParticles3D = null
var last_logged_atmosphere_state := ""
var suppress_graphics_settings_signal := false


func _ready() -> void:
	var startup_begin_ms := Time.get_ticks_msec()
	if not use_external_loading_screen:
		_create_startup_fade()
	_set_players_processing_enabled(false)
	_cache_lighting_nodes()
	_create_cloud_layer()
	_create_storm_wall_layer()
	_create_moon_visual()
	_create_ground_haze_layer()
	_create_air_particles()
	_connect_graphics_settings()

	_apply_graphics_settings_to_map(true)
	_apply_atmosphere_state(false)

	for _frame in range(STARTUP_READY_FRAMES):
		await get_tree().physics_frame

	await _ensure_navigation_ready()

	for _frame in range(STARTUP_READY_FRAMES):
		await get_tree().physics_frame

	_apply_graphics_settings_to_map(false)
	_apply_atmosphere_state(is_night)
	_set_players_processing_enabled(true)
	print("[MAP] Cena pronta em %dms." % (Time.get_ticks_msec() - startup_begin_ms))
	startup_ready.emit()
	if not use_external_loading_screen:
		await _fade_from_black()


func _process(delta: float) -> void:
	if cloud_root:
		cloud_root.position += CLOUD_DRIFT_SPEED * delta
		cloud_root.position.x = wrapf(cloud_root.position.x, -CLOUD_LAYER_RADIUS, CLOUD_LAYER_RADIUS)
		cloud_root.position.z = wrapf(cloud_root.position.z, -CLOUD_LAYER_RADIUS, CLOUD_LAYER_RADIUS)

	if storm_wall_root:
		storm_wall_root.rotate_y(0.002 * delta)

	if ground_haze_root:
		ground_haze_root.position += CLOUD_DRIFT_SPEED * delta * 0.22
		ground_haze_root.position.x = wrapf(ground_haze_root.position.x, -40.0, 40.0)
		ground_haze_root.position.z = wrapf(ground_haze_root.position.z, -40.0, 40.0)

	_update_air_particle_position()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		var is_day_night_toggle := key_event.physical_keycode == KEY_F8
		if key_event.pressed and not key_event.echo and is_day_night_toggle:
			is_night = not is_night
			_apply_night_state(is_night)
			get_viewport().set_input_as_handled()


func _ensure_navigation_ready() -> void:
	var nav_region := _get_navigation_region()
	if nav_region and nav_region.navigation_mesh and nav_region.navigation_mesh.get_polygon_count() > 0:
		print("[MAP] Usando NavigationRegion3D pre-assada.")
		await get_tree().physics_frame
		return

	push_warning("Mapa sem NavigationRegion3D pre-assada. Usando fallback incremental em runtime.")
	var navigation_start_ms := Time.get_ticks_msec()
	await _build_navigation_fallback()
	print("[MAP] Fallback de navegacao concluido em %dms." % (Time.get_ticks_msec() - navigation_start_ms))


func _get_navigation_region() -> NavigationRegion3D:
	var explicit_region := get_node_or_null(PREBAKED_NAV_REGION_NAME) as NavigationRegion3D
	if explicit_region:
		return explicit_region

	var found_regions := find_children("*", "NavigationRegion3D", true, false)
	if not found_regions.is_empty():
		return found_regions[0] as NavigationRegion3D
	return null


func _build_navigation_fallback() -> void:
	var nav_region := _get_navigation_region()
	if not nav_region:
		nav_region = NavigationRegion3D.new()
		nav_region.name = PREBAKED_NAV_REGION_NAME
		add_child(nav_region)

	var nav_mesh := nav_region.navigation_mesh if nav_region.navigation_mesh else NavigationMesh.new()
	var vertices := PackedVector3Array()
	var heights: Array[float] = []
	var points_per_axis := int((NAV_EXTENT * 2.0) / NAV_STEP) + 1
	var excludes := _get_navigation_raycast_excludes()

	for z_index in range(points_per_axis):
		for x_index in range(points_per_axis):
			var x := -NAV_EXTENT + float(x_index) * NAV_STEP
			var z := -NAV_EXTENT + float(z_index) * NAV_STEP
			var y := _sample_ground_height(Vector3(x, 0.0, z), excludes)
			heights.append(y)
			if y == INF:
				vertices.append(Vector3(x, 0.0, z))
			else:
				vertices.append(Vector3(x, y + NAV_SURFACE_OFFSET, z))
		if z_index % NAV_BUILD_YIELD_ROWS == 0:
			await get_tree().process_frame

	nav_mesh.vertices = vertices

	for z_index in range(points_per_axis - 1):
		for x_index in range(points_per_axis - 1):
			var i0 := z_index * points_per_axis + x_index
			var i1 := i0 + 1
			var i2 := i0 + points_per_axis
			var i3 := i2 + 1
			if _cell_is_walkable(heights, [i0, i1, i2, i3]):
				nav_mesh.add_polygon(PackedInt32Array([i0, i2, i1]))
				nav_mesh.add_polygon(PackedInt32Array([i1, i2, i3]))
		if z_index % NAV_BUILD_YIELD_ROWS == 0:
			await get_tree().process_frame

	nav_region.navigation_mesh = nav_mesh
	await NavigationServer3D.map_changed


func _cell_is_walkable(heights: Array[float], indices: Array[int]) -> bool:
	var min_height := INF
	var max_height := -INF
	for index in indices:
		var height := heights[index]
		if height == INF:
			return false
		min_height = minf(min_height, height)
		max_height = maxf(max_height, height)
	return max_height - min_height <= NAV_MAX_CELL_HEIGHT_DELTA


func _sample_ground_height(pos: Vector3, excludes: Array[RID]) -> float:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(pos.x, NAV_RAY_TOP, pos.z),
		Vector3(pos.x, NAV_RAY_BOTTOM, pos.z)
	)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.exclude = excludes

	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return INF
	var collider := hit.get("collider") as Node
	if not _is_terrain_collider(collider):
		return INF

	var hit_position: Vector3 = hit["position"]
	return hit_position.y


func _is_terrain_collider(collider: Node) -> bool:
	var current := collider
	while current:
		if current.name == "HTerrain":
			return true
		current = current.get_parent()
	return false


func _get_navigation_raycast_excludes() -> Array[RID]:
	var excludes: Array[RID] = []
	for player in get_tree().get_nodes_in_group("player"):
		if player is CollisionObject3D:
			excludes.append((player as CollisionObject3D).get_rid())
	return excludes


func _cache_lighting_nodes() -> void:
	world_environment = get_node_or_null("WorldEnvironment") as WorldEnvironment
	directional_light = get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if not world_environment:
		world_environment = find_child("WorldEnvironment", true, false) as WorldEnvironment
	if not directional_light:
		directional_light = find_child("DirectionalLight3D", true, false) as DirectionalLight3D


func _connect_graphics_settings() -> void:
	if GraphicsSettings.settings_changed.is_connected(_on_graphics_settings_changed):
		return

	GraphicsSettings.settings_changed.connect(_on_graphics_settings_changed)


func _apply_graphics_settings_to_map(include_viewport: bool) -> void:
	suppress_graphics_settings_signal = true
	if include_viewport:
		GraphicsSettings.apply_to_viewport(get_viewport())
	GraphicsSettings.apply_to_scene(self)
	suppress_graphics_settings_signal = false


func _create_cloud_layer() -> void:
	if cloud_root:
		return

	cloud_root = Node3D.new()
	cloud_root.name = "CloudLayer"
	add_child(cloud_root)

	cloud_material = _create_cloud_material()
	var cloud_layout: Array[Dictionary] = [
		{"pos": Vector3(-235, CLOUD_LAYER_HEIGHT, -205), "scale": Vector3(165, 1, 62), "rot": 0.18},
		{"pos": Vector3(-86, CLOUD_LAYER_HEIGHT + 8.0, -232), "scale": Vector3(190, 1, 58), "rot": -0.12},
		{"pos": Vector3(125, CLOUD_LAYER_HEIGHT + 5.0, -218), "scale": Vector3(156, 1, 60), "rot": 0.31},
		{"pos": Vector3(250, CLOUD_LAYER_HEIGHT + 14.0, -76), "scale": Vector3(180, 1, 70), "rot": -0.24},
		{"pos": Vector3(176, CLOUD_LAYER_HEIGHT + 4.0, 84), "scale": Vector3(142, 1, 52), "rot": 0.09},
		{"pos": Vector3(42, CLOUD_LAYER_HEIGHT + 18.0, 210), "scale": Vector3(220, 1, 72), "rot": -0.33},
		{"pos": Vector3(-155, CLOUD_LAYER_HEIGHT + 7.0, 218), "scale": Vector3(160, 1, 50), "rot": 0.27},
		{"pos": Vector3(-252, CLOUD_LAYER_HEIGHT + 12.0, 68), "scale": Vector3(185, 1, 76), "rot": -0.18},
		{"pos": Vector3(-26, CLOUD_LAYER_HEIGHT + 25.0, -42), "scale": Vector3(240, 1, 82), "rot": 0.04},
		{"pos": Vector3(122, CLOUD_LAYER_HEIGHT + 31.0, 22), "scale": Vector3(155, 1, 54), "rot": -0.41},
		{"pos": Vector3(-188, CLOUD_LAYER_HEIGHT + 28.0, -28), "scale": Vector3(138, 1, 46), "rot": 0.36},
		{"pos": Vector3(20, CLOUD_LAYER_HEIGHT + 36.0, -170), "scale": Vector3(150, 1, 48), "rot": -0.08},
		{"pos": Vector3(238, CLOUD_LAYER_HEIGHT + 25.0, 210), "scale": Vector3(176, 1, 60), "rot": 0.22},
		{"pos": Vector3(-238, CLOUD_LAYER_HEIGHT + 21.0, -242), "scale": Vector3(170, 1, 56), "rot": -0.29},
		{"pos": Vector3(-38, CLOUD_LAYER_HEIGHT + 42.0, 134), "scale": Vector3(270, 1, 92), "rot": 0.17},
		{"pos": Vector3(206, CLOUD_LAYER_HEIGHT + 46.0, -186), "scale": Vector3(235, 1, 86), "rot": -0.22},
		{"pos": Vector3(-224, CLOUD_LAYER_HEIGHT + 40.0, 166), "scale": Vector3(225, 1, 80), "rot": 0.33}
	]

	for index in range(cloud_layout.size()):
		var data: Dictionary = cloud_layout[index]
		var cloud := MeshInstance3D.new()
		cloud.name = "Cloud_%02d" % index
		cloud.mesh = PlaneMesh.new()
		cloud.material_override = cloud_material
		cloud.position = data["pos"]
		cloud.rotation = Vector3(0.0, float(data["rot"]), 0.0)
		cloud.scale = data["scale"]
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cloud_root.add_child(cloud)


func _create_cloud_material() -> ShaderMaterial:
	var noise := FastNoiseLite.new()
	noise.seed = 2417
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.016
	noise.fractal_octaves = 5
	noise.fractal_gain = 0.54

	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.noise = noise

	var shader := Shader.new()
	shader.code = CLOUD_SHADER

	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("cloud_noise", texture)
	material.set_shader_parameter("cloud_color", Color(0.58, 0.63, 0.61, 1.0))
	material.set_shader_parameter("alpha", 0.52)
	material.set_shader_parameter("cutoff", 0.34)
	return material


func _apply_cloud_lighting(enabled: bool) -> void:
	if not cloud_material:
		return

	if enabled:
		cloud_material.set_shader_parameter("cloud_color", Color(0.20, 0.25, 0.36, 1.0))
		cloud_material.set_shader_parameter("alpha", 0.24 * zone_cloud_opacity)
		cloud_material.set_shader_parameter("cutoff", 0.46)
	else:
		cloud_material.set_shader_parameter("cloud_color", Color(0.50, 0.56, 0.53, 1.0))
		cloud_material.set_shader_parameter("alpha", 0.38 * zone_cloud_opacity)
		cloud_material.set_shader_parameter("cutoff", 0.42)


func _create_storm_wall_layer() -> void:
	if storm_wall_root:
		return

	storm_wall_root = Node3D.new()
	storm_wall_root.name = "StormWallLayer"
	add_child(storm_wall_root)

	storm_wall_material = _create_cloud_material()
	var wall_layout: Array[Dictionary] = [
		{"angle": -150.0, "scale": Vector3(155, 1, 44), "height": 0.0},
		{"angle": -112.0, "scale": Vector3(205, 1, 58), "height": 8.0},
		{"angle": -68.0, "scale": Vector3(190, 1, 52), "height": 4.0},
		{"angle": -24.0, "scale": Vector3(235, 1, 66), "height": 12.0},
		{"angle": 28.0, "scale": Vector3(210, 1, 60), "height": 6.0},
		{"angle": 78.0, "scale": Vector3(180, 1, 50), "height": 2.0},
		{"angle": 122.0, "scale": Vector3(225, 1, 64), "height": 10.0},
		{"angle": 162.0, "scale": Vector3(175, 1, 48), "height": 5.0}
	]

	for index in range(wall_layout.size()):
		var data: Dictionary = wall_layout[index]
		var angle := deg_to_rad(float(data["angle"]))
		var wall := MeshInstance3D.new()
		wall.name = "StormWall_%02d" % index
		wall.mesh = QuadMesh.new()
		wall.material_override = storm_wall_material
		wall.position = Vector3(cos(angle) * STORM_WALL_RADIUS, STORM_WALL_HEIGHT + float(data["height"]), sin(angle) * STORM_WALL_RADIUS)
		wall.scale = data["scale"]
		wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		storm_wall_root.add_child(wall)
		wall.look_at(Vector3.ZERO, Vector3.UP)


func _apply_storm_wall_lighting(enabled: bool) -> void:
	if not storm_wall_material:
		return

	if enabled:
		storm_wall_material.set_shader_parameter("cloud_color", Color(0.13, 0.16, 0.24, 1.0))
		storm_wall_material.set_shader_parameter("alpha", 0.24 * zone_cloud_opacity)
		storm_wall_material.set_shader_parameter("cutoff", 0.44)
	else:
		storm_wall_material.set_shader_parameter("cloud_color", Color(0.25, 0.29, 0.29, 1.0))
		storm_wall_material.set_shader_parameter("alpha", 0.32 * zone_cloud_opacity)
		storm_wall_material.set_shader_parameter("cutoff", 0.40)


func _create_moon_visual() -> void:
	if moon_visual:
		return

	moon_visual = MeshInstance3D.new()
	moon_visual.name = "MoonVisual"
	var mesh := SphereMesh.new()
	mesh.radius = 7.5
	mesh.height = 15.0
	mesh.radial_segments = 48
	mesh.rings = 24
	moon_visual.mesh = mesh
	moon_visual.position = MOON_POSITION
	moon_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.70, 0.78, 0.95, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.48, 0.58, 0.95, 1.0)
	material.emission_energy_multiplier = 0.75
	moon_visual.material_override = material
	moon_visual.visible = false
	add_child(moon_visual)

	moon_halo_visual = MeshInstance3D.new()
	moon_halo_visual.name = "MoonHalo"
	var halo_mesh := QuadMesh.new()
	halo_mesh.size = Vector2(58.0, 58.0)
	moon_halo_visual.mesh = halo_mesh
	moon_halo_visual.position = MOON_POSITION + Vector3(0.0, 0.0, 1.0)
	moon_halo_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var halo_shader := Shader.new()
	halo_shader.code = MOON_HALO_SHADER
	var halo_material := ShaderMaterial.new()
	halo_material.shader = halo_shader
	halo_material.set_shader_parameter("halo_color", Color(0.28, 0.38, 0.72, 1.0))
	halo_material.set_shader_parameter("alpha", 0.18)
	moon_halo_visual.material_override = halo_material
	moon_halo_visual.visible = false
	add_child(moon_halo_visual)
	moon_halo_visual.look_at(Vector3.ZERO, Vector3.UP)


func _apply_moon_visibility(enabled: bool) -> void:
	if moon_visual:
		moon_visual.visible = enabled
	if moon_halo_visual:
		moon_halo_visual.visible = enabled


func _create_ground_haze_layer() -> void:
	if ground_haze_root:
		return

	ground_haze_root = Node3D.new()
	ground_haze_root.name = "GroundHazeLayer"
	add_child(ground_haze_root)

	ground_haze_material = _create_ground_haze_material()
	var haze_layout: Array[Dictionary] = [
		{"pos": Vector3(-205, HAZE_LAYER_HEIGHT, -130), "scale": Vector3(160, 1, 28), "rot": 0.42},
		{"pos": Vector3(-72, HAZE_LAYER_HEIGHT + 0.6, -190), "scale": Vector3(205, 1, 32), "rot": -0.25},
		{"pos": Vector3(128, HAZE_LAYER_HEIGHT + 0.4, -142), "scale": Vector3(172, 1, 30), "rot": 0.18},
		{"pos": Vector3(220, HAZE_LAYER_HEIGHT + 0.8, 18), "scale": Vector3(184, 1, 34), "rot": -0.48},
		{"pos": Vector3(74, HAZE_LAYER_HEIGHT + 0.5, 148), "scale": Vector3(230, 1, 36), "rot": 0.13},
		{"pos": Vector3(-172, HAZE_LAYER_HEIGHT + 0.7, 116), "scale": Vector3(190, 1, 30), "rot": -0.34},
		{"pos": Vector3(-252, HAZE_LAYER_HEIGHT + 0.2, -8), "scale": Vector3(150, 1, 26), "rot": 0.04},
		{"pos": Vector3(12, HAZE_LAYER_HEIGHT + 0.9, -12), "scale": Vector3(260, 1, 38), "rot": 0.28}
	]

	for index in range(haze_layout.size()):
		var data: Dictionary = haze_layout[index]
		var haze := MeshInstance3D.new()
		haze.name = "GroundHaze_%02d" % index
		haze.mesh = PlaneMesh.new()
		haze.material_override = ground_haze_material
		haze.position = data["pos"]
		haze.rotation = Vector3(deg_to_rad(88.0), float(data["rot"]), 0.0)
		haze.scale = data["scale"]
		haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ground_haze_root.add_child(haze)


func _create_ground_haze_material() -> ShaderMaterial:
	var noise := FastNoiseLite.new()
	noise.seed = 7391
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.022
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.50

	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 256
	texture.seamless = true
	texture.noise = noise

	var shader := Shader.new()
	shader.code = HAZE_SHADER

	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("haze_noise", texture)
	material.set_shader_parameter("haze_color", Color(0.45, 0.50, 0.48, 1.0))
	material.set_shader_parameter("alpha", 0.18)
	material.set_shader_parameter("cutoff", 0.42)
	return material


func _apply_ground_haze_lighting(enabled: bool) -> void:
	if not ground_haze_material:
		return

	if enabled:
		ground_haze_material.set_shader_parameter("haze_color", Color(0.11, 0.15, 0.22, 1.0))
		ground_haze_material.set_shader_parameter("alpha", 0.13 * zone_fog_intensity)
		ground_haze_material.set_shader_parameter("cutoff", 0.50)
	else:
		ground_haze_material.set_shader_parameter("haze_color", Color(0.34, 0.39, 0.36, 1.0))
		ground_haze_material.set_shader_parameter("alpha", 0.16 * zone_fog_intensity)
		ground_haze_material.set_shader_parameter("cutoff", 0.46)


func _create_air_particles() -> void:
	if air_particles:
		return

	air_particles = GPUParticles3D.new()
	air_particles.name = "ZoneAirParticles"
	air_particles.amount = 180
	air_particles.lifetime = 18.0
	air_particles.preprocess = 18.0
	air_particles.randomness = 0.78
	air_particles.visibility_aabb = AABB(-AIR_PARTICLE_EXTENTS * 0.5, AIR_PARTICLE_EXTENTS)
	air_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.075, 0.075)
	air_particles.draw_pass_1 = mesh

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = Color(0.56, 0.62, 0.58, 0.18)
	material.disable_receive_shadows = true
	mesh.material = material

	var particle_material := ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	particle_material.emission_box_extents = AIR_PARTICLE_EXTENTS
	particle_material.gravity = Vector3(0.0, -0.006, 0.0)
	particle_material.direction = Vector3(-0.45, -0.04, 0.16)
	particle_material.spread = 38.0
	particle_material.initial_velocity_min = 0.018
	particle_material.initial_velocity_max = 0.065
	particle_material.angular_velocity_min = -4.0
	particle_material.angular_velocity_max = 4.0
	particle_material.scale_min = 0.65
	particle_material.scale_max = 1.55
	air_particles.process_material = particle_material

	add_child(air_particles)


func _apply_air_particle_lighting(enabled: bool) -> void:
	if not air_particles:
		return

	air_particles.amount = 240 if enabled else 160
	var mesh := air_particles.draw_pass_1 as Mesh
	if not mesh or not mesh.material:
		return

	var material := mesh.material as StandardMaterial3D
	if not material:
		return

	if enabled:
		material.albedo_color = Color(0.34, 0.44, 0.72, 0.22)
	else:
		material.albedo_color = Color(0.48, 0.55, 0.50, 0.15)


func _update_air_particle_position() -> void:
	if not air_particles:
		return

	var camera := get_viewport().get_camera_3d()
	if camera:
		air_particles.global_position = camera.global_position + Vector3(0.0, 6.0, 0.0)
		return

	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty() and players[0] is Node3D:
		air_particles.global_position = (players[0] as Node3D).global_position + Vector3(0.0, 6.0, 0.0)


func _create_startup_fade() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "StartupFadeCanvas"
	canvas.layer = 100
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)

	startup_fade_rect = ColorRect.new()
	startup_fade_rect.name = "StartupFade"
	startup_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	startup_fade_rect.color = Color.BLACK
	startup_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(startup_fade_rect)


func _set_players_processing_enabled(enabled: bool) -> void:
	var player_process_mode := (Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED) as Node.ProcessMode
	for player in get_tree().get_nodes_in_group("player"):
		player.process_mode = player_process_mode
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO


func _fade_from_black() -> void:
	if not startup_fade_rect:
		return

	var tween := create_tween()
	tween.tween_property(startup_fade_rect, "modulate:a", 0.0, GAMEPLAY_FADE_IN_TIME)
	await tween.finished

	var fade_canvas := startup_fade_rect.get_parent()
	if fade_canvas:
		fade_canvas.queue_free()
	startup_fade_rect = null


func _apply_night_state(enabled: bool) -> void:
	_apply_graphics_settings_to_map(false)
	_apply_atmosphere_state(enabled)


func _apply_atmosphere_state(enabled: bool) -> void:
	if enabled:
		_apply_night_lighting()
	else:
		_apply_day_lighting()
	_apply_cloud_lighting(enabled)
	_apply_storm_wall_lighting(enabled)
	_apply_moon_visibility(enabled)
	_apply_ground_haze_lighting(enabled)
	_apply_air_particle_lighting(enabled)
	_set_player_flashlights(enabled)
	_log_atmosphere_state(enabled)


func _apply_day_lighting() -> void:
	if world_environment and world_environment.environment:
		var env := world_environment.environment
		env.background_mode = Environment.BG_SKY
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_color = Color(0.43, 0.48, 0.45, 1.0)
		env.ambient_light_energy = 0.78
		env.ambient_light_sky_contribution = 0.58
		env.tonemap_mode = Environment.TONE_MAPPER_ACES
		_set_if_property(env, "tonemap_exposure", 0.86)
		_set_if_property(env, "tonemap_white", 4.2)
		env.adjustment_enabled = true
		env.adjustment_brightness = 0.88
		env.adjustment_contrast = 1.13
		env.adjustment_saturation = 0.62
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		env.fog_light_color = Color(0.40, 0.46, 0.45, 1.0)
		env.fog_density = 0.0031 * zone_fog_intensity
		env.fog_sky_affect = 0.84
		env.glow_enabled = true
		env.glow_intensity = 0.11
		_apply_zone_post_process(env, false)
		if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
			var sky := env.sky.sky_material as ProceduralSkyMaterial
			sky.sky_top_color = Color(0.20, 0.24, 0.28, 1.0)
			sky.sky_horizon_color = Color(0.43, 0.47, 0.43, 1.0)
			sky.sky_curve = 0.16
			sky.ground_bottom_color = Color(0.12, 0.11, 0.09, 1.0)
			sky.ground_horizon_color = Color(0.31, 0.32, 0.27, 1.0)

	if directional_light:
		directional_light.visible = true
		directional_light.light_color = Color(0.66, 0.68, 0.57, 1.0)
		directional_light.light_energy = 0.38
		directional_light.rotation_degrees = Vector3(-21.0, 38.0, 0.0)
		_apply_directional_light_mood(false)


func _apply_night_lighting() -> void:
	if world_environment and world_environment.environment:
		var env := world_environment.environment
		env.background_mode = Environment.BG_SKY
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.24, 0.30, 0.42, 1.0)
		env.ambient_light_energy = 1.05
		env.ambient_light_sky_contribution = 0.28
		env.tonemap_mode = Environment.TONE_MAPPER_ACES
		_set_if_property(env, "tonemap_exposure", 1.08)
		_set_if_property(env, "tonemap_white", 4.1)
		env.adjustment_enabled = true
		env.adjustment_brightness = 1.04
		env.adjustment_contrast = 1.04
		env.adjustment_saturation = 0.64
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		env.fog_light_color = Color(0.18, 0.23, 0.34, 1.0)
		env.fog_density = 0.0022 * zone_fog_intensity
		env.fog_sky_affect = 0.36
		env.glow_enabled = true
		env.glow_intensity = 0.08
		_apply_zone_post_process(env, true)
		if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
			var sky := env.sky.sky_material as ProceduralSkyMaterial
			sky.sky_top_color = Color(0.035, 0.050, 0.095, 1.0)
			sky.sky_horizon_color = Color(0.15, 0.17, 0.26, 1.0)
			sky.sky_curve = 0.18
			sky.ground_bottom_color = Color(0.035, 0.040, 0.050, 1.0)
			sky.ground_horizon_color = Color(0.12, 0.13, 0.16, 1.0)

	if directional_light:
		directional_light.visible = true
		directional_light.light_color = Color(0.58, 0.68, 1.0, 1.0)
		directional_light.light_energy = 1.12 * zone_moonlight_intensity
		directional_light.rotation_degrees = Vector3(-58.0, -42.0, 0.0)
		_apply_directional_light_mood(true)


func _set_player_flashlights(enabled: bool) -> void:
	for player in get_tree().get_nodes_in_group("player"):
		if player.has_method("set_flashlight_enabled"):
			player.call("set_flashlight_enabled", enabled)


func _apply_directional_light_mood(enabled: bool) -> void:
	if not directional_light:
		return

	if enabled:
		directional_light.shadow_blur = 0.36
		_set_if_property(directional_light, "light_specular", 0.32)
		_set_if_property(directional_light, "light_angular_distance", 1.05)
	else:
		directional_light.shadow_blur = 0.48
		_set_if_property(directional_light, "light_specular", 0.22)
		_set_if_property(directional_light, "light_angular_distance", 1.45)


func _apply_zone_post_process(env: Environment, enabled: bool) -> void:
	_set_if_property(env, "volumetric_fog_enabled", true)
	_set_if_property(env, "volumetric_fog_length", 96.0 if enabled else 128.0)
	_set_if_property(env, "volumetric_fog_density", (0.020 if enabled else 0.016) * zone_fog_intensity)
	_set_if_property(env, "volumetric_fog_albedo", Color(0.17, 0.22, 0.34, 1.0) if enabled else Color(0.42, 0.46, 0.42, 1.0))
	_set_if_property(env, "volumetric_fog_emission", Color(0.035, 0.055, 0.12, 1.0) if enabled else Color(0.035, 0.040, 0.032, 1.0))
	_set_if_property(env, "volumetric_fog_emission_energy", (0.12 if enabled else 0.04) * zone_moonlight_intensity if enabled else 0.04)
	_set_if_property(env, "volumetric_fog_gi_inject", 0.35 if enabled else 0.18)
	_set_if_property(env, "volumetric_fog_anisotropy", 0.32 if enabled else 0.18)
	_set_if_property(env, "ssao_enabled", true)
	_set_if_property(env, "ssao_radius", 2.8 if enabled else 3.4)
	_set_if_property(env, "ssao_intensity", 1.45 if enabled else 1.15)
	_set_if_property(env, "ssao_power", 1.55 if enabled else 1.35)
	_set_if_property(env, "auto_exposure_enabled", true)
	_set_if_property(env, "auto_exposure_scale", 0.55 if enabled else 0.42)
	_set_if_property(env, "auto_exposure_min_luma", 0.08 if enabled else 0.18)
	_set_if_property(env, "auto_exposure_max_luma", 2.2 if enabled else 3.0)
	_set_if_property(env, "auto_exposure_speed", 0.55)


func _on_graphics_settings_changed(_settings: Dictionary) -> void:
	if suppress_graphics_settings_signal:
		return

	_apply_atmosphere_state(is_night)


func _log_atmosphere_state(enabled: bool) -> void:
	var state_id := "night" if enabled else "day"
	if last_logged_atmosphere_state == state_id:
		return

	last_logged_atmosphere_state = state_id
	if not world_environment or not world_environment.environment or not directional_light:
		return

	var env := world_environment.environment
	print(
		"[ATMOS] %s exposure=%.2f fog=%.4f ambient=%.2f direct=%.2f saturation=%.2f" % [
			state_id,
			float(env.get("tonemap_exposure")),
			env.fog_density,
			env.ambient_light_energy,
			directional_light.light_energy,
			env.adjustment_saturation
		]
	)


func _set_if_property(object: Object, property_name: String, value: Variant) -> void:
	for property in object.get_property_list():
		if property.get("name", "") == property_name:
			object.set(property_name, value)
			return
