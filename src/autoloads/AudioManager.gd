extends Node

@onready var bgm_player: AudioStreamPlayer = $BGMPlayer
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer

var _bgm_lib: Dictionary = {}
var _sfx_lib: Dictionary = {}
var _current_bgm: String = ""

func _ready() -> void:
	_bgm_lib = JsonLoader.load_json("res://data/audio_bgm.json")
	_sfx_lib = JsonLoader.load_json("res://data/audio_sfx.json")

func switch_bgm(id: String, fade_time: float = 0.5) -> void:
	if id == _current_bgm:
		return
	var path: String = _bgm_lib.get(id, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	if bgm_player.stream and bgm_player.playing:
		var tw := create_tween()
		tw.tween_property(bgm_player, "volume_db", -60.0, fade_time)
		await tw.finished
	bgm_player.stream = load(path)
	bgm_player.volume_db = 0.0
	bgm_player.play()
	_current_bgm = id

func play_sfx(id: String) -> void:
	var path: String = _sfx_lib.get(id, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	sfx_player.stream = load(path)
	sfx_player.play()
