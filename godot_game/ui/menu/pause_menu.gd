class_name PauseMenu
extends CanvasLayer

signal return_to_title_requested

enum Page {
	MAIN,
	ARCHIVE,
	GUIDE,
	TUTORIAL,
	SETTINGS,
}

const COLOR_INK := Color("#090a0f")
const COLOR_PANEL := Color("#12141c")
const COLOR_TEXT := Color("#f6f3e9")
const COLOR_MUTED := Color("#9296a3")
const CONFIG_PATH := "user://settings.cfg"
const TITLE_FONT := preload("res://assets/fonts/SmileySans-Oblique.ttf")
const BODY_FONT := preload("res://assets/fonts/SourceHanSansCN-Bold.otf")
const NUMBER_FONT := preload("res://assets/fonts/BebasNeue-Regular.ttf")
const JAPANESE_FONT := preload("res://assets/fonts/YujiSyuku-Regular.ttf")
const SILHOUETTE_TRANSITION_SCRIPT := preload("res://ui/menu/silhouette_transition.gd")

var enabled := false
var can_open_callback := Callable()
var current_page := Page.MAIN
var current_character_key := "night_chain"
var current_primary := Color("#7b5ce0")
var current_secondary := Color("#e0b84c")
var selected_character_index := 0
var rule_page_index := 0
var archive_tab := "attributes"
var selected_menu_index := 0
var _tree_was_paused := false
var _theme_tween: Tween
var _word_tween: Tween
var _hover_focus_generation := 0

var overlay: Control
var blur_rect: ColorRect
var accent_bar: ColorRect
var menu_title: Label
var subtitle: Label
var content_root: Control
var bottom_hint: Label
var silhouette_transition: Control
var silhouette: TextureRect
var silhouette_shadow: TextureRect
var onomatopoeia: Label
var main_buttons: Array[Button] = []
var archive_content: Control
var archive_name: Label
var archive_story: Label
var archive_portrait: TextureRect
var archive_attribute_button: Button
var archive_skill_button: Button
var radar_chart: RadarChart
var rule_title: Label
var rule_body: RichTextLabel
var rule_visual: Label
var rule_counter: Label
var confirm_layer: ColorRect
var confirm_title: Label
var confirm_yes: Button
var confirm_action := ""


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_audio_buses()
	_build_overlay()
	_load_settings()
	visible = false


func is_open() -> bool:
	return visible


func open_menu() -> bool:
	if visible or not enabled:
		return false
	if can_open_callback.is_valid() and not bool(can_open_callback.call()):
		return false
	_tree_was_paused = get_tree().paused
	visible = true
	current_page = Page.MAIN
	confirm_layer.visible = false
	_show_main_page()
	get_tree().paused = true
	return true


func close_menu() -> void:
	if not visible:
		return
	confirm_layer.visible = false
	visible = false
	get_tree().paused = _tree_was_paused


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_TAB:
		if visible:
			_go_back()
		elif enabled:
			open_menu()
		get_viewport().set_input_as_handled()
	elif visible and event.keycode == KEY_ESCAPE:
		_go_back()
		get_viewport().set_input_as_handled()


