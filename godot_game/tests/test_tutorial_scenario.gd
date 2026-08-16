extends SceneTree

const BattleModelScript = preload("res://core/battle_model.gd")
const ScenarioScript = preload("res://tutorial/tutorial_scenario.gd")

const SEED := 20260816

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func _apply_overrides(model: BattleModel) -> void:
	for unit in model.units:
		var key := str(unit["key"])
		if ScenarioScript.UNIT_OVERRIDES.has(key):
			var overrides: Dictionary = ScenarioScript.UNIT_OVERRIDES[key]
			for field in overrides:
				unit[field] = overrides[field]
		for skill_data in unit["skills"]:
			var sid := str(skill_data["id"])
			if ScenarioScript.SKILL_RANGE_OVERRIDES.has(sid):
				var ranges: Dictionary = ScenarioScript.SKILL_RANGE_OVERRIDES[sid]
				for field in ranges:
					skill_data[field] = ranges[field]


func _unit(model: BattleModel, key: String) -> Dictionary:
	for unit in model.units:
		if str(unit["key"]) == key:
			return unit
	return {}


func _skill_of(unit: Dictionary, skill_id: String) -> Dictionary:
	for skill_data in unit["skills"]:
		if str(skill_data["id"]) == skill_id:
			return skill_data
	return {}


func _ensure_turn(model: BattleModel, unit: Dictionary) -> void:
	var current := model.current_unit()
	if current.is_empty() or int(current["id"]) != int(unit["id"]):
		model.current_unit_id = int(unit["id"])
		model._start_unit_turn(false)


func _execute_action(model: BattleModel, action: Dictionary) -> bool:
	match str(action["type"]):
		"move":
			var unit := _unit(model, str(action["unit"]))
			_ensure_turn(model, unit)
			if bool(action.get("sprint", false)):
				model.set_sprint_enabled(true)
			return model.move_to(action["to"])
		"attack":
			var unit := _unit(model, str(action["unit"]))
			var target := _unit(model, str(action["target"]))
			_ensure_turn(model, unit)
			return model.perform_basic_attack(int(target["id"]))
		"skill":
			var unit := _unit(model, str(action["unit"]))
			var target := _unit(model, str(action["target"]))
			var skill_data := _skill_of(unit, str(action["skill_id"]))
			_ensure_turn(model, unit)
			return model.perform_skill(skill_data, int(target["id"]))
		"defend":
			var unit := _unit(model, str(action["unit"]))
			_ensure_turn(model, unit)
			return model.perform_defend()
		"wait":
			var unit := _unit(model, str(action["unit"]))
			_ensure_turn(model, unit)
			return model.perform_wait()
		"force_turn":
			var unit := _unit(model, str(action["unit"]))
			model.current_unit_id = int(unit["id"])
			model._start_unit_turn(bool(action.get("start_effects", false)))
			return true
		"set_state":
			var unit := _unit(model, str(action["unit"]))
			unit[action["field"]] = action["value"]
			return true
	return true


func _replay(chapter: Dictionary) -> BattleModel:
	var model: BattleModel = BattleModelScript.new()
	model.start_battle("local", SEED, chapter["teams"], chapter["spawns"], ScenarioScript.BOARD_SIZE)
	_apply_overrides(model)
	for action in chapter.get("setup", []):
		_execute_action(model, action)
	return model


func _run() -> void:
	_test_chapter_structure()
	_test_playthrough_deterministic()
	_test_overrides_applied()
	if failures == 0:
		print("ALL TUTORIAL TESTS PASSED")
	else:
		push_error("%d TUTORIAL TESTS FAILED" % failures)
	quit(failures)


func _test_chapter_structure() -> void:
	var chapters: Array = ScenarioScript.CHAPTERS
	_check(chapters.size() == 6, "教程共 6 章")
	for chapter in chapters:
		var id := str(chapter["id"])
		_check(chapter.has("id") and chapter.has("title") and chapter.has("teams") and chapter.has("spawns") and chapter.has("steps"), "章节 %s 结构完整" % id)
		_check(chapter["steps"].size() >= 2, "章节 %s 至少 2 步" % id)


func _test_playthrough_deterministic() -> void:
	for chapter in ScenarioScript.CHAPTERS:
		var model1 := _replay(chapter)
		for step in chapter["steps"]:
			if step.has("action"):
				_execute_action(model1, step["action"])
		var model2 := _replay(chapter)
		for step in chapter["steps"]:
			if step.has("action"):
				_execute_action(model2, step["action"])
		_check(str(model1.events) == str(model2.events), "章节 %s 固定种子下事件序列确定" % chapter["id"])


func _test_overrides_applied() -> void:
	var chapter: Dictionary = ScenarioScript.CHAPTERS[0]
	var model := _replay(chapter)
	var sun := _unit(model, "sun_blade")
	var molten := _unit(model, "molten_core")
	_check(int(sun["r_max"]) == 3 and int(sun["r_opt"]) == 1, "曜锋射程覆写为 R_opt 1 / R_max 3")
	_check(int(molten["r_max"]) == 3, "熔芯射程覆写为 R_max 3")
	_check(model.board_size == 3, "教程棋盘为 3×3")
