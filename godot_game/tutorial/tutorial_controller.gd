class_name TutorialController
extends Control

## 游戏教程控制器：自包含（BattleModel + BoardView + 说明卡片 + 目录 + 控制条）。
## 章节化 6 块，支持目录跳转、正文关键词跳转、上一步/下一步/重播/返回。

signal exit_requested

const SEED := 20260816

const COLOR_BG := Color("#0b0c14")
const COLOR_PANEL := Color("#14161f")
const COLOR_TEXT := Color("#f7f4eb")
const COLOR_MUTED := Color("#858b9c")
const COLOR_GOLD := Color("#ffd241")
const COLOR_BLUE := Color("#3589e0")
const COLOR_RED := Color("#ee232f")
const COLOR_ACCENT := Color("#42cdca")

var model: BattleModel
var board: BoardView
var current_chapter_index := 0
var current_step := 0
var step_phase := 0          # 0 = before（显示 body），1 = after（已执行，显示 after）
var last_result: Dictionary = {}

var step_title: Label
var body_label: RichTextLabel
var status_label: RichTextLabel
var chapter_tabs: Array[Button] = []
var next_button: Button
var prev_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var game_theme := Theme.new()
	game_theme.default_font = load("res://assets/fonts/simhei.ttf")
	theme = game_theme
	_build_interface()
	_load_chapter(0)


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = COLOR_BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	_build_chapter_tabs()

	board = BoardView.new()
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(board, Rect2(30, 90, 620, 620))
	add_child(board)

	var card_panel := _make_panel(Rect2(690, 90, 880, 620))
	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 12)
	card_panel.add_child(card_box)

	step_title = Label.new()
	step_title.add_theme_font_size_override("font_size", 30)
	step_title.add_theme_color_override("font_color", COLOR_GOLD)
	card_box.add_child(step_title)

	body_label = RichTextLabel.new()
	body_label.bbcode_enabled = true
	body_label.selection_enabled = true
	body_label.fit_content = false
	body_label.scroll_active = false
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_label.add_theme_font_size_override("normal_font_size", 22)
	body_label.add_theme_color_override("default_color", COLOR_TEXT)
	body_label.meta_clicked.connect(_on_meta_clicked)
	card_box.add_child(body_label)

	status_label = RichTextLabel.new()
	status_label.bbcode_enabled = true
	status_label.fit_content = false
	status_label.scroll_active = false
	status_label.add_theme_font_size_override("normal_font_size", 17)
	card_box.add_child(status_label)

	_build_controls()


func _build_chapter_tabs() -> void:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	_place(tabs, Rect2(30, 24, 1540, 52))
	add_child(tabs)
	for index in TutorialScenario.CHAPTERS.size():
		var chapter: Dictionary = TutorialScenario.CHAPTERS[index]
		var button := Button.new()
		button.text = str(chapter["title"])
		button.custom_minimum_size = Vector2(240, 46)
		button.pressed.connect(_jump_to_chapter_index.bind(index))
		tabs.add_child(button)
		chapter_tabs.append(button)


func _build_controls() -> void:
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 14)
	_place(controls, Rect2(30, 760, 1540, 100))
	add_child(controls)

	prev_button = _button("上一步  (←/A)")
	prev_button.pressed.connect(_prev)
	controls.add_child(prev_button)

	next_button = _button("下一步  (→/D)")
	next_button.pressed.connect(_next)
	controls.add_child(next_button)

	var replay := _button("重播  (R)")
	replay.pressed.connect(_replay)
	controls.add_child(replay)

	var exit := _button("返回  (Esc)")
	exit.pressed.connect(func() -> void: exit_requested.emit())
	controls.add_child(exit)


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(230, 60)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_stylebox_override("normal", _panel_style(Color("#141a24"), COLOR_ACCENT, 1))
	button.add_theme_stylebox_override("hover", _panel_style(Color("#1a2232"), COLOR_ACCENT, 2))
	button.add_theme_stylebox_override("disabled", _panel_style(Color("#0e1118"), Color("#2a2f3a"), 1))
	return button


func _load_chapter(index: int) -> void:
	current_chapter_index = clampi(index, 0, TutorialScenario.CHAPTERS.size() - 1)
	current_step = 0
	step_phase = 0
	_render()


func _jump_to_chapter_index(index: int) -> void:
	_load_chapter(index)


func _jump_to_chapter(chapter_id: String) -> void:
	var index := TutorialScenario.chapter_index_by_id(chapter_id)
	if index >= 0:
		_load_chapter(index)


func _on_meta_clicked(meta: Variant) -> void:
	if str(meta).begins_with("topic:"):
		_jump_to_chapter(str(meta).trim_prefix("topic:"))


func _replay() -> void:
	_load_chapter(0)


