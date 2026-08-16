class_name BattleData
extends RefCounted

const TEAM_A := 0
const TEAM_B := 1
const MAX_AP := 10

static func skill(
	id: String,
	display_name: String,
	cost: int,
	target: String,
	min_range: int,
	max_range: int,
	effect: String,
	multiplier: float = 0.0,
	hits: int = 1,
	guaranteed: bool = false,
	physical: bool = false
) -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"cost": cost,
		"target": target,
		"min_range": min_range,
		"max_range": max_range,
		"effect": effect,
		"multiplier": multiplier,
		"hits": hits,
		"guaranteed": guaranteed,
		"physical": physical,
	}


static func characters() -> Array[Dictionary]:
	return [
		{
			"id": 0, "key": "night_chain", "name": "夜链", "stand": "磁锁协议",
			"story": "拘束控制型战术机娘。她以磁力链刃封锁战场，在敌人露出破绽前始终保持冷静。",
			"team": TEAM_A, "max_hp": 240, "initial_ap": 3, "damage": 32,
			"crit": 15, "defense": 14, "luck": 5, "speed": 14,
			"r_opt": 1, "r_max": 6, "texture": "res://assets/characters/units/night_chain.png",
			"avatar_texture": "res://assets/characters/avatars/night_chain.png",
			"portrait_texture": "res://assets/characters/portraits/night_chain.png",
			"critical_texture": "res://assets/characters/critical/night_chain.png",
			"radar": [100, 100, 60, 100, 100, 100],
			"skills": [
				skill("magnetic_lunge", "磁链突袭", 1, "enemy", 0, 2, "damage", 1.0, 1, true, true),
				skill("chain_barrage", "链刃连打", 3, "enemy", 0, 1, "damage", 1.0, 2, false, true),
				skill("kinetic_counter", "势能反击", 2, "self", 0, 0, "counter_charge"),
				skill("zero_lock", "零时封锁", 5, "self", 0, 0, "time_stop"),
			],
		},
		{
			"id": 1, "key": "mirror_tide", "name": "镜澜", "stand": "镜域阵列",
			"story": "信息侦察型机娘。悬浮数据刃与半脸目镜让她能在远距离解析目标并扰乱行动节奏。",
			"team": TEAM_A, "max_hp": 160, "initial_ap": 3, "damage": 20,
			"crit": 8, "defense": 7, "luck": 8, "speed": 9,
			"r_opt": 6, "r_max": 10, "texture": "res://assets/characters/units/mirror_tide.png",
			"avatar_texture": "res://assets/characters/avatars/mirror_tide.png",
			"portrait_texture": "res://assets/characters/portraits/mirror_tide.png",
			"critical_texture": "res://assets/characters/critical/mirror_tide.png",
			"radar": [60, 80, 100, 80, 60, 40],
			"skills": [
				skill("data_prism", "数据棱光", 2, "enemy", 3, 8, "damage", 1.2, 1, true),
				skill("scan_mark", "镜域标记", 1, "enemy", 3, 10, "mark", 0.0, 1, true),
				skill("signal_barrier", "干扰屏障", 4, "enemy", 3, 10, "delay", 1.6),
				skill("data_bind", "信号拘束", 3, "enemy", 2, 8, "bind", 0.6),
			],
		},
		{
			"id": 2, "key": "sun_blade", "name": "曜锋", "stand": "折光刃组",
			"story": "高速切割型机娘。折叠式等离子长刃与轻量装甲让她能连续突进，在近身战中制造致命切口。",
			"team": TEAM_A, "max_hp": 140, "initial_ap": 4, "damage": 22,
			"crit": 18, "defense": 4, "luck": 12, "speed": 13,
			"r_opt": 1, "r_max": 5, "texture": "res://assets/characters/units/sun_blade.png",
			"avatar_texture": "res://assets/characters/avatars/sun_blade.png",
			"portrait_texture": "res://assets/characters/portraits/sun_blade.png",
			"critical_texture": "res://assets/characters/critical/sun_blade.png",
			"radar": [60, 100, 60, 80, 80, 60],
			"skills": [
				skill("plasma_thrust", "裂空突刺", 1, "enemy", 0, 1, "crit_strike", 1.0, 1, false, true),
				skill("plasma_combo", "等离子连斩", 3, "enemy", 0, 1, "damage", 0.7, 3, false, true),
				skill("lightweight_overclock", "轻装超频", 2, "self", 0, 0, "armor_off"),
				skill("refraction_echo", "折光残影", 2, "self", 0, 0, "afterimage"),
			],
		},
		{
			"id": 3, "key": "crimson_thorn", "name": "绯棘", "stand": "棘时核心",
			"story": "反击防御型重甲机娘。六边盾与冲击拳套构成她的正面防线，腰部核心能够短暂冻结局部时间。",
			"team": TEAM_B, "max_hp": 230, "initial_ap": 3, "damage": 32,
			"crit": 10, "defense": 12, "luck": 14, "speed": 15,
			"r_opt": 1, "r_max": 6, "texture": "res://assets/characters/units/crimson_thorn.png",
			"avatar_texture": "res://assets/characters/avatars/crimson_thorn.png",
			"portrait_texture": "res://assets/characters/portraits/crimson_thorn.png",
			"critical_texture": "res://assets/characters/critical/crimson_thorn.png",
			"radar": [100, 100, 60, 100, 80, 80],
			"tags": ["overheated_core"],
			"skills": [
				skill("thorn_shards", "棘片投射", 1, "enemy", 0, 3, "damage", 0.8),
				skill("impact_barrage", "冲击连拳", 3, "enemy", 0, 1, "damage", 1.0, 2, false, true),
				skill("core_siphon", "核心汲取", 2, "enemy", 0, 1, "drain", 1.0, 1, false, true),
				skill("crimson_stasis", "赤域停滞", 5, "self", 0, 0, "time_stop_free"),
			],
		},
		{
			"id": 4, "key": "molten_core", "name": "熔芯", "stand": "熔炉矩阵",
			"story": "熔炉重锤工程型机娘。背部锅炉为重锤与装甲持续供能，擅长制造灼热区域并压制成群目标。",
			"team": TEAM_B, "max_hp": 170, "initial_ap": 3, "damage": 26,
			"crit": 8, "defense": 8, "luck": 7, "speed": 8,
			"r_opt": 4, "r_max": 9, "texture": "res://assets/characters/units/molten_core.png",
			"avatar_texture": "res://assets/characters/avatars/molten_core.png",
			"portrait_texture": "res://assets/characters/portraits/molten_core.png",
			"critical_texture": "res://assets/characters/critical/molten_core.png",
			"radar": [80, 80, 80, 80, 60, 40],
			"skills": [
				skill("molten_spray", "熔流喷射", 2, "enemy", 2, 7, "burn", 1.1),
				skill("furnace_quake", "炉心震荡", 4, "enemy", 2, 6, "area", 1.6),
				skill("heat_zone", "灼热区", 2, "cell", 1, 1, "fire_wall"),
				skill("thermal_calibration", "热感校准", 1, "self", 0, 0, "accuracy_up"),
			],
		},
		{
			"id": 5, "key": "frost_wing", "name": "霜翊", "stand": "冰翼系统",
			"story": "冰翼长枪侦察型机娘。非对称机械翼负责高速索敌，能量长枪兼具破甲、牵制与队友支援能力。",
			"team": TEAM_B, "max_hp": 200, "initial_ap": 2, "damage": 14,
			"crit": 5, "defense": 12, "luck": 10, "speed": 6,
			"r_opt": 1, "r_max": 4, "texture": "res://assets/characters/units/frost_wing.png",
			"avatar_texture": "res://assets/characters/avatars/frost_wing.png",
			"portrait_texture": "res://assets/characters/portraits/frost_wing.png",
			"critical_texture": "res://assets/characters/critical/frost_wing.png",
			"radar": [40, 60, 40, 100, 40, 20],
			"skills": [
				skill("frost_lance", "冰锥突进", 1, "enemy", 0, 1, "core_pierce", 1.0, 1, false, true),
				skill("frost_bind", "霜索拘束", 2, "enemy", 0, 3, "bind", 0.6),
				skill("ice_mirror", "冰镜先机", 1, "ally", 0, 10, "advance"),
				skill("crystal_guard", "晶翼护盾", 2, "self", 0, 0, "crystal_guard"),
			],
		},
	]
