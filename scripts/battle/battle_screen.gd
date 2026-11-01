extends Control
## 卡牌战斗界面。UI 全部代码构建 + 绝对定位，让角色能站在背景草坪线上。
## 手牌为扇形排布：悬停时整张牌平滑凸起（带旋转回正），并在牌上方浮出效果面板。

const CardDB := preload("res://scripts/cards/card_db.gd")
const BattleState := preload("res://scripts/battle/battle_state.gd")

const ENEMY_IDLE_TEXTURE := "res://art/enemies/nailong_idle.png"
const ENEMY_ACTION_TEXTURE := "res://art/enemies/nailong_action.png"
const PLAYER_TEXTURE := "res://art/characters/whale_girl.png"
const CARD_ART := "res://art/ui/card_face.jpg"
const CARD_SHADER := "res://art/ui/card_round.gdshader"
const BG_ART := "res://art/bg/night_sky.jpg"

const POSE_TIME := 0.1
## 背景放大倍率（1.0 = 刚好铺满；越大越近）
const BG_ZOOM := 1.12
## 背景图里草坪线所在的纵向比例（0=顶部 1=底部）
const GRASS_RATIO := 0.872
## 草坪线在屏幕上的高度比例（角色脚底落在这里）
const GRASS_SCREEN_RATIO := 0.72
## 角色显示尺寸（比之前缩小）
const CHAR_SIZE := Vector2(200, 230)

const CARD_SIZE := Vector2(140, 184)
const HAND_AREA_HEIGHT := 250.0
const FAN_SPREAD_DEG := 12.0
const HOVER_LIFT := 58.0
const HOVER_SCALE := 1.16
const HOVER_TIME := 0.26
## 悬停时两侧卡牌让位的最大距离
const NEIGHBOR_PUSH := 30.0
## 入牌动画
const ENTRY_TIME := 0.22
const ENTRY_STAGGER := 0.045
## 抽牌动画（从抽牌堆飞入手牌）
const DRAW_FLY_TIME := 0.46
const DRAW_STAGGER := 0.07

var state: BattleState

var bg: TextureRect
var player_pic: TextureRect
var enemy_pic: TextureRect
var player_head: Label
var enemy_head: Label
var log_panel: PanelContainer
var log_box: RichTextLabel
var hand_area: Control
var bottom_bar: HBoxContainer
var energy_label: Label
var turn_label: Label
var result_label: Label
var end_turn_button: Button
var restart_button: Button
var card_tip: PanelContainer
var card_tip_label: RichTextLabel
var fx_layer: Control

var _card_nodes: Array[Button] = []
var _card_base: Dictionary = {}
## 每张卡当前的动画 tween，重新触发时先杀掉，避免叠加抖动
var _card_tweens: Dictionary = {}
## 下次布局时是否播放入牌动画（刷新手牌后为 true）
var _cards_entry := false
## 抽牌堆视觉 + 上次手牌快照（用于识别“新抽到的牌”）
var draw_pile: Control
var draw_pile_label: Label
var _last_hand: Array[String] = []
var _pending_draw: Array[int] = []
## 同一帧内 _refresh 会被信号 + 显式调用触发两次，这里去重，避免待抽列表被清空
var _refresh_in_frame := false
## 抽牌动画播放中，暂时屏蔽悬停，避免邻牌让位把飞行 tween 打断
var _draw_animating := false
var _enemy_rest_pos := Vector2.ZERO
var _pose_tween: Tween
var _busy := false
## 当前处于悬停态的卡牌（同一时刻只允许一张，避免邻牌被推到光标下触发级联）
var _hover_node: Button = null
## 草坪线在屏幕上的 y 坐标（拖拽判定用）
var _grass_y := 0.0
# 拖拽出牌状态
var _dragging := false
var _drag_index := -1
var _drag_node: Button = null
var _drag_offset := Vector2.ZERO
var _drag_moved := false


func _ready() -> void:
	_apply_font()
	_build_ui()
	state = BattleState.new()
	state.logged.connect(_on_log)
	state.changed.connect(_refresh)
	state.battle_over.connect(_on_battle_over)
	state.damaged.connect(_on_damaged)
	_start_battle()
	_layout_stage.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_stage.call_deferred()


func _apply_font() -> void:
	var cjk := SystemFont.new()
	cjk.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei", "SimHei", "Noto Sans CJK SC"
	])
	var t := Theme.new()
	t.default_font = cjk
	t.default_font_size = 18
	theme = t


# ---------------------------------------------------------------- UI 构建

