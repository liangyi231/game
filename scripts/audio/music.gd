extends Node
## 背景音乐（autoload: Music）。循环播放 res://audio/music/ 下的曲子。
##
## 命名约定：放 `audio/music/bgm.ogg`（或 .wav/.mp3）就会被自动循环播放；
## 想换曲就覆盖同名文件，或用 `una_mas_funk_2.ogg` 命名（优先读取 bgm.*）。
## 没有文件时静默，不影响游戏；M 键切换静音，F11 全屏不受影响。

const MUSIC_DIR := "res://audio/music/"
const TRACK_NAMES := ["bgm", "una_mas_funk_2"]
const DEFAULT_VOLUME_DB := -12.0

var player: AudioStreamPlayer
var muted := false


func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.bus = "Master"
	add_child(player)
	player.finished.connect(_on_finished)
	play_bgm()


func play_bgm() -> void:
	var stream := _load_stream()
	if stream == null:
		return
	_enable_loop(stream)
	player.stream = stream
	player.volume_db = -80.0 if muted else DEFAULT_VOLUME_DB
	player.play()


## 循环：OGG/WAV 都显式开启；再留一个 finished 兜底（某些导入设置会关掉循环）
func _enable_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)


func _on_finished() -> void:
	if not muted:
		player.play()


func toggle_mute() -> bool:
	muted = not muted
	player.volume_db = -80.0 if muted else DEFAULT_VOLUME_DB
	return muted


func _load_stream() -> AudioStream:
	for track in TRACK_NAMES:
		for ext in ["ogg", "wav", "mp3"]:
			var path: String = MUSIC_DIR + track + "." + ext
			if ResourceLoader.exists(path):
				return load(path) as AudioStream
	return null