func _next() -> void:
	var chapter: Dictionary = TutorialScenario.CHAPTERS[current_chapter_index]
	var steps: Array = chapter["steps"]
	var step: Dictionary = steps[current_step]
	if step.has("action") and step_phase == 0:
		step_phase = 1
	elif current_step < steps.size() - 1:
		current_step += 1
		step_phase = 0
	elif current_chapter_index < TutorialScenario.CHAPTERS.size() - 1:
		current_chapter_index += 1
		current_step = 0
		step_phase = 0
	_render()


func _prev() -> void:
	if step_phase == 1:
		step_phase = 0
	elif current_step > 0:
		current_step -= 1
		var prev_step: Dictionary = TutorialScenario.CHAPTERS[current_chapter_index]["steps"][current_step]
		step_phase = 1 if prev_step.has("action") else 0
	elif current_chapter_index > 0:
		current_chapter_index -= 1
		var chapter: Dictionary = TutorialScenario.CHAPTERS[current_chapter_index]
		current_step = chapter["steps"].size() - 1
		var last_step: Dictionary = chapter["steps"][current_step]
		step_phase = 1 if last_step.has("action") else 0
	_render()


func _render() -> void:
	var chapter: Dictionary = TutorialScenario.CHAPTERS[current_chapter_index]
	var steps: Array = chapter["steps"]
	var step: Dictionary = steps[current_step]

	# 重建 model 并重放到当前步
	model = BattleModel.new()
	model.start_battle("local", SEED, chapter["teams"], chapter["spawns"], TutorialScenario.BOARD_SIZE)
	_apply_overrides()
	for action in chapter.get("setup", []):
		_execute_action(action)
	for i in range(current_step):
		var earlier: Dictionary = steps[i]
		if earlier.has("action"):
			_execute_action(earlier["action"])
	last_result = {}
	if step_phase == 1 and step.has("action"):
		_execute_action(step["action"])

	board.set_model(model)
	board.set_highlights(_compute_highlights(step))
	board.queue_redraw()

	var chapter_label := "第 %d / %d 章 · %s" % [current_chapter_index + 1, TutorialScenario.CHAPTERS.size(), chapter["title"]]
	var progress := "%02d / %02d" % [current_step + 1, steps.size()]
	step_title.text = "%s   %s   %s" % [chapter_label, progress, step["title"]]
	var text: String = str(step["after"]) if step_phase == 1 and step.has("after") else str(step["body"])
	body_label.text = _fill(text)
	_update_status()
	_update_tabs()
	_update_controls(step, steps.size())