func _build_ui() -> void:
	# 背景：像素夜景（尺寸由 _layout_stage 按放大倍率计算）
	bg = TextureRect.new()
	bg.texture = load(BG_ART)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var bg_shade := ColorRect.new()
	bg_shade.color = Color(0.02, 0.04, 0.09, 0.34)
	bg_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_shade)

	# --- 角色立绘 ---
	player_pic = TextureRect.new()
	player_pic.texture = load(PLAYER_TEXTURE)
	player_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	player_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(player_pic)

	enemy_pic = TextureRect.new()
	enemy_pic.texture = load(ENEMY_IDLE_TEXTURE)
	enemy_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	enemy_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(enemy_pic)

	# --- 头顶名字 / 血量 / 意图 ---
	player_head = Label.new()
	player_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_head.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	player_head.add_theme_font_size_override("font_size", 16)
	player_head.add_theme_color_override("font_color", Color("#bfe9ff"))
	player_head.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	player_head.add_theme_constant_override("outline_size", 6)
	add_child(player_head)

	enemy_head = Label.new()
	enemy_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_head.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	enemy_head.add_theme_font_size_override("font_size", 16)
	enemy_head.add_theme_color_override("font_color", Color("#ffd0d0"))
	enemy_head.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	enemy_head.add_theme_constant_override("outline_size", 6)
	add_child(enemy_head)

	# --- 战斗日志（顶部半透明面板） ---
	log_panel = PanelContainer.new()
	var log_style := StyleBoxFlat.new()
	log_style.bg_color = Color(0.02, 0.05, 0.10, 0.55)
	log_style.set_corner_radius_all(10)
	log_style.set_content_margin_all(10)
	log_panel.add_theme_stylebox_override("panel", log_style)
	add_child(log_panel)
	log_box = RichTextLabel.new()
	log_box.bbcode_enabled = true
	log_box.scroll_following = true
	log_box.add_theme_font_size_override("normal_font_size", 15)
	log_panel.add_child(log_box)

	# --- 手牌区（扇形） ---
	hand_area = Control.new()
	hand_area.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(hand_area)

	# --- 抽牌堆（左下角卡背 + 剩余张数，抽牌从这里飞进手牌） ---
	draw_pile = Control.new()
	draw_pile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw_pile.z_index = 2
	add_child(draw_pile)
	var pile_art := TextureRect.new()
	pile_art.texture = load(CARD_ART)
	pile_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pile_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var pile_size := Vector2(92.0, 120.0)
	pile_art.size = pile_size
	pile_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pile_mat := ShaderMaterial.new()
	pile_mat.shader = load(CARD_SHADER)
	pile_mat.set_shader_parameter("card_size", pile_size)
	pile_mat.set_shader_parameter("radius", 10.0)
	pile_art.material = pile_mat
	draw_pile.add_child(pile_art)
	var pile_shade := Panel.new()
	var pile_sb := StyleBoxFlat.new()
	pile_sb.bg_color = Color(0.02, 0.03, 0.08, 0.45)
	pile_sb.set_corner_radius_all(8)
	pile_shade.add_theme_stylebox_override("panel", pile_sb)
	pile_shade.position = Vector2(5, 5)
	pile_shade.size = pile_size - Vector2(10, 10)
	pile_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw_pile.add_child(pile_shade)
	draw_pile_label = Label.new()
	draw_pile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	draw_pile_label.add_theme_font_size_override("font_size", 20)
	draw_pile_label.add_theme_color_override("font_color", Color("#ffe9b0"))
	draw_pile_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	draw_pile_label.add_theme_constant_override("outline_size", 6)
	draw_pile_label.position = Vector2(0, pile_size.y - 40.0)
	draw_pile_label.size = Vector2(pile_size.x, 32.0)
	draw_pile_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw_pile.add_child(draw_pile_label)

	# --- 底部操作栏 ---
	bottom_bar = HBoxContainer.new()
	bottom_bar.add_theme_constant_override("separation", 14)
	add_child(bottom_bar)
	energy_label = Label.new()
	energy_label.add_theme_font_size_override("font_size", 22)
	energy_label.add_theme_color_override("font_color", Color("#ffd479"))
	bottom_bar.add_child(energy_label)
	turn_label = Label.new()
	turn_label.add_theme_font_size_override("font_size", 15)
	turn_label.add_theme_color_override("font_color", Color("#9fb3c8"))
	bottom_bar.add_child(turn_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_bar.add_child(spacer)
	var hint := Label.new()
	hint.text = "F11 全屏 · M 静音"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color("#5c7896"))
	bottom_bar.add_child(hint)
	restart_button = Button.new()
	restart_button.text = "重新开始"
	restart_button.custom_minimum_size = Vector2(130, 46)
	restart_button.visible = false
	restart_button.pressed.connect(_on_restart)
	bottom_bar.add_child(restart_button)
	end_turn_button = Button.new()
	end_turn_button.text = "结束回合"
	end_turn_button.custom_minimum_size = Vector2(150, 46)
	end_turn_button.pressed.connect(_on_end_turn)
	bottom_bar.add_child(end_turn_button)

	# --- 结果 ---
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 34)
	result_label.visible = false
	add_child(result_label)

	# --- 卡牌效果浮窗（最上层，压住手牌） ---
	card_tip = PanelContainer.new()
	card_tip.visible = false
	card_tip.z_index = 1000
	card_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tip_style := StyleBoxFlat.new()
	tip_style.bg_color = Color(0.03, 0.06, 0.12, 0.97)
	tip_style.border_color = Color(0.72, 0.60, 0.35, 1.0)
	tip_style.set_border_width_all(2)
	tip_style.set_corner_radius_all(8)
	tip_style.set_content_margin_all(12)
	card_tip.add_theme_stylebox_override("panel", tip_style)
	add_child(card_tip)
	card_tip_label = RichTextLabel.new()
	card_tip_label.bbcode_enabled = true
	card_tip_label.fit_content = true
	card_tip_label.scroll_active = false
	card_tip_label.custom_minimum_size = Vector2(380, 0)
	card_tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_tip.add_child(card_tip_label)

	# --- 伤害数字所在的特效层（压在手牌之上、浮窗之下） ---
	fx_layer = Control.new()
	fx_layer.z_index = 900
	fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx_layer)