func _build_overlay() -> void:
	var back_buffer := BackBufferCopy.new()
	back_buffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(back_buffer)

	blur_rect = ColorRect.new()
	blur_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blur_rect.color = Color.WHITE
	blur_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var blur_shader := Shader.new()
	blur_shader.code = """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint_color : source_color = vec4(0.48, 0.36, 0.88, 1.0);
void fragment() {
	vec4 screen = textureLod(screen_texture, SCREEN_UV, 2.2);
	screen.rgb = mix(screen.rgb * 0.28, tint_color.rgb * 0.22, 0.34);
	COLOR = vec4(screen.rgb, 1.0);
}
"""
	var blur_material := ShaderMaterial.new()
	blur_material.shader = blur_shader
	blur_rect.material = blur_material
	add_child(blur_rect)

	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	accent_bar = ColorRect.new()
	accent_bar.color = current_primary
	_place(accent_bar, Rect2(0, 0, 22, 900))
	overlay.add_child(accent_bar)

	menu_title = Label.new()
	menu_title.text = "MENU"
	menu_title.add_theme_font_override("font", TITLE_FONT)
	menu_title.add_theme_font_size_override("font_size", 72)
	menu_title.add_theme_color_override("font_color", current_primary)
	_place(menu_title, Rect2(72, 38, 560, 92))
	overlay.add_child(menu_title)

	subtitle = Label.new()
	subtitle.text = "PAUSED / MECHA CTB TACTICS"
	subtitle.add_theme_font_override("font", NUMBER_FONT)
	subtitle.add_theme_font_size_override("font_size", 23)
	subtitle.add_theme_color_override("font_color", COLOR_MUTED)
	_place(subtitle, Rect2(78, 126, 520, 38))
	overlay.add_child(subtitle)

	silhouette_transition = SILHOUETTE_TRANSITION_SCRIPT.new()
	_place(silhouette_transition, Rect2(650, 55, 840, 790))
	overlay.add_child(silhouette_transition)
	silhouette = silhouette_transition.incoming_main
	silhouette_shadow = silhouette_transition.incoming_shadow

	content_root = Control.new()
	content_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(content_root)

	bottom_hint = Label.new()
	bottom_hint.text = "ARROWS  SELECT    ENTER  CONFIRM    TAB / ESC  BACK"
	bottom_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom_hint.add_theme_font_override("font", NUMBER_FONT)
	bottom_hint.add_theme_font_size_override("font_size", 21)
	bottom_hint.add_theme_color_override("font_color", COLOR_TEXT)
	_place(bottom_hint, Rect2(300, 836, 1000, 42))
	overlay.add_child(bottom_hint)

	_build_confirmation()


func _show_main_page() -> void:
	current_page = Page.MAIN
	menu_title.text = "MENU"
	subtitle.text = "PAUSED / MECHA CTB TACTICS"
	bottom_hint.text = "ARROWS  SELECT    ENTER  CONFIRM    TAB / ESC  BACK"
	_clear_content()
	main_buttons.clear()
	silhouette_transition.visible = true
	selected_menu_index = 0

	var menu_box := VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 13)
	_place(menu_box, Rect2(82, 195, 530, 520))
	content_root.add_child(menu_box)
	for index in MenuThemeData.MENU_ITEMS.size():
		var item: Dictionary = MenuThemeData.MENU_ITEMS[index]
		var button := Button.new()
		button.text = "%02d  %s" % [index + 1, item["label"]]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(500, 76)
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_font_override("font", TITLE_FONT)
		button.add_theme_font_size_override("font_size", 32)
		button.focus_entered.connect(_select_main_item.bind(index))
		button.mouse_entered.connect(_focus_main_button_after_delay.bind(button))
		button.pressed.connect(_activate_main_item.bind(str(item["id"])))
		menu_box.add_child(button)
		main_buttons.append(button)


	onomatopoeia = Label.new()
	onomatopoeia.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	onomatopoeia.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	onomatopoeia.rotation = -0.08
	onomatopoeia.add_theme_font_override("font", JAPANESE_FONT)
	onomatopoeia.add_theme_font_size_override("font_size", 72)
	onomatopoeia.add_theme_color_override("font_color", current_secondary)
	onomatopoeia.add_theme_color_override("font_outline_color", COLOR_INK)
	onomatopoeia.add_theme_constant_override("outline_size", 8)
	_place(onomatopoeia, Rect2(910, 676, 620, 112))
	content_root.add_child(onomatopoeia)

	_select_main_item(0, false)
	main_buttons[0].grab_focus()


func _select_main_item(index: int, animate := true) -> void:
	if index < 0 or index >= MenuThemeData.MENU_ITEMS.size():
		return
	var previous_index := selected_menu_index
	selected_menu_index = index
	var item: Dictionary = MenuThemeData.MENU_ITEMS[index]
	var character_key := str(item["character"])
	if animate and character_key == silhouette_transition.target_key:
		_apply_main_button_styles(index)
		return
	var selected_theme := MenuThemeData.theme_for(character_key)
	_set_character_theme(character_key, animate)
	if animate:
		silhouette_transition.transition_to(
			character_key,
			selected_theme["primary"],
			selected_theme["secondary"],
			1 if index > previous_index else -1
		)
		_animate_onomatopoeia()
	else:
		silhouette_transition.set_initial(
			character_key,
			selected_theme["primary"],
			selected_theme["secondary"]
		)
	_apply_main_button_styles(index)


func _focus_main_button_after_delay(button: Button) -> void:
	_hover_focus_generation += 1
	var run_id := _hover_focus_generation
	await get_tree().create_timer(0.045, true).timeout
	if run_id != _hover_focus_generation or current_page != Page.MAIN:
		return
	if is_instance_valid(button) and button.is_hovered():
		button.grab_focus()


