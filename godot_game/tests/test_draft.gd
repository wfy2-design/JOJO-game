extends SceneTree

const DraftModelScript = preload("res://ui/menu/draft_model.gd")

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
	_test_snake_order()
	_test_teams_balanced()
	_test_first_picker_random()
	_test_any_two_can_face_off()
	_test_ai_random_pick()
	_test_no_undo()
	_test_team_sizes()
	if failures == 0:
		print("ALL DRAFT TESTS PASSED")
	else:
		push_error("%d DRAFT TESTS FAILED" % failures)
	quit(failures)


func _test_snake_order() -> void:
	var draft = DraftModelScript.new()
	draft.start(42)
	_check(draft.pick_queue.size() == 6, "选角共 6 次")
	var counts := {"A": 0, "B": 0}
	for team in draft.pick_queue:
		counts[team] += 1
	_check(counts["A"] == 3 and counts["B"] == 3, "每队各选 3 人")
	var first: String = draft.pick_queue[0]
	var other := "B" if first == "A" else "A"
	var expected: Array = [first, other, other, first, first, other]
	_check(draft.pick_queue == expected, "蛇形 1-2-2-1 顺序正确")


func _test_team_sizes() -> void:
	var draft = DraftModelScript.new()
	draft.start(5, 1)
	_check(draft.pick_queue.size() == 2, "1v1 选角共 2 次")
	draft = DraftModelScript.new()
	draft.start(5, 2)
	_check(draft.pick_queue.size() == 4, "2v2 选角共 4 次")
	draft = DraftModelScript.new()
	draft.start(5, 3)
	_check(draft.pick_queue.size() == 6, "3v3 选角共 6 次")
	for size in [1, 2, 3]:
		var d = DraftModelScript.new()
		d.start(7, size)
		while not d.is_finished():
			d.pick(d.remaining[0])
		_check(d.a_team.size() == size and d.b_team.size() == size, "%dv%d 选满后每队 %d 人" % [size, size, size])
	var d1 = DraftModelScript.new()
	d1.start(42, 1)
	var f1: String = d1.pick_queue[0]
	var o1 := "B" if f1 == "A" else "A"
	_check(d1.pick_queue == [f1, o1], "1v1 顺序 1-1 正确")
	var d2 = DraftModelScript.new()
	d2.start(42, 2)
	var f2: String = d2.pick_queue[0]
	var o2 := "B" if f2 == "A" else "A"
	_check(d2.pick_queue == [f2, o2, o2, f2], "2v2 顺序 1-2-1 正确")


func _test_teams_balanced() -> void:
	var draft = DraftModelScript.new()
	draft.start(7)
	while not draft.is_finished():
		draft.pick(draft.remaining[0])
	_check(draft.a_team.size() == 3 and draft.b_team.size() == 3, "选满后每队 3 人")
	var result: Dictionary = draft.result()
	_check(result["A"].size() == 3 and result["B"].size() == 3, "result() 返回两队各 3 人")
	var all: Array = result["A"] + result["B"]
	_check(all.size() == 6, "六名角色无重复分配")


func _test_first_picker_random() -> void:
	var saw_a := false
	var saw_b := false
	for seed in range(0, 50):
		var draft = DraftModelScript.new()
		draft.start(seed)
		if draft.first_picker == 0:
			saw_a = true
		else:
			saw_b = true
	_check(saw_a and saw_b, "先手在 A/B 之间随机（多 seed 覆盖到双方）")


func _test_any_two_can_face_off() -> void:
	var draft = DraftModelScript.new()
	draft.start(11)
	var first: String = draft.current_team()
	_check(draft.pick("sun_blade"), "sun_blade 可被选中")
	var second: String = draft.current_team()
	_check(draft.pick("molten_core"), "molten_core 可被选中")
	_check(first != second, "连续两次选择分属不同队")
	var sun_team := "A" if "sun_blade" in draft.a_team else "B"
	var molten_team := "A" if "molten_core" in draft.a_team else "B"
	_check(sun_team != molten_team, "sun_blade 与 molten_core 分属两队（可对打）")


func _test_ai_random_pick() -> void:
	var draft = DraftModelScript.new()
	draft.start(5)
	var before: int = draft.remaining.size()
	_check(draft.ai_pick(), "AI 可随机选角")
	_check(draft.remaining.size() == before - 1, "AI 选角后剩余角色减 1")


func _test_no_undo() -> void:
	var draft = DraftModelScript.new()
	draft.start(3)
	var key: String = draft.remaining[0]
	_check(draft.pick(key), "首次选择成功")
	_check(not draft.pick(key), "重复选择同一角色被拒绝（不支持悔选/重选）")