# ---------------------------------------------------------------- 布局

func _layout_stage() -> void:
	if bg == null or player_pic == null:
		return
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return

	# 背景按 cover 放大；让草坪线落在指定屏幕高度，人物脚底对齐它
	var tex := bg.texture
	if tex == null:
		return
	var img_size := tex.get_size()
	var scale := maxf(w / img_size.x, h / img_size.y) * BG_ZOOM
	bg.size = img_size * scale
	var grass_target := h * GRASS_SCREEN_RATIO
	bg.position = Vector2((w - bg.size.x) * 0.5, grass_target - bg.size.y * GRASS_RATIO)
	var grass_y := grass_target
	_grass_y = grass_y

	# 角色：脚底落在草坪线上
	player_pic.size = CHAR_SIZE
	player_pic.position = Vector2(w * 0.24 - CHAR_SIZE.x * 0.5, grass_y - CHAR_SIZE.y)
	enemy_pic.size = CHAR_SIZE
	enemy_pic.position = Vector2(w * 0.76 - CHAR_SIZE.x * 0.5, grass_y - CHAR_SIZE.y)
	enemy_pic.pivot_offset = Vector2(CHAR_SIZE.x * 0.5, CHAR_SIZE.y)
	_enemy_rest_pos = enemy_pic.position
	# 初始化阶段姿势 tween 可能把敌人拉到 (0,0)，这里强制归位
	if _pose_tween != null and _pose_tween.is_valid():
		_pose_tween.kill()
	enemy_pic.position = _enemy_rest_pos
	enemy_pic.scale = Vector2.ONE

	# 头顶信息
	player_head.size = Vector2(CHAR_SIZE.x + 160.0, 62.0)
	player_head.position = Vector2(
		player_pic.position.x + CHAR_SIZE.x * 0.5 - player_head.size.x * 0.5,
		player_pic.position.y - 60.0
	)
	enemy_head.size = Vector2(CHAR_SIZE.x + 220.0, 92.0)
	enemy_head.position = Vector2(
		enemy_pic.position.x + CHAR_SIZE.x * 0.5 - enemy_head.size.x * 0.5,
		enemy_pic.position.y - 90.0
	)

	# 日志面板（顶部居中）
	log_panel.position = Vector2(w * 0.5 - 330.0, 14.0)
	log_panel.size = Vector2(660.0, 132.0)

	# 手牌区：从草坪线下方开始，把底栏让出来
	hand_area.position = Vector2(0.0, grass_y + 6.0)
	hand_area.size = Vector2(w, maxf(120.0, h - grass_y - 6.0))
	draw_pile.position = Vector2(18.0, h - 224.0)
	draw_pile.size = Vector2(92.0, 120.0)
	bottom_bar.position = Vector2(24.0, h - 56.0)
	bottom_bar.size = Vector2(w - 48.0, 46.0)

	result_label.size = Vector2(w, 60.0)
	result_label.position = Vector2(0.0, h * 0.38)

	_layout_hand()


func _layout_hand() -> void:
	if hand_area == null:
		return
	var n := _card_nodes.size()
	if n == 0:
		return
	var slots := _hand_slots(n)
	for i in n:
		var node := _card_nodes[i]
		if not is_instance_valid(node):
			continue
		var slot: Dictionary = slots[i]
		node.position = slot["pos"]
		node.rotation_degrees = float(slot["rot"])
		_card_base[node] = slot

	# 抽牌动画：这次新抽到的牌从抽牌堆飞入槽位，其余牌直接就位
	if _cards_entry and n > 0:
		_cards_entry = false
		var draw_set := {}
		for idx in _pending_draw:
			draw_set[idx] = true
		_pending_draw.clear()
		var order := 0
		for i in n:
			var card_node := _card_nodes[i]
			if not is_instance_valid(card_node):
				continue
			var base: Dictionary = _card_base.get(card_node, {})
			if base.is_empty():
				continue
			if draw_set.has(i):
				_animate_draw_in(card_node, base, order)
				order += 1
			else:
				card_node.modulate.a = 1.0
		if order > 0:
			_draw_animating = true
			var wait := DRAW_FLY_TIME + float(order - 1) * DRAW_STAGGER + 0.06
			get_tree().create_timer(wait).timeout.connect(func(): _draw_animating = false)
	_update_hand_hover.call_deferred()


