extends RefCounted
## 卡牌战斗状态机（纯逻辑，不碰 UI）。
## 回合：玩家（3 能量、5 张手牌）→ 出牌 → 结束回合 → 敌人按意图行动 →
## 动画播完由 UI 调 begin_player_turn() 开新回合。
##
## 状态系统：
##   易伤 vulnerable —— 受到伤害 ×1.5
##   虚弱 weak       —— 造成伤害 ×0.75
##   中毒 poison     —— 自己回合开始掉 N 点血（无视格挡），随后层数 -1
## 易伤/虚弱在「对方回合结束时」-1；中毒在「自己回合开始时」结算并 -1。

signal changed
signal logged(text: String)
signal battle_over(won: bool)
## 实际掉血时发出（格挡吸收掉的不算），供 UI 播音效。
signal damaged(target: String, amount: int)

const CardDB := preload("res://scripts/cards/card_db.gd")

const MAX_ENERGY := 3
const HAND_SIZE := 5
const PLAYER_MAX_HP := 70
const ENEMY_MAX_HP := 80

## 敌人意图循环（加强了：血更厚、伤害更高、加入多段攻击）
const ENEMY_INTENTS := [
	{"name": "糖浆雨", "type": "attack", "value": 10},
	{"name": "奶泡膨胀", "type": "defend", "value": 10},
	{"name": "糖晶暴食", "type": "attack", "value": 16},
	{"name": "糖浆连击", "type": "attack_multi", "value": 6, "hits": 2},
	{"name": "奶泡膨胀", "type": "defend", "value": 10},
]

var draw_pile: Array[String] = []
var hand: Array[String] = []
var discard_pile: Array[String] = []

var energy := MAX_ENERGY
var turn := 1
var finished := false
var won := false

var player_hp := PLAYER_MAX_HP
var player_block := 0
var enemy_hp := ENEMY_MAX_HP
var enemy_block := 0
var intent_index := 0

# 玩家状态
var player_vulnerable := 0
var player_weak := 0
var player_poison := 0
# 敌人状态
var enemy_vulnerable := 0
var enemy_weak := 0
var enemy_poison := 0


func start_battle() -> void:
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	energy = MAX_ENERGY
	turn = 1
	finished = false
	won = false
	player_hp = PLAYER_MAX_HP
	player_block = 0
	enemy_hp = ENEMY_MAX_HP
	enemy_block = 0
	intent_index = 0
	player_vulnerable = 0
	player_weak = 0
	player_poison = 0
	enemy_vulnerable = 0
	enemy_weak = 0
	enemy_poison = 0

	# 初始牌组 14 张
	for i in 4:
		draw_pile.append("strike")
	for i in 3:
		draw_pile.append("defend")
	for id in ["tail_whip", "breathe", "lunge", "blubber", "bite", "iron_wall", "gnaw"]:
		draw_pile.append(id)
	draw_pile.shuffle()

	logged.emit("[color=#8fd3ff]战斗开始：[/color]奶龙挡住了去路。")
	_draw(HAND_SIZE)
	changed.emit()


# ---------------------------------------------------------------- 出牌

func can_play(index: int) -> bool:
	if finished or index < 0 or index >= hand.size():
		return false
	var card := CardDB.get_card(hand[index])
	return not card.is_empty() and int(card.get("cost", 0)) <= energy


