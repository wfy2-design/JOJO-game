class_name SilhouetteTransition
extends Control

const WIPE_SHADER := preload("res://ui/menu/silhouette_wipe.gdshader")
const DURATION := 0.26
const SLIDE_DISTANCE := 52.0
const MAIN_RECT := Rect2(0, 0, 840, 790)
const SHADOW_RECT := Rect2(50, 30, 790, 745)

var current_key := ""
var target_key := ""
var outgoing_main: TextureRect
var outgoing_shadow: TextureRect
var incoming_main: TextureRect
var incoming_shadow: TextureRect

var _tween: Tween
var _cover_tween: Tween
var _generation := 0
var _texture_cache: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	outgoing_shadow = _create_layer(SHADOW_RECT, 0.30)
	incoming_shadow = _create_layer(SHADOW_RECT, 0.30)
	outgoing_main = _create_layer(MAIN_RECT, 1.0)
	incoming_main = _create_layer(MAIN_RECT, 1.0)
	_set_pair_progress(outgoing_main, outgoing_shadow, 0.0)
	_set_pair_progress(incoming_main, incoming_shadow, 0.0)


func set_initial(character_key: String, primary: Color, secondary: Color) -> void:
	_kill_transition()
	reset_page_cover_pose()
	current_key = character_key
	target_key = character_key
	_assign_pair(incoming_main, incoming_shadow, character_key, primary, secondary)
	_reset_pair_positions()
	_set_pair_progress(incoming_main, incoming_shadow, 1.0)
	_set_pair_progress(outgoing_main, outgoing_shadow, 0.0)


func transition_to(character_key: String, primary: Color, secondary: Color, move_direction: int) -> void:
	if character_key == target_key:
		return
	_commit_interrupted_target()
	_generation += 1
	var run_id := _generation
	target_key = character_key

	_copy_pair(incoming_main, incoming_shadow, outgoing_main, outgoing_shadow)
	_assign_pair(incoming_main, incoming_shadow, character_key, primary, secondary)
	_set_pair_progress(outgoing_main, outgoing_shadow, 1.0)
	_set_pair_progress(incoming_main, incoming_shadow, 0.0)

	var direction_value := 1.0 if move_direction >= 0 else -1.0
	_set_pair_direction(outgoing_main, outgoing_shadow, direction_value)
	_set_pair_direction(incoming_main, incoming_shadow, direction_value)
	outgoing_main.position = MAIN_RECT.position
	outgoing_shadow.position = SHADOW_RECT.position
	incoming_main.position = MAIN_RECT.position + Vector2(SLIDE_DISTANCE * direction_value, 0)
	incoming_shadow.position = SHADOW_RECT.position + Vector2(SLIDE_DISTANCE * direction_value, 0)

	_tween = create_tween()
	_tween.set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_outgoing_progress, 1.0, 0.0, DURATION * 0.82)
	_tween.tween_method(_set_incoming_progress, 0.0, 1.0, DURATION)
	_tween.tween_property(outgoing_main, "position:x", MAIN_RECT.position.x - SLIDE_DISTANCE * direction_value, DURATION)
	_tween.tween_property(outgoing_shadow, "position:x", SHADOW_RECT.position.x - SLIDE_DISTANCE * direction_value, DURATION)
	_tween.tween_property(incoming_main, "position:x", MAIN_RECT.position.x, DURATION)
	_tween.tween_property(incoming_shadow, "position:x", SHADOW_RECT.position.x, DURATION)
	_tween.finished.connect(func() -> void:
		if run_id != _generation:
			return
		current_key = target_key
		_set_pair_progress(outgoing_main, outgoing_shadow, 0.0)
		_tween = null
	)


func is_transitioning() -> bool:
	return _tween != null and _tween.is_valid()