## 对比上次手牌，找出这次新抽到的牌的索引（多重集合差集）
func _compute_draw_indices() -> Array[int]:
	var old_counts := {}
	for id in _last_hand:
		old_counts[id] = int(old_counts.get(id, 0)) + 1
	var result: Array[int] = []
	for i in state.hand.size():
		var id := state.hand[i]
		if int(old_counts.get(id, 0)) > 0:
			old_counts[id] = int(old_counts[id]) - 1
		else:
			result.append(i)
	return result


## 单张牌抽牌动画：抽牌堆小卡背 → 弧线放大落位（BACK 过冲）
func _animate_draw_in(node: Button, slot: Dictionary, order: int) -> void:
	var target: Vector2 = slot["pos"]
	var target_rot := float(slot["rot"])
	var start_global := draw_pile.get_global_rect().get_center() - CARD_SIZE * 0.5
	var start_local := hand_area.get_global_transform().affine_inverse() * start_global
	_kill_card_tween(node)
	node.position = start_local
	node.scale = Vector2(0.42, 0.42)
	node.rotation_degrees = -24.0
	node.modulate.a = 1.0
	node.z_index = 60
	var delay := float(order) * DRAW_STAGGER
	var t := node.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "position", target, DRAW_FLY_TIME).set_delay(delay)
	t.tween_property(node, "scale", Vector2.ONE, DRAW_FLY_TIME * 0.85).set_delay(delay)
	t.tween_property(node, "rotation_degrees", target_rot, DRAW_FLY_TIME * 0.85).set_delay(delay)
	t.chain().tween_callback(func():
		if is_instance_valid(node):
			node.z_index = 0
	)
	_card_tweens[node] = t


## 计算 count 张手牌的扇形位置（不含动画），供布局与出牌后的收拢复用
func _hand_slots(count: int) -> Array:
	var w := hand_area.size.x
	if w < 100.0:
		w = 1280.0
	var h := hand_area.size.y
	if h < 100.0:
		h = HAND_AREA_HEIGHT
	var spacing := minf(116.0, (w - CARD_SIZE.x) / maxf(1.0, float(count)))
	var total := spacing * float(count - 1)
	var start_x := (w - total - CARD_SIZE.x) * 0.5
	var out: Array = []
	for i in count:
		var t := 0.0 if count == 1 else (float(i) / float(count - 1)) * 2.0 - 1.0
		out.append({
			"pos": Vector2(start_x + spacing * float(i), h - CARD_SIZE.y - 46.0 + absf(t) * 14.0),
			"rot": t * FAN_SPREAD_DEG,
		})
	return out


## 打出一张牌后，把剩下的牌平滑收拢（不重建节点）
func _reflow_without(index: int) -> void:
	var remaining: Array[Button] = []
	for i in _card_nodes.size():
		if i == index:
			continue
		remaining.append(_card_nodes[i])
	var slots := _hand_slots(remaining.size())
	for k in remaining.size():
		var node := remaining[k]
		if not is_instance_valid(node):
			continue
		var slot: Dictionary = slots[k]
		_kill_card_tween(node)
		var t := node.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(node, "position", slot["pos"], 0.18)
		t.tween_property(node, "rotation_degrees", float(slot["rot"]), 0.18)
		t.tween_property(node, "scale", Vector2.ONE, 0.18)
		_card_tweens[node] = t


# ---------------------------------------------------------------- 数据 → UI

func _start_battle() -> void:
	_busy = false
	_last_hand.clear()
	log_box.clear()
	result_label.visible = false
	restart_button.visible = false
	card_tip.visible = false
	_set_enemy_pose(false)
	state.start_battle()
	_refresh()


func _refresh() -> void:
	if _refresh_in_frame:
		# 同一帧的重复刷新：只更新操作按钮状态，保留待抽列表
		end_turn_button.disabled = state.finished or _busy
		return
	_refresh_in_frame = true
	_reset_refresh_flag.call_deferred()
	player_head.text = "鲸娘\n生命 %d / %d　格挡 %d\n%s" % [
		state.player_hp, state.PLAYER_MAX_HP, state.player_block, state.player_status_text()
	]
	var it := state.intent()
	var intent_value := int(it.get("value", 0))
	var intent_text := "意图：%s（格挡 +%d）" % [str(it.get("name", "")), intent_value]
	if str(it.get("type", "")) == "attack":
		intent_text = "意图：%s（%d 伤害）" % [str(it.get("name", "")), intent_value]
	enemy_head.text = "奶龙\n生命 %d / %d　格挡 %d\n%s\n%s" % [
		state.enemy_hp, state.ENEMY_MAX_HP, state.enemy_block,
		state.enemy_status_text(), intent_text
	]
	energy_label.text = "大米饭 %d / %d" % [state.energy, state.MAX_ENERGY]
	turn_label.text = "第 %d 回合 · 抽牌堆 %d · 弃牌堆 %d" % [
		state.turn, state.draw_pile.size(), state.discard_pile.size()
	]
	end_turn_button.disabled = state.finished or _busy
	if draw_pile_label != null:
		draw_pile_label.text = "×%d" % state.draw_pile.size()

	# 先对比旧手牌，找出这次新抽到的牌（用于抽牌动画）
	_pending_draw = _compute_draw_indices()
	_last_hand = state.hand.duplicate()

	for node in _card_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_card_nodes.clear()
	_card_base.clear()
	_card_tweens.clear()
	_hover_node = null
	_cards_entry = true
	card_tip.visible = false

	for i in state.hand.size():
		var node := _make_card(i)
		hand_area.add_child(node)
		_card_nodes.append(node)
	_layout_hand.call_deferred()


