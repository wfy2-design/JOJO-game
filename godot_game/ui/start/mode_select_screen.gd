class_name ModeSelectScreen
extends Control

## 模式选择：左侧命令列 + 右侧实时预演。

signal mode_selected(selected_mode: String)
signal tutorial_requested
signal back_requested

const TITLE_FONT := preload("res://assets/fonts/BebasNeue-Regular.ttf")
const BODY_FONT := preload("res://assets/fonts/simhei.ttf")

const COLOR_TEXT := Color("#f7f4eb")
const COLOR_MUTED := Color("#858b9c")
const COLOR_RED := Color("#ee232f")
const COLOR_BLUE := Color("#3589e0")
const COLOR_GOLD := Color("#ffd241")
const COLOR_PANEL := Color("#14161f")

const MODES := [
	{"id": "local", "zh": "本地双人", "en": "LOCAL VERSUS", "tag": "2 PLAYERS / SNAKE DRAFT / SHARED DEVICE", "desc": "两名玩家同屏轮流选角，红蓝双方隔线对峙。"},
	{"id": "ai", "zh": "玩家对 AI", "en": "PLAYER VS AI", "tag": "1 PLAYER / RANDOM AI DRAFT / TACTICAL", "desc": "玩家部署己方角色，AI 随机选角并接管敌方行动。"},
	{"id": "tutorial", "zh": "游戏教程", "en": "TUTORIAL", "tag": "6 CHAPTERS / STEP PLAYBACK / PRACTICE", "desc": "3×3 小棋盘上分六章演示移动、射程、技能与状态。"},
]

var selected_index := 0
var mode_buttons: Array[Button] = []
var preview_title: Label
var preview_tag: Label
var preview_desc: Label
var preview_visual: Control
var confirm_button: Button
var preview_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_select(0, false)


func _build() -> void:
	var backdrop := TacticalBackdrop.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var title := Label.new()
	title.text = "MODE SELECT / 任务协议"
	title.add_theme_font_override("font", TITLE_FONT)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	_place(title, Rect2(70, 70, 700, 56))
	add_child(title)

	# 左侧命令列
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	_place(list, Rect2(70, 190, 500, 420))
	add_child(list)
	for index in MODES.size():
		var mode: Dictionary = MODES[index]
		var button := Button.new()
		button.text = "%02d  %s\n     %s" % [index + 1, mode["zh"], mode["en"]]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(470, 92)
		button.add_theme_font_override("font", BODY_FONT)
		button.add_theme_font_size_override("font_size", 24)
		button.focus_entered.connect(_select.bind(index, true))
		button.mouse_entered.connect(func() -> void: button.grab_focus())
		button.pressed.connect(_activate.bind(index))
		list.add_child(button)
		mode_buttons.append(button)

	var back := Button.new()
	back.text = "返回标题"
	back.custom_minimum_size = Vector2(200, 48)
	back.add_theme_font_override("font", BODY_FONT)
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(func() -> void: back_requested.emit())
	_place(back, Rect2(70, 640, 200, 48))
	add_child(back)
	_style_button(back, COLOR_MUTED)

	# 右侧预演
	var preview_panel := PanelContainer.new()
	preview_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.03, 0.03, 0.05, 0.82), Color("#343846"), 1))
	_place(preview_panel, Rect2(640, 150, 880, 560))
	add_child(preview_panel)
	var preview_box := VBoxContainer.new()
	preview_box.add_theme_constant_override("separation", 14)
	preview_panel.add_child(preview_box)

	preview_visual = Control.new()
	preview_visual.custom_minimum_size = Vector2(0, 300)
	preview_box.add_child(preview_visual)

	preview_title = Label.new()
	preview_title.add_theme_font_override("font", TITLE_FONT)
	preview_title.add_theme_font_size_override("font_size", 64)
	preview_title.add_theme_color_override("font_color", COLOR_TEXT)
	preview_box.add_child(preview_title)

	preview_tag = Label.new()
	preview_tag.add_theme_font_override("font", TITLE_FONT)
	preview_tag.add_theme_font_size_override("font_size", 20)
	preview_tag.add_theme_color_override("font_color", COLOR_GOLD)
	preview_box.add_child(preview_tag)

	preview_desc = Label.new()
	preview_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_desc.add_theme_font_override("font", BODY_FONT)
	preview_desc.add_theme_font_size_override("font_size", 18)
	preview_desc.add_theme_color_override("font_color", COLOR_MUTED)
	preview_box.add_child(preview_desc)

	confirm_button = Button.new()
	confirm_button.text = "确认模式"
	confirm_button.custom_minimum_size = Vector2(260, 56)
	confirm_button.add_theme_font_override("font", BODY_FONT)
	confirm_button.add_theme_font_size_override("font_size", 22)
	confirm_button.pressed.connect(_confirm)
	_place(confirm_button, Rect2(1240, 730, 280, 56))
	add_child(confirm_button)
	_style_button(confirm_button, COLOR_RED)


