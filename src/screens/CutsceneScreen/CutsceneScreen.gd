extends Control
## 過場演出播放器（資料驅動逐幀，GDD §8.6）。
## 幀序列由 Higgsfield 影片經 tools/extract_cutscene.ps1 拆成 12fps PNG，
## 放在 res://assets/cutscenes/<id>/frame_%04d.png。
## 本節點只負責「播放幀 + 發 finished 訊號」，不處理場景路由：
##   - 全螢幕過場：SceneRouter.play_cutscene() 切到本場景、await finished 後再轉場。
##   - 戰鬥內過場：SceneRouter.play_battle_cutscene() 把本場景疊加到戰鬥上、await 後移除。

signal finished

const FPS: float = 12.0
const FRAME_DIR: String = "res://assets/cutscenes/%s/"

## 各過場的音效提示：cutscene_id -> { 幀號(1-based): sfx_id }。
## 僅使用 data/audio_sfx.json 既有的 key；缺檔時 AudioManager 會安全略過。
const SFX_CUES: Dictionary = {
	"break_food":     {36: "vow_break", 42: "karma_surge"},
	"break_lust":     {30: "vow_break", 48: "karma_surge"},
	"break_greed":    {22: "vow_break", 36: "gold_collect"},
	"heat_tathagata": {24: "heat_buildup", 60: "impact_heavy"},
	"heat_diamond":   {18: "heat_buildup", 54: "merit_chime"},
	"heat_thousand":  {20: "heat_buildup", 48: "gold_collect"},
	# ares_phase2 改用整段去背影片抽出的 audio.ogg（見 _play_audio），不另用幀號 SFX 以免疊音。
}

@onready var frame_rect: TextureRect = $FrameRect
@onready var cutscene_audio: AudioStreamPlayer = $CutsceneAudio

var _frames: Array[Texture2D] = []
var _cues: Dictionary = {}
var _idx: int = 0
var _accum: float = 0.0
var _playing: bool = false
var _done: bool = false


func _ready() -> void:
	# 右下角半透明「ESC 跳過」提示（可按 confirm/cancel/ESC 跳過本過場；不擋輸入）。
	var l := Label.new()
	l.text = "ESC 跳過"
	l.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	l.offset_left = -200.0; l.offset_top = -54.0
	l.offset_right = -28.0; l.offset_bottom = -20.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(0.92, 0.89, 0.82))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.add_theme_constant_override("shadow_outline_size", 4)
	l.modulate = Color(1, 1, 1, 0.5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)


func play(cutscene_id: String) -> void:
	_cues = SFX_CUES.get(cutscene_id, {})
	_load_frames(cutscene_id)
	if _frames.is_empty():
		push_warning("CutsceneScreen: 找不到過場幀 %s，直接結束" % cutscene_id)
		# 延後一幀再發訊號，確保呼叫端已 await cs.finished
		_finish.call_deferred()
		return
	_idx = 0
	_accum = 0.0
	frame_rect.texture = _frames[0]
	_play_cue(1)
	_play_audio(cutscene_id)
	_playing = true


func _load_frames(cutscene_id: String) -> void:
	_frames.clear()
	var dir: String = FRAME_DIR % cutscene_id
	var i: int = 1
	while true:
		var path: String = dir + "frame_%04d.png" % i
		if not ResourceLoader.exists(path):
			break
		_frames.append(load(path))
		i += 1


func _process(delta: float) -> void:
	if not _playing:
		return
	_accum += delta
	var spf: float = 1.0 / FPS
	while _accum >= spf:
		_accum -= spf
		_idx += 1
		if _idx >= _frames.size():
			_finish()
			return
		frame_rect.texture = _frames[_idx]
		_play_cue(_idx + 1)  # 幀號 1-based


func _play_cue(frame_no: int) -> void:
	if _cues.has(frame_no):
		AudioManager.play_sfx(_cues[frame_no])


## 若該過場資料夾內附有整段配音 audio.ogg（含原生音效），用獨立 player 同步播放，
## 與逐幀 SFX_CUES 互斥（見上方常數註解）。缺檔則安全略過。
func _play_audio(cutscene_id: String) -> void:
	var path: String = (FRAME_DIR % cutscene_id) + "audio.ogg"
	if not ResourceLoader.exists(path):
		return
	cutscene_audio.stream = load(path)
	cutscene_audio.play()


func _unhandled_input(event: InputEvent) -> void:
	if not _playing:
		return
	if event.is_action_pressed("confirm") or event.is_action_pressed("cancel"):
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	_playing = false
	if cutscene_audio.playing:
		cutscene_audio.stop()
	finished.emit()