func _reset_refresh_flag() -> void:
	_refresh_in_frame = false


func _make_card(index: int) -> Button:
	var id: String = state.hand[index]
	var node := _build_card_visual(id)
	if not state.can_play(index):
		node.modulate = Color(0.55, 0.55, 0.62, 1.0)
	node.gui_input.connect(_on_card_gui_input.bind(index, node))
	return node


## 纯视觉卡牌（无信号），出牌飞行动画复用它
func _build_card_visual(id: String) -> Button:
	var card := CardDB.get_card(id)
	var node := Button.new()
	node.flat = true
	node.size = CARD_SIZE
	node.custom_minimum_size = CARD_SIZE
	node.pivot_offset = Vector2(CARD_SIZE.x * 0.5, CARD_SIZE.y)
	node.focus_mode = Control.FOCUS_NONE
	node.mouse_filter = Control.MOUSE_FILTER_STOP

	# 柔和投影：让卡牌"浮"在夜景上
	var shadow := Panel.new()
	var shadow_sb := StyleBoxFlat.new()
	shadow_sb.bg_color = Color(0, 0, 0, 0.28)
	shadow_sb.set_corner_radius_all(14)
	shadow_sb.shadow_color = Color(0, 0, 0, 0.45)
	shadow_sb.shadow_size = 8
	shadow_sb.shadow_offset = Vector2(0, 5)
	shadow.add_theme_stylebox_override("panel", shadow_sb)
	shadow.position = Vector2(-2, -1)
	shadow.size = CARD_SIZE + Vector2(4, 8)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(shadow)

	var art := TextureRect.new()
	art.texture = load(CARD_ART)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.size = CARD_SIZE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 圆角遮罩（着色器按 UV 裁出圆角，卡面更"光滑"）
	var card_mat := ShaderMaterial.new()
	card_mat.shader = load(CARD_SHADER)
	card_mat.set_shader_parameter("card_size", CARD_SIZE)
	card_mat.set_shader_parameter("radius", 12.0)
	art.material = card_mat
	node.add_child(art)

	# 圆角半透明底衬，保证文字可读
	var shade := Panel.new()
	var shade_sb := StyleBoxFlat.new()
	shade_sb.bg_color = Color(0.02, 0.03, 0.08, 0.55)
	shade_sb.set_corner_radius_all(9)
	shade.add_theme_stylebox_override("panel", shade_sb)
	shade.position = Vector2(7, 7)
	shade.size = CARD_SIZE - Vector2(14, 14)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(shade)

	var cost := int(card.get("cost", 0))
	var cost_label := Label.new()
	cost_label.text = str(cost)
	cost_label.add_theme_font_size_override("font_size", 24)
	cost_label.add_theme_color_override("font_color", Color("#ffd479"))
	cost_label.position = Vector2(10, 4)
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(cost_label)

	var name_label := Label.new()
	name_label.text = str(card.get("name", id))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color("#ffe9b0"))
	name_label.position = Vector2(0, 40)
	name_label.size = Vector2(CARD_SIZE.x, 22)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = str(card.get("desc", ""))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color("#e8eef7"))
	desc_label.position = Vector2(9, 108)
	desc_label.size = Vector2(CARD_SIZE.x - 18, 76)
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(desc_label)

	# 金色描边光晕（悬停时淡入，炉石那种选中高亮感）
	var glow := Panel.new()
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color(0, 0, 0, 0)
	gsb.border_color = Color(1.0, 0.86, 0.45, 1.0)
	gsb.set_border_width_all(3)
	gsb.set_corner_radius_all(8)
	glow.add_theme_stylebox_override("panel", gsb)
	glow.position = Vector2(-5, -5)
	glow.size = CARD_SIZE + Vector2(10, 10)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.modulate.a = 0.0
	node.add_child(glow)
	node.set_meta("glow", glow)
	return node


# ---------------------------------------------------------------- 手牌交互

