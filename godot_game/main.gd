extends Control

const PAUSE_MENU_SCENE := preload("res://ui/menu/pause_menu.tscn")

enum UiMode {
	ACTION,
	MOVE,
	ATTACK_TARGET,
	SKILL_LIST,
	SKILL_TARGET,
	GAME_OVER,
}

const COLOR_BG := Color("#0b0c14")
const COLOR_PANEL := Color("#14161f")
const COLOR_RED := Color("#ee232f")
const COLOR_BLUE := Color("#3589e0")
const COLOR_GOLD := Color("#ffd241")
const COLOR_TEXT := Color("#f7f4eb")
const COLOR_MUTED := Color("#858b9c")

var model := BattleModel.new()
var board: BoardView
var ui_mode := UiMode.ACTION
var pending_skill: Dictionary = {}
var hovered_cell := Vector2i(-1, -1)
var hovered_unit_id := -1
var ai_running := false

var turn_banner: Label
var order_list: RichTextLabel
var status_rows_box: VBoxContainer
var status_rows: Dictionary = {}
var status_label: RichTextLabel
var target_label: RichTextLabel
var log_label: RichTextLabel
var instruction_label: Label
var skill_panel: PanelContainer
var skill_list: VBoxContainer
var skill_description: RichTextLabel
var stand_preview: TextureRect
var previewed_skill_id := ""
var attack_button: Button
var skill_button: Button
var defend_button: Button
var move_button: Button
var wait_button: Button
var sprint_button: Button
var undo_button: Button
var target_popup: PopupMenu
var menu_overlay: ColorRect
var result_overlay: ColorRect
var result_label: Label
var impact_label: Label
var critical_overlay: ColorRect
var critical_image: TextureRect
var critical_tween: Tween
var cinematic_running := false
var pause_menu: PauseMenu
var draft_screen: DraftScreen
var tutorial_controller: TutorialController
var pending_board_size := 6
var pending_random_spawn := false
var start_flow: StartFlow


func _ready() -> void:
	var game_theme := Theme.new()
	game_theme.default_font = load("res://assets/fonts/simhei.ttf")
	theme = game_theme
	_build_interface()
	pause_menu = PAUSE_MENU_SCENE.instantiate()
	pause_menu.enabled = false
	pause_menu.can_open_callback = _can_open_pause_menu
	pause_menu.return_to_title_requested.connect(_on_pause_return_to_title)
	add_child(pause_menu)
	model.changed.connect(_refresh)
	model.event_created.connect(_on_battle_event)
	model.battle_ended.connect(_on_battle_ended)
	start_flow = StartFlow.new()
	start_flow.mode_confirmed.connect(_on_start_flow_confirmed)
	start_flow.tutorial_requested.connect(_open_tutorial)
	start_flow.exit_requested.connect(func() -> void: get_tree().quit())
	start_flow.archive_requested.connect(_open_archive_from_title)
	start_flow.settings_requested.connect(_open_settings_from_title)
	add_child(start_flow)


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = COLOR_BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	turn_banner = Label.new()
	turn_banner.add_theme_font_size_override("font_size", 27)
	turn_banner.add_theme_color_override("font_color", COLOR_TEXT)
	turn_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	turn_banner.add_theme_stylebox_override("normal", _panel_style(COLOR_RED))
	_place(turn_banner, Rect2(20, 18, 230, 56))
	add_child(turn_banner)

	var order_panel := _make_panel(Rect2(20, 88, 230, 300))
	var order_box := VBoxContainer.new()
	order_box.add_theme_constant_override("separation", 8)
	order_panel.add_child(order_box)
	order_box.add_child(_section_title("行动顺序 / CTB"))
	order_list = RichTextLabel.new()
	order_list.fit_content = false
	order_list.scroll_active = false
	order_list.bbcode_enabled = true
	order_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	order_box.add_child(order_list)

	var status_panel := _make_panel(Rect2(20, 404, 230, 460))
	var status_box := VBoxContainer.new()
	status_box.add_theme_constant_override("separation", 5)
	status_panel.add_child(status_box)
	status_box.add_child(_section_title("全员状态"))
	status_rows_box = VBoxContainer.new()
	status_rows_box.add_theme_constant_override("separation", 3)
	status_box.add_child(status_rows_box)

	var board_panel := _make_panel(Rect2(266, 72, 1080, 690), Color("#10121b"))
	board = BoardView.new()
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	board.cell_clicked.connect(_on_board_cell_clicked)
	board.cell_hovered.connect(_on_board_cell_hovered)
	board.unit_clicked.connect(_on_board_unit_clicked)
	board.unit_hovered.connect(_on_board_unit_hovered)
	board_panel.add_child(board)

	var target_panel := _make_panel(Rect2(1362, 88, 218, 300))
	var target_box := VBoxContainer.new()
	target_box.add_theme_constant_override("separation", 8)
	target_panel.add_child(target_box)
	target_box.add_child(_section_title("目标预估"))
	target_label = RichTextLabel.new()
	target_label.bbcode_enabled = true
	target_label.scroll_active = false
	target_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	target_box.add_child(target_label)

	var log_panel := _make_panel(Rect2(1362, 404, 218, 460))
	var log_box := VBoxContainer.new()
	log_box.add_theme_constant_override("separation", 8)
	log_panel.add_child(log_box)
	log_box.add_child(_section_title("战斗记录"))
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_active = true
	log_label.scroll_following = true
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_box.add_child(log_label)

	var action_panel := _make_panel(Rect2(266, 778, 1080, 86))
	var action_box := VBoxContainer.new()
	action_box.add_theme_constant_override("separation", 5)
	action_panel.add_child(action_box)
	instruction_label = Label.new()
	instruction_label.text = "选择行动"
	instruction_label.add_theme_color_override("font_color", COLOR_GOLD)
	instruction_label.add_theme_font_size_override("font_size", 16)
	action_box.add_child(instruction_label)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 10)
	action_box.add_child(actions)
	attack_button = _action_button("A  普通攻击", _select_attack)
	skill_button = _action_button("E  技能", _open_skill_list)
	defend_button = _action_button("C  防御", _perform_defend)
	move_button = _action_button("M  移动", _enter_move_mode)
	wait_button = _action_button("X  不行动", _perform_wait)
	sprint_button = _action_button("Shift  冲刺", _toggle_sprint)
	undo_button = _action_button("Esc  撤销", _cancel_or_undo)
	for button in [attack_button, skill_button, defend_button, move_button, wait_button, sprint_button, undo_button]:
		actions.add_child(button)

	_build_skill_panel()
	_build_target_popup()
	_build_result_overlay()
	_build_critical_overlay()
	_build_impact_label()


