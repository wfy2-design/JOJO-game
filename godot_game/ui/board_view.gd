class_name BoardView
extends Control

signal cell_clicked(cell: Vector2i)
signal cell_hovered(cell: Vector2i)

const BOARD_SIZE := 6
const TILE_WIDTH := 146.0
const TILE_HEIGHT := 74.0

var model: BattleModel
var highlights: Dictionary = {}
var hovered_cell := Vector2i(-1, -1)
var texture_cache: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)


func set_model(value: BattleModel) -> void:
	model = value
	queue_redraw()


func set_highlights(value: Dictionary) -> void:
	highlights = value
	queue_redraw()


func board_origin() -> Vector2:
	return Vector2(size.x * 0.5, 140.0)


func cell_center(cell: Vector2i) -> Vector2:
	var origin := board_origin()
	return origin + Vector2(
		float(cell.x - cell.y) * TILE_WIDTH * 0.5,
		float(cell.x + cell.y) * TILE_HEIGHT * 0.5
	)


func cell_polygon(cell: Vector2i) -> PackedVector2Array:
	var center := cell_center(cell)
	return PackedVector2Array([
		center + Vector2(0, -TILE_HEIGHT * 0.5),
		center + Vector2(TILE_WIDTH * 0.5, 0),
		center + Vector2(0, TILE_HEIGHT * 0.5),
		center + Vector2(-TILE_WIDTH * 0.5, 0),
	])


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#10121b"), true)
	for y in BOARD_SIZE:
		for x in BOARD_SIZE:
			var cell := Vector2i(x, y)
			var base := Color("#1a1c28") if (x + y) % 2 == 0 else Color("#222532")
			var kind := str(highlights.get(cell, ""))
			match kind:
				"move":
					base = Color(0.21, 0.54, 0.88, 0.62)
				"sprint":
					base = Color(0.26, 0.80, 0.79, 0.75)
				"attack":
					base = Color(0.95, 0.71, 0.18, 0.58)
				"skill":
					base = Color(0.24, 0.75, 0.44, 0.62)
				"danger":
					base = Color(0.93, 0.14, 0.18, 0.67)
			if cell == hovered_cell:
				base = base.lightened(0.18)
			var poly := cell_polygon(cell)
			draw_colored_polygon(poly, base)
			draw_polyline(_closed(poly), Color("#52586a"), 2.0, true)
	if model == null:
		return
	for field in model.fields:
		if field["type"] == "fire_wall":
			var center := cell_center(field["cell"])
			draw_circle(center, 24.0, Color(0.94, 0.18, 0.08, 0.68))
			draw_arc(center, 31.0, 0, TAU, 24, Color("#ffd241"), 4.0)
	_draw_units()


func _draw_units() -> void:
	var groups: Dictionary = {}
	for unit in model.living_units():
		var cell: Vector2i = unit["pos"]
		if not groups.has(cell):
			groups[cell] = []
		groups[cell].append(unit)
	for cell in groups:
		var group: Array = groups[cell]
		group.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["id"]) < int(b["id"]))
		for index in group.size():
			var unit: Dictionary = group[index]
			var offset := _stack_offset(index, group.size())
			var center := cell_center(cell) + offset
			var team_color := Color("#3589e0") if unit["team"] == BattleData.TEAM_A else Color("#ee232f")
			var is_current: bool = unit["id"] == model.current_unit_id
			var portrait_size := 76.0 if is_current else (58.0 if group.size() > 1 else 68.0)
			var portrait_center := center + Vector2(0, -44)
			var portrait_rect := Rect2(
				portrait_center - Vector2.ONE * portrait_size * 0.5,
				Vector2.ONE * portrait_size
			)
			var texture := _load_texture(unit["texture"])
			if texture != null:
				draw_texture_rect(texture, portrait_rect, false)
			draw_arc(portrait_center, portrait_size * 0.5 + 4.0, 0, TAU, 28, team_color, 4.0)
			if is_current:
				draw_arc(portrait_center, portrait_size * 0.5 + 10.0, 0, TAU, 28, Color("#ffd241"), 4.0)
			var hp_ratio: float = float(unit["hp"]) / float(unit["max_hp"])
			draw_rect(Rect2(center + Vector2(-35, -7), Vector2(70, 8)), Color("#0b0c14"), true)
			draw_rect(Rect2(center + Vector2(-34, -6), Vector2(68 * hp_ratio, 6)), team_color, true)
			draw_string(
				ThemeDB.fallback_font,
				center + Vector2(-34, 18),
				str(unit["name"]),
				HORIZONTAL_ALIGNMENT_CENTER,
				68,
				13,
				Color("#f7f4eb")
			)


func _stack_offset(index: int, count: int) -> Vector2:
	if count <= 1:
		return Vector2.ZERO
	var spacing := 72.0
	return Vector2((float(index) - float(count - 1) * 0.5) * spacing, float(index % 2) * 10.0)


func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if not texture_cache.has(path):
		texture_cache[path] = load(path)
	return texture_cache[path]


func _closed(poly: PackedVector2Array) -> PackedVector2Array:
	var points := PackedVector2Array(poly)
	points.append(poly[0])
	return points


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var cell := _cell_at(event.position)
		if cell != hovered_cell:
			hovered_cell = cell
			cell_hovered.emit(cell)
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var cell := _cell_at(event.position)
		if cell.x >= 0:
			cell_clicked.emit(cell)
			accept_event()


func _cell_at(point: Vector2) -> Vector2i:
	for y in BOARD_SIZE:
		for x in BOARD_SIZE:
			var cell := Vector2i(x, y)
			if Geometry2D.is_point_in_polygon(point, cell_polygon(cell)):
				return cell
	return Vector2i(-1, -1)