func _on_card_hover(index: int, node: Button) -> void:
	if _busy or _dragging or not is_instance_valid(node):
		return
	if _hover_node == node:
		return
	# 切换悬停：先把上一张恢复，否则被打断的 tween 会把它卡在半空
	if _hover_node != null and is_instance_valid(_hover_node):
		_restore_card(_hover_node, 0.16)
	_hover_node = node
	card_tip.visible = false
	var base: Dictionary = _card_base.get(node, {})
	if base.is_empty():
		return
	node.z_index = 120
	_kill_card_tween(node)
	# 弹性抬起，但**保留扇形角度**：不拉直就不会有"卡在 0°"的状态
	var target: Vector2 = (base["pos"] as Vector2) + Vector2(0.0, -HOVER_LIFT)
	var t := node.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "position", target, HOVER_TIME)
	t.tween_property(node, "scale", Vector2(HOVER_SCALE, HOVER_SCALE), HOVER_TIME)
	_card_tweens[node] = t
	_fade_glow(node, 1.0, 0.14)
	_push_neighbors(index, node)
	_show_card_tip(index, node)


func _on_card_unhover(_index: int, node: Button) -> void:
	if _dragging or not is_instance_valid(node):
		return
	if _hover_node == node:
		_hover_node = null
	_fade_glow(node, 0.0, 0.16)
	_restore_neighbors()
	card_tip.visible = false


## 根据光标在手牌区的水平位置选最近的牌作为悬停目标
func _update_hand_hover() -> void:
	if _busy or _dragging or _draw_animating or hand_area == null:
		return
	var mouse := hand_area.get_local_mouse_position()
	var zone := Rect2(
		Vector2(-60.0, -HOVER_LIFT - 70.0),
		hand_area.size + Vector2(120.0, HOVER_LIFT + 70.0)
	)
	if not zone.has_point(mouse):
		if _hover_node != null and is_instance_valid(_hover_node):
			_hover_node = null
			_restore_neighbors()
			card_tip.visible = false
		return
	var best := -1
	var best_dist := INF
	for i in _card_nodes.size():
		var node := _card_nodes[i]
		if not is_instance_valid(node):
			continue
		var base: Dictionary = _card_base.get(node, {})
		if base.is_empty():
			continue
		var center: Vector2 = (base["pos"] as Vector2) + CARD_SIZE * 0.5
		var d := absf(mouse.x - center.x)
		if d < best_dist:
			best_dist = d
			best = i
	if best < 0:
		return
	var target := _card_nodes[best]
	if target != _hover_node:
		_on_card_hover(best, target)


## 把一张牌恢复到手牌槽位（位置 / 旋转 / 缩放都归位）
func _restore_card(node: Button, time: float) -> void:
	if not is_instance_valid(node):
		return
	var base: Dictionary = _card_base.get(node, {})
	if base.is_empty():
		return
	node.z_index = 0
	_kill_card_tween(node)
	var t := node.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "position", base["pos"], time)
	t.tween_property(node, "rotation_degrees", float(base["rot"]), time)
	t.tween_property(node, "scale", Vector2.ONE, time)
	_card_tweens[node] = t


# ---------------------------------------------------------------- 拖拽出牌

func _on_card_gui_input(event: InputEvent, index: int, node: Button) -> void:
	if _busy:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(index, node)
			node.accept_event()
		else:
			_end_drag()
			node.accept_event()


func _begin_drag(index: int, node: Button) -> void:
	if not is_instance_valid(node):
		return
	if index < 0 or index >= state.hand.size():
		return
	if not state.can_play(index):
		return
	_dragging = true
	_drag_index = index
	_drag_node = node
	_drag_moved = false
	_hover_node = null
	# 记录抓取点与牌左上角的偏移，拖动时牌不会"跳"
	_drag_offset = node.position - hand_area.get_local_mouse_position()
	node.z_index = 500
	_kill_card_tween(node)
	_fade_glow(node, 1.0, 0.1)
	card_tip.visible = false
	var t := node.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", Vector2(1.1, 1.1), 0.12)
	t.tween_property(node, "rotation_degrees", 0.0, 0.12)
	_card_tweens[node] = t


func _update_drag() -> void:
	if _drag_node == null or not is_instance_valid(_drag_node):
		return
	var target := hand_area.get_local_mouse_position() + _drag_offset
	if (target - _drag_node.position).length() > 3.0:
		_drag_moved = true
	_drag_node.position = target


func _end_drag() -> void:
	if not _dragging:
		return
	var node := _drag_node
	var idx := _drag_index
	_dragging = false
	_drag_node = null
	_drag_index = -1
	if node == null or not is_instance_valid(node):
		return
	node.z_index = 0
	_fade_glow(node, 0.0, 0.12)
	# 拖到草坪线以上 = 打进战场；否则弹回手牌
	var dropped_in_field := node.get_global_rect().get_center().y < _grass_y - 40.0
	if not _drag_moved or dropped_in_field:
		_on_card_pressed(idx)
		return
	var base: Dictionary = _card_base.get(node, {})
	if base.is_empty():
		return
	_kill_card_tween(node)
	var t := node.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "position", base["pos"], 0.24)
	t.tween_property(node, "rotation_degrees", float(base["rot"]), 0.24)
	t.tween_property(node, "scale", Vector2.ONE, 0.24)
	_card_tweens[node] = t


