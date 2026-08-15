class_name RadarChart
extends Control

const AXES := ["破坏力", "速度", "射程", "持久力", "精密度", "成长性"]

var values: Array = [0, 0, 0, 0, 0, 0]
var display_scale := 1.0
var accent := Color("#7b5ce0")
var animation: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(330, 300)


func set_chart(next_values: Array, next_accent: Color, animate := true) -> void:
	values = next_values.duplicate()
	accent = next_accent
	if animation != null and animation.is_valid():
		animation.kill()
	display_scale = 0.0 if animate else 1.0
	queue_redraw()
	if animate:
		animation = create_tween()
		animation.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		animation.tween_method(_set_display_scale, 0.0, 1.0, 0.4)


func _set_display_scale(value: float) -> void:
	display_scale = value
	queue_redraw()


func _draw() -> void:
	var center := size * Vector2(0.5, 0.52)
	var radius := minf(size.x, size.y) * 0.32
	for ring in range(1, 5):
		var points := PackedVector2Array()
		for index in AXES.size():
			points.append(_point(center, radius * float(ring) / 4.0, index))
		points.append(points[0])
		draw_polyline(points, Color(1, 1, 1, 0.18), 1.5, true)
	for index in AXES.size():
		var edge := _point(center, radius, index)
		draw_line(center, edge, Color(1, 1, 1, 0.16), 1.0, true)
		var label_position := _point(center, radius + 28.0, index)
		var font := ThemeDB.fallback_font
		var text_size := font.get_string_size(AXES[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
		draw_string(font, label_position - Vector2(text_size.x * 0.5, -5), AXES[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#f5f3ea"))
	var data_points := PackedVector2Array()
	for index in AXES.size():
		var normalized := clampf(float(values[index]) / 100.0, 0.0, 1.0) * display_scale
		data_points.append(_point(center, radius * normalized, index))
	if data_points.size() == AXES.size():
		draw_colored_polygon(data_points, Color(accent, 0.35))
		data_points.append(data_points[0])
		draw_polyline(data_points, accent, 3.0, true)


func _point(center: Vector2, radius: float, index: int) -> Vector2:
	var angle := -PI * 0.5 + TAU * float(index) / float(AXES.size())
	return center + Vector2(cos(angle), sin(angle)) * radius
