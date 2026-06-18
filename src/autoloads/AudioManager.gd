extends Node

const _SILENCE_LINEAR_THRESHOLD := 0.0005  # below ~-66 dB, treat as full mute (-80 dB)

@onready var bgm_player: AudioStreamPlayer = $BGMPlayer
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer
@onready var voice_player: AudioStreamPlayer = $VoicePlayer

var _bgm_lib: Dictionary = {}
var _sfx_lib: Dictionary = {}
var _current_bgm: String = ""

func _ready() -> void:
	_bgm_lib = JsonLoader.load_json("res://data/audio_bgm.json")
	_sfx_lib = JsonLoader.load_json("res://data/audio_sfx.json")
	_ensure_buses()
	bgm_player.bus = "BGM"
	sfx_player.bus = "SFX"
	voice_player.bus = "SFX"

## target_db：本曲的目標音量（雨聲偏大時可調低）。
## fade_in：新曲是否從靜音淡入（醒來接場景用）。
func switch_bgm(id: String, fade_time: float = 0.5, target_db: float = 0.0, fade_in: bool = false) -> void:
	if id == _current_bgm:
		return
	var path: String = _bgm_lib.get(id, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	if bgm_player.stream and bgm_player.playing:
		var tw := create_tween()
		tw.tween_property(bgm_player, "volume_db", -60.0, fade_time)
		await tw.finished
	var stream := load(path)
	# Force BGM to loop regardless of per-file import settings (.ogg/.mp3
	# default loop varies; this guarantees seamless looping in-game).
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamMP3:
		stream.loop = true
	bgm_player.stream = stream
	if fade_in:
		bgm_player.volume_db = -60.0
		bgm_player.play()
		var tw2 := create_tween()
		tw2.tween_property(bgm_player, "volume_db", target_db, maxf(0.05, fade_time))
	else:
		bgm_player.volume_db = target_db
		bgm_player.play()
	_current_bgm = id

## 不換曲，只把目前 BGM 音量淡到 target_db（暈倒淡出／醒來淡入用）。
func fade_bgm_to(target_db: float, time: float = 1.0) -> void:
	if not bgm_player.playing:
		return
	var tw := create_tween()
	tw.tween_property(bgm_player, "volume_db", target_db, maxf(0.05, time))

func play_sfx(id: String) -> void:
	var path: String = _sfx_lib.get(id, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	sfx_player.stream = load(path)
	sfx_player.play()

## 語音／人聲：走獨立聲道，與 SFX 同時播放不互相切斷（過場台詞配音用）。
## 與 SFX 共用 audio_sfx.json 的查表。
func play_voice(id: String) -> void:
	var path: String = _sfx_lib.get(id, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	voice_player.stream = load(path)
	voice_player.play()

## 執行期建立 BGM/SFX 兩條子匯流排（送往 Master），避免依賴 .tres bus layout。
func _ensure_buses() -> void:
	for bus_name in ["BGM", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")

## 設某 bus 音量（linear 0~1）。0 視為靜音（-80dB）。
func set_bus_volume_linear(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	linear = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(linear) if linear > _SILENCE_LINEAR_THRESHOLD else -80.0)

## 讀某 bus 目前音量（linear 0~1）。bus 不存在回 1.0。
func get_bus_volume_linear(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return 1.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(idx)), 0.0, 1.0)
