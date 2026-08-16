class_name DraftModel
extends RefCounted

## 选角逻辑：蛇形 1-2-2-1 draft，先手随机，AI 随机，不支持悔选。
## 队伍由选角决定，任意角色可被分到 A/B 队，解除"角色固有队伍"约束。

signal changed

const PICK_COUNTS_BY_SIZE := {
	1: [1, 1],       # 1v1：先手 1、后手 1
	2: [1, 2, 1],    # 2v2：先手 1、后手 2、先手 1
	3: [1, 2, 2, 1], # 3v3：先手 1、后手 2、先手 2、后手 1
}
const TEAM_NAMES := ["A", "B"]

var rng := RandomNumberGenerator.new()
var first_picker := 0               # 0=A 先手，1=B 先手
var team_size := 3
var remaining: Array[String] = []
var a_team: Array[String] = []
var b_team: Array[String] = []
var pick_queue: Array[String] = []  # 选角队伍序列，如 3v3 为 [A,B,B,A,A,B]
var pick_index := 0


func start(seed: int = 0, size: int = 3) -> void:
	team_size = size
	rng.seed = seed if seed != 0 else randi()
	first_picker = rng.randi_range(0, 1)
	remaining.clear()
	for definition in BattleData.characters():
		remaining.append(str(definition["key"]))
	a_team.clear()
	b_team.clear()
	pick_queue.clear()
	var counts: Array = PICK_COUNTS_BY_SIZE.get(team_size, [1, 2, 2, 1])
	var other := 1 - first_picker
	for round_index in counts.size():
		var count: int = counts[round_index]
		var picker: int = first_picker if round_index % 2 == 0 else other
		for i in count:
			pick_queue.append(TEAM_NAMES[picker])
	pick_index = 0
	changed.emit()


func current_team() -> String:
	if is_finished():
		return ""
	return pick_queue[pick_index]


func picks_left() -> int:
	return maxi(0, pick_queue.size() - pick_index)


func is_finished() -> bool:
	return pick_index >= pick_queue.size()


func is_available(character_key: String) -> bool:
	return remaining.has(character_key)


func pick(character_key: String) -> bool:
	if is_finished() or not remaining.has(character_key):
		return false
	var team := pick_queue[pick_index]
	if team == "A":
		a_team.append(character_key)
	else:
		b_team.append(character_key)
	remaining.erase(character_key)
	pick_index += 1
	changed.emit()
	return true


func ai_pick() -> bool:
	if is_finished() or remaining.is_empty():
		return false
	var choice := remaining[rng.randi_range(0, remaining.size() - 1)]
	return pick(choice)


func result() -> Dictionary:
	return {"A": a_team.duplicate(), "B": b_team.duplicate()}
