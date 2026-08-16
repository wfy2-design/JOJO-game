class_name MatchConfigScreen
extends Control

## 作战简报：合并规模、棋盘、出生三项配置，带实时棋盘预览。

signal confirm_requested(selected_mode: String, team_size: int, board_size: int, random_spawn: bool)
signal back_requested

const TITLE_FONT := preload("res://assets/fonts/BebasNeue-Regular.ttf")
const BODY_FONT := preload("res://assets/fonts/simhei.ttf")

const COLOR_TEXT := Color("#f7f4eb")
const COLOR_MUTED := Color("#858b9c")
const COLOR_RED := Color("#ee232f")
const COLOR_BLUE := Color("#3589e0")
const COLOR_GOLD := Color("#ffd241")
const COLOR_PANEL := Color("#14161f")

var selected_mode := "local"
var team_size := 3
var board_size := 6
var random_spawn := false

var board_preview: BoardPreview
var summary_label: RichTextLabel
var size_buttons: Array[Button] = []
var board_buttons: Array[Button] = []
var spawn_fixed: Button
var spawn_random: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_refresh()


func setup(selected_mode: String) -> void:
	self.selected_mode = selected_mode
	_refresh()


func _build() -> void:
	var backdrop := TacticalBackdrop.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var title := Label.new()
	title.text = "MATCH CONFIG / 作战简报"
	title.add_theme_font_override("font", TITLE_FONT)
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(title, Rect2(0, 50, 1600, 56))
	add_child(title)

	# 中央：棋盘预览
	var preview_panel := PanelContainer.new()
	preview_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.03, 0.03, 0.05, 0.82), Color("#343846"), 1))
	_place(preview_panel, Rect2(210, 140, 620, 560))
	add_child(preview_panel)
	board_preview = BoardPreview.new()
	board_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	preview_panel.add_child(board_preview)

	# 右侧：配置项
	var config_panel := PanelContainer.new()
	config_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.03, 0.03, 0.05, 0.82), Color("#343846"), 1))
	_place(config_panel, Rect2(890, 140, 500, 560))
	add_child(config_panel)
	var config_box := VBoxContainer.new()
	config_box.add_theme_constant_override("separation", 14)
	config_panel.add_child(config_box)

	config_box.add_child(_section("对局规模"))
	size_buttons = _build_segment(["1 VS 1", "2 VS 2", "3 VS 3"], [1, 2, 3], func(value: int) -> void:
		team_size = value
		_refresh()
	)
	var size_row := HBoxContainer.new()
	size_row.add_theme_constant_override("separation", 8)
	for b in size_buttons:
		size_row.add_child(b)
	config_box.add_child(size_row)

	config_box.add_child(_section("棋盘大小"))
	board_buttons = _build_segment(["5 × 5", "6 × 6", "7 × 7"], [5, 6, 7], func(value: int) -> void:
		board_size = value
		_refresh()
	)
	var board_row := HBoxContainer.new()
	board_row.add_theme_constant_override("separation", 8)
	for b in board_buttons:
		board_row.add_child(b)
	config_box.add_child(board_row)

	config_box.add_child(_section("出生方式"))
	spawn_fixed = _segment_button("固定", false, func() -> void:
		random_spawn = false
		_refresh()
	)
	spawn_random = _segment_button("随机", true, func() -> void:
		random_spawn = true
		_refresh()
	)
	var spawn_row := HBoxContainer.new()
	spawn_row.add_theme_constant_override("separation", 8)
	spawn_row.add_child(spawn_fixed)
	spawn_row.add_child(spawn_random)
	config_box.add_child(spawn_row)

	summary_label = RichTextLabel.new()
	summary_label.bbcode_enabled = true
	summary_label.fit_content = false
	summary_label.scroll_active = false
	summary_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary_label.add_theme_font_size_override("normal_font_size", 20)
	config_box.add_child(summary_label)

	# 底部命令
	var back := Button.new()
	back.text = "返回上一步"
	back.custom_minimum_size = Vector2(200, 52)
	back.add_theme_font_override("font", BODY_FONT)
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(func() -> void: back_requested.emit())
	_place(back, Rect2(210, 720, 200, 52))
	add_child(back)
	_style_button(back, COLOR_MUTED)

	var reset := Button.new()
	reset.text = "重置"
	reset.custom_minimum_size = Vector2(150, 52)
	reset.add_theme_font_override("font", BODY_FONT)
	reset.add_theme_font_size_override("font_size", 18)
	reset.pressed.connect(_reset)
	_place(reset, Rect2(420, 720, 150, 52))
	add_child(reset)
	_style_button(reset, COLOR_MUTED)

	var confirm := Button.new()
	confirm.text = "进入选角"
	confirm.custom_minimum_size = Vector2(280, 52)
	confirm.add_theme_font_override("font", BODY_FONT)
	confirm.add_theme_font_size_override("font_size", 20)
	confirm.pressed.connect(_confirm)
	_place(confirm, Rect2(1130, 720, 260, 52))
	add_child(confirm)
	_style_button(confirm, COLOR_RED)