func play_card(index: int) -> void:
	if not can_play(index):
		return
	var id := hand[index]
	var card := CardDB.get_card(id)
	hand.remove_at(index)
	energy -= int(card.get("cost", 0))
	logged.emit("你打出 [color=#ffd479]【%s】[/color]" % CardDB.card_name(id))

	var effect: Dictionary = card.get("effect", {})

	if effect.has("damage"):
		var hits := int(effect.get("hits", 1))
		for i in hits:
			var dmg := _incoming_damage(int(effect["damage"]), "player", "enemy")
			_damage_enemy(dmg)

	if effect.has("block"):
		var gain := int(effect["block"])
		player_block += gain
		logged.emit("  获得 %d 点格挡（当前 %d）" % [gain, player_block])

	if effect.has("heal"):
		var before := player_hp
		player_hp = mini(PLAYER_MAX_HP, player_hp + int(effect["heal"]))
		logged.emit("  回复 %d 点生命" % (player_hp - before))

	if effect.has("draw"):
		_draw(int(effect["draw"]))

	if effect.has("energy"):
		energy += int(effect["energy"])

	if effect.has("cleanse_self"):
		player_vulnerable = 0
		player_weak = 0
		logged.emit("  清除了自身的易伤与虚弱")

	if effect.has("apply_enemy"):
		_apply_status("enemy", effect["apply_enemy"])

	if effect.has("apply_self"):
		_apply_status("player", effect["apply_self"])

	discard_pile.append(id)
	_check_over()
	changed.emit()


# ---------------------------------------------------------------- 回合

## 敌人行动阶段（也是玩家回合的结束）：玩家状态 -1 → 敌人中毒结算 → 敌人出手。
func enemy_turn() -> Dictionary:
	if finished:
		return {"type": "none", "name": "", "value": 0, "damage": 0}

	# 玩家回合结束：玩家身上的易伤/虚弱 -1
	player_vulnerable = maxi(0, player_vulnerable - 1)
	player_weak = maxi(0, player_weak - 1)

	# 敌人回合开始：先吃中毒
	if enemy_poison > 0:
		var poison_dmg := enemy_poison
		enemy_poison -= 1
		enemy_hp = maxi(0, enemy_hp - poison_dmg)
		logged.emit("[color=#a6e3a1]奶龙受到 %d 点中毒伤害（无视格挡）。[/color]" % poison_dmg)
		damaged.emit("enemy", poison_dmg)
		_check_over()
		if finished:
			changed.emit()
			return {"type": "poison", "name": "中毒", "value": poison_dmg, "damage": 0}

	# 弃手牌
	for id in hand:
		discard_pile.append(id)
	hand.clear()

	enemy_block = 0
	var act: Dictionary = ENEMY_INTENTS[intent_index % ENEMY_INTENTS.size()]
	intent_index += 1
	var value := int(act.get("value", 0))
	var result := {
		"type": str(act.get("type", "")),
		"name": str(act.get("name", "")),
		"value": value,
		"damage": 0,
	}
	if result["type"] == "attack":
		var real := _incoming_damage(value, "enemy", "player")
		var before := player_hp
		logged.emit("[color=#ff9d9d]奶龙使用【%s】，造成 %d 点伤害。[/color]" % [str(act.get("name", "")), real])
		_damage_player(real)
		result["damage"] = before - player_hp
	elif result["type"] == "attack_multi":
		var hits := int(act.get("hits", 2))
		var before := player_hp
		var total := 0
		for i in hits:
			var real := _incoming_damage(value, "enemy", "player")
			total += real
			_damage_player(real)
		logged.emit("[color=#ff9d9d]奶龙使用【%s】，连续 %d 次造成共 %d 点伤害。[/color]" % [
			str(act.get("name", "")), hits, total
		])
		result["damage"] = before - player_hp
		result["hits"] = hits
	elif result["type"] == "defend":
		enemy_block += value
		logged.emit("[color=#ff9d9d]奶龙使用【%s】，获得 %d 点格挡。[/color]" % [str(act.get("name", "")), value])

	# 敌人回合结束：敌人身上的易伤/虚弱 -1
	enemy_vulnerable = maxi(0, enemy_vulnerable - 1)
	enemy_weak = maxi(0, enemy_weak - 1)

	_check_over()
	changed.emit()
	return result


## 玩家新回合：中毒结算 → 回合数 +1、格挡清零、能量回满、补牌。
func begin_player_turn() -> void:
	if finished:
		return

	if player_poison > 0:
		var poison_dmg := player_poison
		player_poison -= 1
		player_hp = maxi(0, player_hp - poison_dmg)
		logged.emit("[color=#ff9d9d]你受到 %d 点中毒伤害（无视格挡）。[/color]" % poison_dmg)
		damaged.emit("player", poison_dmg)
		_check_over()
		if finished:
			changed.emit()
			return

	turn += 1
	player_block = 0
	energy = MAX_ENERGY
	_draw(HAND_SIZE)
	logged.emit("[color=#8fd3ff]—— 第 %d 回合 ——[/color]" % turn)
	changed.emit()