func _select(index: int, animate: bool) -> void:
	if index < 0 or index >= MODES.size():
		return
	selected_index = index
	for i in mode_buttons.size():
		var button := mode_buttons[i]
		var active := i == selected_index
		var accent := _accent_for(i)
		button.add_theme_stylebox_override("normal", _panel_style(accent.darkened(0.55) if active else COLOR_PANEL, accent if active else Color("#343846"), 1))
		button.add_theme_stylebox_override("hover", _panel_style(accent.darkened(0.4), accent, 2))
		button.add_theme_stylebox_override("focus", _panel_style(accent.darkened(0.4), accent, 2))
		button.add_theme_color_override("font_color", COLOR_TEXT if active else COLOR_MUTED)
	_update_preview(animate)


func _activate(index: int) -> void:
	selected_index = index
	var id: String = MODES[index]["id"]
	if id == "tutorial":
		tutorial_requested.emit()
	else:
		mode_selected.emit(id)


func _confirm() -> void:
	_activate(selected_index)


func _update_preview(animate: bool) -> void:
	var mode: Dictionary = MODES[selected_index]
	var id: String = mode["id"]
	preview_title.text = mode["en"]
	preview_tag.text = mode["tag"]
	preview_desc.text = mode["desc"]
	preview_title.add_theme_color_override("font_color", _accent_for(selected_index))
	for child in preview_visual.get_children():
		child.queue_free()
	match id:
		"local":
			_build_versus_preview()
		"ai":
			_build_ai_preview()
		"tutorial":
			_build_tutorial_preview()
	if animate and preview_tween == null:
		preview_panel_fade()


func _build_versus_preview() -> void:
	var left := _preview_portrait("night_chain", Rect2(80, 10, 250, 300))
	left.modulate = Color(0.7, 0.8, 1.0, 1.0)
	preview_visual.add_child(left)
	var right := _preview_portrait("frost_wing", Rect2(500, 10, 250, 300))
	right.modulate = Color(1.0, 0.7, 0.7, 1.0)
	preview_visual.add_child(right)
	var vs := Label.new()
	vs.text = "VS"
	vs.add_theme_font_override("font", TITLE_FONT)
	vs.add_theme_font_size_override("font_size", 72)
	vs.add_theme_color_override("font_color", COLOR_RED)
	_place(vs, Rect2(370, 110, 130, 90))
	preview_visual.add_child(vs)


func _build_ai_preview() -> void:
	var player := _preview_portrait("mirror_tide", Rect2(180, 10, 250, 300))
	preview_visual.add_child(player)
	var silhouette := _preview_portrait("crimson_thorn", Rect2(500, 10, 250, 300))
	silhouette.modulate = Color(0.2, 0.22, 0.3, 1.0)
	preview_visual.add_child(silhouette)
	var lock := Label.new()
	lock.text = "[ LOCK ]"
	lock.add_theme_font_override("font", TITLE_FONT)
	lock.add_theme_font_size_override("font_size", 26)
	lock.add_theme_color_override("font_color", COLOR_GOLD)
	_place(lock, Rect2(520, 300, 220, 40))
	preview_visual.add_child(lock)


func _build_tutorial_preview() -> void:
	var left := _preview_portrait("sun_blade", Rect2(80, 10, 250, 300))
	preview_visual.add_child(left)
	var right := _preview_portrait("molten_core", Rect2(500, 10, 250, 300))
	preview_visual.add_child(right)


func _preview_portrait(key: String, rect: Rect2) -> TextureRect:
	var character := _character(key)
	var texture_rect := TextureRect.new()
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.texture = load(str(character.get("portrait_texture", character.get("texture", "")))) as Texture2D
	_place(texture_rect, rect)
	return texture_rect


func preview_panel_fade() -> void:
	preview_tween = create_tween()
	preview_title.modulate.a = 0.2
	preview_tween.tween_property(preview_title, "modulate:a", 1.0, 0.22)
	preview_tween.tween_callback(func() -> void: preview_tween = null)


func _accent_for(index: int) -> Color:
	return [COLOR_RED, COLOR_BLUE, COLOR_GOLD][index]


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_UP, KEY_W:
			_select(posmod(selected_index - 1, MODES.size()), true)
			mode_buttons[selected_index].grab_focus()
		KEY_DOWN, KEY_S:
			_select(posmod(selected_index + 1, MODES.size()), true)
			mode_buttons[selected_index].grab_focus()
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
	style.border_width_left = 3
	style.set_corner_radius_all(0)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _character(key: String) -> Dictionary:
	for definition in BattleData.characters():
		if str(definition["key"]) == key:
			return definition
	return {}


func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
