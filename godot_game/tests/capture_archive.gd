extends SceneTree

const OUTPUT_DIR := "res://tests/artifacts"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._start_game("local", {"A": ["night_chain", "mirror_tide", "sun_blade"], "B": ["crimson_thorn", "molten_core", "frost_wing"]})
	await process_frame
	game.pause_menu.open_menu()
	await process_frame
	game.pause_menu._show_archive_page()
	await process_frame
	for index in range(6):
		game.pause_menu._select_archive_character(index)
		await process_frame
		await process_frame
		_save_viewport("archive_%d.png" % index)
	quit()


func _save_viewport(file_name: String) -> void:
	var image := root.get_texture().get_image()
	var result := image.save_png("%s/%s" % [OUTPUT_DIR, file_name])
	if result != OK:
		push_error("Failed to save %s" % file_name)
