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
	_save("mode_menu.png")
	game._show_size_menu("local")
	await process_frame
	await process_frame
	_save("size_menu.png")
	game._show_board_menu("local", 2)
	await process_frame
	await process_frame
	_save("board_menu.png")
	game._open_draft("local", 2, 6)
	await process_frame
	await process_frame
	_save("draft_2v2.png")
	quit()


func _save(file_name: String) -> void:
	var image := root.get_texture().get_image()
	var result := image.save_png("%s/%s" % [OUTPUT_DIR, file_name])
	if result != OK:
		push_error("Failed to save %s" % file_name)