## 悬停时把左右的牌往外推开（越远推得越少），手牌有"被拨开"的生动感
func _push_neighbors(hover_index: int, hover_node: Button) -> void:
	for j in _card_nodes.size():
		var other := _card_nodes[j]
		if other == hover_node or not is_instance_valid(other):
			continue
		var base: Dictionary = _card_base.get(other, {})
		if base.is_empty():
			continue
		var dist := absi(j - hover_index)
		var push := NEIGHBOR_PUSH * clampf(1.0 - float(dist) / 3.0, 0.0, 1.0)
		var dir := -1.0 if j < hover_index else 1.0
		_kill_card_tween(other)
		var t := other.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(other, "position", (base["pos"] as Vector2) + Vector2(dir * push, 0.0), 0.18)
		_card_tweens[other] = t


func _restore_neighbors() -> void:
	for other in _card_nodes:
		_restore_card(other, 0.18)


func _fade_glow(node: Button, target_alpha: float, time: float) -> void:
	var glow: Variant = node.get_meta("glow", null)
	if glow is Control and is_instance_valid(glow):
		var gt := (glow as Control).create_tween()
		gt.tween_property(glow, "modulate:a", target_alpha, time)


func _kill_card_tween(node: Node) -> void:
	if _card_tweens.has(node):
		var t: Tween = _card_tweens[node]
		if t != null and t.is_valid():
			t.kill()
		_card_tweens.erase(node)


func _show_card_tip(index: int, node: Button) -> void:
	if index < 0 or index >= state.hand.size():
		return
	var card := CardDB.get_card(state.hand[index])
	if card.is_empty():
		return
	card_tip_label.text = "[b][color=#ffe9b0]%s[/color][/b]　[color=#ffd479]%d 费[/color]\n%s" % [
		str(card.get("name", "")), int(card.get("cost", 0)), str(card.get("desc", ""))
	]
	# 先让文本完成排版，再按实际内容高度固定面板尺寸，避免文字被裁
	card_tip_label.custom_minimum_size = Vector2(380, 0)
	card_tip.size = Vector2(404, 0)
	card_tip_label.size = Vector2(380, 0)
	var content_h := maxf(card_tip_label.get_content_height(), 48.0)
	card_tip_label.custom_minimum_size = Vector2(380, content_h)
	card_tip_label.size = Vector2(380, content_h)
	card_tip.size = Vector2(404, content_h + 24.0)
	card_tip.visible = true

	var rect := node.get_global_rect()
	var center := Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y - 10.0)
	var local := get_global_transform().affine_inverse() * center
	var max_x := maxf(12.0, size.x - card_tip.size.x - 12.0)
	var x := clampf(local.x - card_tip.size.x * 0.5, 12.0, max_x)
	var y := clampf(local.y - card_tip.size.y, 10.0, size.y - card_tip.size.y - 10.0)
	card_tip.position = Vector2(x, y)


# ---------------------------------------------------------------- 交互

func _on_card_pressed(index: int) -> void:
	if _busy:
		return
	if index < 0 or index >= state.hand.size():
		return
	if not state.can_play(index):
		return
	_busy = true
	_dragging = false
	card_tip.visible = false

	var id: String = state.hand[index]
	var start_rect := Rect2(Vector2.ZERO, CARD_SIZE)
	var node: Button = null
	if index < _card_nodes.size():
		node = _card_nodes[index]
	if node != null and is_instance_valid(node):
		start_rect = node.get_global_rect()
		node.visible = false
	_layout_hand()
	_reflow_without(index)

	# 先飞到屏幕中央烧掉，再结算效果
	await _play_card_burn(id, start_rect)
	_sfx("seekseek")
	state.play_card(index)
	_busy = false
	_refresh()


## 出牌动画：过冲起飞 → 空中回正 → 中央白闪 → 焚烧（参考炉石打出手感）
func _play_card_burn(id: String, start_rect: Rect2) -> void:
	var visual := _build_card_visual(id)
	visual.size = CARD_SIZE
	visual.pivot_offset = CARD_SIZE * 0.5
	visual.z_index = 950
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(visual)

	var start_local := get_global_transform().affine_inverse() * start_rect.position
	visual.position = start_local
	visual.scale = Vector2(0.96, 0.96)
	visual.rotation_degrees = 0.0

	var target_pos := Vector2(size.x * 0.5 - CARD_SIZE.x * 0.5, size.y * 0.36 - CARD_SIZE.y * 0.5)

	# 1) 起飞：TRANS_BACK 带一点过冲，飞向中央时略有回弹
	var fly := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	fly.tween_property(visual, "position", target_pos, 0.34)
	fly.tween_property(visual, "scale", Vector2(1.5, 1.5), 0.34)
	fly.tween_property(visual, "rotation_degrees", 5.0, 0.34)
	await fly.finished

	# 2) 空中回正 + 收势
	var settle := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	settle.tween_property(visual, "rotation_degrees", 0.0, 0.12)
	settle.tween_property(visual, "scale", Vector2(1.56, 1.56), 0.12)
	await settle.finished

	# 3) 白闪：打出瞬间"一亮"
	var flash := create_tween()
	flash.tween_property(visual, "modulate", Color(2.0, 1.8, 1.3, 1.0), 0.07)
	flash.tween_property(visual, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.07)
	await flash.finished

	# 4) 焚烧：变橙红、放大、上飘、淡出
	var burn := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	burn.tween_property(visual, "modulate", Color(2.6, 0.6, 0.1, 0.0), 0.45)
	burn.tween_property(visual, "scale", Vector2(1.95, 1.95), 0.45)
	burn.tween_property(visual, "position", target_pos + Vector2(0, -46), 0.45)
	await burn.finished

	if is_instance_valid(visual):
		visual.queue_free()