func _compute_highlights(step: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for item in step.get("highlight", []):
		result[item["cell"]] = str(item["kind"])
	if step.has("action"):
		var action: Dictionary = step["action"]
		if action["type"] in ["attack", "skill"] and action.has("target"):
			var attacker := _unit(str(action["unit"]))
			var target := _unit(str(action["target"]))
			if not attacker.is_empty() and not target.is_empty():
				var saved := model.current_unit_id
				model.current_unit_id = int(attacker["id"])
				var skill_data := {}
				if action["type"] == "skill":
					skill_data = _skill_of(attacker, str(action["skill_id"]))
				var preview := model.preview_against(int(target["id"]), skill_data)
				model.current_unit_id = saved
				if not preview.is_empty():
					result[target["pos"]] = {"kind": "hit", "hit": float(preview["hit"]), "count": 1}
	return result


func _update_status() -> void:
	var lines: Array[String] = []
	for unit in model.units:
		var team_color := "#3589e0" if unit["team"] == BattleData.TEAM_A else "#ee232f"
		lines.append("[color=%s]■ %s[/color]   HP %d/%d   AP %d/%d   S %.2f" % [
			team_color, unit["name"], unit["hp"], unit["max_hp"], unit["ap"], BattleData.MAX_AP, unit["s"],
		])
	status_label.text = "\n".join(lines)


func _update_tabs() -> void:
	for index in chapter_tabs.size():
		var button := chapter_tabs[index]
		var active := index == current_chapter_index
		button.add_theme_stylebox_override("normal", _panel_style(COLOR_ACCENT.darkened(0.65) if active else COLOR_PANEL, COLOR_ACCENT if active else Color("#343846"), 1))
		button.add_theme_color_override("font_color", COLOR_TEXT if active else COLOR_MUTED)


func _update_controls(step: Dictionary, step_count: int) -> void:
	var has_action := step.has("action")
	if has_action and step_phase == 0:
		next_button.text = "执行  (→/D)"
	elif current_step == step_count - 1 and step_phase == 1 and current_chapter_index == TutorialScenario.CHAPTERS.size() - 1:
		next_button.text = "已结束"
		next_button.disabled = true
	else:
		next_button.text = "下一步  (→/D)"
		next_button.disabled = false
	prev_button.disabled = current_chapter_index == 0 and current_step == 0 and step_phase == 0


func _execute_action(action: Dictionary) -> void:
	match str(action["type"]):
		"move":
			_do_move(action)
		"attack":
			_do_attack(action)
		"skill":
			_do_skill(action)
		"defend":
			_do_defend(action)
		"wait":
			_do_wait(action)
		"force_turn":
			_do_force_turn(action)
		"set_state":
			_do_set_state(action)


func _do_move(action: Dictionary) -> void:
	var unit := _unit(str(action["unit"]))
	if unit.is_empty():
		return
	_ensure_turn(unit)
	if bool(action.get("sprint", false)):
		model.set_sprint_enabled(true)
	model.move_to(action["to"])


func _do_attack(action: Dictionary) -> void:
	var unit := _unit(str(action["unit"]))
	var target := _unit(str(action["target"]))
	if unit.is_empty() or target.is_empty():
		return
	_ensure_turn(unit)
	last_result["hit"] = float(model.preview_against(int(target["id"]))["hit"])
	model.perform_basic_attack(int(target["id"]))
	last_result["damage"] = _last_event_amount(["damage", "critical"])
	last_result["hp"] = int(target["hp"])


func _do_skill(action: Dictionary) -> void:
	var unit := _unit(str(action["unit"]))
	var target := _unit(str(action["target"]))
	if unit.is_empty() or target.is_empty():
		return
	var skill_data := _skill_of(unit, str(action["skill_id"]))
	if skill_data.is_empty():
		return
	_ensure_turn(unit)
	last_result["hit"] = float(model.preview_against(int(target["id"]), skill_data)["hit"])
	model.perform_skill(skill_data, int(target["id"]))
	last_result["damage"] = _last_event_amount(["damage", "critical"])
	last_result["hp"] = int(target["hp"])


func _do_defend(action: Dictionary) -> void:
	var unit := _unit(str(action["unit"]))
	if unit.is_empty():
		return
	_ensure_turn(unit)
	model.perform_defend()


func _do_wait(action: Dictionary) -> void:
	var unit := _unit(str(action["unit"]))
	if unit.is_empty():
		return
	_ensure_turn(unit)
	model.perform_wait()


func _do_force_turn(action: Dictionary) -> void:
	var unit := _unit(str(action["unit"]))
	if unit.is_empty():
		return
	model.current_unit_id = int(unit["id"])
	model._start_unit_turn(bool(action.get("start_effects", false)))


func _do_set_state(action: Dictionary) -> void:
	var unit := _unit(str(action["unit"]))
	if unit.is_empty():
		return
	unit[action["field"]] = action["value"]


func _ensure_turn(unit: Dictionary) -> void:
	var current := model.current_unit()
	if current.is_empty() or int(current["id"]) != int(unit["id"]):
		model.current_unit_id = int(unit["id"])
		model._start_unit_turn(false)


func _apply_overrides() -> void:
	for unit in model.units:
		var key := str(unit["key"])
		if TutorialScenario.UNIT_OVERRIDES.has(key):
			var overrides: Dictionary = TutorialScenario.UNIT_OVERRIDES[key]
			for field in overrides:
				unit[field] = overrides[field]
		for skill_data in unit["skills"]:
			var sid := str(skill_data["id"])
			if TutorialScenario.SKILL_RANGE_OVERRIDES.has(sid):
				var ranges: Dictionary = TutorialScenario.SKILL_RANGE_OVERRIDES[sid]
				for field in ranges:
					skill_data[field] = ranges[field]


func _unit(key: String) -> Dictionary:
	for unit in model.units:
		if str(unit["key"]) == key:
			return unit
	return {}


func _skill_of(unit: Dictionary, skill_id: String) -> Dictionary:
	for skill_data in unit["skills"]:
		if str(skill_data["id"]) == skill_id:
			return skill_data
	return {}


func _last_event_amount(types: Array) -> int:
	for index in range(model.events.size() - 1, -1, -1):
		var event: Dictionary = model.events[index]
		if str(event["type"]) in types:
			return int(event.get("amount", 0))
	return 0


func _fill(text: String) -> String:
	var result := text
	result = result.replace("{hit}", "%d%%" % roundi(float(last_result.get("hit", 0.0)) * 100.0))
	result = result.replace("{damage}", str(last_result.get("damage", 0)))
	result = result.replace("{hp}", str(last_result.get("hp", 0)))
	result = result.replace("{ap}", str(last_result.get("ap", 0)))
	return result


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_LEFT, KEY_A:
			_prev()
		KEY_RIGHT, KEY_D:
			_next()
		KEY_R:
			_replay()
		KEY_ESCAPE:
			exit_requested.emit()


func _make_panel(rect: Rect2, color: Color = COLOR_PANEL) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(color))
	_place(panel, rect)
	add_child(panel)
	return panel


func _panel_style(color: Color, border_color: Color = COLOR_ACCENT, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.border_width_top = 3
	style.set_corner_radius_all(0)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
