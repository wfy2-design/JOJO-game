class_name TacticalBackdrop
extends Control

## 战术透视棋盘背景：只绘制透视线、格点与阵营边界，不运行战斗模型。

const COLOR_BG := Color("#0b0c14")
const COLOR_GRID := Color("#232838")
const COLOR_BLUE := Color("#3589e0")
const COLOR_RED := Color("#ee232f")
const COLOR_SCAN := Color("#ffd241")

var scan_t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(delta: float) -> void:
	scan_t = fmod(scan_t + delta * 0.22, 1.0)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG, true)
	var vanish := Vector2(size.x * 0.5, size.y * 0.30)

	# 放射状纵深线
	for i in range(-8, 9):
		var angle := float(i) * 0.10
		var direction := Vector2(sin(angle), cos(angle))
		var start := vanish + direction * 140.0
		var finish := vanish + direction * (size.y * 1.6)
		draw_line(start, finish, Color(COLOR_GRID, 0.55), 1.2)

	# 水平透视格线（越远越密）
	for i in range(1, 10):
		var t := float(i) / 10.0
		var y := vanish.y + pow(t, 2.1) * (size.y - vanish.y)
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(COLOR_GRID, 0.48), 1.0)

	# 阵营边界：蓝、红两线汇向消失点
	draw_line(Vector2(-40, size.y * 0.52), vanish, Color(COLOR_BLUE, 0.55), 2.5)
	draw_line(Vector2(size.x + 40, size.y * 0.52), vanish, Color(COLOR_RED, 0.55), 2.5)

	# 横向扫描线
	var scan_y := vanish.y + scan_t * (size.y - vanish.y)
	draw_line(Vector2(0, scan_y), Vector2(size.x, scan_y), Color(COLOR_SCAN, 0.16), 2.0)
