class_name BattleModel
extends RefCounted

signal changed
signal event_created(event: Dictionary)
signal battle_ended(winning_team: int)

const PHASE_IDLE := "idle"
const PHASE_TURN := "turn"
const PHASE_MOVE := "move"
const PHASE_TARGET := "target"
const PHASE_GAME_OVER := "game_over"

var units: Array[Dictionary] = []
var fields: Array[Dictionary] = []
var events: Array[Dictionary] = []
var current_unit_id := -1
var phase := PHASE_IDLE
var mode := "local"
var board_size := 6
var winner := -1
var turn_count := 0
var move_path: Array[Vector2i] = []
var move_budget := 2
var sprint_enabled := false
var move_locked := false
var in_time_stop := false
var time_stop_free_sprint := false
var selected_skill: Dictionary = {}
var turn_snapshot: Dictionary = {}
var rng := RandomNumberGenerator.new()


func start_battle(
	selected_mode: String = "local",
	seed: int = 1,
	teams: Dictionary = {},
	spawns: Dictionary = {},
	board_size: int = 6,
	random_spawn: bool = false
) -> void:
	mode = selected_mode
	self.board_size = board_size
	rng.seed = seed
	units.clear()
	fields.clear()
	events.clear()
	winner = -1
	turn_count = 0
	in_time_stop = false
	time_stop_free_sprint = false
	selected_skill = {}
	var definitions: Array[Dictionary] = []
	if teams.is_empty():
		definitions = BattleData.characters()
	else:
		for team_key in ["A", "B"]:
			var keys: Array = teams.get(team_key, [])
			for character_key in keys:
				for definition in BattleData.characters():
					if str(definition["key"]) == str(character_key):
						var copy: Dictionary = definition.duplicate(true)
						copy["team"] = BattleData.TEAM_A if team_key == "A" else BattleData.TEAM_B
						definitions.append(copy)
	for definition in definitions:
		var unit := definition.duplicate(true)
		unit["hp"] = unit["max_hp"]
		unit["ap"] = unit["initial_ap"]
		unit["alive"] = true
		if spawns.has(str(unit["key"])):
			unit["pos"] = spawns[str(unit["key"])]
		elif random_spawn:
			unit["pos"] = Vector2i(rng.randi_range(0, self.board_size - 1), rng.randi_range(0, self.board_size - 1))
		else:
			unit["pos"] = Vector2i.ZERO if unit["team"] == BattleData.TEAM_A else Vector2i(self.board_size - 1, self.board_size - 1)
		unit["s"] = 100.0 / float(unit["speed"])
		unit["defending"] = false
		unit["burns"] = []
		unit["marked"] = false
		unit["counter_charge"] = false
		unit["counter_was_hit"] = false
		unit["counter_guard"] = false
		unit["armor_off"] = false
		unit["afterimage"] = false
		unit["accuracy_up"] = false
		unit["crystal_guard"] = false
		unit["bind_turns"] = 0
		units.append(unit)
	phase = PHASE_TURN
	_begin_next_turn()


func get_unit(unit_id: int) -> Dictionary:
	for unit in units:
		if unit["id"] == unit_id:
			return unit
	return {}


func current_unit() -> Dictionary:
	return get_unit(current_unit_id)


func living_units(team: int = -1) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for unit in units:
		if unit["alive"] and (team < 0 or unit["team"] == team):
			result.append(unit)
	return result


func units_at(cell: Vector2i, team: int = -1) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for unit in living_units(team):
		if unit["pos"] == cell:
			result.append(unit)
	result.sort_custom(_unit_id_less)
	return result


func _unit_id_less(a: Dictionary, b: Dictionary) -> bool:
	return int(a["id"]) < int(b["id"])


func distance_between(a: Dictionary, b: Dictionary) -> int:
	return manhattan(a["pos"], b["pos"])