func _build_skill_panel() -> void:
	skill_panel = PanelContainer.new()
	skill_panel.add_theme_stylebox_override("panel", _panel_style(Color("#18131c"), COLOR_RED, 3))
	_place(skill_panel, Rect2(300, 430, 1012, 332))
	add_child(skill_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	skill_panel.add_child(row)

	stand_preview = TextureRect.new()
	stand_preview.custom_minimum_size = Vector2(190, 290)
	stand_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stand_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(stand_preview)

	skill_list = VBoxContainer.new()
	skill_list.custom_minimum_size = Vector2(430, 0)
	skill_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_list.add_theme_constant_override("separation", 7)
	row.add_child(skill_list)

	skill_description = RichTextLabel.new()
	skill_description.custom_minimum_size = Vector2(320, 0)
	skill_description.bbcode_enabled = true
	skill_description.fit_content = false
	skill_description.scroll_active = false
	skill_description.add_theme_font_size_override("normal_font_size", 16)
	skill_description.add_theme_stylebox_override("normal", _panel_style(Color("#10121b"), Color("#343846"), 2))
	row.add_child(skill_description)
	skill_panel.visible = false


func _build_target_popup() -> void:
	target_popup = PopupMenu.new()
	target_popup.id_pressed.connect(_on_target_popup_selected)
	add_child(target_popup)


func _build_result_overlay() -> void:
	result_overlay = ColorRect.new()
	result_overlay.color = Color(0.02, 0.02, 0.03, 0.88)
	result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_overlay.visible = false
	result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(result_overlay)
	var center := VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	_place(center, Rect2(480, 270, 640, 320))
	result_overlay.add_child(center)
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 54)
	result_label.add_theme_color_override("font_color", COLOR_GOLD)
	center.add_child(result_label)
	var restart := Button.new()
	restart.text = "返回模式选择"
	restart.custom_minimum_size = Vector2(280, 54)
	restart.pressed.connect(_return_to_mode)
	center.add_child(restart)


func _build_critical_overlay() -> void:
	critical_overlay = ColorRect.new()
	critical_overlay.color = Color("#050507")
	_place(critical_overlay, Rect2(346, 158, 920, 518))
	critical_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	critical_overlay.z_index = 50
	critical_overlay.visible = false
	add_child(critical_overlay)

	critical_image = TextureRect.new()
	critical_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	critical_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	critical_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	critical_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	critical_overlay.add_child(critical_image)


func _build_impact_label() -> void:
	impact_label = Label.new()
	impact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	impact_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	impact_label.add_theme_font_size_override("font_size", 42)
	impact_label.add_theme_color_override("font_color", COLOR_GOLD)
	impact_label.add_theme_stylebox_override("normal", _panel_style(Color(0.93, 0.14, 0.18, 0.9), COLOR_TEXT, 4))
	_place(impact_label, Rect2(490, 42, 620, 80))
	impact_label.visible = false
	add_child(impact_label)


func _start_game(selected_mode: String, teams: Dictionary = {}, board_size: int = 6, random_spawn: bool = false) -> void:
	if menu_overlay != null:
		menu_overlay.queue_free()
		menu_overlay = null
	ui_mode = UiMode.ACTION
	pending_skill = {}
	previewed_skill_id = ""
	ai_running = false
	cinematic_running = false
	critical_overlay.visible = false
	model.start_battle(selected_mode, int(Time.get_ticks_msec()), teams, {}, board_size, random_spawn)
	board.set_model(model)
	board.set_targeted_unit(-1)
	pause_menu.enabled = true
	_refresh()


func _open_draft(selected_mode: String, team_size: int, board_size: int, random_spawn: bool = false) -> void:
	if menu_overlay != null:
		menu_overlay.queue_free()
		menu_overlay = null
	result_overlay.visible = false
	pause_menu.enabled = false
	pending_board_size = board_size
	pending_random_spawn = random_spawn
	draft_screen = DraftScreen.new()
	draft_screen.draft_finished.connect(_on_draft_finished.bind(selected_mode))
	add_child(draft_screen)
	draft_screen.setup(selected_mode, int(Time.get_ticks_msec()), team_size)