func _activate_main_item(item_id: String) -> void:
	match item_id:
		"continue": close_menu()
		"archive": _show_archive_page()
		"guide": _show_guide_page()
		"tutorial": _show_tutorial_page()
		"settings": _show_settings_page()
		"exit": _show_confirmation("exit", "确定要退出游戏吗？")


func _show_archive_page() -> void:
	current_page = Page.ARCHIVE
	silhouette_transition.visible = false
	menu_title.text = "ARCHIVE"
	subtitle.text = "人物与技能图鉴"
	bottom_hint.text = "选择角色与标签页查看资料    TAB / ESC  返回"
	_clear_content()

	var list_box := VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 8)
	_place(list_box, Rect2(56, 184, 250, 580))
	content_root.add_child(list_box)
	var characters := BattleData.characters()
	for index in characters.size():
		var character: Dictionary = characters[index]
		var button := Button.new()
		button.text = str(character["name"])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(238, 62)
		button.add_theme_font_override("font", BODY_FONT)
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(_select_archive_character.bind(index))
		list_box.add_child(button)

	archive_portrait = TextureRect.new()
	archive_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	archive_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	archive_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(archive_portrait, Rect2(314, 174, 360, 600))
	content_root.add_child(archive_portrait)

	var details := PanelContainer.new()
	details.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.025, 0.04, 0.86), current_primary, 3))
	_place(details, Rect2(692, 170, 850, 620))
	content_root.add_child(details)
	var details_box := VBoxContainer.new()
	details_box.add_theme_constant_override("separation", 10)
	details.add_child(details_box)

	archive_name = Label.new()
	archive_name.add_theme_font_override("font", BODY_FONT)
	archive_name.add_theme_font_size_override("font_size", 31)
	archive_name.add_theme_color_override("font_color", COLOR_TEXT)
	details_box.add_child(archive_name)

	archive_story = Label.new()
	archive_story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	archive_story.custom_minimum_size = Vector2(0, 64)
	archive_story.add_theme_font_override("font", BODY_FONT)
	archive_story.add_theme_font_size_override("font_size", 16)
	archive_story.add_theme_color_override("font_color", COLOR_MUTED)
	details_box.add_child(archive_story)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	details_box.add_child(tabs)
	archive_attribute_button = _text_button("属性", Vector2(140, 44))
	archive_attribute_button.pressed.connect(_set_archive_tab.bind("attributes"))
	tabs.add_child(archive_attribute_button)
	archive_skill_button = _text_button("技能", Vector2(140, 44))
	archive_skill_button.pressed.connect(_set_archive_tab.bind("skills"))
	tabs.add_child(archive_skill_button)

	archive_content = Control.new()
	archive_content.custom_minimum_size = Vector2(800, 425)
	archive_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_box.add_child(archive_content)

	selected_character_index = clampi(selected_character_index, 0, characters.size() - 1)
	_select_archive_character(selected_character_index)


func _select_archive_character(index: int) -> void:
	var characters := BattleData.characters()
	if index < 0 or index >= characters.size():
		return
	selected_character_index = index
	var character: Dictionary = characters[index]
	_set_character_theme(str(character["key"]))
	archive_name.text = "%s  /  %s" % [character["name"], character["stand"]]
	archive_story.text = str(character["story"])
	_set_portrait(archive_portrait, str(character["key"]), false)
	_rebuild_archive_content(character)


func _set_archive_tab(tab_id: String) -> void:
	archive_tab = tab_id
	_rebuild_archive_content(BattleData.characters()[selected_character_index])


func _rebuild_archive_content(character: Dictionary) -> void:
	for child in archive_content.get_children():
		archive_content.remove_child(child)
		child.queue_free()
	archive_attribute_button.add_theme_stylebox_override("normal", _panel_style(current_primary.darkened(0.42) if archive_tab == "attributes" else COLOR_PANEL, current_primary, 2))
	archive_skill_button.add_theme_stylebox_override("normal", _panel_style(current_primary.darkened(0.42) if archive_tab == "skills" else COLOR_PANEL, current_primary, 2))
	if archive_tab == "attributes":
		_build_attribute_content(character)
	else:
		_build_skill_content(character)