func _on_end_turn() -> void:
	if state.finished or _busy:
		return
	_busy = true
	_refresh()

	_set_enemy_pose(true)
	await get_tree().create_timer(0.45).timeout

	# 奶龙行动音效（大笑）；掉血时 damaged 信号播 hurt
	_sfx("laugh")
	state.enemy_turn()

	await get_tree().create_timer(0.85).timeout
	_set_enemy_pose(false)
	await get_tree().create_timer(0.2).timeout

	if not state.finished:
		state.begin_player_turn()
	_busy = false
	_refresh()


func _set_enemy_pose(action: bool) -> void:
	if enemy_pic == null:
		return
	enemy_pic.texture = load(ENEMY_ACTION_TEXTURE if action else ENEMY_IDLE_TEXTURE)
	var target_scale := Vector2(1.06, 1.06) if action else Vector2.ONE
	var target_pos := _enemy_rest_pos + (Vector2(-8, -6) if action else Vector2.ZERO)
	var laid_out := _enemy_rest_pos != Vector2.ZERO
	if _pose_tween != null and _pose_tween.is_valid():
		_pose_tween.kill()
	_pose_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(enemy_pic, "scale", target_scale, POSE_TIME)
	if laid_out:
		_pose_tween.tween_property(enemy_pic, "position", target_pos, POSE_TIME)


func _on_restart() -> void:
	_start_battle()


func _on_log(text: String) -> void:
	log_box.append_text(text + "\n")


func _on_battle_over(won: bool) -> void:
	_sfx("victory" if won else "defeat")
	result_label.visible = true
	restart_button.visible = true
	if won:
		result_label.text = "胜利！奶龙被你打倒了"
		result_label.add_theme_color_override("font_color", Color("#9dffa0"))
	else:
		result_label.text = "败北……按「重新开始」再来一次"
		result_label.add_theme_color_override("font_color", Color("#ff9d9d"))


func _sfx(sound: String) -> void:
	var player := get_node_or_null("/root/Sfx")
	if player != null and player.has_method("play"):
		player.play(sound)


# ---------------------------------------------------------------- 受击特效

## 受击：变红 + 掉血数字 + hurt 音效
func _on_damaged(target: String, amount: int) -> void:
	_sfx("hurt")
	var pic: TextureRect = enemy_pic if target == "enemy" else player_pic
	_flash(pic)
	_spawn_damage_number(pic, amount)


## 受伤变红：整体闪红再缓动恢复
func _flash(pic: TextureRect) -> void:
	if pic == null:
		return
	pic.modulate = Color(2.4, 0.35, 0.35, 1.0)
	var t := create_tween()
	t.tween_property(pic, "modulate", Color(1, 1, 1, 1), 0.24) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 掉血数字：从角色胸口上浮并淡出
func _spawn_damage_number(pic: TextureRect, amount: int) -> void:
	if fx_layer == null or pic == null or amount <= 0:
		return
	var label := Label.new()
	label.text = "-%d" % amount
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", Color("#ff5b5b"))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(140, 54)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(label)

	var center := pic.get_global_rect().get_center()
	var local := fx_layer.get_global_transform().affine_inverse() * center
	label.position = local - Vector2(70, 16)

	var rise := create_tween().set_parallel(true)
	rise.tween_property(label, "position:y", label.position.y - 84, 0.8) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rise.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.2)
	var cleanup := create_tween()
	cleanup.tween_interval(0.9)
	cleanup.tween_callback(label.queue_free)


# ---------------------------------------------------------------- 全屏

func _input(event: InputEvent) -> void:
	# 拖拽中：鼠标移动跟手，松开决定打出还是弹回
	if _dragging:
		if event is InputEventMouseMotion:
			_update_drag()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_end_drag()
			return
	# 悬停判定按"手牌区里离光标最近的牌"来算，不依赖卡片的 enter/exit，
	# 这样卡片抬起离开光标下方也不会丢失悬停（否则会 enter/exit 抖动）。
	if event is InputEventMouseMotion and not _dragging:
		_update_hand_hover()
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F11:
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_M:
		var music := get_node_or_null("/root/Music")
		if music != null and music.has_method("toggle_mute"):
			music.toggle_mute()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and _is_fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		get_viewport().set_input_as_handled()


func _toggle_fullscreen() -> void:
	if _is_fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return (
		mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)
