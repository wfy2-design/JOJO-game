extends SceneTree

const OUTPUT_DIR := "res://tests/artifacts"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._start_game("local", {"A": ["night_chain", "mirror_tide", "sun_blade"], "B": ["crimson_thorn", "molten_core", "frost_wing"]}, 6, false)
	await process_frame
	await process_frame
	game.model.fields.append({"type": "fire_wall", "cell": Vector2i(2, 2), "owner_id": 4, "owner_turns_left": 2})
	game._refresh()
	for i in range(40):
		await process_frame
	_save("fire_wall.png")

	game.board.play_ice_effect(Vector2i(3, 3))
	for i in range(40):
		await process_frame
	_save("ice_effect.png")
	quit()


func _save(file_name: String) -> void:
	var image := root.get_texture().get_image()
	var result := image.save_png("%s/%s" % [OUTPUT_DIR, file_name])
	if result != OK:
		push_error("Failed to save %s" % file_name)