func _on_draft_finished(result: Dictionary, selected_mode: String) -> void:
	if draft_screen != null:
		draft_screen.queue_free()
		draft_screen = null
	_start_game(selected_mode, result, pending_board_size, pending_random_spawn)


func _open_tutorial() -> void:
	if menu_overlay != null:
		menu_overlay.queue_free()
		menu_overlay = null
	result_overlay.visible = false
	if pause_menu != null:
		pause_menu.enabled = false
		pause_menu.close_menu()
	if start_flow != null:
		start_flow.visible = false
	tutorial_controller = TutorialController.new()
	tutorial_controller.exit_requested.connect(_on_tutorial_exit)
	add_child(tutorial_controller)


func _on_tutorial_exit() -> void:
	if tutorial_controller != null:
		tutorial_controller.queue_free()
		tutorial_controller = null
	_return_to_mode()


func _can_open_pause_menu() -> bool:
	return menu_overlay == null and not cinematic_running and model.phase != BattleModel.PHASE_GAME_OVER and not model.units.is_empty()


func _on_pause_return_to_title() -> void:
	_return_to_title()


func _on_start_flow_confirmed(selected_mode: String, team_size: int, board_size: int, random_spawn: bool) -> void:
	if start_flow != null:
		start_flow.visible = false
	_open_draft(selected_mode, team_size, board_size, random_spawn)


func _open_archive_from_title() -> void:
	if start_flow != null:
		start_flow.visible = false
	if pause_menu != null:
		pause_menu.open_page(PauseMenu.Page.ARCHIVE)


func _open_settings_from_title() -> void:
	if start_flow != null:
		start_flow.visible = false
	if pause_menu != null:
		pause_menu.open_page(PauseMenu.Page.SETTINGS)


func _return_to_title() -> void:
	if pause_menu != null:
		pause_menu.enabled = false
		pause_menu.close_menu()
	if start_flow != null:
		start_flow.visible = true
		start_flow.show_title()


func _return_to_mode() -> void:
	if pause_menu != null:
		pause_menu.enabled = false
		pause_menu.close_menu()
	if start_flow != null:
		start_flow.visible = true
		start_flow.show_mode()


func _make_panel(rect: Rect2, color: Color = COLOR_PANEL) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(color))
	_place(panel, rect)
	add_child(panel)
	return panel