func intent() -> Dictionary:
	return ENEMY_INTENTS[intent_index % ENEMY_INTENTS.size()]


func player_status_text() -> String:
	return _status_text(player_vulnerable, player_weak, player_poison)


func enemy_status_text() -> String:
	return _status_text(enemy_vulnerable, enemy_weak, enemy_poison)


# ---------------------------------------------------------------- 内部

func _status_text(vuln: int, weak: int, poison: int) -> String:
	var parts: Array[String] = []
	if vuln > 0:
		parts.append("易伤 %d" % vuln)
	if weak > 0:
		parts.append("虚弱 %d" % weak)
	if poison > 0:
		parts.append("中毒 %d" % poison)
	if parts.is_empty():
		return "无状态"
	return " · ".join(parts)


## 伤害修正：攻击方虚弱 ×0.75，受击方易伤 ×1.5
func _incoming_damage(base: int, attacker: String, target: String) -> int:
	var dmg := float(base)
	if attacker == "player" and player_weak > 0:
		dmg *= 0.75
	elif attacker == "enemy" and enemy_weak > 0:
		dmg *= 0.75
	if target == "enemy" and enemy_vulnerable > 0:
		dmg *= 1.5
	elif target == "player" and player_vulnerable > 0:
		dmg *= 1.5
	return maxi(1, int(floor(dmg)))


func _apply_status(target: String, statuses: Dictionary) -> void:
	for key in statuses.keys():
		var amount := int(statuses[key])
		match key:
			"vulnerable":
				if target == "enemy":
					enemy_vulnerable += amount
				else:
					player_vulnerable += amount
				logged.emit("  %s获得 %d 层易伤" % ["奶龙" if target == "enemy" else "你", amount])
			"weak":
				if target == "enemy":
					enemy_weak += amount
				else:
					player_weak += amount
				logged.emit("  %s获得 %d 层虚弱" % ["奶龙" if target == "enemy" else "你", amount])
			"poison":
				if target == "enemy":
					enemy_poison += amount
				else:
					player_poison += amount
				logged.emit("  %s获得 %d 层中毒" % ["奶龙" if target == "enemy" else "你", amount])


func _draw(count: int) -> void:
	for i in count:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				return
			draw_pile.assign(discard_pile)
			discard_pile.clear()
			draw_pile.shuffle()
			logged.emit("  弃牌堆洗回抽牌堆")
		if hand.size() >= 10:
			return
		hand.append(draw_pile.pop_back())


func _damage_enemy(amount: int) -> void:
	var absorbed := mini(enemy_block, amount)
	enemy_block -= absorbed
	var real := amount - absorbed
	enemy_hp = maxi(0, enemy_hp - real)
	logged.emit("  造成 %d 点伤害（格挡吸收 %d）" % [real, absorbed])
	if real > 0:
		damaged.emit("enemy", real)


func _damage_player(amount: int) -> void:
	var absorbed := mini(player_block, amount)
	player_block -= absorbed
	var real := amount - absorbed
	player_hp = maxi(0, player_hp - real)
	if absorbed > 0:
		logged.emit("  格挡吸收 %d 点，实际受到 %d 点伤害" % [absorbed, real])
	if real > 0:
		damaged.emit("player", real)


func _check_over() -> void:
	if finished:
		return
	if enemy_hp <= 0:
		finished = true
		won = true
		logged.emit("[color=#9dffa0]敌人倒下了！[/color]")
		battle_over.emit(true)
	elif player_hp <= 0:
		finished = true
		won = false
		logged.emit("[color=#ff9d9d]你被奶龙吃掉了……[/color]")
		battle_over.emit(false)
