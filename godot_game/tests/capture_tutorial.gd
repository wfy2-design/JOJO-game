extends SceneTree

const OUTPUT_DIR := "res://tests/artifacts"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	_save_viewport("menu_mode.png")

	game._open_draft("local", 3, 6, false)
	await process_frame
	await process_frame
	_save_viewport("draft_screen.png")
	game._on_draft_finished({"A": ["night_chain", "mirror_tide", "sun_blade"], "B": ["crimson_thorn", "molten_core", "frost_wing"]}, "local")
	await process_frame
	await process_frame
	_save_viewport("battle_after_draft.png")

	game._return_to_mode()
	await process_frame
	game._open_tutorial()
	await process_frame
	await process_frame
	_save_viewport("tutorial_intro.png")
	game.tutorial_controller._jump_to_chapter("range")
	await process_frame
	await process_frame
	_save_viewport("tutorial_range.png")
	game.tutorial_controller._jump_to_chapter("status")
	game.tutorial_controller._next()
	await process_frame
	_save_viewport("tutorial_status.png")
	game._on_tutorial_exit()
	await process_frame

	game._start_game("local", {"A": ["night_chain", "mirror_tide", "sun_blade"], "B": ["crimson_thorn", "molten_core", "frost_wing"]})
	await process_frame
	game.pause_menu.open_menu()
	await process_frame
	_save_viewport("menu_with_tutorial.png")
	game.pause_menu._show_tutorial_page()
	await process_frame
	await process_frame
	_save_viewport("tutorial_from_menu.png")
	quit()


func _save_viewport(file_name: String) -> void:
	var image := root.get_texture().get_image()
	var result := image.save_png("%s/%s" % [OUTPUT_DIR, file_name])
	if result != OK:
		push_error("Failed to save %s: %s" % [file_name, error_string(result)])