func _panel_style(color: Color, border_color: Color = Color("#343846"), border_width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(4)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _section_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", COLOR_TEXT)
	return label


func _action_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(135, 45)
	button.pressed.connect(callback)
	return button


func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size


func _refresh() -> void:
	if model.phase == BattleModel.PHASE_IDLE or model.units.is_empty():
		return
	var actor := model.current_unit()
	if actor.is_empty():
		return
	var team_color := COLOR_BLUE if actor["team"] == BattleData.TEAM_A else COLOR_RED
	turn_banner.add_theme_stylebox_override("normal", _panel_style(team_color, COLOR_TEXT, 3))
	turn_banner.text = "%s队行动  /  %s" % ["A" if actor["team"] == BattleData.TEAM_A else "B", actor["name"]]
	_update_order()
	_update_status(actor)
	_update_log()
	_update_target_info()
	_update_highlights()
	board.sync_fields(model.fields)
	board.queue_redraw()
	var is_ai_turn: bool = model.mode == "ai" and actor["team"] == BattleData.TEAM_B
	var disabled: bool = cinematic_running or is_ai_turn or model.phase == BattleModel.PHASE_GAME_OVER
	for button in [attack_button, skill_button, defend_button, move_button, wait_button, sprint_button, undo_button]:
		button.disabled = disabled
	sprint_button.disabled = disabled or model.move_locked or model.time_stop_free_sprint
	sprint_button.text = "时停移动 4 格" if model.time_stop_free_sprint else (
		"Shift  取消冲刺" if model.sprint_enabled else "Shift  冲刺"
	)
	if is_ai_turn:
		instruction_label.text = "AI 正在判断..."
	else:
		instruction_label.text = _instruction_for_mode()
	_maybe_schedule_ai()


func _update_order() -> void:
	var lines: Array[String] = []
	var order := model.preview_turn_order(9)
	for index in order.size():
		var unit := model.get_unit(order[index])
		var marker := "▶" if index == 0 else "  "
		var color := "#3589e0" if unit["team"] == BattleData.TEAM_A else "#ee232f"
		lines.append("[color=%s]%s %d. %s[/color]" % [color, marker, index + 1, unit["name"]])
	order_list.text = "\n".join(lines)


func _update_status(actor: Dictionary) -> void:
	for child in status_rows_box.get_children():
		status_rows_box.remove_child(child)
		child.queue_free()
	status_rows.clear()
	for team in [BattleData.TEAM_A, BattleData.TEAM_B]:
		var team_color := COLOR_BLUE if team == BattleData.TEAM_A else COLOR_RED
		var team_label := Label.new()
		team_label.text = "%s 队" % ("A" if team == BattleData.TEAM_A else "B")
		team_label.add_theme_font_size_override("font_size", 14)
		team_label.add_theme_color_override("font_color", team_color)
		status_rows_box.add_child(team_label)
		for unit in model.units:
			if int(unit["team"]) != team:
				continue
			var is_current: bool = int(unit["id"]) == int(actor["id"])
			var row := HBoxContainer.new()
			row.custom_minimum_size = Vector2(0, 53)
			row.add_theme_constant_override("separation", 7)
			status_rows_box.add_child(row)

			var avatar := TextureRect.new()
			avatar.custom_minimum_size = Vector2(52, 52)
			avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			avatar.clip_contents = true
			avatar.texture = load(unit.get("avatar_texture", unit["texture"]))
			avatar.modulate = Color.WHITE if unit["alive"] else Color(0.48, 0.48, 0.52, 0.78)
			avatar.tooltip_text = str(unit["name"])
			row.add_child(avatar)

			var details := VBoxContainer.new()
			details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			details.add_theme_constant_override("separation", 0)
			row.add_child(details)
			var name_label := Label.new()
			name_label.text = "%s%s" % ["▶ " if is_current else "", unit["name"]]
			name_label.add_theme_font_size_override("font_size", 14)
			name_label.add_theme_color_override("font_color", team_color if unit["alive"] else COLOR_MUTED)
			details.add_child(name_label)
			var hp_ratio := float(unit["hp"]) / float(unit["max_hp"])
			var hp_color := Color("#3fbf6f") if hp_ratio > 0.5 else (COLOR_GOLD if hp_ratio > 0.25 else COLOR_RED)
			var vitals_row := HBoxContainer.new()
			vitals_row.add_theme_constant_override("separation", 8)
			details.add_child(vitals_row)
			var hp_label := Label.new()
			hp_label.text = "HP %d/%d" % [unit["hp"], unit["max_hp"]]
			hp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hp_label.add_theme_font_size_override("font_size", 12)
			hp_label.add_theme_color_override("font_color", hp_color)
			vitals_row.add_child(hp_label)
			var ap_label := Label.new()
			ap_label.text = "AP %d/%d" % [unit["ap"], BattleData.MAX_AP]
			ap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			ap_label.add_theme_font_size_override("font_size", 11)
			ap_label.add_theme_color_override("font_color", Color("#f4a5da"))
			vitals_row.add_child(ap_label)
			var state_label := Label.new()
			var state_text := _compact_status(unit)
			state_label.text = "%s  S %.1f" % [state_text if not state_text.is_empty() else "待命", unit["s"]]
			state_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			state_label.add_theme_font_size_override("font_size", 11)
			state_label.add_theme_color_override("font_color", COLOR_MUTED)
			details.add_child(state_label)
			status_rows[int(unit["id"])] = {"row": row, "avatar": avatar, "ap_label": ap_label, "name_label": name_label, "hp_label": hp_label}


func _update_status_text(actor: Dictionary) -> void:
	var lines: Array[String] = []
	for team in [BattleData.TEAM_A, BattleData.TEAM_B]:
		var team_color := "#3589e0" if team == BattleData.TEAM_A else "#ee232f"
		lines.append("[color=%s][b]%s 队[/b][/color]" % [team_color, "A" if team == BattleData.TEAM_A else "B"])
		for unit in model.units:
			if int(unit["team"]) != team:
				continue
			var is_current: bool = int(unit["id"]) == int(actor["id"])
			var marker := "▶ " if is_current else "   "
			var name_color := team_color if unit["alive"] else "#858b9c"
			var hp_ratio := float(unit["hp"]) / float(unit["max_hp"])
			var hp_color := "#3fbf6f" if hp_ratio > 0.5 else ("#ffd241" if hp_ratio > 0.25 else "#ee232f")
			var state_text := _compact_status(unit)
			lines.append("[color=%s][b]%s%s[/b][/color]  [color=#858b9c]%s[/color]" % [
				name_color, marker, unit["name"], state_text,
			])
			lines.append("[font_size=13]HP [color=%s]%d/%d[/color]  AP [color=#dd42b7]%d/%d[/color]  S %.2f[/font_size]" % [
				hp_color, unit["hp"], unit["max_hp"], unit["ap"], BattleData.MAX_AP, unit["s"],
			])
	status_label.text = "
".join(lines)


func _compact_status(unit: Dictionary) -> String:
	if not unit["alive"]:
		return "退场"
	var effects: Array[String] = []
	if unit["defending"]:
		effects.append("防御")
	if unit["counter_charge"]:
		effects.append("蓄力")
	if unit["armor_off"]:
		effects.append("脱甲")
	if unit["afterimage"]:
		effects.append("残影")
	if unit["accuracy_up"]:
		effects.append("照明")
	if unit["crystal_guard"]:
		effects.append("护体")
	if int(unit["bind_turns"]) > 0:
		effects.append("束缚")
	if unit["marked"]:
		effects.append("标记")
	return "" if effects.is_empty() else " / ".join(effects)

func _update_log() -> void:
	var lines: Array[String] = []
	var start := maxi(0, model.events.size() - 13)
	for index in range(start, model.events.size()):
		var event: Dictionary = model.events[index]
		var color := "#f7f4eb"
		if event["type"] == "critical":
			color = "#ffd241"
		elif event["type"] == "miss":
			color = "#42cdca"
		elif event["type"] in ["defeat", "victory"]:
			color = "#ee232f"
		lines.append("[color=%s]• %s[/color]" % [color, event["text"]])
	log_label.text = "\n".join(lines)
	log_label.scroll_to_line(maxi(0, lines.size() - 1))


func _update_target_info() -> void:
	if hovered_cell.x < 0:
		target_label.text = "[color=#858b9c]将鼠标移至角色所在格查看预估[/color]"
		return
	var actor := model.current_unit()
	var candidates := model.units_at(hovered_cell, 1 - int(actor["team"]))
	if candidates.is_empty():
		target_label.text = (
			"格子  (%d, %d)\n距离  %d\n\n[color=#858b9c]没有敌方角色[/color]"
			% [hovered_cell.x, hovered_cell.y, model.manhattan(actor["pos"], hovered_cell)]
		)
		return
	var target: Dictionary = candidates[0]
	for candidate in candidates:
		if int(candidate["id"]) == hovered_unit_id:
			target = candidate
			break
	var preview := model.preview_against(target["id"], pending_skill if ui_mode == UiMode.SKILL_TARGET else {})
	var hit_color := "#3fbf6f" if preview["hit"] >= 0.8 else ("#ffd241" if preview["hit"] >= 0.5 else "#ee232f")
	target_label.text = (
		"[font_size=22][b]%s[/b][/font_size]\n"
		+ "%s\n\n"
		+ "距离  %d 格\n"
		+ "命中  [color=%s][b]%d%%[/b][/color]\n"
		+ "伤害  %d ~ %d\n"
		+ "暴击  %d%%\n"
		+ "同格目标  %d"
	) % [
		target["name"], target["stand"], preview["distance"], hit_color,
		roundi(preview["hit"] * 100.0), preview["normal_damage"],
		preview["critical_damage"], roundi(preview["crit"] * 100.0), candidates.size(),
	]


func _update_highlights() -> void:
	var highlights: Dictionary = {}
	if model.units.is_empty():
		board.set_highlights(highlights)
		return
	var actor := model.current_unit()
	match ui_mode:
		UiMode.MOVE:
			if not model.move_locked:
				var used_steps := model.move_path.size() - 1
				var available_budget := model.move_budget
				if not model.sprint_enabled and not model.time_stop_free_sprint and int(actor["ap"]) >= 1:
					available_budget = 4
				var visible_remaining := maxi(0, available_budget - used_steps)
				for y in 6:
					for x in 6:
						var cell := Vector2i(x, y)
						var distance := model.manhattan(actor["pos"], cell)
						if distance <= visible_remaining:
							var total_steps := used_steps + distance
							highlights[cell] = "move" if total_steps <= 2 else "sprint"
		UiMode.ATTACK_TARGET:
			for target in model.living_units(1 - int(actor["team"])):
				_add_hit_highlight(highlights, target, {})
		UiMode.SKILL_TARGET:
			if pending_skill.get("target", "") == "cell":
				for y in 6:
					for x in 6:
						var cell := Vector2i(x, y)
						if model.can_target_cell(cell, pending_skill):
							highlights[cell] = "skill"
			else:
				var team: int = actor["team"] if pending_skill.get("target", "") == "ally" else 1 - int(actor["team"])
				for target in model.living_units(team):
					if model.can_target_unit(target["id"], pending_skill):
						if pending_skill.get("target", "") == "enemy" and _skill_uses_hit_roll(pending_skill):
							_add_hit_highlight(highlights, target, pending_skill)
						else:
							highlights[target["pos"]] = "skill"
	board.set_highlights(highlights)


func _add_hit_highlight(highlights: Dictionary, target: Dictionary, skill_data: Dictionary) -> void:
	var cell: Vector2i = target["pos"]
	var hit := float(model.preview_against(target["id"], skill_data)["hit"])
	if highlights.has(cell) and highlights[cell] is Dictionary:
		var previous: Dictionary = highlights[cell]
		var count := int(previous.get("count", 1))
		previous["hit"] = (float(previous["hit"]) * count + hit) / float(count + 1)
		previous["count"] = count + 1
		highlights[cell] = previous
	else:
		highlights[cell] = {"kind": "hit", "hit": hit, "count": 1}


func _skill_uses_hit_roll(skill_data: Dictionary) -> bool:
	return skill_data.get("effect", "") in ["damage", "crit_strike", "core_pierce", "drain", "burn", "delay", "bind", "area"]


func _instruction_for_mode() -> String:
	match ui_mode:
		UiMode.MOVE:
			return "点击格子或 WASD 移动；Shift 冲刺；Esc 撤销全部移动"
		UiMode.ATTACK_TARGET:
			return "点击角色本体指定目标；格子颜色越深命中率越高；Esc 取消"
		UiMode.SKILL_LIST:
			return "再次选择当前技能以发动；Esc 返回" if not previewed_skill_id.is_empty() else "选择技能（Num1~Num4）查看详情；Esc 返回"
		UiMode.SKILL_TARGET:
			return "选择技能目标；Esc 取消"
		_:
			return "移动不会结束行动；选择攻击、技能或防御完成本次行动"


func _select_attack() -> void:
	ui_mode = UiMode.ATTACK_TARGET
	pending_skill = {}
	previewed_skill_id = ""
	board.set_targeted_unit(-1)
	_refresh()


func _open_skill_list() -> void:
	ui_mode = UiMode.SKILL_LIST
	pending_skill = {}
	previewed_skill_id = ""
	_rebuild_skill_list()
	skill_panel.visible = true
	_refresh()


func _rebuild_skill_list() -> void:
	for child in skill_list.get_children():
		skill_list.remove_child(child)
		child.queue_free()
	var actor := model.current_unit()
	stand_preview.texture = load(actor.get("portrait_texture", actor["texture"]))
	var title := Label.new()
	title.text = "%s / %s" % [actor["name"], actor["stand"]]
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	skill_list.add_child(title)
	for index in actor["skills"].size():
		var skill_data: Dictionary = actor["skills"][index]
		var is_previewed: bool = previewed_skill_id == str(skill_data["id"])
		var button := Button.new()
		button.text = "%s%d  %s   %d AP   射程 %s" % [
			"▶ " if is_previewed else "",
			index + 1, skill_data["name"], skill_data["cost"], _range_text(skill_data),
		]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 42)
		var insufficient_ap: bool = int(actor["ap"]) < int(skill_data["cost"])
		button.disabled = insufficient_ap or (
			model.in_time_stop and str(skill_data["effect"]).begins_with("time_stop")
		)
		if is_previewed:
			button.add_theme_color_override("font_color", COLOR_GOLD)
		if insufficient_ap:
			button.text += "   AP 不足"
			button.add_theme_color_override("font_disabled_color", COLOR_RED)
		button.pressed.connect(func() -> void: _choose_skill(skill_data))
		skill_list.add_child(button)
	if pending_skill.is_empty():
		skill_description.text = "[color=#858b9c][font_size=18]未选择技能[/font_size][/color]"
	else:
		_update_skill_description(pending_skill)


