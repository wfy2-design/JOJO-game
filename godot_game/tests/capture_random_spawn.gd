extends SceneTree

const OUTPUT_DIR := "res://tests/artifacts"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game._start_game("local", {"A": ["night_chain", "mirror_tide", "sun_blade"], "B": ["crimson_thorn", "molten_core", "frost_wing"]}, 6, true)
	await process_frame
	await process_frame
	_save("battle_random_spawn.png")
	for unit in game.model.units:
		print("POS ", unit["name"], " team=", unit["team"], " pos=", unit["pos"])
	quit()


func _save(file_name: String) -> void:
	var image := root.get_texture().get_image()
	var result := image.save_png("%s/%s" % [OUTPUT_DIR, file_name])
	if result != OK:
		push_error("Failed to save %s" % file_name)
