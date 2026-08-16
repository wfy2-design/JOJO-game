class_name DraftScreen
extends Control

## 选角界面：蛇形 1-2-2-1，先手随机，AI 随机，不支持悔选。

signal draft_finished(result: Dictionary)
signal draft_cancelled

const COLOR_BG := Color("#0b0c14")
const COLOR_PANEL := Color("#14161f")
const COLOR_TEXT := Color("#f7f4eb")
const COLOR_MUTED := Color("#858b9c")
const COLOR_BLUE := Color("#3589e0")
const COLOR_RED := Color("#ee232f")
const COLOR_GOLD := Color("#ffd241")

var mode := "local"          # "local" 或 "ai"
var draft := DraftModel.new()
var character_buttons: Dictionary = {}
var a_team_list: RichTextLabel
var b_team_list: RichTextLabel
var title_label: Label
var turn_label: Label
var ai_busy := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var game_theme := Theme.new()
	game_theme.default_font = load("res://assets/fonts/simhei.ttf")
	theme = game_theme
	_build_interface()


func setup(selected_mode: String, seed: int, team_size: int = 3) -> void:
	mode = selected_mode
	draft.changed.connect(_refresh)
	draft.start(seed, team_size)
	if title_label != null:
		title_label.text = "选择角色  /  %d VS %d  DRAFT" % [team_size, team_size]
	_refresh()


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = COLOR_BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	title_label = Label.new()
	title_label.text = "选择角色  /  DRAFT"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 40)
	title_label.add_theme_color_override("font_color", COLOR_TEXT)
	_place(title_label, Rect2(0, 40, 1600, 60))
	add_child(title_label)

	turn_label = Label.new()
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_label.add_theme_font_size_override("font_size", 22)
	turn_label.add_theme_color_override("font_color", COLOR_GOLD)
	_place(turn_label, Rect2(0, 108, 1600, 40))
	add_child(turn_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_place(row, Rect2(60, 170, 1480, 340))
	add_child(row)
	for definition in BattleData.characters():
		var card := _make_character_card(str(definition["key"]))
		character_buttons[str(definition["key"])] = card
		row.add_child(card)

	var teams_row := HBoxContainer.new()
	teams_row.alignment = BoxContainer.ALIGNMENT_CENTER
	teams_row.add_theme_constant_override("separation", 24)
	_place(teams_row, Rect2(120, 560, 1360, 240))
	add_child(teams_row)
	var a_panel := _team_panel("A 队", COLOR_BLUE)
	a_team_list = a_panel.get_meta("list")
	teams_row.add_child(a_panel)
	var b_panel := _team_panel("B 队", COLOR_RED)
	b_team_list = b_panel.get_meta("list")
	teams_row.add_child(b_panel)

	var hint := Label.new()
	hint.text = "点击角色进行选择；蛇形顺序 1-2-2-1；不支持悔选"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", COLOR_MUTED)
	_place(hint, Rect2(0, 820, 1600, 40))
	add_child(hint)


func _make_character_card(key: String) -> Button:
	var definition := _character(key)
	var button := Button.new()
	button.custom_minimum_size = Vector2(210, 330)
	button.pressed.connect(_on_pick.bind(key))
	button.add_theme_stylebox_override("normal", _panel_style(Color("#181c28"), Color("#343846"), 2))
	button.add_theme_stylebox_override("hover", _panel_style(Color("#22283a"), COLOR_GOLD, 3))
	button.add_theme_stylebox_override("disabled", _panel_style(Color("#10131b"), Color("#2a2f3a"), 2))

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)

	var avatar := TextureRect.new()
	avatar.custom_minimum_size = Vector2(120, 120)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.texture = load(str(definition["avatar_texture"])) as Texture2D
	box.add_child(avatar)

	var name_label := Label.new()
	name_label.text = str(definition["name"])
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", COLOR_TEXT)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)

	var stat_label := Label.new()
	stat_label.text = "HP %d   速度 %d   射程 %d~%d" % [
		int(definition["max_hp"]), int(definition["speed"]), int(definition["r_opt"]), int(definition["r_max"]),
	]
	stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_label.add_theme_font_size_override("font_size", 14)
	stat_label.add_theme_color_override("font_color", COLOR_MUTED)
	stat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(stat_label)

	return button


func _team_panel(title: String, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL, color, 3))
	panel.custom_minimum_size = Vector2(620, 210)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", color)
	box.add_child(title_label)
	var list := RichTextLabel.new()
	list.bbcode_enabled = true
	list.fit_content = false
	list.scroll_active = false
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_theme_font_size_override("normal_font_size", 20)
	box.add_child(list)
	panel.set_meta("list", list)
	return panel


func _refresh() -> void:
	var finished := draft.is_finished()
	var current_team := draft.current_team()
	for key in character_buttons:
		var button: Button = character_buttons[key]
		var available := draft.is_available(str(key))
		var manual_ok := mode == "local" or (mode == "ai" and current_team == "A")
		button.disabled = finished or not available or not manual_ok
		var chosen: bool = (str(key) in draft.a_team) or (str(key) in draft.b_team)
		if chosen:
			button.modulate = Color(0.4, 0.4, 0.42, 0.75)
		else:
			button.modulate = Color.WHITE

	var team_color := COLOR_BLUE if current_team == "A" else COLOR_RED
	if finished:
		turn_label.text = "选角完成，准备进入战斗"
	else:
		var owner := "A 队" if current_team == "A" else "B 队"
		var ai_hint := "（AI 正在选择…）" if (mode == "ai" and current_team == "B") else ""
		turn_label.text = "轮到 %s 选择%s" % [owner, ai_hint]
		turn_label.add_theme_color_override("font_color", team_color)

	_render_team_list(a_team_list, draft.a_team)
	_render_team_list(b_team_list, draft.b_team)

	if finished:
		draft_finished.emit(draft.result())
	elif mode == "ai" and current_team == "B" and not ai_busy:
		_schedule_ai_pick()


func _render_team_list(list: RichTextLabel, team: Array) -> void:
	var lines: Array[String] = []
	for key in team:
		var definition := _character(str(key))
		lines.append("•  %s  /  %s" % [definition["name"], definition["stand"]])
	if lines.is_empty():
		list.text = "[color=#858b9c]（尚未选择）[/color]"
	else:
		list.text = "\n".join(lines)


func _on_pick(key: String) -> void:
	if draft.is_finished():
		return
	if mode == "ai" and draft.current_team() != "A":
		return
	draft.pick(key)
	_refresh()


func _schedule_ai_pick() -> void:
	ai_busy = true
	_run_ai_pick()


func _run_ai_pick() -> void:
	await get_tree().create_timer(0.5, false).timeout
	draft.ai_pick()
	ai_busy = false
	_refresh()


func _character(key: String) -> Dictionary:
	for definition in BattleData.characters():
		if str(definition["key"]) == key:
			return definition
	return {}


func _panel_style(color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(0)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
