extends Node
## 過場系統執行時驗證（headless 可跑，不需繪圖）。
## 跑法: godot --headless res://test/TestCutscene.tscn
## 驗證:幀載入數、播放推進、finished 發出、play_battle_cutscene 疊加播完歸還。

func _ready() -> void:
	await _run()
	get_tree().quit()


func _run() -> void:
	var results: Array = []

	# ── Test 1：CutsceneScreen 載入幀 + 播放 + 發 finished ──
	var cs_scene: PackedScene = load("res://src/screens/CutsceneScreen/CutsceneScreen.tscn")
	var cs: Node = cs_scene.instantiate()
	add_child(cs)
	var finished_flag := {"v": false}
	cs.finished.connect(func() -> void: finished_flag.v = true)
	cs.play("break_food")
	var frame_count: int = cs._frames.size()
	results.append(["break_food 載入 49 幀", frame_count == 49, str(frame_count)])

	# break_food = 49 幀 / 12fps ≈ 4.1s，等 6s 應播完
	await get_tree().create_timer(6.0).timeout
	results.append(["播放完成發出 finished", finished_flag.v, str(finished_flag.v)])
	if is_instance_valid(cs):
		cs.queue_free()

	# ── Test 2：SceneRouter.play_battle_cutscene 疊加播完歸還 ──
	var t0: int = Time.get_ticks_msec()
	await SceneRouter.play_battle_cutscene("break_greed")  # 49 幀 ≈ 4.1s
	var dt: int = Time.get_ticks_msec() - t0
	results.append(["overlay 播完歸還控制 (3~8s)", dt > 3000 and dt < 8000, "%dms" % dt])
	# queue_free 在本幀結束才釋放，等兩幀讓它真正移除再數
	await get_tree().process_frame
	await get_tree().process_frame
	var leftover: int = 0
	for c in get_children():
		if c.has_method("play") and c.has_signal("finished"):
			leftover += 1
	results.append(["overlay 已自我移除", leftover == 0, "leftover=%d" % leftover])

	# ── Test 3：ares_phase2 二階變身過場帶 audio.ogg ──
	var cs2: Node = cs_scene.instantiate()
	add_child(cs2)
	var fin2 := {"v": false}
	cs2.finished.connect(func() -> void: fin2.v = true)
	cs2.play("ares_phase2")
	var fc2: int = cs2._frames.size()
	results.append(["ares_phase2 載入 61 幀", fc2 == 61, str(fc2)])
	var has_audio: bool = cs2.cutscene_audio.stream != null
	results.append(["ares_phase2 載入 audio.ogg", has_audio, str(has_audio)])
	results.append(["變身音軌開始播放", cs2.cutscene_audio.playing, str(cs2.cutscene_audio.playing)])
	# 61 幀 / 12fps ≈ 5.08s，等 6s 應播完並停音
	await get_tree().create_timer(6.0).timeout
	results.append(["ares_phase2 播完發 finished", fin2.v, str(fin2.v)])
	results.append(["播完後音軌已停", not cs2.cutscene_audio.playing, str(cs2.cutscene_audio.playing)])
	if is_instance_valid(cs2):
		cs2.queue_free()

	# ── 輸出 ──
	var all_pass := true
	print("==== TestCutscene 結果 ====")
	for r in results:
		var ok: bool = r[1]
		all_pass = all_pass and ok
		print("%s | %s (%s)" % ["PASS" if ok else "FAIL", r[0], r[2]])
	print("==== RESULT: %s ====" % ["ALL PASS" if all_pass else "SOME FAIL"])
