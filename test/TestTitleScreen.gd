extends Node
## TitleScreen 背景圖＋BGM 接線回歸（2026-07-11）：
## 正式背景圖載入時，程式標題字要藏、按鈕群要在、title_theme BGM 已在 _ready 播放
## 且時長為新版 150s 曲目（非舊 30s 佔位曲）。
## 缺檔 fallback 行為（改名→驗證→還原）因涉及 Godot import 快取，於 headless
## 單一 process 內無法可靠模擬缺檔狀態，改以獨立 process 實驗驗證，見交付報告。

const TITLE_SCENE := "res://src/screens/TitleScreen/TitleScreen.tscn"

func _ready() -> void:
	var title1: Control = (load(TITLE_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(title1)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var bg_image: TextureRect = title1.get_node("%BgImage")
	var title_label: Label = title1.get_node("%Title")
	var subtitle_label: Label = title1.get_node("%Subtitle")
	var start_btn: Button = title1.get_node("%StartButton")

	if not bg_image.visible or bg_image.texture == null:
		return _fail("背景圖存在時 BgImage 應可見且有 texture")
	if title_label.visible or subtitle_label.visible:
		return _fail("背景圖存在時程式標題字應已隱藏")
	if not is_instance_valid(start_btn) or not start_btn.visible:
		return _fail("背景圖存在時 StartButton 仍應可見可讀")

	if AudioManager._current_bgm != "title_theme":
		return _fail("TitleScreen._ready 應已切到 title_theme，實為 %s" % AudioManager._current_bgm)
	var stream: AudioStream = AudioManager.bgm_player.stream
	if stream == null:
		return _fail("title_theme stream 未載入")
	var len_s: float = stream.get_length()
	if len_s < 120.0 or len_s > 180.0:
		return _fail("title_theme 時長應為新版 150s 曲目，實測 %.1fs（疑似仍是舊 30s 佔位曲）" % len_s)
	print("TEST: title_theme 實測時長 = %.2fs" % len_s)

	title1.queue_free()
	await get_tree().process_frame

	print("TEST PASS: TitleScreen 背景圖／BGM 接線通過")
	get_tree().quit(0)

func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m)
	get_tree().quit(1)