func _build_attribute_content(character: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	archive_content.add_child(row)
	var stats := RichTextLabel.new()
	stats.custom_minimum_size = Vector2(390, 390)
	stats.bbcode_enabled = true
	stats.fit_content = false
	stats.scroll_active = false
	stats.add_theme_font_override("normal_font", BODY_FONT)
	stats.add_theme_font_size_override("normal_font_size", 18)
	stats.text = (
		"[color=#9296a3]固定基础属性[/color]\n\n"
		+ "HP              [color=%s]%d[/color]\n"
		+ "初始 AP         %d / %d\n"
		+ "基础伤害        %d\n"
		+ "暴击值          %d / 50\n"
		+ "防御            %d / 50\n"
		+ "运气            %d / 50\n"
		+ "速度 p          %d\n"
		+ "射程            R_opt %d  /  R_max %d"
	) % [current_primary.to_html(), character["max_hp"], character["initial_ap"], BattleData.MAX_AP, character["damage"], character["crit"], character["defense"], character["luck"], character["speed"], character["r_opt"], character["r_max"]]
	row.add_child(stats)
	radar_chart = RadarChart.new()
	radar_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	radar_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(radar_chart)
	radar_chart.set_chart(character["radar"], current_primary)


func _build_skill_content(character: Dictionary) -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	archive_content.add_child(scroll)
	var skill_box := VBoxContainer.new()
	skill_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_box.add_theme_constant_override("separation", 8)
	scroll.add_child(skill_box)
	for skill_data in character["skills"]:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _panel_style(Color("#171923"), current_primary.darkened(0.18), 2))
		skill_box.add_child(panel)
		var text := RichTextLabel.new()
		text.custom_minimum_size = Vector2(0, 86)
		text.bbcode_enabled = true
		text.fit_content = false
		text.scroll_active = false
		text.add_theme_font_override("normal_font", BODY_FONT)
		text.add_theme_font_size_override("normal_font_size", 16)
		text.text = "[font_size=21][b]%s[/b][/font_size]    [color=%s]%d AP[/color]    射程 %s    [color=#d8b84c]%s[/color]\n%s" % [skill_data["name"], current_primary.to_html(), skill_data["cost"], MenuThemeData.range_text(skill_data), MenuThemeData.skill_summary(skill_data), MenuThemeData.skill_description(skill_data)]
		panel.add_child(text)


