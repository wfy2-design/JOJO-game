class_name TutorialScenario
extends RefCounted

## 教程剧本：6 章分块，每章自洽 mini 1v1（3×3 棋盘），可独立跳转。

const BOARD_SIZE := 3

## 教程专用：角色射程覆写（3×3 棋盘对角距离 4，原射程为 6×6 设计，须缩小以保留命中衰减）
const UNIT_OVERRIDES := {
	"sun_blade": {"r_opt": 1, "r_max": 3},
	"molten_core": {"r_opt": 1, "r_max": 3},
	"crimson_thorn": {"r_opt": 1, "r_max": 3},
	"night_chain": {"r_opt": 1, "r_max": 3},
	"frost_wing": {"r_opt": 1, "r_max": 3},
	"mirror_tide": {"r_opt": 1, "r_max": 3},
}

## 技能射程覆写：熔芯远程技能原 min 2~7/2~6，3×3 里缩小到 1~3
const SKILL_RANGE_OVERRIDES := {
	"molten_spray": {"min_range": 1, "max_range": 3},
	"furnace_quake": {"min_range": 1, "max_range": 3},
}

const CHAPTERS := [
	{
		"id": "intro",
		"title": "入门与目标",
		"keywords": ["目标", "胜利", "控制"],
		"teams": {"A": ["sun_blade"], "B": ["molten_core"]},
		"spawns": {"sun_blade": Vector2i(0, 0), "molten_core": Vector2i(1, 0)},
		"setup": [],
		"steps": [
			{
				"title": "欢迎",
				"body": "这是 [b]1v1 教学演示[/b]：两名角色在 [color=#ffd241]3×3 小棋盘[/color] 上对战，一方 HP 归零退场即判负。\n\n棋盘比正式对局（6×6）更小，方便你一眼看全。",
				"highlight": [{"cell": Vector2i(0, 0), "kind": "attack"}, {"cell": Vector2i(1, 0), "kind": "danger"}],
			},
			{
				"title": "操作方式",
				"body": "点「下一步」逐步推进；「上一步」回退；「目录」随时跳转到任意主题。\n\n正文里带下划线的词（如 [url=topic:board]移动[/url]）也可以点击直达对应章节。",
			},
			{
				"title": "第一次攻击",
				"body": "曜锋速度更高，因此先手。现在对熔芯发动普通攻击。",
				"action": {"type": "attack", "unit": "sun_blade", "target": "molten_core"},
				"after": "本次命中率 {hit}%，实际造成 {damage} 点伤害。",
			},
		],
	},
	{
		"id": "board",
		"title": "棋盘与移动",
		"keywords": ["棋盘", "移动", "冲刺"],
		"teams": {"A": ["sun_blade"], "B": ["crimson_thorn"]},
		"spawns": {"sun_blade": Vector2i(0, 0), "crimson_thorn": Vector2i(2, 2)},
		"setup": [],
		"steps": [
			{
				"title": "棋盘与同格",
				"body": "棋盘是菱形格阵。多个角色可以站在 [color=#ffd241]同一格[/color]，移动也可以穿过敌人或友军。",
				"highlight": [{"cell": Vector2i(0, 0), "kind": "attack"}, {"cell": Vector2i(2, 2), "kind": "danger"}],
			},
			{
				"title": "免费移动",
				"body": "每个回合可以 [color=#ffd241]免费移动 2 格[/color]，移动 [b]不会[/b] 结束行动，之后仍可攻击、放技能或防御。",
				"highlight": [
					{"cell": Vector2i(0, 0), "kind": "move"}, {"cell": Vector2i(1, 0), "kind": "move"},
					{"cell": Vector2i(0, 1), "kind": "move"}, {"cell": Vector2i(1, 1), "kind": "move"},
				],
			},
			{
				"title": "移动演示",
				"body": "曜锋移动 2 格，从 (0,0) 走到 (1,1)。",
				"action": {"type": "move", "unit": "sun_blade", "to": Vector2i(1, 1)},
				"after": "曜锋到达 (1,1)，现在距离绯棘 2 格。",
			},
			{
				"title": "冲刺",
				"body": "消耗 [color=#dd42b7]1 AP[/color] 可以 [color=#ffd241]冲刺[/color]，本回合移动上限从 2 格提升到 4 格。",
				"highlight": [{"cell": Vector2i(2, 2), "kind": "sprint"}, {"cell": Vector2i(2, 1), "kind": "sprint"}],
			},
			{
				"title": "冲刺演示",
				"body": "曜锋开启冲刺，移动到 (2,1)，贴到绯棘面前。",
				"action": {"type": "move", "unit": "sun_blade", "to": Vector2i(2, 1), "sprint": true},
				"after": "冲刺后曜锋 AP 由 4 降到 3。",
			},
		],
	},
	{
		"id": "ctb",
		"title": "行动顺序",
		"keywords": ["CTB", "速度", "顺序"],
		"teams": {"A": ["night_chain"], "B": ["frost_wing"]},
		"spawns": {"night_chain": Vector2i(0, 0), "frost_wing": Vector2i(2, 2)},
		"setup": [],
		"steps": [
			{
				"title": "行动条 CTB",
				"body": "六名角色共用一条行动队列，速度条 [color=#ffd241]S = 100 / 速度 p[/color]，S 越小越先行动。\n\n夜链 S≈7.1，霜翊 S≈16.7，因此夜链先手。",
				"highlight": [{"cell": Vector2i(0, 0), "kind": "attack"}],
			},
			{
				"title": "当前行动者",
				"body": "棋盘上带金色圈的即当前行动者。行动后 S 增加 100/速度，再重新排序。",
			},
			{
				"title": "不行动",
				"body": "「不行动」直接结束回合，正常推进 S。",
				"action": {"type": "wait", "unit": "night_chain"},
				"after": "夜链 S += 100/14，现在轮到霜翊行动。",
			},
			{
				"title": "同 S 判定",
				"body": "若 S 相同，先比较 [color=#ffd241]速度[/color]，仍相同再比较固定角色 ID。",
			},
		],
	},
	{
		"id": "range",
		"title": "距离与命中",
		"keywords": ["射程", "距离", "命中", "闪避"],
		"teams": {"A": ["molten_core"], "B": ["sun_blade"]},
		"spawns": {"molten_core": Vector2i(0, 0), "sun_blade": Vector2i(2, 2)},
		"setup": [],
		"steps": [
			{
				"title": "曼哈顿距离",
				"body": "距离采用曼哈顿距离：\n[color=#ffd241]d = |Δx| + |Δy|[/color]\n\n熔芯 (0,0) 到曜锋 (2,2) 距离 4。",
				"highlight": [{"cell": Vector2i(0, 0), "kind": "attack"}, {"cell": Vector2i(2, 2), "kind": "danger"}],
			},
			{
				"title": "射程与命中衰减",
				"body": "距离 d ≤ R_opt 时命中 100%；R_opt ~ R_max 之间线性下降；达到 R_max 必失。\n\n熔芯 R_opt=1、R_max=3（教程覆写）。当前距离 4 已超出射程，命中 0%。",
			},
			{
				"title": "靠近",
				"body": "熔芯移动 2 格到 (1,1)，距离缩短为 2。",
				"action": {"type": "move", "unit": "molten_core", "to": Vector2i(1, 1)},
				"after": "距离 2，命中率降到 38%（(3-2)/(3-1) × 闪避修正）。",
			},
			{
				"title": "进入最优射程",
				"body": "冲刺移动到 (2,1)，距离 1。",
				"action": {"type": "move", "unit": "molten_core", "to": Vector2i(2, 1), "sprint": true},
				"after": "距离 1，进入 R_opt 内，命中率 76%。",
			},
			{
				"title": "运气闪避",
				"body": "曜锋运气 12，令最终命中率打折；现在落地一次攻击。",
				"action": {"type": "attack", "unit": "molten_core", "target": "sun_blade"},
				"after": "命中率 {hit}%，实际造成 {damage} 点伤害（若命中）。",
			},
		],
	},
	{
		"id": "attack",
		"title": "攻击与技能",
		"keywords": ["攻击", "伤害", "技能", "AP", "防御"],
		"teams": {"A": ["night_chain"], "B": ["crimson_thorn"]},
		"spawns": {"night_chain": Vector2i(0, 0), "crimson_thorn": Vector2i(1, 0)},
		"setup": [],
		"steps": [
			{
				"title": "伤害公式",
				"body": "伤害 = 攻击力 × 倍率 ÷ (1 + 防御/50)。\n\n绯棘防御 12，能明显减免受到的伤害。",
			},
			{
				"title": "普通攻击",
				"body": "夜链对绯棘发动普通攻击。",
				"action": {"type": "attack", "unit": "night_chain", "target": "crimson_thorn"},
				"after": "造成 {damage} 点伤害。",
			},
			{
				"title": "技能系统",
				"body": "技能：首次选择显示详情，[color=#ffd241]再次选择同一技能才发动[/color]，并消耗 AP。",
			},
			{
				"title": "必中技能",
				"body": "夜链「磁链突袭」0~2 格、必中 1.0x。",
				"action": {"type": "skill", "unit": "night_chain", "skill_id": "magnetic_lunge", "target": "crimson_thorn"},
				"after": "造成 {damage} 点伤害（必中，不受运气闪避影响）。",
			},
		],
	},
	{
		"id": "status",
		"title": "状态与暴击",
		"keywords": ["状态", "点燃", "火墙", "暴击"],
		"teams": {"A": ["sun_blade"], "B": ["molten_core"]},
		"spawns": {"sun_blade": Vector2i(0, 0), "molten_core": Vector2i(1, 0)},
		"setup": [{"type": "set_state", "unit": "sun_blade", "field": "crit", "value": 50}],
		"steps": [
			{
				"title": "状态效果",
				"body": "点燃会在目标行动开始时结算（共 2 次）；火墙在角色进入对应格时受伤；束缚、标记等更多状态见 [url=topic:attack]GUIDE[/url]。",
			},
			{
				"title": "点燃",
				"body": "熔芯「熔流喷射」点燃曜锋。",
				"action": {"type": "skill", "unit": "molten_core", "skill_id": "molten_spray", "target": "sun_blade"},
				"after": "曜锋被点燃；进入曜锋回合时先结算一次点燃，HP 剩 {hp}。",
			},
			{
				"title": "暴击",
				"body": "暴击造成 [color=#ffd241]1.5 倍[/color] 伤害。「裂空突刺」额外 +20% 暴击（本教程已把暴击调到 100% 以稳定演示）。",
			},
			{
				"title": "暴击演示",
				"body": "曜锋「裂空突刺」触发暴击。",
				"action": {"type": "skill", "unit": "sun_blade", "skill_id": "plasma_thrust", "target": "molten_core"},
				"after": "暴击造成 {damage} 点伤害（1.5 倍）。",
			},
		],
	},
]


static func chapter_by_id(chapter_id: String) -> Dictionary:
	for chapter in CHAPTERS:
		if str(chapter["id"]) == chapter_id:
			return chapter
	return {}


static func chapter_index_by_id(chapter_id: String) -> int:
	for index in CHAPTERS.size():
		if str(CHAPTERS[index]["id"]) == chapter_id:
			return index
	return -1


static func character(key: String) -> Dictionary:
	for definition in BattleData.characters():
		if str(definition["key"]) == key:
			return definition
	return {}
