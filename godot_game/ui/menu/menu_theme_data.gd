class_name MenuThemeData
extends RefCounted

const MENU_ITEMS := [
	{"id": "continue", "label": "CONTINUE", "character": "jotaro"},
	{"id": "archive", "label": "ARCHIVE", "character": "dio"},
	{"id": "guide", "label": "GUIDE", "character": "kakyoin"},
	{"id": "settings", "label": "SETTINGS", "character": "polnareff"},
	{"id": "exit", "label": "EXIT", "character": "avdol"},
]

const CHARACTER_THEMES := {
	"jotaro": {"primary": Color("#7b5ce0"), "secondary": Color("#e0b84c"), "onomatopoeia": "オラオラ"},
	"dio": {"primary": Color("#f5c518"), "secondary": Color("#8b1a1a"), "onomatopoeia": "無駄無駄"},
	"polnareff": {"primary": Color("#c9ccd6"), "secondary": Color("#5c7a99"), "onomatopoeia": "CHING"},
	"kakyoin": {"primary": Color("#35b56a"), "secondary": Color("#7fe0a8"), "onomatopoeia": "レロレロ"},
	"avdol": {"primary": Color("#ee4b2b"), "secondary": Color("#ffa53d"), "onomatopoeia": "CROSSFIRE"},
	"joseph": {"primary": Color("#8e6bc0"), "secondary": Color("#4a2e6b"), "onomatopoeia": "OH MY GOD"},
}

const RULE_PAGES := [
	{
		"title": "基本规则",
		"number": "01",
		"body": "双方各操控 3 名角色，在 6×6 棋盘上同时作战。\n\nA 队从 (0,0) 出发，B 队从 (5,5) 出发。同一格可以容纳多名角色，移动也可以穿过敌军和友军。\n\n当一方全部角色 HP 降至 0 并退场时，另一方获胜。每次行动由免费移动与一次攻击、技能或防御组成。",
	},
	{
		"title": "距离与命中",
		"number": "02",
		"body": "距离采用曼哈顿距离：\n\nd = |x₁-x₂| + |y₁-y₂|\n\n距离 0 表示同格，也属于近战射程。d≤R_opt 时距离修正为 100%；从 R_opt 到 R_max 之间线性降低；到达或超过 R_max 时无法命中。\n\n最终命中还会受到目标运气、技能必中与命中强化影响；距离不会改变伤害值。",
	},
	{
		"title": "行动条 CTB",
		"number": "03",
		"body": "六名角色共用一条行动队列，速度条 S 越小越先行动。\n\n初始值：S = 100 / 速度 p\n行动后：S += 100 / 速度 p\n\nS 相同时先比较速度，仍相同则比较固定角色 ID。速度越高，行动间隔越短。时停会给予使用者一次额外行动，但整个时停过程只推进一次 S。",
	},
	{
		"title": "战斗机制",
		"number": "04",
		"body": "普通移动每回合免费 2 格；冲刺消耗 1 AP，再增加 2 格。确认行动前可以撤销本回合移动。\n\n暴击造成 1.5 倍伤害；防御动作令所受伤害降低 50%，持续到角色下次行动开始。多段技能逐段判定命中和暴击。\n\n点燃在目标行动开始时触发；角色每次进入火墙格都会受到伤害。同格 AOE 会命中该坐标内的全部敌人，但不会伤害友军。",
	},
]

const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]


static func theme_for(character_key: String) -> Dictionary:
	return CHARACTER_THEMES.get(character_key, CHARACTER_THEMES["jotaro"])


static func character_by_key(character_key: String) -> Dictionary:
	for character in BattleData.characters():
		if character["key"] == character_key:
			return character
	return BattleData.characters()[0]


static func range_text(skill_data: Dictionary) -> String:
	if skill_data["target"] == "self":
		return "自身"
	if skill_data["target"] == "cell" and skill_data["min_range"] == 1 and skill_data["max_range"] == 1:
		return "相邻"
	if skill_data["min_range"] == skill_data["max_range"]:
		return str(skill_data["max_range"])
	return "%d~%d" % [skill_data["min_range"], skill_data["max_range"]]


