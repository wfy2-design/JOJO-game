class_name BoardView
extends Control

signal cell_clicked(cell: Vector2i)
signal cell_hovered(cell: Vector2i)
signal unit_clicked(unit_id: int)
signal unit_hovered(unit_id: int)

const TILE_WIDTH := 164.0
const TILE_HEIGHT := 82.0

var board_size := 6
var model: BattleModel
var highlights: Dictionary = {}
var hovered_cell := Vector2i(-1, -1)
var hovered_unit_id := -1
var targeted_unit_id := -1
var texture_cache: Dictionary = {}
var effect_layer: Node2D
var fire_particles: Dictionary = {}
var _particle_texture: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)
	effect_layer = Node2D.new()
	add_child(effect_layer)
	_particle_texture = _make_particle_texture()


func set_model(value: BattleModel) -> void:
	model = value
	if model != null:
		board_size = model.board_size
	clear_fire_particles()
	queue_redraw()


func clear_fire_particles() -> void:
	for p in fire_particles.values():
		if is_instance_valid(p):
			p.queue_free()
	fire_particles.clear()


func set_highlights(value: Dictionary) -> void:
	highlights = value
	queue_redraw()


func set_targeted_unit(unit_id: int) -> void:
	targeted_unit_id = unit_id
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
	for y in board_size:
		for x in board_size:
			var cell := Vector2i(x, y)
			var base := Color("#1a1c28") if (x + y) % 2 == 0 else Color("#222532")
			var highlight: Variant = highlights.get(cell, "")
			var kind := str(highlight.get("kind", "")) if highlight is Dictionary else str(highlight)
			var hit_chance := float(highlight.get("hit", -1.0)) if highlight is Dictionary else -1.0
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
				"hit":
					var heat := clampf(hit_chance, 0.0, 1.0)
					base = Color("#f7d9c4").lerp(Color("#c91836"), heat)
					base.a = lerpf(0.50, 0.88, heat)
			if cell == hovered_cell:
				base = base.lightened(0.18)
			var poly := cell_polygon(cell)
			draw_colored_polygon(poly, base)
			draw_polyline(_closed(poly), Color("#52586a"), 2.0, true)
			if kind == "hit":
				var percent := "%d%%" % roundi(hit_chance * 100.0)
				draw_string(
					ThemeDB.fallback_font,
					cell_center(cell) + Vector2(-28, 7),
					percent,
					HORIZONTAL_ALIGNMENT_CENTER,
					56,
					15,
					Color("#fff8ef") if hit_chance >= 0.45 else Color("#51212b")
				)
	if model == null:
		return
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
			if int(unit["id"]) == targeted_unit_id:
				var target_ring := _ellipse_points(center + Vector2(0, 2), Vector2(34, 12))
				draw_colored_polygon(target_ring, Color(0.93, 0.08, 0.12, 0.24))
				draw_polyline(_closed(target_ring), Color("#ff263d"), 4.0, true)
			var texture := _load_texture(unit["texture"])
			if texture != null:
				var source_size := texture.get_size()
				var fit_scale := portrait_size / maxf(source_size.x, source_size.y)
				var fitted_size := source_size * fit_scale
				var fitted_rect := Rect2(portrait_center - fitted_size * 0.5, fitted_size)
				draw_texture_rect(texture, fitted_rect, false)
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


func _unit_at(point: Vector2) -> int:
	if model == null:
		return -1
	var groups: Dictionary = {}
	for unit in model.living_units():
		var cell: Vector2i = unit["pos"]
		if not groups.has(cell):
			groups[cell] = []
		groups[cell].append(unit)
	var best_id := -1
	var best_distance := INF
	for cell in groups:
		var group: Array = groups[cell]
		group.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["id"]) < int(b["id"]))
		for index in group.size():
			var unit: Dictionary = group[index]
			var center := cell_center(cell) + _stack_offset(index, group.size())
			var portrait_center := center + Vector2(0, -44)
			var portrait_size := 76.0 if int(unit["id"]) == model.current_unit_id else (58.0 if group.size() > 1 else 68.0)
			var distance := point.distance_to(portrait_center)
			if distance <= portrait_size * 0.5 + 8.0 and distance < best_distance:
				best_distance = distance
				best_id = int(unit["id"])
	return best_id


