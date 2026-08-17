class_name TitleScreen
extends Control

## 独立主页：系统待机。全屏立绘构图 + 透视棋盘背景 + 入场动画（可跳过）。

signal enter_requested
signal exit_requested
signal archive_requested
signal settings_requested

const TITLE_FONT := preload("res://assets/fonts/BebasNeue-Regular.ttf")
const BODY_FONT := preload("res://assets/fonts/simhei.ttf")
const DISPLAY_FONT := preload("res://assets/fonts/SmileySans-Oblique.ttf")

const COLOR_TEXT := Color("#f7f4eb")
const COLOR_MUTED := Color("#858b9c")
const COLOR_RED := Color("#ee232f")
const COLOR_GOLD := Color("#ffd241")
const COLOR_PANEL := Color("#14161f")

var enter_button: Button
var exit_button: Button
var archive_button: Button
var settings_button: Button
var portraits: Array[TextureRect] = []
var intro_tween: Tween
var animating := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_play_intro()


func _build() -> void:
	var backdrop := TacticalBackdrop.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	# 立绘：后景(霜翊) → 中景(曜锋) → 前景(夜链)，横向错开避免遮挡
	portraits.append(_add_portrait("frost_wing", Rect2(1400, 400, 190, 300)))
	portraits.append(_add_portrait("sun_blade", Rect2(1150, 220, 250, 390)))
	portraits.append(_add_portrait("night_chain", Rect2(800, 100, 350, 550)))

	var brand := Label.new()
	brand.text = "MECHA  CTB  TACTICS"
	brand.add_theme_font_override("font", TITLE_FONT)
	brand.add_theme_font_size_override("font_size", 22)
	brand.add_theme_color_override("font_color", COLOR_MUTED)
	_place(brand, Rect2(74, 150, 560, 40))
	add_child(brand)

	var main_title := Label.new()
	main_title.text = "机械战术演算"
	main_title.add_theme_font_override("font", DISPLAY_FONT)
	main_title.add_theme_font_size_override("font_size", 78)
	main_title.add_theme_color_override("font_color", COLOR_TEXT)
	main_title.add_theme_color_override("font_outline_color", Color(0.5, 0.02, 0.08, 0.6))
	main_title.add_theme_constant_override("outline_size", 6)
	_place(main_title, Rect2(66, 198, 600, 108))
	add_child(main_title)

	var subtitle := Label.new()
	subtitle.text = "同格战棋"
	subtitle.add_theme_font_override("font", BODY_FONT)
	subtitle.add_theme_font_size_override("font_size", 26)
	subtitle.add_theme_color_override("font_color", COLOR_RED)
	_place(subtitle, Rect2(74, 310, 400, 44))
	add_child(subtitle)

	enter_button = Button.new()
	enter_button.text = "进入战术系统"
	enter_button.custom_minimum_size = Vector2(360, 66)
	enter_button.add_theme_font_override("font", BODY_FONT)
	enter_button.add_theme_font_size_override("font_size", 24)
	enter_button.pressed.connect(func() -> void: enter_requested.emit())
	_place(enter_button, Rect2(74, 500, 360, 66))
	add_child(enter_button)
	_style_button(enter_button, COLOR_RED)

	archive_button = Button.new()
	archive_button.text = "人物图鉴"
	archive_button.custom_minimum_size = Vector2(170, 48)
	archive_button.add_theme_font_override("font", BODY_FONT)
	archive_button.add_theme_font_size_override("font_size", 18)
	archive_button.pressed.connect(func() -> void: archive_requested.emit())
	_place(archive_button, Rect2(74, 620, 170, 48))
	add_child(archive_button)
	_style_button(archive_button, COLOR_MUTED)

	settings_button = Button.new()
	settings_button.text = "设置"
	settings_button.custom_minimum_size = Vector2(170, 48)
	settings_button.add_theme_font_override("font", BODY_FONT)
	settings_button.add_theme_font_size_override("font_size", 18)
	settings_button.pressed.connect(func() -> void: settings_requested.emit())
	_place(settings_button, Rect2(254, 620, 170, 48))
	add_child(settings_button)
	_style_button(settings_button, COLOR_MUTED)

	exit_button = Button.new()
	exit_button.text = "退出"
	exit_button.custom_minimum_size = Vector2(160, 48)
	exit_button.add_theme_font_override("font", BODY_FONT)
	exit_button.add_theme_font_size_override("font_size", 18)
	exit_button.pressed.connect(func() -> void: exit_requested.emit())
	_place(exit_button, Rect2(74, 690, 160, 48))
	add_child(exit_button)
	_style_button(exit_button, COLOR_MUTED)

	var ready := Label.new()
	ready.text = "─────  CTB READY  ─────"
	ready.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ready.add_theme_font_override("font", TITLE_FONT)
	ready.add_theme_font_size_override("font_size", 20)
	ready.add_theme_color_override("font_color", COLOR_GOLD)
	_place(ready, Rect2(0, 830, 1600, 40))
	add_child(ready)


func _add_portrait(key: String, rect: Rect2) -> TextureRect:
	var character := _character(key)
	var texture_rect := TextureRect.new()
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.texture = load(str(character.get("portrait_texture", character.get("texture", "")))) as Texture2D
	_place(texture_rect, rect)
	add_child(texture_rect)
	return texture_rect


func _play_intro() -> void:
	animating = true
	intro_tween = create_tween()
	intro_tween.set_parallel(true)
	for index in portraits.size():
		var portrait := portraits[index]
		portrait.modulate.a = 0.0
		portrait.position += Vector2(42.0 - float(index) * 16.0, 0.0)
		intro_tween.tween_property(portrait, "modulate:a", 1.0, 0.45).set_delay(0.12 + float(index) * 0.12)
		intro_tween.tween_property(portrait, "position", portrait.position - Vector2(42.0 - float(index) * 16.0, 0.0), 0.45).set_delay(0.12 + float(index) * 0.12)
	for control in [enter_button, archive_button, settings_button, exit_button]:
		control.modulate.a = 0.0
		intro_tween.tween_property(control, "modulate:a", 1.0, 0.3).set_delay(0.62)
	intro_tween.chain().tween_callback(func() -> void: animating = false)


func _unhandled_key_input(event: InputEvent) -> void:
	if not animating or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode in [KEY_ENTER, KEY_SPACE, KEY_ESCAPE]:
		_skip_intro()


func _skip_intro() -> void:
	if intro_tween != null and intro_tween.is_valid():
		intro_tween.kill()
	animating = false
	for portrait in portraits:
		portrait.modulate.a = 1.0
	for control in [enter_button, archive_button, settings_button, exit_button]:
		control.modulate.a = 1.0


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
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _character(key: String) -> Dictionary:
	for definition in BattleData.characters():
		if str(definition["key"]) == key:
			return definition
	return {}


func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
