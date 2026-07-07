extends Node
## AudioManager.switch_bgm 併發競態回歸（2026-07-08）：
## 淡出 await 期間來了更新的切歌請求時，舊請求醒來後必須放棄，
## 不得倒回去播較早請求的曲子。

func _ready() -> void:
	# 先正常放一首（無淡出路徑，立即生效）
	AudioManager.switch_bgm("title_theme", 0.1)
	await get_tree().create_timer(0.2).timeout
	if AudioManager._current_bgm != "title_theme":
		return _fail("前置：title_theme 應已就位，實為 %s" % AudioManager._current_bgm)

	# 競態：長淡出切 A，緊接著短淡出切 B → 最終必須是 B
	AudioManager.switch_bgm("ximen_day", 1.0)    # 舊請求（慢）
	await get_tree().process_frame
	AudioManager.switch_bgm("ximen_night", 0.1)  # 新請求（快）
	await get_tree().create_timer(1.6).timeout   # 讓兩條淡出都跑完
	if AudioManager._current_bgm != "ximen_night":
		return _fail("併發切歌後應停在最新請求 ximen_night，實為 %s" % AudioManager._current_bgm)
	var sp: String = AudioManager.bgm_player.stream.resource_path if AudioManager.bgm_player.stream else ""
	if not sp.contains("ximen_night"):
		return _fail("實際播放的 stream 應是 ximen_night，實為 %s" % sp)

	# 去重：切同一首不應重啟
	AudioManager.switch_bgm("ximen_night", 0.1)
	await get_tree().create_timer(0.3).timeout
	if AudioManager._current_bgm != "ximen_night":
		return _fail("同曲重複請求後狀態不應變")

	print("TEST PASS: AudioManager 併發切歌競態（新請求勝出/同曲去重） OK")
	get_tree().quit(0)

func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m)
	get_tree().quit(1)