func _section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", BODY_FONT)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", COLOR_GOLD)
	return label


func _build_segment(labels: Array, values: Array, on_change: Callable) -> Array[Button]:
	var buttons: Array[Button] = []
	for index in labels.size():
		var value: int = values[index]
		var button := _segment_button(str(labels[index]), value, func() -> void: on_change.call(value))
		buttons.append(button)
	return buttons


func _segment_button(text: String, value: Variant, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(160, 54)
	button.add_theme_font_override("font", BODY_FONT)
	button.add_theme_font_size_override("font_size", 19)
	button.pressed.connect(on_press)
	return button


func _refresh() -> void:
	for index in size_buttons.size():
		_style_segment(size_buttons[index], team_size == [1, 2, 3][index])
	for index in board_buttons.size():
		_style_segment(board_buttons[index], board_size == [5, 6, 7][index])
	_style_segment(spawn_fixed, not random_spawn)
	_style_segment(spawn_random, random_spawn)
	board_preview.configure(board_size, team_size, random_spawn)
	summary_label.text = (
		"[color=#858b9c]配置摘要[/color]\n\n"
		+ "模式    [color=%s]%s[/color]\n"
		+ "规模    [color=%s]%d VS %d[/color]\n"
		+ "棋盘    [color=%s]%d × %d[/color]\n"
		+ "出生    [color=%s]%s[/color]"
	) % [
		COLOR_RED.to_html(), "本地双人" if selected_mode == "local" else "玩家对 AI",
		COLOR_GOLD.to_html(), team_size, team_size,
		COLOR_GOLD.to_html(), board_size, board_size,
		COLOR_GOLD.to_html(), "固定" if not random_spawn else "随机",
	]


func _style_segment(button: Button, active: bool) -> void:
	var accent := COLOR_BLUE
	button.add_theme_stylebox_override("normal", _panel_style(accent.darkened(0.55) if active else COLOR_PANEL, accent if active else Color("#343846"), 1))
	button.add_theme_stylebox_override("hover", _panel_style(accent.darkened(0.4), accent, 2))
	button.add_theme_color_override("font_color", COLOR_TEXT if active else COLOR_MUTED)


func _reset() -> void:
	team_size = 3
	board_size = 6
	random_spawn = false
	_refresh()


func _confirm() -> void:
	confirm_requested.emit(selected_mode, team_size, board_size, random_spawn)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_ENTER, KEY_SPACE:
			_confirm()
		KEY_ESCAPE:
			back_requested.emit()


func _style_button(button: Button, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", _panel_style(Color("#141a24"), accent, 1))
	button.add_theme_stylebox_override("hover", _panel_style(Color("#1a2232"), accent, 2))
	button.add_theme_stylebox_override("focus", _panel_style(Color("#1a2232"), accent, 2))


func _panel_style(color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.border_width_top = 2
	style.set_corner_radius_all(0)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size


class BoardPreview:
	extends Control

	const TILE_W := 64.0
	const TILE_H := 32.0

	var board_size := 6
	var team_size := 3
	var random_spawn := false
	var positions: Array[Vector2i] = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func configure(size: int, team: int, random: bool) -> void:
		board_size = size
		team_size = team
		random_spawn = random
		positions.clear()
		if random_spawn:
			var rng := RandomNumberGenerator.new()
			rng.seed = 20260816
			for i in team_size * 2:
				positions.append(Vector2i(rng.randi_range(0, size - 1), rng.randi_range(0, size - 1)))
		else:
			for i in team_size:
				positions.append(Vector2i(0, 0))
			for i in team_size:
				positions.append(Vector2i(size - 1, size - 1))
		queue_redraw()

	func _origin() -> Vector2:
		return Vector2(size.x * 0.5, 60.0)

	func _center(cell: Vector2i) -> Vector2:
		var origin := _origin()
		return origin + Vector2(float(cell.x - cell.y) * TILE_W * 0.5, float(cell.x + cell.y) * TILE_H * 0.5)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#0b0c14"), true)
		for y in board_size:
			for x in board_size:
				var cell := Vector2i(x, y)
				var center := _center(cell)
				var poly := PackedVector2Array([
					center + Vector2(0, -TILE_H * 0.5),
					center + Vector2(TILE_W * 0.5, 0),
					center + Vector2(0, TILE_H * 0.5),
					center + Vector2(-TILE_W * 0.5, 0),
				])
				draw_colored_polygon(poly, Color("#1a1c28") if (x + y) % 2 == 0 else Color("#222532"))
				draw_polyline(PackedVector2Array([poly[0], poly[1], poly[2], poly[3], poly[0]]), Color("#52586a"), 1.0)
		for index in positions.size():
			var cell := positions[index]
			var color := Color("#3589e0") if index < team_size else Color("#ee232f")
			draw_circle(_center(cell), 9.0, color)
