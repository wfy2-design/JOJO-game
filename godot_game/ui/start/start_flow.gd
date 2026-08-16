class_name StartFlow
extends Control

## 开始流程状态机：TITLE → MODE → CONFIG，统一方向性转场。

signal mode_confirmed(selected_mode: String, team_size: int, board_size: int, random_spawn: bool)
signal tutorial_requested
signal exit_requested

var title_screen: TitleScreen
var mode_screen: ModeSelectScreen
var config_screen: MatchConfigScreen
var pending_mode := "local"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	title_screen = TitleScreen.new()
	title_screen.enter_requested.connect(show_mode)
	title_screen.exit_requested.connect(func() -> void: exit_requested.emit())
	add_child(title_screen)

	mode_screen = ModeSelectScreen.new()
	mode_screen.mode_selected.connect(show_config)
	mode_screen.tutorial_requested.connect(func() -> void: tutorial_requested.emit())
	mode_screen.back_requested.connect(show_title)
	add_child(mode_screen)

	config_screen = MatchConfigScreen.new()
	config_screen.confirm_requested.connect(func(mode: String, team: int, board: int, random: bool) -> void:
		mode_confirmed.emit(mode, team, board, random)
	)
	config_screen.back_requested.connect(show_mode)
	add_child(config_screen)

	title_screen.visible = true
	mode_screen.visible = false
	config_screen.visible = false


func show_title() -> void:
	pending_mode = "local"
	_switch_to(title_screen)


func show_mode() -> void:
	_switch_to(mode_screen)


func show_config(selected_mode: String) -> void:
	pending_mode = selected_mode
	config_screen.setup(selected_mode)
	_switch_to(config_screen)


func _switch_to(target: Control) -> void:
	title_screen.visible = target == title_screen
	mode_screen.visible = target == mode_screen
	config_screen.visible = target == config_screen
	target.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(target, "modulate:a", 1.0, 0.18)
