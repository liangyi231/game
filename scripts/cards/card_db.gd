extends RefCounted
## 卡牌数据表。
## 每张牌：id -> {name, cost, type, desc, effect}
## effect 支持的键：
##   damage / hits（多段） / block / draw / heal / energy
##   apply_enemy / apply_self：{"vulnerable": n, "weak": n, "poison": n}
##   cleanse_self：清除自身易伤与虚弱
## type 仅用于 UI 着色：attack / skill


const CARDS := {
	# ---------------- 基础攻击 ----------------
	"strike": {
		"name": "打击", "cost": 1, "type": "attack",
		"desc": "造成 6 点伤害。",
		"effect": {"damage": 6},
	},
	"tail_whip": {
		"name": "甩尾", "cost": 1, "type": "attack",
		"desc": "造成 8 点伤害，抽 1 张牌。",
		"effect": {"damage": 8, "draw": 1},
	},
	"salty_jab": {
		"name": "咸鱼突刺", "cost": 0, "type": "attack",
		"desc": "造成 3 点伤害。",
		"effect": {"damage": 3},
	},
	"lunge": {
		"name": "鱼跃冲撞", "cost": 2, "type": "attack",
		"desc": "造成 14 点伤害。",
		"effect": {"damage": 14},
	},
	"bubble_combo": {
		"name": "泡沫连击", "cost": 2, "type": "attack",
		"desc": "造成 4 点伤害 3 次。",
		"effect": {"damage": 4, "hits": 3},
	},
	"fish_school": {
		"name": "鱼群战术", "cost": 2, "type": "attack",
		"desc": "造成 3 点伤害 4 次。",
		"effect": {"damage": 3, "hits": 4},
	},
	"whale_fall": {
		"name": "鲸落", "cost": 3, "type": "attack",
		"desc": "造成 24 点伤害。",
		"effect": {"damage": 24},
	},
	"charge_rush": {
		"name": "冲锋", "cost": 1, "type": "attack",
		"desc": "造成 9 点伤害，获得 4 点格挡。",
		"effect": {"damage": 9, "block": 4},
	},

	# ---------------- 施加状态 ----------------
	"bite": {
		"name": "撕咬", "cost": 1, "type": "attack",
		"desc": "造成 5 点伤害，施加 2 层易伤。",
		"effect": {"damage": 5, "apply_enemy": {"vulnerable": 2}},
	},
	"heavy_slap": {
		"name": "甩鳍", "cost": 2, "type": "attack",
		"desc": "造成 10 点伤害，施加 2 层虚弱。",
		"effect": {"damage": 10, "apply_enemy": {"weak": 2}},
	},
	"gnaw": {
		"name": "啃咬", "cost": 1, "type": "attack",
		"desc": "造成 4 点伤害，施加 3 层中毒。",
		"effect": {"damage": 4, "apply_enemy": {"poison": 3}},
	},
	"poison_cloud": {
		"name": "毒雾", "cost": 1, "type": "skill",
		"desc": "施加 4 层中毒。",
		"effect": {"apply_enemy": {"poison": 4}},
	},
	"stare": {
		"name": "凝视", "cost": 0, "type": "skill",
		"desc": "施加 2 层易伤。",
		"effect": {"apply_enemy": {"vulnerable": 2}},
	},
	"taunt": {
		"name": "挑衅", "cost": 1, "type": "skill",
		"desc": "获得 5 点格挡，施加 2 层虚弱。",
		"effect": {"block": 5, "apply_enemy": {"weak": 2}},
	},

	# ---------------- 格挡 / 功能 ----------------
	"defend": {
		"name": "防御", "cost": 1, "type": "skill",
		"desc": "获得 5 点格挡。",
		"effect": {"block": 5},
	},
	"blubber": {
		"name": "脂肪护体", "cost": 2, "type": "skill",
		"desc": "获得 12 点格挡。",
		"effect": {"block": 12},
	},
	"iron_wall": {
		"name": "铁壁", "cost": 1, "type": "skill",
		"desc": "获得 8 点格挡，抽 1 张牌。",
		"effect": {"block": 8, "draw": 1},
	},
	"breathe": {
		"name": "深呼吸", "cost": 0, "type": "skill",
		"desc": "抽 2 张牌。",
		"effect": {"draw": 2},
	},
	"focus": {
		"name": "蓄力", "cost": 0, "type": "skill",
		"desc": "获得 1 点能量。",
		"effect": {"energy": 1},
	},
	"molt": {
		"name": "蜕皮", "cost": 1, "type": "skill",
		"desc": "清除自身易伤与虚弱，获得 4 点格挡。",
		"effect": {"cleanse_self": true, "block": 4},
	},
	"feast": {
		"name": "大餐", "cost": 2, "type": "skill",
		"desc": "回复 8 点生命。",
		"effect": {"heal": 8},
	},
}


static func get_card(id: String) -> Dictionary:
	return CARDS.get(id, {})


static func card_name(id: String) -> String:
	return str(CARDS.get(id, {}).get("name", id))
