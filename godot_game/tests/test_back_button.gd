extends SceneTree

## 验证从 TITLE 打开图鉴/设置后，点「返回」按钮回到 TITLE 而非暂停菜单主菜单。

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	game._open_archive_from_title()
	await process_frame
	await process_frame
	var back := _find_back_button(game)
	_check(back != null, "图鉴页存在「返回」按钮")
	_check(back != null and back.position.x < 320.0, "图鉴页「返回」按钮位于屏幕左侧")
	_check(not game.pause_menu.bottom_hint.visible, "图鉴页不显示底部重复提示文字")
	if back != null:
		back.pressed.emit()
		await process_frame
		await process_frame
		_check(game.start_flow.visible and not game.pause_menu.visible, "图鉴页点返回回到 TITLE")

	game._open_settings_from_title()
	await process_frame
	await process_frame
	var back2 := _find_back_button(game)
	if back2 != null:
		back2.pressed.emit()
		await process_frame
		await process_frame
		_check(game.start_flow.visible and not game.pause_menu.visible, "设置页点返回回到 TITLE")
	else:
		# 设置页没有显式返回按钮，走 Tab/Esc 的 _go_back
		game.pause_menu._go_back()
		await process_frame
		_check(game.start_flow.visible and not game.pause_menu.visible, "设置页 Esc 返回回到 TITLE")

	# 即使标题页来源状态曾残留，游戏内打开菜单也必须建立新的返回上下文。
	game._start_game("local")
	game.start_flow.visible = false
	game.pause_menu.opened_from_title = true
	_check(game.pause_menu.open_menu(), "战斗中可以打开暂停菜单")
	_check(not game.pause_menu.opened_from_title, "战斗菜单会清除标题页来源状态")
	game.pause_menu._show_archive_page()
	game.pause_menu._go_back()
	_check(
		game.pause_menu.visible and game.pause_menu.current_page == PauseMenu.Page.MAIN,
		"战斗中图鉴返回暂停菜单主栏"
	)
	_check(not game.start_flow.visible, "战斗中图鉴返回不会显示游戏开始界面")
	game.pause_menu.close_menu()

	if failures == 0:
		print("ALL BACK BUTTON TESTS PASSED")
	else:
		push_error("%d BACK BUTTON TESTS FAILED" % failures)
	quit(failures)


func _find_back_button(game: Node) -> Button:
	for child in game.pause_menu.content_root.get_children():
		if child is Button and child.text == "返回":
			return child
	return null
