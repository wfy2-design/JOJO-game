extends SceneTree

const OUTPUT_DIR := "res://tests/artifacts"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._start_game("local")
	await process_frame
	await process_frame
	_save_viewport("battle_main.png")

	var overlap_cell := Vector2i(2, 2)
	game.model.get_unit(0)["pos"] = overlap_cell
	game.model.get_unit(3)["pos"] = overlap_cell
	game.model.get_unit(4)["pos"] = overlap_cell
	game.model.get_unit(5)["pos"] = Vector2i(5, 2)
	game.model.get_unit(3)["luck"] = 0
	game.model.get_unit(4)["luck"] = 0
	game.model.get_unit(5)["luck"] = 0
	game.model.current_unit_id = 0
	game.model._start_unit_turn(true)
	game._refresh()
	game._select_attack()
	await process_frame
	await process_frame
	_save_viewport("battle_targeting.png")

	game._on_board_unit_hovered(4)
	await process_frame
	await process_frame
	_save_viewport("battle_selected_target.png")

	game._show_critical(0)
	await process_frame
	_save_viewport("battle_critical.png")
	await create_timer(1.6).timeout

	game.pause_menu.open_menu()
	await process_frame
	await process_frame
	_save_viewport("menu_main.png")
	game.pause_menu._select_main_item(1)
	await process_frame
	_save_viewport("menu_transition_start.png")
	await create_timer(0.11, true).timeout
	_save_viewport("menu_transition_middle.png")
	await create_timer(0.18, true).timeout
	_save_viewport("menu_transition_end.png")

	game.pause_menu._activate_main_item("archive")
	await process_frame
	_save_viewport("menu_page_cover_start.png")
	await create_timer(0.11, true).timeout
	await process_frame
	_save_viewport("menu_page_cover_middle.png")
	while game.pause_menu.current_page == PauseMenu.Page.MAIN:
		await process_frame
	_save_viewport("menu_page_cover_peak.png")
	await create_timer(0.08, true).timeout
	await process_frame
	_save_viewport("menu_page_cover_reveal.png")
	while game.pause_menu.page_transition_active:
		await process_frame
	_save_viewport("menu_archive.png")

	game.pause_menu._show_settings_page()
	await process_frame
	await process_frame
	_save_viewport("menu_settings.png")
	game.pause_menu.close_menu()
	quit()


func _save_viewport(file_name: String) -> void:
	var image := root.get_texture().get_image()
	var result := image.save_png("%s/%s" % [OUTPUT_DIR, file_name])
	if result != OK:
		push_error("Failed to save %s: %s" % [file_name, error_string(result)])