func _show_guide_page() -> void:
	current_page = Page.GUIDE
	silhouette_transition.visible = false
	menu_title.text = "GUIDE"
	subtitle.text = "游戏规则介绍"
	bottom_hint.text = "左右按钮翻页    TAB / ESC  返回"
	_clear_content()

	var page_panel := PanelContainer.new()
	page_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.025, 0.04, 0.88), current_primary, 3))
	_place(page_panel, Rect2(80, 180, 1440, 590))
	content_root.add_child(page_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	page_panel.add_child(row)

	var text_box := VBoxContainer.new()
	text_box.custom_minimum_size = Vector2(880, 0)
	text_box.add_theme_constant_override("separation", 18)
	row.add_child(text_box)
	rule_counter = Label.new()
	rule_counter.add_theme_font_override("font", NUMBER_FONT)
	rule_counter.add_theme_font_size_override("font_size", 24)
	rule_counter.add_theme_color_override("font_color", current_primary)
	text_box.add_child(rule_counter)
	rule_title = Label.new()
	rule_title.add_theme_font_override("font", BODY_FONT)
	rule_title.add_theme_font_size_override("font_size", 38)
	rule_title.add_theme_color_override("font_color", COLOR_TEXT)
	text_box.add_child(rule_title)
	rule_body = RichTextLabel.new()
	rule_body.bbcode_enabled = false
	rule_body.fit_content = false
	rule_body.scroll_active = false
	rule_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule_body.add_theme_font_override("normal_font", BODY_FONT)
	rule_body.add_theme_font_size_override("normal_font_size", 20)
	rule_body.add_theme_color_override("default_color", Color("#dedde2"))
	rule_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_box.add_child(rule_body)

	var visual_panel := PanelContainer.new()
	visual_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	visual_panel.add_theme_stylebox_override("panel", _panel_style(Color("#090a10"), current_secondary, 4))
	row.add_child(visual_panel)
	rule_visual = Label.new()
	rule_visual.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule_visual.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rule_visual.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule_visual.add_theme_font_override("font", NUMBER_FONT)
	rule_visual.add_theme_font_size_override("font_size", 54)
	rule_visual.add_theme_color_override("font_color", current_primary)
	visual_panel.add_child(rule_visual)

	var previous := _text_button("上一页", Vector2(150, 48))
	_place(previous, Rect2(555, 784, 150, 48))
	previous.pressed.connect(_change_rule_page.bind(-1))
	content_root.add_child(previous)
	var next := _text_button("下一页", Vector2(150, 48))
	_place(next, Rect2(895, 784, 150, 48))
	next.pressed.connect(_change_rule_page.bind(1))
	content_root.add_child(next)
	_update_rule_page()


func _change_rule_page(delta: int) -> void:
	rule_page_index = posmod(rule_page_index + delta, MenuThemeData.RULE_PAGES.size())
	_update_rule_page()


func _update_rule_page() -> void:
	var page: Dictionary = MenuThemeData.RULE_PAGES[rule_page_index]
	rule_counter.text = "%s  /  04" % page["number"]
	rule_title.text = str(page["title"])
	rule_body.text = str(page["body"])
	var visuals := ["3 VS 3\n\n6 × 6", "DISTANCE\n\n|X1-X2| + |Y1-Y2|", "CTB\n\nS = 100 / p", "CRITICAL\n\n× 1.5"]
	rule_visual.text = visuals[rule_page_index]


func _show_tutorial_page() -> void:
	current_page = Page.TUTORIAL
	silhouette_transition.visible = false
	menu_title.text = "TUTORIAL"
	subtitle.text = "游戏教程"
	bottom_hint.text = "上一步 / 下一步 / 重播 / 返回    TAB / ESC  返回菜单"
	_clear_content()
	var tutorial_controller := TutorialController.new()
	tutorial_controller.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tutorial_controller.exit_requested.connect(_show_main_page)
	content_root.add_child(tutorial_controller)


func _show_settings_page() -> void:
	current_page = Page.SETTINGS
	silhouette_transition.visible = false
	menu_title.text = "SETTINGS"
	subtitle.text = "系统设置"
	bottom_hint.text = "设置自动保存    TAB / ESC  返回"
	_clear_content()

	var settings_panel := PanelContainer.new()
	settings_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.025, 0.04, 0.9), current_primary, 3))
	_place(settings_panel, Rect2(300, 180, 1000, 600))
	content_root.add_child(settings_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	settings_panel.add_child(box)
	box.add_child(_section_label("音量"))
	for bus_name in ["BGM", "SE", "Voice"]:
		box.add_child(_build_volume_row(bus_name))
	box.add_child(HSeparator.new())
	box.add_child(_section_label("显示"))

	var fullscreen_row := HBoxContainer.new()
	fullscreen_row.add_child(_setting_label("全屏模式"))
	var fullscreen := CheckButton.new()
	fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen.text = "开启"
	fullscreen.add_theme_font_override("font", BODY_FONT)
	fullscreen.toggled.connect(_set_fullscreen)
	fullscreen_row.add_child(fullscreen)
	box.add_child(fullscreen_row)

	var resolution_row := HBoxContainer.new()
	resolution_row.add_child(_setting_label("窗口分辨率"))
	var resolution_select := OptionButton.new()
	resolution_select.custom_minimum_size = Vector2(300, 46)
	resolution_select.add_theme_font_override("font", BODY_FONT)
	var configured_resolution := _configured_resolution()
	for index in MenuThemeData.RESOLUTIONS.size():
		var resolution: Vector2i = MenuThemeData.RESOLUTIONS[index]
		resolution_select.add_item("%d × %d" % [resolution.x, resolution.y], index)
		if resolution == configured_resolution:
			resolution_select.select(index)
	resolution_select.item_selected.connect(_set_resolution)
	resolution_row.add_child(resolution_select)
	box.add_child(resolution_row)

	var title_button := _text_button("返回标题", Vector2(280, 52))
	title_button.pressed.connect(_show_confirmation.bind("title", "返回标题将放弃当前战斗进度，是否继续？"))
	box.add_child(title_button)


func _build_volume_row(bus_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_child(_setting_label({"BGM": "背景音乐", "SE": "音效", "Voice": "语音"}[bus_name]))
	var slider := HSlider.new()
	slider.name = "%sSlider" % bus_name
	slider.custom_minimum_size = Vector2(500, 32)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = _bus_linear_volume(bus_name)
	slider.value_changed.connect(_set_bus_volume.bind(bus_name))
	row.add_child(slider)
	return row


func _setting_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(260, 42)
	label.add_theme_font_override("font", BODY_FONT)
	label.add_theme_font_size_override("font_size", 19)
	return label


func _section_label(text: String) -> Label:
	var label := _setting_label(text)
	label.add_theme_font_size_override("font_size", 25)
	label.add_theme_color_override("font_color", current_primary)
	return label


func _set_bus_volume(value: float, bus_name: String) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	AudioServer.set_bus_mute(bus_index, value <= 0.001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(value, 0.001)))
	_save_settings()


func _bus_linear_volume(bus_name: String) -> float:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0 or AudioServer.is_bus_mute(bus_index):
		return 0.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(bus_index)), 0.0, 1.0)


