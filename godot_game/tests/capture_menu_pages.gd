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

	game._open_archive_from_title()
	for i in range(10):
		await process_frame
	_save("archive.png")

	game.pause_menu._go_back()
	for i in range(10):
		await process_frame
	_save("back_to_title.png")

	game._open_settings_from_title()
	for i in range(10):
		await process_frame
	_save("settings.png")
	game.pause_menu._go_back()
	for i in range(10):
		await process_frame

	game._start_game("local", {"A": ["night_chain", "mirror_tide", "sun_blade"], "B": ["crimson_thorn", "molten_core", "frost_wing"]})
	await process_frame
	game.pause_menu.open_menu()
	await process_frame
	game.pause_menu._show_guide_page()
	await process_frame
	await process_frame
	_save("guide.png")
	quit()


func _save(file_name: String) -> void:
	var image := root.get_texture().get_image()
	var result := image.save_png("%s/%s" % [OUTPUT_DIR, file_name])
	if result != OK:
		push_error("Failed to save %s" % file_name)