static func skill_summary(skill_data: Dictionary) -> String:
	match str(skill_data["id"]):
		"star_finger": return "必中 1.0x"
		"ora_ora": return "2段 x1.0"
		"counter_charge": return "蓄力 / 减伤20%"
		"star_platinum_world": return "时停 / 额外行动"
		"emerald_splash": return "必中 1.2x"
		"hierophant_mark": return "标记 / 命中+20%"
		"barrier": return "1.6x / 延后一档"
		"barrier_bind": return "0.6x / 束缚"
		"thrust": return "1.0x / 暴击+20%"
		"blade_combo": return "3段 x0.7"
		"armor_off": return "速度x1.5 / 脱甲"
		"afterimage": return "闪避翻倍"
		"knives": return "0.8x"
		"muda_muda": return "2段 x1.0"
		"blood_drain": return "1.0x / 50%吸血"
		"the_world": return "时停 / 免费移动"
		"flame_spray": return "1.1x / 点燃"
		"cross_fire": return "十字 AOE 1.6x"
		"fire_wall": return "入格伤害 0.4x"
		"illumination": return "下次攻击命中+20%"
		"hamon": return "1.0x / 克制吸血鬼"
		"hermit_bind": return "0.6x / 束缚"
		"spirit_photo": return "队友行动提前"
		"hamon_guard": return "减伤30% / 反弹20%"
		_: return "特殊技能"


static func skill_description(skill_data: Dictionary) -> String:
	match str(skill_data["id"]):
		"star_finger": return "对 0~2 格敌人造成 1.0 倍伤害。本次攻击必中。"
		"ora_ora": return "对贴身敌人连续攻击 2 段，每段独立判定命中与暴击。"
		"counter_charge": return "强化下一次物理攻击；蓄力期间受伤会进一步强化。本回合减伤 20%。"
		"star_platinum_world": return "停止时间并获得一次完整额外行动，整个时停只推进一次 S。"
		"emerald_splash": return "对 3~8 格敌人造成 1.2 倍伤害，本次攻击必中。"
		"hierophant_mark": return "标记远处敌人，使我方攻击该目标时命中率增加 20 个百分点。"
		"barrier": return "造成 1.6 倍伤害，并令目标的下一次行动延后。"
		"barrier_bind": return "造成 0.6 倍伤害并束缚目标，使其下一次行动无法移动。"
		"thrust": return "造成 1.0 倍伤害，本次攻击的暴击率额外增加 20%。"
		"blade_combo": return "连续攻击 3 段，每段 0.7 倍伤害并独立结算。"
		"armor_off": return "本回合提升速度与暴击率，但防御减半。"
		"afterimage": return "本回合运气翻倍，使敌方攻击更容易落空。"
		"knives": return "对 0~3 格敌人造成 0.8 倍远程伤害。"
		"muda_muda": return "对贴身敌人连续攻击 2 段，每段 1.0 倍伤害。"
		"blood_drain": return "造成物理伤害，并回复实际伤害量 50% 的 HP。"
		"the_world": return "停止时间并获得一次额外行动，时停行动拥有 4 格免费移动。"
		"flame_spray": return "造成 1.1 倍伤害并点燃目标，点燃在目标行动开始时结算两次。"
		"cross_fire": return "攻击目标格及其上下左右格内的全部敌人，不伤害友军。"
		"fire_wall": return "在相邻格生成火墙，角色每次进入该格都会受到间接伤害。"
		"illumination": return "使下一次直接攻击的全部伤害段命中率增加 20 个百分点。"
		"hamon": return "造成物理伤害，对吸血鬼或非人目标造成额外伤害。"
		"hermit_bind": return "造成 0.6 倍伤害并束缚目标，使其下一次行动无法移动。"
		"spirit_photo": return "使一名存活队友的行动提前，但不会超过当前行动者。"
		"hamon_guard": return "本回合减伤 30%，并反弹所受贴身物理伤害的 20%。"
		_: return skill_summary(skill_data)