func _range_text(skill_data: Dictionary) -> String:
	if skill_data["target"] == "self":
		return "自身"
	if skill_data["target"] == "cell" and skill_data["min_range"] == 1 and skill_data["max_range"] == 1:
		return "相邻"
	if skill_data["min_range"] == skill_data["max_range"]:
		return str(skill_data["max_range"])
	return "%d~%d" % [skill_data["min_range"], skill_data["max_range"]]


func _skill_summary(skill_data: Dictionary) -> String:
	return MenuThemeData.skill_summary(skill_data)


func _skill_description(skill_data: Dictionary) -> String:
	return MenuThemeData.skill_description(skill_data)


func _update_skill_description(skill_data: Dictionary) -> void:
	skill_description.text = (
		"[font_size=24][b]%s[/b][/font_size]
"
		+ "[color=#dd42b7]%d AP[/color]   [color=#42cdca]射程 %s[/color]

"
		+ "[color=#ffd241]%s[/color]

"
		+ "%s

"
		+ "[color=#ffd241][b]已选中，再次选择后发动[/b][/color]"
	) % [
		skill_data["name"], skill_data["cost"], _range_text(skill_data),
		_skill_summary(skill_data), _skill_description(skill_data),
	]


func _choose_skill(skill_data: Dictionary) -> void:
	var actor := model.current_unit()
	if int(actor["ap"]) < int(skill_data["cost"]):
		return
	if model.in_time_stop and str(skill_data["effect"]).begins_with("time_stop"):
		return
	var skill_id := str(skill_data["id"])
	if previewed_skill_id != skill_id:
		previewed_skill_id = skill_id
		pending_skill = skill_data
		_rebuild_skill_list()
		_refresh()
		return
	previewed_skill_id = ""
	pending_skill = skill_data
	if skill_data["target"] == "self":
		skill_panel.visible = false
		model.perform_skill(skill_data)
		ui_mode = UiMode.ACTION
	else:
		skill_panel.visible = false
		ui_mode = UiMode.SKILL_TARGET
		board.set_targeted_unit(-1)
		_refresh()