func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if not texture_cache.has(path):
		texture_cache[path] = load(path)
	return texture_cache[path]


func _make_particle_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 32
	texture.height = 32
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	return texture


func _make_fire_particles() -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.texture = _particle_texture
	particles.amount = 26
	particles.lifetime = 0.9
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.emitting = true
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 5.0
	material.direction = Vector3(0, -1, 0)
	material.spread = 22.0
	material.initial_velocity_min = 24.0
	material.initial_velocity_max = 48.0
	material.gravity = Vector3(0, -85, 0)
	material.scale_min = 0.35
	material.scale_max = 0.85
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([
		Color(1.0, 0.95, 0.45, 1.0),
		Color(1.0, 0.55, 0.12, 1.0),
		Color(0.88, 0.18, 0.05, 0.85),
		Color(0.45, 0.0, 0.0, 0.0),
	])
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 0.72, 1.0])
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	material.color_ramp = ramp_texture
	particles.process_material = material
	return particles


func _make_ice_particles() -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.texture = _particle_texture
	particles.amount = 22
	particles.lifetime = 0.9
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.emitting = true
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 8.0
	material.direction = Vector3(0, 0, 0)
	material.spread = 180.0
	material.initial_velocity_min = 30.0
	material.initial_velocity_max = 70.0
	material.gravity = Vector3(0, 40, 0)
	material.scale_min = 0.25
	material.scale_max = 0.6
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([
		Color(0.95, 1.0, 1.0, 1.0),
		Color(0.55, 0.85, 1.0, 0.9),
		Color(0.3, 0.6, 1.0, 0.0),
	])
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	material.color_ramp = ramp_texture
	particles.process_material = material
	return particles


func sync_fields(fields: Array) -> void:
	if effect_layer == null:
		return
	var active := {}
	for field in fields:
		if str(field["type"]) == "fire_wall":
			active[field["cell"]] = true
	var to_remove: Array = []
	for cell in fire_particles.keys():
		if not active.has(cell):
			to_remove.append(cell)
	for cell in to_remove:
		var p: GPUParticles2D = fire_particles[cell]
		if is_instance_valid(p):
			p.queue_free()
		fire_particles.erase(cell)
	for cell in active:
		if not fire_particles.has(cell):
			var p := _make_fire_particles()
			p.position = cell_center(cell)
			effect_layer.add_child(p)
			fire_particles[cell] = p


func play_ice_effect(cell: Vector2i) -> void:
	if effect_layer == null:
		return
	var p := _make_ice_particles()
	p.position = cell_center(cell)
	p.emitting = true
	effect_layer.add_child(p)
	get_tree().create_timer(p.lifetime + 0.3).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free()
	)


func _closed(poly: PackedVector2Array) -> PackedVector2Array:
	var points := PackedVector2Array(poly)
	points.append(poly[0])
	return points


func _ellipse_points(center: Vector2, radii: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in 32:
		var angle := TAU * float(index) / 32.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var cell := _cell_at(event.position)
		var unit_id := _unit_at(event.position)
		if unit_id != hovered_unit_id:
			hovered_unit_id = unit_id
			unit_hovered.emit(unit_id)
		if cell != hovered_cell:
			hovered_cell = cell
			cell_hovered.emit(cell)
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var unit_id := _unit_at(event.position)
		if unit_id >= 0:
			unit_clicked.emit(unit_id)
			accept_event()
			return
		var cell := _cell_at(event.position)
		if cell.x >= 0:
			cell_clicked.emit(cell)
			accept_event()


func _cell_at(point: Vector2) -> Vector2i:
	for y in board_size:
		for x in board_size:
			var cell := Vector2i(x, y)
			if Geometry2D.is_point_in_polygon(point, cell_polygon(cell)):
				return cell
	return Vector2i(-1, -1)
