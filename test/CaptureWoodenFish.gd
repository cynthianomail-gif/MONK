extends Node
## windowed 截圖三僧木魚（節奏天國式重寫）：①示範段 ②玩家段判定文字 ③結算面板。
## 跑法：Godot（非 headless）res://test/CaptureWoodenFish.tscn -- smoke
const SCENE := preload("res://src/screens/Minigames/WoodenFishRhythm.tscn")

func _ready() -> void:
	var s := SCENE.instantiate()
	get_tree().root.add_child.call_deferred(s)
	if not OS.get_cmdline_user_args().has("smoke"):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var g = get_tree().root.get_node("WoodenFishRhythm")

	# ① 示範段：一開場就在 DEMO_A，等幾幀讓角色動畫跑起來再拍。
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img1: Image = get_viewport().get_texture().get_image()
	img1.save_png("res://_cap_woodfish_01.png")
	print("WOODFISH_SHOT_SAVED _cap_woodfish_01.png ", img1.get_width(), "x", img1.get_height())

	# ② 玩家段：快轉時間跳過示範A段落，再快轉跳過示範B段落，敲一拍讓判定文字顯示。
	var rd: Dictionary = g.ROUNDS[0]
	var dur: float = g.round_phase_duration_ms(rd)
	g._clock_start_ms -= (dur + 10.0)
	for i in 3:
		await get_tree().process_frame
	g._clock_start_ms -= (dur + 10.0)
	for i in 3:
		await get_tree().process_frame
	# 確認已進玩家段（重試快轉，避免單次時間補償不足）
	var tries := 0
	while g._phase != 2 and tries < 10:
		g._clock_start_ms -= (dur + 10.0)
		await get_tree().process_frame
		tries += 1
	if g._player_beats.size() > 0:
		var beat0: Dictionary = g._player_beats[0]
		g._register_player(beat0, "perfect", 5.0)
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img2: Image = get_viewport().get_texture().get_image()
	img2.save_png("res://_cap_woodfish_02.png")
	print("WOODFISH_SHOT_SAVED _cap_woodfish_02.png ", img2.get_width(), "x", img2.get_height())

	# ③ 結算面板：直接呼叫 _end() 觸發 show_result_panel。
	g.score = g.total_beats_count() * 100
	g.judged = g.total_beats_count()
	g.perfects = g.total_beats_count()
	g._end()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img3: Image = get_viewport().get_texture().get_image()
	img3.save_png("res://_cap_woodfish_03.png")
	print("WOODFISH_SHOT_SAVED _cap_woodfish_03.png ", img3.get_width(), "x", img3.get_height())

	get_tree().quit()
