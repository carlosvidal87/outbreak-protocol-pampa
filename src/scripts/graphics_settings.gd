extends Node

signal settings_changed(settings: Dictionary)

const CONFIG_PATH := "user://graphics_settings.cfg"
const CONFIG_VERSION := 1
const DEFAULT_PRESET_ID := "low"

const SCHEMA_PATHS := [
	"display.window_mode",
	"display.vsync",
	"display.fps_limit",
	"render.scale_3d",
	"render.aa_mode",
	"render.taa",
	"quality.camera_far",
	"quality.shadow_quality",
	"quality.shadow_distance",
	"quality.fog",
	"quality.glow",
	"quality.ssao",
	"quality.terrain_detail_distance",
	"quality.flashlight_shadows"
]

const PRESET_MANAGED_PATHS := [
	"render.scale_3d",
	"render.aa_mode",
	"render.taa",
	"quality.camera_far",
	"quality.shadow_quality",
	"quality.shadow_distance",
	"quality.fog",
	"quality.glow",
	"quality.ssao",
	"quality.terrain_detail_distance",
	"quality.flashlight_shadows"
]

const PRESET_LABELS := {
	"low": "PC FRACO",
	"medium": "EQUILIBRADO",
	"high": "QUALIDADE",
	"custom": "PERSONALIZADO"
}

const PRESET_TEMPLATES := {
	"low": {
		"display": {
			"window_mode": DisplayServer.WINDOW_MODE_WINDOWED,
			"vsync": DisplayServer.VSYNC_ENABLED,
			"fps_limit": 0
		},
		"render": {
			"scale_3d": 0.65,
			"aa_mode": "disabled",
			"taa": false
		},
		"quality": {
			"camera_far": 250.0,
			"shadow_quality": "off",
			"shadow_distance": 140.0,
			"fog": false,
			"glow": false,
			"ssao": false,
			"terrain_detail_distance": 180.0,
			"flashlight_shadows": false
		}
	},
	"medium": {
		"display": {
			"window_mode": DisplayServer.WINDOW_MODE_WINDOWED,
			"vsync": DisplayServer.VSYNC_ENABLED,
			"fps_limit": 0
		},
		"render": {
			"scale_3d": 0.85,
			"aa_mode": "fxaa",
			"taa": false
		},
		"quality": {
			"camera_far": 400.0,
			"shadow_quality": "hard",
			"shadow_distance": 260.0,
			"fog": true,
			"glow": true,
			"ssao": false,
			"terrain_detail_distance": 320.0,
			"flashlight_shadows": false
		}
	},
	"high": {
		"display": {
			"window_mode": DisplayServer.WINDOW_MODE_WINDOWED,
			"vsync": DisplayServer.VSYNC_ENABLED,
			"fps_limit": 0
		},
		"render": {
			"scale_3d": 1.0,
			"aa_mode": "msaa_2x",
			"taa": true
		},
		"quality": {
			"camera_far": 600.0,
			"shadow_quality": "soft",
			"shadow_distance": 500.0,
			"fog": true,
			"glow": true,
			"ssao": true,
			"terrain_detail_distance": 500.0,
			"flashlight_shadows": true
		}
	}
}

var _settings: Dictionary = {}


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	load_settings()


func load_settings() -> void:
	_settings = get_preset_settings(DEFAULT_PRESET_ID)

	var config := ConfigFile.new()
	var err := config.load(CONFIG_PATH)
	if err == OK:
		var version := int(config.get_value("meta", "config_version", 0))
		if version == CONFIG_VERSION:
			for path in SCHEMA_PATHS:
				var parts: PackedStringArray = path.split(".")
				if config.has_section_key(parts[0], parts[1]):
					set_setting(path, config.get_value(parts[0], parts[1]))
		else:
			var legacy_preset := str(config.get_value("graphics", "preset", DEFAULT_PRESET_ID))
			if PRESET_TEMPLATES.has(legacy_preset):
				_settings = get_preset_settings(legacy_preset)

	_settings["preset_id"] = get_matching_preset_id(_settings)
	_apply_global_display_settings()
	_emit_settings_changed()


func save_settings() -> bool:
	var config := ConfigFile.new()
	config.set_value("meta", "config_version", CONFIG_VERSION)
	config.set_value("graphics", "preset_id", str(_settings.get("preset_id", DEFAULT_PRESET_ID)))

	for path in SCHEMA_PATHS:
		var parts: PackedStringArray = path.split(".")
		config.set_value(parts[0], parts[1], get_setting(path))

	var save_error: int = config.save(CONFIG_PATH)
	if save_error != OK:
		push_warning("GraphicsSettings nao conseguiu salvar %s. Erro: %d" % [CONFIG_PATH, save_error])
		return false
	return true