func _set_fullscreen(active: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if active else DisplayServer.WINDOW_MODE_WINDOWED)
	_save_settings()


func _set_resolution(index: int) -> void:
	if index < 0 or index >= MenuThemeData.RESOLUTIONS.size():
		return
	var resolution: Vector2i = MenuThemeData.RESOLUTIONS[index]
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_size(resolution)
	_save_settings(resolution)


func _configured_resolution() -> Vector2i:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		return Vector2i(config.get_value("display", "width", 1280), config.get_value("display", "height", 720))
	return Vector2i(1280, 720)


func _save_settings(resolution := Vector2i.ZERO) -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	for bus_name in ["BGM", "SE", "Voice"]:
		config.set_value("audio", bus_name.to_lower(), _bus_linear_volume(bus_name))
	config.set_value("display", "fullscreen", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	var target_resolution: Vector2i = resolution if resolution != Vector2i.ZERO else _configured_resolution()
	config.set_value("display", "width", target_resolution.x)
	config.set_value("display", "height", target_resolution.y)
	config.save(CONFIG_PATH)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	for bus_name in ["BGM", "SE", "Voice"]:
		_set_bus_volume(float(config.get_value("audio", bus_name.to_lower(), 0.8)), bus_name)
	var fullscreen := bool(config.get_value("display", "fullscreen", false))
	var resolution := Vector2i(config.get_value("display", "width", 1280), config.get_value("display", "height", 720))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if not fullscreen:
		DisplayServer.window_set_size(resolution)


func _ensure_audio_buses() -> void:
	for bus_name in ["BGM", "SE", "Voice"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func _build_confirmation() -> void:
	confirm_layer = ColorRect.new()
	confirm_layer.color = Color(0, 0, 0, 0.76)
	confirm_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirm_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_layer.visible = false
	overlay.add_child(confirm_layer)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL, current_primary, 4))
	_place(panel, Rect2(470, 290, 660, 300))
	confirm_layer.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)
	panel.add_child(box)
	confirm_title = Label.new()
	confirm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_title.add_theme_font_override("font", BODY_FONT)
	confirm_title.add_theme_font_size_override("font_size", 24)
	box.add_child(confirm_title)
	var choices := HBoxContainer.new()
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	choices.add_theme_constant_override("separation", 20)
	box.add_child(choices)
	confirm_yes = _text_button("是", Vector2(170, 52))
	confirm_yes.pressed.connect(_confirm_yes)
	choices.add_child(confirm_yes)
	var no := _text_button("否", Vector2(170, 52))
	no.pressed.connect(func() -> void: confirm_layer.visible = false)
	choices.add_child(no)


func _show_confirmation(action: String, text: String) -> void:
	confirm_action = action
	confirm_title.text = text
	confirm_layer.visible = true
	confirm_yes.grab_focus()


func _confirm_yes() -> void:
	match confirm_action:
		"exit":
			get_tree().paused = false
			get_tree().quit()
		"title":
			close_menu()
			return_to_title_requested.emit()


func _go_back() -> void:
	if confirm_layer.visible:
		confirm_layer.visible = false
		return
	if current_page == Page.MAIN:
		close_menu()
	else:
		_show_main_page()