func play_page_cover(move_direction: int) -> void:
	_commit_interrupted_target()
	if _cover_tween != null and _cover_tween.is_valid():
		_cover_tween.kill()
	pivot_offset = size * 0.5
	scale = Vector2.ONE
	rotation = 0.0
	var direction_value := 1.0 if move_direction >= 0 else -1.0
	_cover_tween = create_tween()
	_cover_tween.set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_cover_tween.tween_property(self, "scale", Vector2(1.18, 1.18), 0.18)
	_cover_tween.tween_property(self, "rotation", 0.016 * direction_value, 0.18)


func reset_page_cover_pose() -> void:
	if _cover_tween != null and _cover_tween.is_valid():
		_cover_tween.kill()
	_cover_tween = null
	scale = Vector2.ONE
	rotation = 0.0


func _create_layer(layer_rect: Rect2, alpha: float) -> TextureRect:
	var layer := TextureRect.new()
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.position = layer_rect.position
	layer.size = layer_rect.size
	layer.modulate.a = alpha
	var shader_material := ShaderMaterial.new()
	shader_material.shader = WIPE_SHADER
	layer.material = shader_material
	add_child(layer)
	return layer


func _assign_pair(main: TextureRect, shadow: TextureRect, character_key: String, primary: Color, secondary: Color) -> void:
	var texture_data := _texture_for(character_key)
	main.texture = texture_data["texture"]
	shadow.texture = texture_data["texture"]
	_set_material_value(main, "theme_color", primary)
	_set_material_value(shadow, "theme_color", secondary)
	_set_material_value(main, "remove_white", texture_data["remove_white"])
	_set_material_value(shadow, "remove_white", texture_data["remove_white"])


func _copy_pair(source_main: TextureRect, source_shadow: TextureRect, destination_main: TextureRect, destination_shadow: TextureRect) -> void:
	destination_main.texture = source_main.texture
	destination_shadow.texture = source_shadow.texture
	for parameter in ["theme_color", "remove_white"]:
		_set_material_value(destination_main, parameter, _material_value(source_main, parameter))
		_set_material_value(destination_shadow, parameter, _material_value(source_shadow, parameter))


func _texture_for(character_key: String) -> Dictionary:
	if _texture_cache.has(character_key):
		return _texture_cache[character_key]
	var character := MenuThemeData.character_by_key(character_key)
	var texture_path := str(character.get("silhouette_texture", character.get("portrait_texture", character["texture"])))
	var texture: Texture2D = load(texture_path)
	var image := texture.get_image()
	var data := {
		"texture": texture,
		"remove_white": 1.0 if image == null or image.detect_alpha() == Image.ALPHA_NONE else 0.0,
	}
	_texture_cache[character_key] = data
	return data


func _commit_interrupted_target() -> void:
	if _tween == null or not _tween.is_valid():
		return
	_tween.kill()
	_tween = null
	_generation += 1
	current_key = target_key
	_set_pair_progress(incoming_main, incoming_shadow, 1.0)
	_set_pair_progress(outgoing_main, outgoing_shadow, 0.0)
	_reset_pair_positions()


func _kill_transition() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_generation += 1


func _reset_pair_positions() -> void:
	outgoing_main.position = MAIN_RECT.position
	outgoing_shadow.position = SHADOW_RECT.position
	incoming_main.position = MAIN_RECT.position
	incoming_shadow.position = SHADOW_RECT.position


func _set_outgoing_progress(value: float) -> void:
	_set_pair_progress(outgoing_main, outgoing_shadow, value)


func _set_incoming_progress(value: float) -> void:
	_set_pair_progress(incoming_main, incoming_shadow, value)


func _set_pair_progress(main: TextureRect, shadow: TextureRect, value: float) -> void:
	_set_material_value(main, "progress", value)
	_set_material_value(shadow, "progress", value)


func _set_pair_direction(main: TextureRect, shadow: TextureRect, value: float) -> void:
	_set_material_value(main, "direction", value)
	_set_material_value(shadow, "direction", value)


func _set_material_value(layer: TextureRect, parameter: StringName, value: Variant) -> void:
	(layer.material as ShaderMaterial).set_shader_parameter(parameter, value)


func _material_value(layer: TextureRect, parameter: StringName) -> Variant:
	return (layer.material as ShaderMaterial).get_shader_parameter(parameter)
