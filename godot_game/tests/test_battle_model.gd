extends SceneTree

const BattleModelScript = preload("res://core/battle_model.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func _approx(actual: float, expected: float, epsilon: float, message: String) -> void:
	_check(absf(actual - expected) <= epsilon, "%s (actual=%.4f expected=%.4f)" % [message, actual, expected])


func _new_battle(seed: int = 42) -> BattleModel:
	var battle := BattleModelScript.new()
	battle.start_battle("local", seed)
	return battle


func _run() -> void:
	_test_initial_state_and_ctb()
	_test_skill_catalog()
	_test_movement_and_undo()
	_test_hit_and_damage_formulas()
	_test_time_stop()
	_test_illumination()
	_test_mark_and_advance()
	_test_fire_wall_path_and_undo()
	_test_field_cleanup()
	_test_wait_action()
	_test_victory()
	if failures == 0:
		print("ALL TESTS PASSED")
	else:
		push_error("%d TESTS FAILED" % failures)
	quit(failures)


func _test_initial_state_and_ctb() -> void:
	var battle := _new_battle()
	_check(battle.units.size() == 6, "加载六名角色")
	_check(battle.living_units(BattleData.TEAM_A).size() == 3, "A 队三人")
	_check(battle.living_units(BattleData.TEAM_B).size() == 3, "B 队三人")
	for unit in battle.living_units(BattleData.TEAM_A):
		_check(unit["pos"] == Vector2i(0, 0), "%s 位于 A 队出生点" % unit["name"])
	for unit in battle.living_units(BattleData.TEAM_B):
		_check(unit["pos"] == Vector2i(5, 5), "%s 位于 B 队出生点" % unit["name"])
	var order := battle.preview_turn_order(3)
	_check(order == [3, 0, 2], "CTB 初始顺序按 S、速度、ID 排列")
	_check(battle.current_unit_id == 3, "绯棘速度最高并先手")


func _test_skill_catalog() -> void:
	var ids: Dictionary = {}
	var skill_count := 0
	for character in BattleData.characters():
		_check(character["skills"].size() == 4, "%s 拥有四个技能" % character["name"])
		_check(ResourceLoader.exists(character["texture"]), "%s 透明人物素材可加载" % character["name"])
		var portrait: Texture2D = load(character["texture"])
		var portrait_image := portrait.get_image()
		_check(portrait_image.detect_alpha() != Image.ALPHA_NONE, "%s 人物素材包含透明通道" % character["name"])
		_check(portrait_image.get_width() < 1000, "%s 人物素材已裁除横向空白" % character["name"])
		_check(ResourceLoader.exists(character["avatar_texture"]), "%s 头像框素材可加载" % character["name"])
		var avatar_image := (load(character["avatar_texture"]) as Texture2D).get_image()
		_check(avatar_image.detect_alpha() != Image.ALPHA_NONE, "%s 头像框包含透明通道" % character["name"])
		_check(avatar_image.get_pixel(0, 0).a < 0.1, "%s 头像框白底已透明化" % character["name"])
		_check(ResourceLoader.exists(character["portrait_texture"]), "%s 立绘素材可加载" % character["name"])
		_check(ResourceLoader.exists(character["critical_texture"]), "%s 弱点击破素材可加载" % character["name"])
		for skill_data in character["skills"]:
			skill_count += 1
			ids[skill_data["id"]] = true
	_check(skill_count == 24, "技能目录共 24 项")
	_check(ids.size() == 24, "技能 ID 全部唯一")


func _test_movement_and_undo() -> void:
	var battle := _new_battle()
	var dio := battle.current_unit()
	var original_ap: int = dio["ap"]
	_check(battle.set_sprint_enabled(true), "AP 足够时可开启冲刺")
	_check(battle.move_step(Vector2i.LEFT), "可移动到空格")
	_check(battle.move_step(Vector2i.LEFT), "移动累计路径")
	_check(battle.move_step(Vector2i.UP), "冲刺提供额外步数")
	_check(dio["pos"] == Vector2i(3, 4), "移动按逐格路径执行")
	_check(battle.undo_movement(), "行动确认前可撤销移动")
	dio = battle.current_unit()
	_check(dio["pos"] == Vector2i(5, 5), "撤销恢复起始位置")
	_check(int(dio["ap"]) == original_ap, "撤销返还冲刺 AP")
	_check(battle.units_at(Vector2i(5, 5), BattleData.TEAM_B).size() == 3, "同格允许三名角色")


func _test_hit_and_damage_formulas() -> void:
	var battle := _new_battle()
	var jotaro := battle.get_unit(0)
	var dio := battle.get_unit(3)
	jotaro["pos"] = Vector2i(0, 0)
	dio["pos"] = Vector2i(1, 0)
	_approx(battle.basic_hit_chance(jotaro, dio), 0.72, 0.0001, "近战基础命中受目标运气影响")
	dio["marked"] = true
	_approx(battle.basic_hit_chance(jotaro, dio), 0.92, 0.0001, "镜域标记增加 20 个百分点")
	dio["marked"] = false
	dio["pos"] = Vector2i(5, 1)
	_approx(battle.basic_hit_chance(jotaro, dio), 0.0, 0.0001, "R_max 边界命中率为零")
	dio["pos"] = Vector2i(1, 0)
	_check(battle.estimate_damage(jotaro, dio, 1.0, false, true) == 26, "防御公式四舍五入")
	_check(battle.estimate_damage(jotaro, dio, 1.0, true, true) == 39, "暴击造成 1.5 倍伤害")
	dio["defending"] = true
	_check(battle.estimate_damage(jotaro, dio, 1.0, false, true) == 13, "防御姿态减伤 50%")
	battle.events.clear()
	battle._apply_damage(dio, 1, jotaro, "暴击归属测试", true, true)
	_check(int(battle.events[-1]["unit_id"]) == int(jotaro["id"]), "暴击事件关联攻击者立绘")


func _test_time_stop() -> void:
	var battle := _new_battle(7)
	var dio := battle.current_unit()
	dio["ap"] = 5
	var before: float = dio["s"]
	var time_stop: Dictionary = dio["skills"][3]
	_check(battle.perform_skill(time_stop), "可释放赤域停滞")
	_check(battle.in_time_stop, "时停后进入额外行动")
	_check(battle.current_unit_id == dio["id"], "额外行动仍由时停者执行")
	_approx(float(dio["s"]), before, 0.0001, "第一次行动不推进 S")
	_check(battle.move_budget == 4, "绯棘时停额外行动有 4 格免费移动")
	_check(battle.move_step(Vector2i.LEFT), "时停中可以免费移动")
	_check(battle.undo_movement(), "时停移动可以撤销")
	_check(battle.current_unit()["pos"] == Vector2i(5, 5), "撤销恢复时停行动起点")
	_check(battle.move_budget == 4, "撤销后仍保留 4 格时停移动")
	var ap_after_time_stop: int = battle.current_unit()["ap"]
	_check(not battle.set_sprint_enabled(true), "时停免费移动不会重复购买冲刺")
	_check(int(battle.current_unit()["ap"]) == ap_after_time_stop, "拒绝重复冲刺时不扣 AP")
	_check(battle.perform_defend(), "额外行动可以选择防御")
	_check(not battle.in_time_stop, "额外行动后退出时停")
	_approx(float(battle.get_unit(3)["s"]), before + 100.0 / 15.0, 0.0001, "整个时停只推进一次 S")


func _test_illumination() -> void:
	var battle := _new_battle(11)
	battle.current_unit_id = 4
	battle._start_unit_turn(true)
	var avdol := battle.get_unit(4)
	var jotaro := battle.get_unit(0)
	avdol["ap"] = 10
	avdol["pos"] = Vector2i(2, 2)
	jotaro["pos"] = Vector2i(4, 2)
	var illumination: Dictionary = avdol["skills"][3]
	_check(battle.perform_skill(illumination), "可释放火焰照明")
	_check(bool(battle.get_unit(4)["accuracy_up"]), "照明在施放行动结束后保留")
	battle.current_unit_id = 4
	battle._start_unit_turn(true)
	avdol = battle.current_unit()
	_check(bool(avdol["accuracy_up"]), "照明保留到下一次攻击")
	var flame_spray: Dictionary = avdol["skills"][0]
	_approx(battle.skill_hit_chance(avdol, jotaro, flame_spray), 1.0, 0.0001, "照明增加 20 个百分点命中")
	_check(battle.perform_skill(flame_spray, jotaro["id"]), "照明后可执行直接攻击技能")
	_check(not bool(battle.get_unit(4)["accuracy_up"]), "直接攻击指令结算后移除照明")


func _test_mark_and_advance() -> void:
	var battle := _new_battle()
	battle.current_unit_id = 1
	battle._start_unit_turn(true)
	var kakyoin := battle.get_unit(1)
	var mark: Dictionary = kakyoin["skills"][1]
	_check(battle.perform_skill(mark, 3), "镜域标记可选择远程敌人")
	_check(bool(battle.get_unit(3)["marked"]), "镜域标记写入目标状态")

	battle = _new_battle()
	var joseph := battle.get_unit(5)
	var dio := battle.get_unit(3)
	joseph["s"] = 20.0
	dio["s"] = 30.0
	battle.current_unit_id = 5
	battle._start_unit_turn(true)
	var advance: Dictionary = joseph["skills"][2]
	_check(battle.perform_skill(advance, 3), "念写·先机可选择队友")
	_approx(float(dio["s"]), 30.0 - 50.0 / 15.0, 0.0001, "冰镜推进半个目标行动间隔")


func _test_fire_wall_path_and_undo() -> void:
	var battle := _new_battle()
	battle.current_unit_id = 4
	battle._start_unit_turn(true)
	var avdol := battle.get_unit(4)
	var fire_wall: Dictionary = avdol["skills"][2]
	_check(battle.perform_skill(fire_wall, -1, Vector2i(4, 5)), "在相邻格生成火墙")
	_check(battle.fields.size() == 1, "火墙加入场地效果")

	var jotaro := battle.get_unit(0)
	jotaro["pos"] = Vector2i(3, 5)
	jotaro["s"] = -1.0
	battle.current_unit_id = 0
	battle._start_unit_turn(false)
	_check(battle.move_step(Vector2i.RIGHT), "角色可进入火墙格")
	_check(int(jotaro["hp"]) == 232, "每次进入火墙格受到 0.4 倍间接伤害")
	_check(battle.undo_movement(), "火墙路径伤害可随移动一起撤销")
	_check(int(battle.get_unit(0)["hp"]) == 240, "撤销恢复火墙造成的伤害")


func _test_field_cleanup() -> void:
	var battle := _new_battle()
	battle.current_unit_id = 4
	battle._start_unit_turn(true)
	var avdol := battle.current_unit()
	var fire_wall: Dictionary = avdol["skills"][2]
	_check(battle.perform_skill(fire_wall, -1, Vector2i(4, 5)), "清理测试中生成火墙")
	_check(battle.fields.size() == 1, "退场前火墙存在")
	battle._defeat_unit(battle.get_unit(4))
	_check(battle.fields.is_empty(), "施放者退场后清理其火墙")


func _test_wait_action() -> void:
	var battle := _new_battle()
	var actor := battle.current_unit()
	var actor_id := int(actor["id"])
	var initial_s := float(actor["s"])
	_check(battle.perform_wait(), "移动前可以选择不行动")
	_check(float(battle.get_unit(actor_id)["s"]) > initial_s, "不行动正常推进当前角色 S")
	_check(battle.events.any(func(event: Dictionary) -> bool: return event["type"] == "wait"), "不行动写入战斗记录")

	battle = _new_battle()
	actor = battle.current_unit()
	actor_id = int(actor["id"])
	_check(battle.move_step(Vector2i.LEFT), "不行动前可以先移动")
	var moved_position: Vector2i = actor["pos"]
	var remaining_ap := int(actor["ap"])
	_check(battle.perform_wait(), "移动后可以选择不行动")
	_check(battle.get_unit(actor_id)["pos"] == moved_position, "不行动保留已经完成的移动")
	_check(int(battle.get_unit(actor_id)["ap"]) == remaining_ap, "不行动本身不消耗 AP")


func _test_victory() -> void:
	var battle := _new_battle()
	for unit in battle.living_units(BattleData.TEAM_A):
		battle._defeat_unit(unit)
	_check(battle.phase == BattleModel.PHASE_GAME_OVER, "一方全部退场后结束战斗")
	_check(battle.winner == BattleData.TEAM_B, "存活方获胜")