func get_settings() -> Dictionary:
	return _settings.duplicate(true)


func get_setting(path: String, fallback: Variant = null) -> Variant:
	return _get_nested_value(_settings, path, fallback)


func set_setting(path: String, value: Variant) -> void:
	_set_nested_value(_settings, path, _coerce_setting_value(path, value))
	_settings["preset_id"] = get_matching_preset_id(_settings)


func apply_to_viewport(viewport: Viewport) -> void:
	if not viewport:
		return

	_apply_global_display_settings()

	viewport.scaling_3d_scale = clampf(float(get_setting("render.scale_3d", 1.0)), 0.5, 1.0)
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED

	match str(get_setting("render.aa_mode", "disabled")):
		"fxaa":
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		"msaa_2x":
			viewport.msaa_3d = Viewport.MSAA_2X
		"msaa_4x":
			viewport.msaa_3d = Viewport.MSAA_4X

	viewport.use_taa = bool(get_setting("render.taa", false))
	_emit_settings_changed()


func apply_to_scene(root: Node) -> void:
	if not root:
		return

	_apply_global_display_settings()

	var camera_far := float(get_setting("quality.camera_far", 400.0))
	for camera in root.find_children("*", "Camera3D", true, false):
		(camera as Camera3D).far = camera_far

	var directional_light := root.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if directional_light:
		_apply_directional_light_settings(directional_light)

	var world_environment := root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_environment and world_environment.environment:
		var env := world_environment.environment
		env.fog_enabled = bool(get_setting("quality.fog", true))
		env.glow_enabled = bool(get_setting("quality.glow", true))
		env.ssao_enabled = bool(get_setting("quality.ssao", false))

	for terrain_detail in root.find_children("HTerrainDetailLayer", "Node3D", true, false):
		_apply_terrain_detail_distance(terrain_detail)

	for flashlight in root.find_children("Flashlight", "SpotLight3D", true, false):
		_apply_flashlight_shadow_state(flashlight as SpotLight3D)

	_emit_settings_changed()


