extends Node
## 音效播放器（autoload: Sfx）。
##
## 你只需要把音效文件丢进 res://audio/sfx/ 目录，文件名对上就会响，
## 缺文件时静默跳过（不会报错、不会影响战斗逻辑）。
##
## 约定文件名（.ogg 优先，其次 .wav）：
##   click.ogg         按钮/出牌点击
##   attack.ogg        玩家攻击牌
##   block.ogg         玩家格挡牌
##   heal.ogg          治疗牌
##   enemy_attack.ogg  奶龙攻击
##   enemy_block.ogg   奶龙格挡
##   victory.ogg       胜利
##   defeat.ogg        失败
##   draw.ogg          抽牌（预留）

const SFX_DIR := "res://audio/sfx/"
const VOICES := 8

var enabled := true
var volume_db := -6.0
## 0.0 ~ 1.0 的用户音效音量（1.0 = volume_db）
var volume_linear := 1.0

var _players: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}


## 设置音效音量（0~1），设置面板用
func set_volume_linear(value: float) -> void:
	volume_linear = clampf(value, 0.0, 1.0)


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)


## 播放一个音效。name 不带扩展名。找不到文件就直接返回。
func play(name: String, volume_offset_db := 0.0) -> void:
	if not enabled or name.is_empty() or volume_linear <= 0.001:
		return
	var stream := _load_stream(name)
	if stream == null:
		return
	var player := _pick_player()
	player.stream = stream
	player.volume_db = volume_db + linear_to_db(volume_linear) + volume_offset_db
	player.play()


func _load_stream(name: String) -> AudioStream:
	if _cache.has(name):
		return _cache[name]
	var stream: AudioStream = null
	for ext in ["ogg", "wav", "mp3"]:
		var path: String = SFX_DIR + name + "." + ext
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStream
			break
	_cache[name] = stream
	return stream


func _pick_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return _players[0]