func _perform_wait() -> void:
	skill_panel.visible = false
	previewed_skill_id = ""
	pending_skill = {}
	ui_mode = UiMode.ACTION
	board.set_targeted_unit(-1)
	model.perform_wait()


func _perform_defend() -> void:
	skill_panel.visible = false
	previewed_skill_id = ""
	pending_skill = {}
	ui_mode = UiMode.ACTION
	model.perform_defend()


func _enter_move_mode() -> void:
	ui_mode = UiMode.MOVE
	skill_panel.visible = false
	previewed_skill_id = ""
	pending_skill = {}
	_refresh()


func _toggle_sprint() -> void:
	if model.set_sprint_enabled(not model.sprint_enabled):
		ui_mode = UiMode.MOVE
	_refresh()


func _cancel_or_undo() -> void:
	if ui_mode == UiMode.SKILL_LIST:
		skill_panel.visible = false
		previewed_skill_id = ""
		pending_skill = {}
		ui_mode = UiMode.ACTION
	elif ui_mode in [UiMode.ATTACK_TARGET, UiMode.SKILL_TARGET]:
		pending_skill = {}
		ui_mode = UiMode.ACTION
		board.set_targeted_unit(-1)
	elif ui_mode == UiMode.MOVE or model.move_path.size() > 1 or model.sprint_enabled:
		model.undo_movement()
		ui_mode = UiMode.ACTION
	_refresh()


