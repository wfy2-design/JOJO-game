extends SceneTree

const OUTPUT_DIR := "res://tests/artifacts"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	for i in range(60):
		await process_frame
	_save("title.png")

	game.start_flow.show_mode()
	for i in range(12):
		await process_frame
	_save("mode_local.png")

	game.start_flow.mode_screen._select(1, true)
	for i in range(12):
		await process_frame
	_save("mode_ai.png")

	game.start_flow.mode_screen._select(2, true)
	for i in range(12):
		await process_frame
	_save("mode_tutorial.png")

	game.start_flow.show_config("local")
	for i in range(12):
		await process_frame
	_save("config.png")
	quit()


func _save(file_name: String) -> void:
	var image := root.get_texture().get_image()
	var result := image.save_png("%s/%s" % [OUTPUT_DIR, file_name])
	if result != OK:
		push_error("Failed to save %s" % file_name)
