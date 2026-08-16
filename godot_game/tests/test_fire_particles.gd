extends SceneTree

## 验证火墙消失时火焰粒子随之一并移除。

const BoardViewScript = preload("res://ui/board_view.gd")
const BattleModelScript = preload("res://core/battle_model.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	var model: BattleModel = BattleModelScript.new()
	model.start_battle("local", 42)
	var board: BoardView = BoardViewScript.new()
	root.add_child(board)
	await process_frame
	board.set_model(model)

	# 火墙生成 → 粒子创建
	model.fields.append({"type": "fire_wall", "cell": Vector2i(2, 2), "owner_id": 4, "owner_turns_left": 2})
	board.sync_fields(model.fields)
	_check(board.fire_particles.size() == 1, "火墙生成后创建 1 个火焰粒子")

	# 火墙消失 → 粒子移除
	model.fields.clear()
	board.sync_fields(model.fields)
	await process_frame
	_check(board.fire_particles.is_empty(), "火墙移除后火焰粒子同步移除")

	# 真实生命周期：owner_turns_left 减到 0 时火墙从 fields 移除
	var model2: BattleModel = BattleModelScript.new()
	model2.start_battle("local", 42)
	model2.fields.append({"type": "fire_wall", "cell": Vector2i(2, 2), "owner_id": 4, "owner_turns_left": 1})
	model2.current_unit_id = 4
	model2._start_unit_turn(true)
	_check(model2.fields.is_empty(), "火墙 owner_turns_left 减到 0 后从 fields 移除")

	if failures == 0:
		print("ALL FIRE PARTICLE TESTS PASSED")
	else:
		push_error("%d FIRE PARTICLE TESTS FAILED" % failures)
	quit(failures)