func _on_board_cell_clicked(cell: Vector2i) -> void:
	if model.phase == BattleModel.PHASE_GAME_OVER:
		return
	match ui_mode:
		UiMode.MOVE:
			var actor := model.current_unit()
			var distance := model.manhattan(actor["pos"], cell)
			if distance > model.remaining_movement() and not model.sprint_enabled:
				if model.set_sprint_enabled(true):
					model.move_to(cell)
			else:
				model.move_to(cell)
		UiMode.ATTACK_TARGET:
			_select_unit_from_cell(cell, {})
		UiMode.SKILL_TARGET:
			if pending_skill.get("target", "") == "cell":
				if model.perform_skill(pending_skill, -1, cell):
					pending_skill = {}
					ui_mode = UiMode.ACTION
			else:
				_select_unit_from_cell(cell, pending_skill)
	_refresh()


func _on_board_unit_clicked(unit_id: int) -> void:
	if model.phase == BattleModel.PHASE_GAME_OVER:
		return
	if ui_mode == UiMode.ATTACK_TARGET:
		_select_unit_direct(unit_id, {})
	elif ui_mode == UiMode.SKILL_TARGET and pending_skill.get("target", "") != "cell":
		_select_unit_direct(unit_id, pending_skill)
	_refresh()


func _select_unit_direct(unit_id: int, skill_data: Dictionary) -> void:
	if not model.can_target_unit(unit_id, skill_data):
		return
	_execute_target(unit_id, skill_data)


func _select_unit_from_cell(cell: Vector2i, skill_data: Dictionary) -> void:
	var actor := model.current_unit()
	var target_team := 1 - int(actor["team"])
	if not skill_data.is_empty() and skill_data.get("target", "") == "ally":
		target_team = int(actor["team"])
	var candidates: Array[Dictionary] = []
	for unit in model.units_at(cell, target_team):
		if model.can_target_unit(unit["id"], skill_data):
			candidates.append(unit)
	if candidates.is_empty():
		return
	if candidates.size() == 1:
		_execute_target(candidates[0]["id"], skill_data)
		return
	target_popup.clear()
	target_popup.set_meta("skill", skill_data)
	for unit in candidates:
		target_popup.add_item("%s  HP %d/%d" % [unit["name"], unit["hp"], unit["max_hp"]], unit["id"])
	target_popup.position = Vector2i(get_viewport().get_mouse_position())
	target_popup.popup()


func _on_target_popup_selected(unit_id: int) -> void:
	var skill_data: Dictionary = target_popup.get_meta("skill", {})
	_execute_target(unit_id, skill_data)


func _execute_target(unit_id: int, skill_data: Dictionary) -> void:
	var succeeded := false
	if skill_data.is_empty():
		succeeded = model.perform_basic_attack(unit_id)
	else:
		succeeded = model.perform_skill(skill_data, unit_id)
	if succeeded:
		board.set_targeted_unit(-1)
		pending_skill = {}
		previewed_skill_id = ""
		ui_mode = UiMode.ACTION
		skill_panel.visible = false
		var skill_id := str(skill_data.get("id", ""))
		if skill_id in ["frost_lance", "frost_bind", "ice_mirror", "crystal_guard"]:
			var target := model.get_unit(unit_id)
			if not target.is_empty():
				board.play_ice_effect(target["pos"])


func _on_board_cell_hovered(cell: Vector2i) -> void:
	hovered_cell = cell
	_update_target_info()


func _on_board_unit_hovered(unit_id: int) -> void:
	hovered_unit_id = unit_id
	var hover_skill: Dictionary = pending_skill if ui_mode == UiMode.SKILL_TARGET else {}
	var selecting_unit: bool = ui_mode == UiMode.ATTACK_TARGET or (
		ui_mode == UiMode.SKILL_TARGET and pending_skill.get("target", "") != "cell"
	)
	board.set_targeted_unit(unit_id if selecting_unit and model.can_target_unit(unit_id, hover_skill) else -1)
	_update_target_info()


func _on_battle_event(event: Dictionary) -> void:
	if event["type"] == "critical":
		_show_critical(int(event["unit_id"]))
	elif event["type"] == "time_stop":
		_show_impact("THE WORLD  /  时间停止")
	elif event["type"] == "defeat":
		_show_impact("RETIRE  /  退场")


func _show_critical(attacker_id: int) -> void:
	var attacker := model.get_unit(attacker_id)
	if attacker.is_empty():
		return
	var texture_path := str(attacker.get("critical_texture", ""))
	if texture_path.is_empty() or not ResourceLoader.exists(texture_path):
		return
	if critical_tween != null and critical_tween.is_valid():
		critical_tween.kill()
	cinematic_running = true
	critical_image.texture = load(texture_path)
	critical_overlay.modulate = Color.WHITE
	critical_overlay.visible = true
	critical_tween = create_tween()
	critical_tween.tween_interval(0.9)
	critical_tween.tween_property(critical_overlay, "modulate:a", 0.0, 0.22)
	critical_tween.finished.connect(func() -> void:
		critical_overlay.visible = false
		critical_overlay.modulate = Color.WHITE
		cinematic_running = false
		_refresh()
	)


func _show_impact(text: String) -> void:
	impact_label.text = text
	impact_label.modulate = Color.WHITE
	impact_label.visible = true
	var tween := create_tween()
	tween.tween_interval(0.45)
	tween.tween_property(impact_label, "modulate:a", 0.0, 0.35)
	tween.finished.connect(func() -> void: impact_label.visible = false)


