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

	_check(BoardView.TILE_WIDTH >= 160.0, "中央棋盘格进一步放大")
	_check(game.status_rows.size() == 6, "左下状态区显示六名角色头像框")
	for unit in game.model.units:
		var status_row: Dictionary = game.status_rows[int(unit["id"])]
		_check(status_row["avatar"].texture != null, "%s 的头像框可见" % unit["name"])
		_check(status_row["hp_label"].text.contains("HP"), "%s 的血量常驻显示" % unit["name"])
		_check(status_row["ap_label"].text.contains("AP"), "%s 的 AP 常驻显示" % unit["name"])
		_check(not status_row["avatar"].is_ancestor_of(status_row["ap_label"]), "%s 的 AP 不遮挡头像框" % unit["name"])
	_check(game.status_rows[5]["row"].get_global_rect().end.y <= 854.0, "六个头像状态行不会超出左下状态面板")
	_check(game.wait_button != null, "操作栏提供不行动选项")

	game._select_attack()
	var zero_hit_cell := Vector2i(0, 0)
	_check(game.board.highlights.has(zero_hit_cell), "全员超出射程时攻击键仍显示敌方占人格")
	var zero_heat: Dictionary = game.board.highlights[zero_hit_cell]
	_check(is_equal_approx(float(zero_heat["hit"]), 0.0), "超出攻击距离的角色格显示 0% 命中")
	game._cancel_or_undo()

	var overlap_cell := Vector2i(2, 2)
	var far_cell := Vector2i(5, 2)
	var attacker: Dictionary = game.model.get_unit(0)
	var first_target: Dictionary = game.model.get_unit(3)
	var clicked_target: Dictionary = game.model.get_unit(4)
	var far_target: Dictionary = game.model.get_unit(5)
	attacker["pos"] = overlap_cell
	first_target["pos"] = overlap_cell
	clicked_target["pos"] = overlap_cell
	far_target["pos"] = far_cell
	first_target["luck"] = 0
	clicked_target["luck"] = 0
	far_target["luck"] = 0
	game.model.current_unit_id = 0
	game.model._start_unit_turn(true)
	game._refresh()
	game._select_attack()
	var near_heat: Dictionary = game.board.highlights[overlap_cell]
	var far_heat: Dictionary = game.board.highlights[far_cell]
	_check(near_heat["kind"] == "hit", "普攻目标格使用命中率热度高亮")
	_check(float(near_heat["hit"]) > float(far_heat["hit"]), "深色热度对应更高命中率")
	var group: Array[Dictionary] = game.model.units_at(overlap_cell)
	var clicked_index: int = group.find(clicked_target)
	var clicked_center: Vector2 = (
		game.board.cell_center(overlap_cell)
		+ game.board._stack_offset(clicked_index, group.size())
		+ Vector2(0, -44)
	)
	_check(game.board._unit_at(clicked_center) == 4, "点击重叠角色本体可解析到具体角色")
	var first_hp := int(first_target["hp"])
	var clicked_hp := int(clicked_target["hp"])
	game._on_board_unit_hovered(4)
	_check(game.board.targeted_unit_id == 4, "鼠标悬停具体目标时显示红圈")
	game._on_board_unit_clicked(4)
	_check(int(first_target["hp"]) == first_hp, "同格未点中的角色不承受单体伤害")
	_check(int(clicked_target["hp"]) < clicked_hp, "同格点中的角色承受单体伤害")
	_check(game.board.targeted_unit_id == -1, "单体攻击完成后清除目标红圈")

	var debuffer: Dictionary = game.model.get_unit(1)
	debuffer["pos"] = Vector2i(0, 0)
	first_target["pos"] = Vector2i(3, 0)
	game.model.current_unit_id = 1
	game.model._start_unit_turn(true)
	game._refresh()
	var mark_skill: Dictionary = debuffer["skills"][1]
	game._open_skill_list()
	game._choose_skill(mark_skill)
	game._choose_skill(mark_skill)
	game._on_board_unit_hovered(3)
	_check(game.board.targeted_unit_id == 3, "Debuff 目标悬停时显示红圈")
	game._on_board_unit_hovered(-1)
	_check(game.board.targeted_unit_id == -1, "鼠标移出角色后清除目标红圈")
	game._on_board_unit_hovered(3)
	game._on_board_unit_clicked(3)
	_check(bool(first_target["marked"]), "Debuff 施加到悬停选中的具体目标")
	_check(game.board.targeted_unit_id == -1, "Debuff 完成后清除目标红圈")

	var buffer: Dictionary = game.model.get_unit(5)
	buffer["pos"] = Vector2i(0, 0)
	first_target["pos"] = Vector2i(1, 0)
	game.model.current_unit_id = 5
	game.model._start_unit_turn(true)
	game._refresh()
	var ally_buff: Dictionary = buffer["skills"][2]
	game._open_skill_list()
	game._choose_skill(ally_buff)
	game._choose_skill(ally_buff)
	game._on_board_unit_hovered(3)
	_check(game.board.targeted_unit_id == 3, "友方 Buff 目标悬停时显示红圈")
	game._on_board_unit_clicked(3)
	_check(game.board.targeted_unit_id == -1, "友方 Buff 完成后清除目标红圈")

	game.model.current_unit_id = 4
	game.model._start_unit_turn(true)
	game._refresh()
	var avdol: Dictionary = game.model.current_unit()
	var illumination: Dictionary = avdol["skills"][3]
	var ap_before: int = avdol["ap"]
	game._open_skill_list()
	game._choose_skill(illumination)
	_check(int(avdol["ap"]) == ap_before, "第一次选择技能只展示详情")
	_check(game.previewed_skill_id == "thermal_calibration", "技能详情状态记录所选技能")
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
