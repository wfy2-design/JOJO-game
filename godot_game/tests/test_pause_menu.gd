extends SceneTree

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
	game._start_game("local")
	await process_frame

	var actor_before: int = game.model.current_unit_id
	var ui_mode_before: int = game.ui_mode
	var tab_event := InputEventKey.new()
	tab_event.keycode = KEY_TAB
	tab_event.physical_keycode = KEY_TAB
	tab_event.pressed = true
	Input.parse_input_event(tab_event)
	await process_frame
	_check(game.pause_menu.is_open(), "物理 Tab 输入可以打开暂停菜单")
	_check(game.pause_menu.visible, "暂停菜单全屏层可见")
	_check(paused, "打开菜单后 SceneTree 暂停")
	_check(game.pause_menu.main_buttons.size() == 6, "主菜单包含六个入口")
	_check(game.pause_menu.silhouette.size.y <= 800.0, "主菜单立绘剪影已适当缩小")
	_check(game.pause_menu.silhouette.position.y >= 0.0, "主菜单立绘剪影顶部不超出屏幕")
	_check(game.pause_menu.silhouette.position.y + game.pause_menu.silhouette.size.y <= 900.0, "主菜单立绘剪影底部不超出屏幕")
	_check(game.pause_menu.silhouette.get_parent() == game.pause_menu.content_root, "立绘剪影不再受右侧边框限制")
	_check(game.pause_menu.silhouette_shadow != null, "主菜单包含副色残影层")
	var expected_labels := ["CONTINUE", "ARCHIVE", "GUIDE", "TUTORIAL", "SETTINGS", "EXIT"]
	for index in expected_labels.size():
		_check(game.pause_menu.main_buttons[index].text.contains(expected_labels[index]), "主入口使用英文：%s" % expected_labels[index])

	game.pause_menu._select_main_item(1, false)
	_check(game.pause_menu.current_character_key == "crimson_thorn", "ARCHIVE 对应绯棘主题")
	game.pause_menu._show_archive_page()
	_check(game.pause_menu.current_page == PauseMenu.Page.ARCHIVE, "可进入中文图鉴页")
	game.pause_menu._select_archive_character(5)
	_check(game.pause_menu.archive_name.text.contains("霜翊"), "图鉴包含第六名角色霜翊")
	_check(not game.pause_menu.archive_story.text.is_empty(), "图鉴显示角色背景故事")
	game.pause_menu._set_archive_tab("skills")
	var skill_scroll: ScrollContainer = game.pause_menu.archive_content.get_child(0)
	var skill_box: VBoxContainer = skill_scroll.get_child(0)
	_check(skill_box.get_child_count() == 4, "图鉴技能页显示角色全部四个技能")

	game.pause_menu._show_guide_page()
	for index in MenuThemeData.RULE_PAGES.size():
		game.pause_menu.rule_page_index = index
		game.pause_menu._update_rule_page()
		_check(game.pause_menu.rule_title.text == MenuThemeData.RULE_PAGES[index]["title"], "规则第 %d 页内容可访问" % (index + 1))

	game.pause_menu._show_settings_page()
	for bus_name in ["BGM", "SE", "Voice"]:
		_check(AudioServer.get_bus_index(bus_name) >= 0, "存在 %s 音频总线接口" % bus_name)
	game.pause_menu._set_bus_volume(0.37, "BGM")
	var config := ConfigFile.new()
	_check(config.load("user://settings.cfg") == OK, "设置保存到 user://settings.cfg")
	_check(is_equal_approx(float(config.get_value("audio", "bgm", 0.0)), 0.37), "音量设置可以持久化")

	game.pause_menu._go_back()
	_check(game.pause_menu.current_page == PauseMenu.Page.MAIN and game.pause_menu.visible, "子页返回主菜单")
	game.pause_menu._go_back()
	_check(not game.pause_menu.visible and not paused, "主菜单返回战斗并解除暂停")
	_check(game.model.current_unit_id == actor_before and game.ui_mode == ui_mode_before, "关闭菜单保持战斗操作状态")

	game._return_to_title()
	_check(not game.pause_menu.open_menu(), "标题模式选择页不能打开战斗菜单")
	game._start_game("ai")
	await process_frame
	var ai_actor_before: int = game.model.current_unit_id
	var events_before: int = game.model.events.size()
	_check(game.ai_running, "AI 回合已经进入等待阶段")
	game.pause_menu.open_menu()
	await create_timer(0.65, true).timeout
	_check(game.model.current_unit_id == ai_actor_before and game.model.events.size() == events_before, "菜单暂停期间 AI 不推进")
	game.pause_menu.close_menu()
	await create_timer(1.2, true).timeout
	_check(game.model.current_unit_id != ai_actor_before or game.model.events.size() > events_before, "关闭菜单后 AI 恢复行动")

	game.pause_menu.open_menu()
	game.pause_menu._show_settings_page()
	game.pause_menu._show_confirmation("title", "测试返回标题")
	game.pause_menu._confirm_yes()
	_check(game.start_flow.visible and not game.pause_menu.enabled, "返回标题回到标题页并禁用战斗菜单")

	if failures == 0:
		print("ALL PAUSE MENU TESTS PASSED")
	else:
		push_error("%d PAUSE MENU TESTS FAILED" % failures)
	quit(failures)