func _set_character_theme(character_key: String, animate := true) -> void:
	current_character_key = character_key
	var selected_theme := MenuThemeData.theme_for(character_key)
	var next_primary: Color = selected_theme["primary"]
	var next_secondary: Color = selected_theme["secondary"]
	if _theme_tween != null and _theme_tween.is_valid():
		_theme_tween.kill()
	if animate and is_inside_tree():
		_theme_tween = create_tween()
		_theme_tween.set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_theme_tween.tween_method(_apply_primary_color, current_primary, next_primary, 0.25)
		_theme_tween.tween_method(_apply_secondary_color, current_secondary, next_secondary, 0.25)
	else:
		_apply_primary_color(next_primary)
		_apply_secondary_color(next_secondary)
	current_primary = next_primary
	current_secondary = next_secondary
	if onomatopoeia != null and is_instance_valid(onomatopoeia):
		onomatopoeia.text = str(selected_theme["onomatopoeia"])


func _apply_primary_color(color: Color) -> void:
	accent_bar.color = color
	menu_title.add_theme_color_override("font_color", color)
	if blur_rect.material is ShaderMaterial:
		blur_rect.material.set_shader_parameter("tint_color", color)


func _apply_secondary_color(color: Color) -> void:
	if onomatopoeia != null:
		onomatopoeia.add_theme_color_override("font_color", color)


func _animate_onomatopoeia() -> void:
	if onomatopoeia == null or not is_instance_valid(onomatopoeia):
		return
	if _word_tween != null and _word_tween.is_valid():
		_word_tween.kill()
	onomatopoeia.pivot_offset = onomatopoeia.size * 0.5
	onomatopoeia.scale = Vector2(0.82, 0.82)
	onomatopoeia.modulate.a = 0.25
	_word_tween = create_tween()
	_word_tween.set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_word_tween.tween_property(onomatopoeia, "scale", Vector2.ONE, 0.24)
	_word_tween.tween_property(onomatopoeia, "modulate:a", 1.0, 0.14)


func _apply_main_button_styles(selected_index: int) -> void:
	for index in main_buttons.size():
		var button := main_buttons[index]
		var selected := index == selected_index
		button.add_theme_color_override("font_color", COLOR_INK if selected else COLOR_TEXT)
		button.add_theme_color_override("font_focus_color", COLOR_INK)
		button.add_theme_color_override("font_hover_color", COLOR_INK)
		button.add_theme_stylebox_override("normal", _panel_style(current_primary if selected else Color(0.04, 0.04, 0.065, 0.78), current_primary.darkened(0.35), 2))
		button.add_theme_stylebox_override("focus", _panel_style(current_primary, current_secondary, 4))
		button.add_theme_stylebox_override("hover", _panel_style(current_primary, current_secondary, 3))


func _set_portrait(target: TextureRect, character_key: String, as_silhouette: bool) -> void:
	var character := MenuThemeData.character_by_key(character_key)
	var texture_path := str(character.get("portrait_texture", character["texture"]))
	var texture: Texture2D = load(texture_path)
	target.texture = texture
	var image := texture.get_image()
	var remove_white := image == null or image.detect_alpha() == Image.ALPHA_NONE
	var shader := Shader.new()
	if as_silhouette:
		shader.code = """
shader_type canvas_item;
uniform vec4 theme_color : source_color = vec4(0.48, 0.36, 0.88, 1.0);
uniform float remove_white = 0.0;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float white_mask = smoothstep(0.90, 0.995, min(tex.r, min(tex.g, tex.b))) * remove_white;
	float mask = tex.a * (1.0 - white_mask);
	COLOR = vec4(theme_color.rgb, mask * 0.96);
}
"""
	else:
		shader.code = """
shader_type canvas_item;
uniform float remove_white = 0.0;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float white_mask = smoothstep(0.93, 0.998, min(tex.r, min(tex.g, tex.b))) * remove_white;
	COLOR = vec4(tex.rgb, tex.a * (1.0 - white_mask));
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("remove_white", 1.0 if remove_white else 0.0)
	if as_silhouette:
		material.set_shader_parameter("theme_color", current_primary)
	target.material = material


func _clear_content() -> void:
	for child in content_root.get_children():
		content_root.remove_child(child)
		child.queue_free()
	onomatopoeia = null


func _text_button(text: String, minimum_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = minimum_size
	button.add_theme_font_override("font", BODY_FONT)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_stylebox_override("normal", _panel_style(COLOR_PANEL, current_primary, 2))
	button.add_theme_stylebox_override("hover", _panel_style(current_primary.darkened(0.35), current_primary, 3))
	button.add_theme_stylebox_override("focus", _panel_style(current_primary.darkened(0.35), current_primary, 3))
	return button


func _panel_style(color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(4)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