func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func is_inside_board(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < board_size and cell.y >= 0 and cell.y < board_size


func _turn_less(a: Dictionary, b: Dictionary) -> bool:
	if not is_equal_approx(float(a["s"]), float(b["s"])):
		return float(a["s"]) < float(b["s"])
	if int(a["speed"]) != int(b["speed"]):
		return int(a["speed"]) > int(b["speed"])
	return int(a["id"]) < int(b["id"])


func preview_turn_order(count: int = 8) -> Array[int]:
	var simulated: Array[Dictionary] = []
	for unit in living_units():
		simulated.append({
			"id": unit["id"],
			"s": unit["s"],
			"speed": unit["speed"],
		})
	var result: Array[int] = []
	for index in count:
		if simulated.is_empty():
			break
		simulated.sort_custom(_turn_less)
		var next: Dictionary = simulated[0]
		result.append(next["id"])
		next["s"] = float(next["s"]) + 100.0 / float(next["speed"])
	return result


func _begin_next_turn() -> void:
	if _check_victory():
		return
	var available := living_units()
	available.sort_custom(_turn_less)
	if available.is_empty():
		return
	current_unit_id = available[0]["id"]
	_start_unit_turn(true)


func _start_unit_turn(process_start_effects: bool) -> void:
	var actor := current_unit()
	if actor.is_empty() or not actor["alive"]:
		_begin_next_turn()
		return
	turn_count += 1
	if process_start_effects:
		_tick_owned_fields(actor["id"])
		_tick_burns(actor)
		if not actor["alive"]:
			_begin_next_turn()
			return
		actor["defending"] = false
		actor["counter_guard"] = false
		actor["armor_off"] = false
		actor["afterimage"] = false
		actor["crystal_guard"] = false
	move_locked = int(actor["bind_turns"]) > 0
	move_budget = 4 if in_time_stop and time_stop_free_sprint else 2
	sprint_enabled = false
	move_path = [actor["pos"]]
	selected_skill = {}
	phase = PHASE_TURN
	turn_snapshot = {
		"units": units.duplicate(true),
		"fields": fields.duplicate(true),
		"move_locked": move_locked,
		"move_budget": move_budget,
		"sprint_enabled": sprint_enabled,
	}
	_push_event("turn", "%s 开始行动" % actor["name"], actor["id"])
	changed.emit()


func _tick_owned_fields(owner_id: int) -> void:
	for index in range(fields.size() - 1, -1, -1):
		var field: Dictionary = fields[index]
		if field["owner_id"] == owner_id:
			field["owner_turns_left"] = int(field["owner_turns_left"]) - 1
			if int(field["owner_turns_left"]) <= 0:
				fields.remove_at(index)


func _tick_burns(unit: Dictionary) -> void:
	var burns: Array = unit["burns"]
	for index in range(burns.size() - 1, -1, -1):
		var burn: Dictionary = burns[index]
		var source := get_unit(burn["source_id"])
		if not source.is_empty():
			var raw := float(source["damage"]) * 0.2
			var damage := _apply_defense(raw, unit, false)
			_apply_damage(unit, damage, source, "点燃", false, false)
		burn["ticks"] = int(burn["ticks"]) - 1
		if int(burn["ticks"]) <= 0:
			burns.remove_at(index)
		if not unit["alive"]:
			break


func set_sprint_enabled(enabled: bool) -> bool:
	if move_locked or phase == PHASE_GAME_OVER or time_stop_free_sprint:
		return false
	var actor := current_unit()
	if enabled == sprint_enabled:
		return true
	if enabled:
		if int(actor["ap"]) < 1:
			_push_event("info", "AP 不足，无法冲刺", actor["id"])
			return false
		actor["ap"] = int(actor["ap"]) - 1
		sprint_enabled = true
		move_budget = 4
	else:
		if move_path.size() - 1 > 2:
			return false
		actor["ap"] = mini(BattleData.MAX_AP, int(actor["ap"]) + 1)
		sprint_enabled = false
		move_budget = 2
	changed.emit()
	return true


func remaining_movement() -> int:
	return maxi(0, move_budget - (move_path.size() - 1))


func move_step(delta: Vector2i) -> bool:
	if move_locked or phase == PHASE_GAME_OVER or remaining_movement() <= 0:
		return false
	var actor := current_unit()
	var destination: Vector2i = actor["pos"] + delta
	if not is_inside_board(destination):
		return false
	actor["pos"] = destination
	move_path.append(destination)
	phase = PHASE_MOVE
	_trigger_fields(actor, destination)
	changed.emit()
	return true


func move_to(destination: Vector2i) -> bool:
	if move_locked or not is_inside_board(destination):
		return false
	var actor := current_unit()
	var needed := manhattan(actor["pos"], destination)
	if needed > remaining_movement():
		return false
	var cursor: Vector2i = actor["pos"]
	while cursor.x != destination.x:
		cursor.x += 1 if destination.x > cursor.x else -1
		if not move_step(cursor - actor["pos"]):
			return false
		if not actor["alive"]:
			return false
	while cursor.y != destination.y:
		cursor.y += 1 if destination.y > cursor.y else -1
		if not move_step(cursor - actor["pos"]):
			return false
		if not actor["alive"]:
			return false
	return true


func undo_movement() -> bool:
	if turn_snapshot.is_empty() or phase == PHASE_GAME_OVER:
		return false
	units = turn_snapshot["units"].duplicate(true)
	fields = turn_snapshot["fields"].duplicate(true)
	move_locked = turn_snapshot["move_locked"]
	var actor := current_unit()
	move_budget = int(turn_snapshot.get("move_budget", 2))
	sprint_enabled = bool(turn_snapshot.get("sprint_enabled", false))
	move_path = [actor["pos"]]
	phase = PHASE_TURN
	_push_event("info", "已撤销本回合移动", actor["id"])
	changed.emit()
	return true


func _trigger_fields(actor: Dictionary, cell: Vector2i) -> void:
	for field in fields:
		if field["type"] == "fire_wall" and field["cell"] == cell:
			var owner := get_unit(field["owner_id"])
			if owner.is_empty() or not owner["alive"]:
				continue
			var raw := float(owner["damage"]) * 0.4
			var damage := _apply_defense(raw, actor, false)
			_apply_damage(actor, damage, owner, "火墙", false, false)
			if not actor["alive"]:
				_handle_current_actor_defeat()
				return


func basic_hit_chance(attacker: Dictionary, defender: Dictionary) -> float:
	var distance := distance_between(attacker, defender)
	var h := 0.0
	var r_opt := int(attacker["r_opt"])
	var r_max := int(attacker["r_max"])
	if distance <= r_opt:
		h = 1.0
	elif distance <= r_max and r_max > r_opt:
		h = float(r_max - distance) / float(r_max - r_opt)
	var chance := h * (1.0 - effective_luck(defender) / 50.0)
	return _apply_accuracy_modifiers(chance, attacker, defender)


func skill_hit_chance(attacker: Dictionary, defender: Dictionary, skill_data: Dictionary) -> float:
	if skill_data.get("guaranteed", false):
		return 1.0
	var chance := 1.0 - effective_luck(defender) / 50.0
	return _apply_accuracy_modifiers(chance, attacker, defender)


func _apply_accuracy_modifiers(chance: float, attacker: Dictionary, defender: Dictionary) -> float:
	if attacker.get("accuracy_up", false):
		chance += 0.2
	if defender.get("marked", false):
		chance += 0.2
	return clampf(chance, 0.0, 1.0)


func effective_luck(unit: Dictionary) -> float:
	var result := float(unit["luck"])
	if unit.get("afterimage", false):
		result *= 2.0
	return minf(result, 50.0)


func critical_chance(attacker: Dictionary, skill_data: Dictionary = {}) -> float:
	var chance := float(attacker["crit"]) / 50.0
	if skill_data.get("effect", "") == "crit_strike":
		chance += 0.2
	if attacker.get("armor_off", false):
		chance += 0.1
	return clampf(chance, 0.0, 1.0)


func estimate_damage(
	attacker: Dictionary,
	defender: Dictionary,
	multiplier: float = 1.0,
	is_critical: bool = false,
	physical: bool = false,
	is_core_piercing: bool = false
) -> int:
	var raw := float(attacker["damage"]) * multiplier
	if is_critical:
		raw *= 1.5
	if is_core_piercing and ("overheated_core" in defender.get("tags", [])):
		raw *= 1.5
	if physical and attacker.get("counter_charge", false):
		raw *= 2.0 if attacker.get("counter_was_hit", false) else 1.5
	return _apply_defense(raw, defender, true)


func _apply_defense(raw_damage: float, defender: Dictionary, include_guards: bool) -> int:
	var defense_value := float(defender["defense"])
	if defender.get("armor_off", false):
		defense_value *= 0.5
	var result := raw_damage / (1.0 + defense_value / 50.0)
	if include_guards:
		if defender.get("defending", false):
			result *= 0.5
		if defender.get("counter_guard", false):
			result *= 0.8
		if defender.get("crystal_guard", false):
			result *= 0.7
	return maxi(0, roundi(result))


func preview_against(target_id: int, skill_data: Dictionary = {}) -> Dictionary:
	var attacker := current_unit()
	var defender := get_unit(target_id)
	if defender.is_empty():
		return {}
	var hit := basic_hit_chance(attacker, defender)
	var mult := 1.0
	var physical := true
	var core_piercing := false
	if not skill_data.is_empty():
		hit = skill_hit_chance(attacker, defender, skill_data)
		mult = skill_data.get("multiplier", 0.0)
		physical = skill_data.get("physical", false)
		core_piercing = skill_data.get("effect", "") == "core_pierce"
	return {
		"distance": distance_between(attacker, defender),
		"hit": hit,
		"crit": critical_chance(attacker, skill_data),
		"normal_damage": estimate_damage(attacker, defender, mult, false, physical, core_piercing),
		"critical_damage": estimate_damage(attacker, defender, mult, true, physical, core_piercing),
	}


func can_target_unit(target_id: int, skill_data: Dictionary = {}) -> bool:
	var actor := current_unit()
	var target := get_unit(target_id)
	if target.is_empty() or not target["alive"] or actor["id"] == target["id"]:
		return false
	var target_kind := "enemy" if skill_data.is_empty() else str(skill_data["target"])
	if target_kind == "enemy" and target["team"] == actor["team"]:
		return false
	if target_kind == "ally" and target["team"] != actor["team"]:
		return false
	var min_range := 0
	var max_range := int(actor["r_max"])
	if not skill_data.is_empty():
		min_range = int(skill_data["min_range"])
		max_range = int(skill_data["max_range"])
	var distance := distance_between(actor, target)
	return distance >= min_range and distance <= max_range


func can_target_cell(cell: Vector2i, skill_data: Dictionary) -> bool:
	if not is_inside_board(cell):
		return false
	var actor := current_unit()
	var distance := manhattan(actor["pos"], cell)
	return distance >= int(skill_data["min_range"]) and distance <= int(skill_data["max_range"])


func perform_basic_attack(target_id: int) -> bool:
	if phase == PHASE_GAME_OVER or not can_target_unit(target_id):
		return false
	var actor := current_unit()
	actor["ap"] = mini(BattleData.MAX_AP, int(actor["ap"]) + 1)
	var basic := {
		"name": "普通攻击", "effect": "damage", "multiplier": 1.0,
		"hits": 1, "guaranteed": false, "physical": true,
	}
	_resolve_damage_command(actor, get_unit(target_id), basic, true)
	actor["accuracy_up"] = false
	_finish_action()
	return true


func perform_defend() -> bool:
	if phase == PHASE_GAME_OVER:
		return false
	var actor := current_unit()
	actor["defending"] = true
	_push_event("defend", "%s 进入防御姿态" % actor["name"], actor["id"])
	_finish_action()
	return true


func perform_wait() -> bool:
	if phase == PHASE_GAME_OVER:
		return false
	var actor := current_unit()
	_push_event("wait", "%s 选择不行动" % actor["name"], actor["id"])
	_finish_action()
	return true


func perform_skill(skill_data: Dictionary, target_id: int = -1, target_cell := Vector2i(-1, -1)) -> bool:
	var actor := current_unit()
	if phase == PHASE_GAME_OVER or skill_data.is_empty() or int(actor["ap"]) < int(skill_data["cost"]):
		_push_event("info", "AP 不足或技能无效", actor["id"])
		return false
	var target_kind := str(skill_data["target"])
	if target_kind == "enemy" or target_kind == "ally":
		if not can_target_unit(target_id, skill_data):
			return false
	elif target_kind == "cell":
		if not can_target_cell(target_cell, skill_data):
			return false
	var effect := str(skill_data["effect"])
	if in_time_stop and effect.begins_with("time_stop"):
		_push_event("info", "时停额外行动中不能再次时停", actor["id"])
		return false
	actor["ap"] = int(actor["ap"]) - int(skill_data["cost"])
	_push_event("skill", "%s：%s" % [actor["name"], skill_data["name"]], actor["id"])
	var target := get_unit(target_id)
	var consumes_accuracy: bool = actor.get("accuracy_up", false) and effect in [
		"damage", "crit_strike", "core_pierce", "drain", "burn", "delay", "bind", "area",
	]
	match effect:
		"damage", "crit_strike", "core_pierce":
			_resolve_damage_command(actor, target, skill_data, false)
		"drain":
			var dealt := _resolve_damage_command(actor, target, skill_data, false)
			var healing := roundi(float(dealt) * 0.5)
			actor["hp"] = mini(int(actor["max_hp"]), int(actor["hp"]) + healing)
			_push_event("heal", "%s 回复 %d HP" % [actor["name"], healing], actor["id"], healing)
		"burn":
			if _resolve_damage_command(actor, target, skill_data, false) > 0 and target["alive"]:
				target["burns"].append({"source_id": actor["id"], "ticks": 2})
				_push_event("status", "%s 被点燃" % target["name"], target["id"])
		"delay":
			if _resolve_damage_command(actor, target, skill_data, false) > 0 and target["alive"]:
				target["s"] = float(target["s"]) + 100.0 / float(target["speed"])
				_push_event("status", "%s 的行动被延后" % target["name"], target["id"])
		"bind":
			if _resolve_damage_command(actor, target, skill_data, false) > 0 and target["alive"]:
				target["bind_turns"] = maxi(1, int(target["bind_turns"]))
				_push_event("status", "%s 下次行动无法移动" % target["name"], target["id"])
		"area":
			_resolve_area(actor, target["pos"], skill_data)
		"mark":
			target["marked"] = true
			_push_event("status", "%s 被镜域标记" % target["name"], target["id"])
		"counter_charge":
			actor["counter_charge"] = true
			actor["counter_was_hit"] = false
			actor["counter_guard"] = true
		"armor_off":
			actor["armor_off"] = true
		"afterimage":
			actor["afterimage"] = true
		"accuracy_up":
			actor["accuracy_up"] = true
		"crystal_guard":
			actor["crystal_guard"] = true
		"advance":
			target["s"] = maxf(float(actor["s"]), float(target["s"]) - 50.0 / float(target["speed"]))
			_push_event("status", "%s 的行动提前" % target["name"], target["id"])
		"fire_wall":
			fields.append({
				"type": "fire_wall", "cell": target_cell, "owner_id": actor["id"],
				"owner_turns_left": 2,
			})
			_push_event("field", "火墙生成于 (%d,%d)" % [target_cell.x, target_cell.y], actor["id"])
		"time_stop", "time_stop_free":
			time_stop_free_sprint = effect == "time_stop_free"
			selected_skill = {"time_stop_triggered": true}
	if consumes_accuracy:
		actor["accuracy_up"] = false
	_finish_action()
	return true


func _resolve_area(attacker: Dictionary, center: Vector2i, skill_data: Dictionary) -> void:
	var cells: Array[Vector2i] = [
		center,
		center + Vector2i.LEFT,
		center + Vector2i.RIGHT,
		center + Vector2i.UP,
		center + Vector2i.DOWN,
	]
	for defender in living_units(1 - int(attacker["team"])):
		if defender["pos"] in cells:
			_resolve_damage_command(attacker, defender, skill_data, false)


func _resolve_damage_command(
	attacker: Dictionary,
	defender: Dictionary,
	skill_data: Dictionary,
	is_basic: bool
) -> int:
	if defender.is_empty() or not defender["alive"]:
		return 0
	var total_dealt := 0
	var distance := distance_between(attacker, defender)
	var physical: bool = skill_data.get("physical", false)
	var uses_charge: bool = physical and attacker.get("counter_charge", false)
	for hit_index in int(skill_data.get("hits", 1)):
		if not defender["alive"]:
			break
		var hit_chance := basic_hit_chance(attacker, defender) if is_basic else skill_hit_chance(attacker, defender, skill_data)
		if rng.randf() >= hit_chance:
			_push_event("miss", "%s 闪避了第 %d 段" % [defender["name"], hit_index + 1], defender["id"])
			continue
		var critical := rng.randf() < critical_chance(attacker, skill_data)
		var damage := estimate_damage(
			attacker,
			defender,
			float(skill_data.get("multiplier", 1.0)),
			critical,
			physical,
			skill_data.get("effect", "") == "core_pierce"
		)
		var actual := _apply_damage(defender, damage, attacker, skill_data["name"], critical, physical)
		total_dealt += actual
		if defender.get("crystal_guard", false) and physical and distance <= 1 and actual > 0 and attacker["alive"]:
			var reflected := maxi(1, roundi(float(actual) * 0.2))
			_apply_damage(attacker, reflected, defender, "晶翼反弹", false, false)
	if uses_charge:
		attacker["counter_charge"] = false
		attacker["counter_was_hit"] = false
	return total_dealt


func _apply_damage(
	defender: Dictionary,
	damage: int,
	attacker: Dictionary,
	source_name: String,
	critical: bool,
	physical: bool
) -> int:
	var before := int(defender["hp"])
	defender["hp"] = maxi(0, before - damage)
	var actual := before - int(defender["hp"])
	if defender.get("counter_charge", false) and actual > 0:
		defender["counter_was_hit"] = true
	var label := "%s 对 %s 造成 %d 伤害" % [source_name, defender["name"], actual]
	var event_unit_id: int = attacker["id"] if critical else defender["id"]
	_push_event("critical" if critical else "damage", label, event_unit_id, actual)
	if int(defender["hp"]) <= 0:
		_defeat_unit(defender, attacker)
	return actual


func _defeat_unit(unit: Dictionary, attacker: Dictionary = {}) -> void:
	if not unit["alive"]:
		return
	unit["alive"] = false
	unit["hp"] = 0
	unit["marked"] = false
	unit["burns"] = []
	for index in range(fields.size() - 1, -1, -1):
		if int(fields[index]["owner_id"]) == int(unit["id"]):
			fields.remove_at(index)
	_push_event("defeat", "%s 退场" % unit["name"], unit["id"])
	_check_victory()


func _handle_current_actor_defeat() -> void:
	if _check_victory():
		return
	in_time_stop = false
	time_stop_free_sprint = false
	selected_skill = {}
	_begin_next_turn()


func _finish_action() -> void:
	if phase == PHASE_GAME_OVER:
		return
	var actor := current_unit()
	if actor.is_empty() or not actor["alive"]:
		_handle_current_actor_defeat()
		return
	if actor.get("marked", false):
		actor["marked"] = false
	if int(actor["bind_turns"]) > 0:
		actor["bind_turns"] = int(actor["bind_turns"]) - 1
	var time_stop_triggered: bool = selected_skill.get("time_stop_triggered", false)
	if time_stop_triggered and not in_time_stop:
		in_time_stop = true
		selected_skill = {}
		_push_event("time_stop", "时间停止！%s 获得额外行动" % actor["name"], actor["id"])
		_start_unit_turn(false)
		return
	var effective_speed := float(actor["speed"])
	if actor.get("armor_off", false):
		effective_speed *= 1.5
	actor["s"] = float(actor["s"]) + 100.0 / effective_speed
	in_time_stop = false
	time_stop_free_sprint = false
	selected_skill = {}
	_begin_next_turn()


func _check_victory() -> bool:
	var a_alive := not living_units(BattleData.TEAM_A).is_empty()
	var b_alive := not living_units(BattleData.TEAM_B).is_empty()
	if a_alive and b_alive:
		return false
	winner = BattleData.TEAM_A if a_alive else BattleData.TEAM_B
	phase = PHASE_GAME_OVER
	_push_event("victory", "%s 获胜" % ("A 队" if winner == BattleData.TEAM_A else "B 队"))
	battle_ended.emit(winner)
	changed.emit()
	return true


func _push_event(
	event_type: String,
	text: String,
	unit_id: int = -1,
	amount: int = 0
) -> void:
	var event := {
		"type": event_type,
		"text": text,
		"unit_id": unit_id,
		"amount": amount,
	}
	events.append(event)
	if events.size() > 80:
		events.pop_front()
	event_created.emit(event)
