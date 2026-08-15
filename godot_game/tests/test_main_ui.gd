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

	_check(BoardView.TILE_WIDTH >= 140.0, "中央棋盘使用放大的格子")
	for unit in game.model.units:
		_check(game.status_label.text.contains(unit["name"]), "%s 的状态常驻显示" % unit["name"])

	game.model.current_unit_id = 4
	game.model._start_unit_turn(true)
	game._refresh()
	var avdol: Dictionary = game.model.current_unit()
	var illumination: Dictionary = avdol["skills"][3]
	var ap_before: int = avdol["ap"]
	game._open_skill_list()
	game._choose_skill(illumination)
	_check(int(avdol["ap"]) == ap_before, "第一次选择技能只展示详情")
	_check(game.previewed_skill_id == "illumination", "技能详情状态记录所选技能")
	_check(game.skill_description.text.contains("再次选择"), "详情栏提示再次选择后发动")
	game._choose_skill(illumination)
	_check(int(game.model.get_unit(4)["ap"]) == ap_before - 1, "第二次选择技能才消耗 AP")

	game._show_critical(4)
	_check(game.critical_overlay.visible, "暴击时显示弱点击破覆盖层")
	_check(game.critical_image.texture != null, "暴击覆盖层加载攻击者图片")
	_check(game.critical_overlay.size.x < 1080.0, "弱点击破图片仅占据棋盘中央")
	_check(game.critical_overlay.position.x >= 266.0, "弱点击破图片不会遮挡左侧状态区")
	_check(game.cinematic_running, "暴击演出期间锁定交互")

	if failures == 0:
		print("ALL UI TESTS PASSED")
	else:
		push_error("%d UI TESTS FAILED" % failures)
	quit(failures)
