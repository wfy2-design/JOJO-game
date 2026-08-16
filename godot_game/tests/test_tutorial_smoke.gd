extends SceneTree

## 冒烟测试：实例化教程控制器与选角界面，验证 UI 构建与步骤推进不崩溃。

const TutorialControllerScript = preload("res://tutorial/tutorial_controller.gd")
const DraftScreenScript = preload("res://ui/menu/draft_screen.gd")

var failures := 0
var draft_done := false


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	var root := get_root()

	var tutorial = TutorialControllerScript.new()
	root.add_child(tutorial)
	await process_frame
	await process_frame
	for i in range(40):
		tutorial._next()
	await process_frame
	tutorial._replay()
	await process_frame
	tutorial.queue_free()
	await process_frame
	print("TUTORIAL SMOKE OK")

	var draft_screen = DraftScreenScript.new()
	draft_screen.draft_finished.connect(func(_result: Dictionary) -> void: draft_done = true)
	root.add_child(draft_screen)
	draft_screen.setup("local", 999)
	await process_frame
	var count := 0
	while not draft_screen.draft.is_finished() and count < 8:
		var key: String = draft_screen.draft.remaining[0]
		draft_screen._on_pick(key)
		count += 1
	await process_frame
	_check(draft_done, "选角完成信号已发出")
	draft_screen.queue_free()
	await process_frame
	print("DRAFT SMOKE OK")

	if failures == 0:
		print("ALL SMOKE TESTS PASSED")
	else:
		push_error("%d SMOKE TESTS FAILED" % failures)
	quit(failures)
