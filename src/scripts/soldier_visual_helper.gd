extends RefCounted

const DEFAULT_ANIM_LIBRARY := "pistol"
const DEFAULT_RIGHT_HAND_BONE := "mixamorig:RightHand"
const DEFAULT_PISTOL_PATH := "res://assets/weapons/blaster-a.glb"


static func setup_pistol_animation_library(
	soldier_model: Node,
	animations: Dictionary,
	library_name := DEFAULT_ANIM_LIBRARY
) -> AnimationPlayer:
	return setup_animation_library(soldier_model, animations, library_name)


static func setup_animation_library(
	soldier_model: Node,
	animations: Dictionary,
	library_name := DEFAULT_ANIM_LIBRARY
) -> AnimationPlayer:
	var anim_player := find_animation_player(soldier_model)
	if not anim_player:
		push_warning("Soldier sem AnimationPlayer. Animacoes nao foram carregadas.")
		return null

	if anim_player.has_animation_library(library_name):
		anim_player.remove_animation_library(library_name)

	var library := AnimationLibrary.new()
	for state in animations.keys():
		var path := str(animations[state])
		var animation := load_first_animation_from_scene(path)
		if not animation:
			push_warning("Nao foi possivel carregar animacao do Soldier: %s" % path)
			continue

		if state == "jump" or state == "stop_walk":
			animation.loop_mode = Animation.LOOP_NONE
		else:
			animation.loop_mode = Animation.LOOP_LINEAR
		strip_horizontal_root_motion(animation)
		library.add_animation(str(state), animation)

	if library.get_animation_list().is_empty():
		push_warning("Nenhuma animacao do Soldier foi carregada.")
		return null

	anim_player.add_animation_library(library_name, library)
	return anim_player


static func play_animation(anim_player: AnimationPlayer, library_name: String, state: String, blend := 0.15) -> bool:
	if not anim_player:
		return false

	var anim_name := "%s/%s" % [library_name, state]
	if not anim_player.has_animation(anim_name):
		return false

	anim_player.play(anim_name, blend)
	return true


static func attach_pistol_to_hand(
	soldier_model: Node,
	bone_name := DEFAULT_RIGHT_HAND_BONE,
	pistol_path := DEFAULT_PISTOL_PATH,
	offset := Vector3.ZERO,
	rotation := Vector3.ZERO,
	scale := Vector3.ONE
) -> Dictionary:
	var skeleton := find_skeleton(soldier_model)
	if not skeleton:
		push_warning("Soldier sem Skeleton3D. Pistola terceira pessoa nao foi anexada.")
		return {"ok": false, "attachment": null, "pistol": null}

	var resolved_bone_name := resolve_bone_name(skeleton, bone_name)
	if resolved_bone_name.is_empty():
		push_warning("Osso da mao direita nao encontrado no Soldier: %s" % bone_name)
		return {"ok": false, "attachment": null, "pistol": null}

	var attachment := BoneAttachment3D.new()
	attachment.name = "ThirdPersonPistolAttachment"
	attachment.bone_name = resolved_bone_name
	skeleton.add_child(attachment)

	var packed_scene := load(pistol_path) as PackedScene
	if not packed_scene:
		push_warning("Modelo da pistola terceira pessoa nao carregou: %s" % pistol_path)
		return {"ok": false, "attachment": attachment, "pistol": null}

	var pistol := packed_scene.instantiate() as Node3D
	if not pistol:
		push_warning("Modelo da pistola terceira pessoa nao e Node3D: %s" % pistol_path)
		return {"ok": false, "attachment": attachment, "pistol": null}

	attachment.add_child(pistol)
	pistol.position = offset
	pistol.rotation = rotation
	pistol.scale = scale
	return {"ok": true, "attachment": attachment, "pistol": pistol}


static func find_animation_player(root: Node) -> AnimationPlayer:
	if not root:
		return null
	if root is AnimationPlayer:
		return root as AnimationPlayer

	for child in root.get_children():
		var found := find_animation_player(child)
		if found:
			return found

	return null


static func find_skeleton(root: Node) -> Skeleton3D:
	if not root:
		return null
	if root is Skeleton3D:
		return root as Skeleton3D

	for child in root.get_children():
		var found := find_skeleton(child)
		if found:
			return found

	return null


static func resolve_bone_name(skeleton: Skeleton3D, preferred_name: String) -> String:
	if skeleton.find_bone(preferred_name) != -1:
		return preferred_name

	var direct_candidates := [
		"RightHand",
		"right_hand",
		"mixamorig_RightHand",
		"mixamorigRightHand",
		"mixamorig:RightHand"
	]
	for candidate in direct_candidates:
		if skeleton.find_bone(candidate) != -1:
			return candidate

	for i in range(skeleton.get_bone_count()):
		var bone_name := skeleton.get_bone_name(i)
		var normalized := bone_name.to_lower()
		normalized = normalized.replace(":", "")
		normalized = normalized.replace("_", "")
		normalized = normalized.replace("-", "")
		normalized = normalized.replace(" ", "")
		if normalized.ends_with("righthand") or normalized.contains("righthand"):
			return bone_name

	return ""


static func load_first_animation_from_scene(path: String) -> Animation:
	var packed_scene := load(path) as PackedScene
	if not packed_scene:
		return null

	var scene := packed_scene.instantiate()
	var source_player := find_animation_player(scene)
	if not source_player:
		scene.free()
		return null

	for anim_name in source_player.get_animation_list():
		if String(anim_name) == "RESET":
			continue
		var animation := source_player.get_animation(anim_name)
		scene.free()
		return animation.duplicate(true) as Animation

	scene.free()
	return null


static func strip_horizontal_root_motion(animation: Animation) -> void:
	for track_idx in range(animation.get_track_count()):
		if animation.track_get_type(track_idx) != Animation.TYPE_POSITION_3D:
			continue
		if not is_root_motion_position_track(animation.track_get_path(track_idx)):
			continue

		for key_idx in range(animation.track_get_key_count(track_idx)):
			var value = animation.track_get_key_value(track_idx, key_idx)
			if value is Vector3:
				var position := value as Vector3
				position.x = 0.0
				position.z = 0.0
				animation.track_set_key_value(track_idx, key_idx, position)


static func is_root_motion_position_track(track_path: NodePath) -> bool:
	var path_text := String(track_path)
	if path_text.contains("mixamorig:Hips"):
		return true
	return not path_text.contains("mixamorig:")
