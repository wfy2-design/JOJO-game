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
			"id": 0, "key": "jotaro", "name": "空条承太郎", "stand": "白金之星",
			"story": "为了拯救受替身影响而病危的母亲，与同伴踏上前往埃及、击败 DIO 的旅程。",
			"team": TEAM_A, "max_hp": 240, "initial_ap": 3, "damage": 32,
			"crit": 15, "defense": 14, "luck": 5, "speed": 14,
			"r_opt": 1, "r_max": 6, "texture": "res://assets/characters/jotaro.png",
			"critical_texture": "res://assets/characters/jotaro_critical.png",
			"radar": [100, 100, 60, 100, 100, 100],
			"skills": [
				skill("star_finger", "流星指刺", 1, "enemy", 0, 2, "damage", 1.0, 1, true, true),
				skill("ora_ora", "欧拉连打", 3, "enemy", 0, 1, "damage", 1.0, 2, false, true),
				skill("counter_charge", "反击蓄力", 2, "self", 0, 0, "counter_charge"),
				skill("star_platinum_world", "白金之星·世界", 5, "self", 0, 0, "time_stop"),
			],
		},
		{
			"id": 1, "key": "kakyoin", "name": "花京院典明", "stand": "绿之法皇",
			"story": "曾被 DIO 的肉芽控制，在承太郎解救后选择同行，以冷静判断面对强敌。",
			"team": TEAM_A, "max_hp": 160, "initial_ap": 3, "damage": 20,
			"crit": 8, "defense": 7, "luck": 8, "speed": 9,
			"r_opt": 6, "r_max": 10, "texture": "res://assets/characters/kakyoin.png",
			"critical_texture": "res://assets/characters/kakyoin_critical.png",
			"radar": [60, 80, 100, 80, 60, 40],
			"skills": [
				skill("emerald_splash", "绿宝石水花", 2, "enemy", 3, 8, "damage", 1.2, 1, true),
				skill("hierophant_mark", "法皇标记", 1, "enemy", 3, 10, "mark", 0.0, 1, true),
				skill("barrier", "法皇结界", 4, "enemy", 3, 10, "delay", 1.6),
				skill("barrier_bind", "结界束缚", 3, "enemy", 2, 8, "bind", 0.6),
			],
		},
		{
			"id": 2, "key": "polnareff", "name": "波鲁纳雷夫", "stand": "银色战车",
			"story": "为追查杀害妹妹的凶手踏上旅途，并在战斗中逐渐成为值得信赖的伙伴。",
			"team": TEAM_A, "max_hp": 140, "initial_ap": 4, "damage": 22,
			"crit": 18, "defense": 4, "luck": 12, "speed": 13,
			"r_opt": 1, "r_max": 5, "texture": "res://assets/characters/polnareff.png",
			"critical_texture": "res://assets/characters/polnareff_critical.png",
			"radar": [60, 100, 60, 80, 80, 60],
			"skills": [
				skill("thrust", "突刺", 1, "enemy", 0, 1, "crit_strike", 1.0, 1, false, true),
				skill("blade_combo", "剑刃连击", 3, "enemy", 0, 1, "damage", 0.7, 3, false, true),
				skill("armor_off", "装甲卸除", 2, "self", 0, 0, "armor_off"),
				skill("afterimage", "残影闪避", 2, "self", 0, 0, "afterimage"),
			],
		},
		{
			"id": 3, "key": "dio", "name": "迪奥", "stand": "世界",
			"story": "夺取乔纳森身体后再次苏醒，以世界的力量盘踞埃及，企图终结乔斯达血脉。",
			"team": TEAM_B, "max_hp": 230, "initial_ap": 3, "damage": 32,
			"crit": 10, "defense": 12, "luck": 14, "speed": 15,
			"r_opt": 1, "r_max": 6, "texture": "res://assets/characters/dio.png",
			"critical_texture": "res://assets/characters/dio_critical.png",
			"radar": [100, 100, 60, 100, 80, 80],
			"tags": ["vampire", "non_human"],
			"skills": [
				skill("knives", "飞刀", 1, "enemy", 0, 3, "damage", 0.8),
				skill("muda_muda", "无駄连打", 3, "enemy", 0, 1, "damage", 1.0, 2, false, true),
				skill("blood_drain", "吸血", 2, "enemy", 0, 1, "drain", 1.0, 1, false, true),
				skill("the_world", "世界·时停", 5, "self", 0, 0, "time_stop_dio"),
			],
		},
		{
			"id": 4, "key": "avdol", "name": "阿布德尔", "stand": "红色魔术师",
			"story": "熟悉替身世界的埃及占卜师，沉着可靠，是远征队的重要战力与向导。",
			"team": TEAM_B, "max_hp": 170, "initial_ap": 3, "damage": 26,
			"crit": 8, "defense": 8, "luck": 7, "speed": 8,
			"r_opt": 4, "r_max": 9, "texture": "res://assets/characters/avdol.png",
			"critical_texture": "res://assets/characters/avdol_critical.png",
			"radar": [80, 80, 80, 80, 60, 40],
			"skills": [
				skill("flame_spray", "火焰喷射", 2, "enemy", 2, 7, "burn", 1.1),
				skill("cross_fire", "十字火焰", 4, "enemy", 2, 6, "area", 1.6),
				skill("fire_wall", "火墙", 2, "cell", 1, 1, "fire_wall"),
				skill("illumination", "火焰照明", 1, "self", 0, 0, "accuracy_up"),
			],
		},
		{
			"id": 5, "key": "joseph", "name": "乔瑟夫", "stand": "隐者之紫",
			"story": "乔斯达家族的老练战士，凭借隐者之紫与丰富经验，引导众人追踪 DIO。",
			"team": TEAM_B, "max_hp": 200, "initial_ap": 2, "damage": 14,
			"crit": 5, "defense": 12, "luck": 10, "speed": 6,
			"r_opt": 1, "r_max": 4, "texture": "res://assets/characters/joseph.png",
			"critical_texture": "res://assets/characters/joseph_critical.png",
			"radar": [40, 60, 40, 100, 40, 20],
			"skills": [
				skill("hamon", "波纹疾走", 1, "enemy", 0, 1, "hamon", 1.0, 1, false, true),
				skill("hermit_bind", "隐者之紫缠绕", 2, "enemy", 0, 3, "bind", 0.6),
				skill("spirit_photo", "念写·先机", 1, "ally", 0, 10, "advance"),
				skill("hamon_guard", "波纹护体", 2, "self", 0, 0, "hamon_guard"),
			],
		},
	]