func _on_battle_ended(winning_team: int) -> void:
	ui_mode = UiMode.GAME_OVER
	result_label.text = "%s 队胜利" % ("A" if winning_team == BattleData.TEAM_A else "B")
	result_overlay.visible = true
	board.clear_fire_particles()


func _maybe_schedule_ai() -> void:
	if cinematic_running or ai_running or model.phase == BattleModel.PHASE_GAME_OVER or model.units.is_empty():
		return
	var actor := model.current_unit()
	if model.mode == "ai" and actor["team"] == BattleData.TEAM_B:
		ai_running = true
		_run_ai_turn()


func _run_ai_turn() -> void:
	await get_tree().create_timer(0.45, false).timeout
	if model.phase == BattleModel.PHASE_GAME_OVER:
		ai_running = false
		return
	var actor := model.current_unit()
	if actor["team"] != BattleData.TEAM_B:
		ai_running = false
		return
	var enemies := model.living_units(BattleData.TEAM_A)
	enemies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return model.distance_between(actor, a) < model.distance_between(actor, b)
	)
	if enemies.is_empty():
		ai_running = false
		return
	var nearest: Dictionary = enemies[0]
	var desired_steps := mini(2, maxi(0, model.distance_between(actor, nearest) - 1))
	for step in desired_steps:
		var delta := Vector2i.ZERO
		if actor["pos"].x != nearest["pos"].x:
			delta.x = 1 if nearest["pos"].x > actor["pos"].x else -1
		elif actor["pos"].y != nearest["pos"].y:
			delta.y = 1 if nearest["pos"].y > actor["pos"].y else -1
		model.move_step(delta)
		await get_tree().create_timer(0.10, false).timeout
	var best_skill: Dictionary = {}
	var best_target_id := -1
	var best_score := -1.0
	for skill_data in actor["skills"]:
		if int(skill_data["cost"]) > int(actor["ap"]) or skill_data["target"] != "enemy":
			continue
		if skill_data["effect"] not in ["damage", "crit_strike", "core_pierce", "drain", "burn", "delay", "bind", "area"]:
			continue
		for enemy in enemies:
			if model.can_target_unit(enemy["id"], skill_data):
				var preview := model.preview_against(enemy["id"], skill_data)
				var score: float = float(preview["normal_damage"]) * float(skill_data.get("hits", 1)) * float(preview["hit"])
				if skill_data["effect"] in ["burn", "delay", "bind"]:
					score += 8.0
				if score > best_score:
					best_score = score
					best_skill = skill_data
					best_target_id = enemy["id"]
	if not best_skill.is_empty():
		model.perform_skill(best_skill, best_target_id)
	else:
		var attack_target := -1
		var attack_score := -1.0
		for enemy in enemies:
			if model.can_target_unit(enemy["id"]):
				var preview := model.preview_against(enemy["id"])
				var score: float = float(preview["normal_damage"]) * float(preview["hit"])
				if score > attack_score:
					attack_score = score
					attack_target = enemy["id"]
		if attack_target >= 0 and attack_score > 0.0:
			model.perform_basic_attack(attack_target)
		else:
			var time_skill: Dictionary = {}
			for skill_data in actor["skills"]:
				if str(skill_data["effect"]).begins_with("time_stop") and int(skill_data["cost"]) <= int(actor["ap"]) and not model.in_time_stop:
					time_skill = skill_data
					break
			if not time_skill.is_empty():
				model.perform_skill(time_skill)
			else:
				model.perform_defend()
	ai_running = false
	ui_mode = UiMode.ACTION
	_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if cinematic_running or not event.pressed or event.echo or menu_overlay != null:
		return
	if model.units.is_empty() or model.phase == BattleModel.PHASE_GAME_OVER:
		return
	var actor := model.current_unit()
	if model.mode == "ai" and actor["team"] == BattleData.TEAM_B:
		return
	if ui_mode == UiMode.MOVE:
		match event.keycode:
			KEY_W, KEY_UP:
				model.move_step(Vector2i.UP)
				return
			KEY_S, KEY_DOWN:
				model.move_step(Vector2i.DOWN)
				return
			KEY_A, KEY_LEFT:
				model.move_step(Vector2i.LEFT)
				return
			KEY_D, KEY_RIGHT:
				model.move_step(Vector2i.RIGHT)
				return
			KEY_SHIFT:
				_toggle_sprint()
				return
			KEY_ESCAPE:
				_cancel_or_undo()
				return
			KEY_M, KEY_ENTER, KEY_SPACE:
				ui_mode = UiMode.ACTION
				_refresh()
				return
	match event.keycode:
		KEY_A:
			_select_attack()
		KEY_E:
			_open_skill_list()
		KEY_C:
			_perform_defend()
		KEY_X:
			_perform_wait()
		KEY_M:
			_enter_move_mode()
		KEY_ESCAPE:
			_cancel_or_undo()
		KEY_SHIFT:
			_toggle_sprint()
		KEY_1, KEY_2, KEY_3, KEY_4:
			if ui_mode == UiMode.SKILL_LIST:
				var index := int(event.keycode - KEY_1)
				var skills: Array = actor["skills"]
				if index >= 0 and index < skills.size() and int(actor["ap"]) >= int(skills[index]["cost"]):
					_choose_skill(skills[index])