func apply_to_menu_preview(root: Node) -> void:
	if not root:
		return

	var preview_viewport := root.get_viewport()
	if preview_viewport:
		preview_viewport.scaling_3d_scale = minf(clampf(float(get_setting("render.scale_3d", 1.0)), 0.5, 1.0), 0.85)
		preview_viewport.msaa_3d = Viewport.MSAA_DISABLED
		preview_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		if str(get_setting("render.aa_mode", "disabled")) != "disabled":
			preview_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		preview_viewport.use_taa = false
		if preview_viewport is SubViewport:
			(preview_viewport as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE

	var menu_camera := root.find_child("MenuCamera", true, false) as Camera3D
	if menu_camera:
		menu_camera.far = 24.0

	var world_environment := root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if world_environment and world_environment.environment:
		var env := world_environment.environment
		env.fog_enabled = bool(get_setting("quality.fog", true))
		env.glow_enabled = bool(get_setting("quality.glow", true))
		env.ssao_enabled = false

	for light in root.find_children("*", "Light3D", true, false):
		var light_3d := light as Light3D
		light_3d.shadow_enabled = false
		if light_3d is DirectionalLight3D:
			(light_3d as DirectionalLight3D).directional_shadow_max_distance = 0.0

	_emit_settings_changed()


func apply_preset(preset_id: String) -> void:
	if not PRESET_TEMPLATES.has(preset_id):
		return

	var current_display: Dictionary = (get_setting("display", {}) as Dictionary).duplicate(true)
	_settings = get_preset_settings(preset_id)
	_settings["display"] = current_display
	_settings["preset_id"] = preset_id
	_apply_global_display_settings()
	_emit_settings_changed()


func reset_to_defaults() -> void:
	apply_preset(DEFAULT_PRESET_ID)


func get_available_presets() -> Dictionary:
	return PRESET_LABELS.duplicate(true)


func get_preset_settings(preset_id: String) -> Dictionary:
	if not PRESET_TEMPLATES.has(preset_id):
		preset_id = DEFAULT_PRESET_ID

	var preset: Dictionary = PRESET_TEMPLATES[preset_id].duplicate(true)
	preset["display"] = _get_runtime_display_defaults()
	preset["preset_id"] = preset_id
	return preset


func get_matching_preset_id(settings: Dictionary = {}) -> String:
	var source := settings if not settings.is_empty() else _settings
	for preset_id in ["low", "medium", "high"]:
		var preset: Dictionary = PRESET_TEMPLATES[preset_id]
		var is_match := true
		for path in PRESET_MANAGED_PATHS:
			if _get_nested_value(source, path) != _get_nested_value(preset, path):
				is_match = false
				break
		if is_match:
			return preset_id
	return "custom"


func get_schema_paths() -> Array[String]:
	var paths: Array[String] = []
	for path in SCHEMA_PATHS:
		paths.append(path)
	return paths


func get_default_preset_id() -> String:
	return DEFAULT_PRESET_ID


func _apply_global_display_settings() -> void:
	var window_mode: DisplayServer.WindowMode = _get_window_mode_value(get_setting("display.window_mode", DisplayServer.WINDOW_MODE_WINDOWED))
	var vsync_mode: DisplayServer.VSyncMode = _get_vsync_mode_value(get_setting("display.vsync", DisplayServer.VSYNC_ENABLED))
	DisplayServer.window_set_mode(window_mode)
	DisplayServer.window_set_vsync_mode(vsync_mode)
	Engine.max_fps = int(get_setting("display.fps_limit", 0))


func _get_runtime_display_defaults() -> Dictionary:
	return {
		"window_mode": DisplayServer.window_get_mode(),
		"vsync": DisplayServer.window_get_vsync_mode(),
		"fps_limit": Engine.max_fps
	}


func _apply_directional_light_settings(light: DirectionalLight3D) -> void:
	var shadow_quality := str(get_setting("quality.shadow_quality", "off"))
	light.shadow_enabled = shadow_quality != "off"
	light.directional_shadow_max_distance = float(get_setting("quality.shadow_distance", 250.0))
	if shadow_quality == "soft":
		light.shadow_blur = 0.18
	else:
		light.shadow_blur = 0.0


func _apply_flashlight_shadow_state(flashlight: SpotLight3D) -> void:
	var allow_shadows := str(get_setting("quality.shadow_quality", "off")) != "off"
	flashlight.shadow_enabled = flashlight.visible and allow_shadows and bool(get_setting("quality.flashlight_shadows", false))


func _apply_terrain_detail_distance(node: Node) -> void:
	var detail_distance := float(get_setting("quality.terrain_detail_distance", 250.0))
	if _has_property(node, "view_distance"):
		node.set("view_distance", detail_distance)
	elif node.has_method("set_view_distance"):
		node.call("set_view_distance", detail_distance)


func _coerce_setting_value(path: String, value: Variant) -> Variant:
	match path:
		"display.window_mode":
			return int(_get_window_mode_value(value))
		"display.vsync":
			return int(_get_vsync_mode_value(value))
		"display.fps_limit":
			return int(value)
		"render.scale_3d", "quality.camera_far", "quality.shadow_distance", "quality.terrain_detail_distance":
			return float(value)
		"render.taa", "quality.fog", "quality.glow", "quality.ssao", "quality.flashlight_shadows":
			return bool(value)
		"render.aa_mode", "quality.shadow_quality":
			return str(value)
	return value


func _get_window_mode_value(value: Variant) -> DisplayServer.WindowMode:
	var window_mode: int = int(value)
	if window_mode < 0 or window_mode > 4:
		window_mode = int(DisplayServer.WINDOW_MODE_WINDOWED)
	return window_mode as DisplayServer.WindowMode


func _get_vsync_mode_value(value: Variant) -> DisplayServer.VSyncMode:
	var vsync_mode: int = int(value)
	if vsync_mode < 0 or vsync_mode > 3:
		vsync_mode = int(DisplayServer.VSYNC_ENABLED)
	return vsync_mode as DisplayServer.VSyncMode


func _get_nested_value(source: Dictionary, path: String, fallback: Variant = null) -> Variant:
	var current: Variant = source
	for key in path.split("."):
		if current is Dictionary and current.has(key):
			current = current[key]
		else:
			return fallback
	return current


func _set_nested_value(target: Dictionary, path: String, value: Variant) -> void:
	var parts: PackedStringArray = path.split(".")
	var current: Dictionary = target
	for index in range(parts.size() - 1):
		var key := parts[index]
		if not current.has(key) or not (current[key] is Dictionary):
			current[key] = {}
		current = current[key] as Dictionary
	current[parts[parts.size() - 1]] = value


func _has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if property.get("name", "") == property_name:
			return true
	return false


func _emit_settings_changed() -> void:
	settings_changed.emit(get_settings())
