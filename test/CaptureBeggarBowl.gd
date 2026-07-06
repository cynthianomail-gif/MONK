extends Node
## windowed 截圖接缽化緣（P5 重寫：接落物玩法）：①遊戲中（缽+落物+HUD）②結算面板。
## 跑法：Godot（非 headless）res://test/CaptureBeggarBowl.tscn -- smoke
const SCENE := preload("res://src/screens/Minigames/BeggarChallenge.tscn")

func _ready() -> void:
	var s := SCENE.instantiate()
	get_tree().root.add_child.call_deferred(s)
	if not OS.get_cmdline_user_args().has("smoke"):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var g = get_tree().root.get_node("BeggarChallenge")

	# ① 遊戲中：手動灑幾顆落物（涵蓋銅板/元寶/飯糰/垃圾）並定位缽，拍一張進行中畫面。
	g.auto_start = false
	g.suppress_end_cutscene = true   # 截圖走同幀斷言路徑，不播結尾過場（有 minigame_beggar_challenge_win 素材會擋住面板）
	g._running = true
	g.score = 245
	g.combo_mult = 1.21
	g._update_hud()
	g._bowl_x = 960.0
	if g._bowl_node:
		g._bowl_node.position.x = g._bowl_x
	var drop_specs := [
		{"type": "coin", "x": 500.0, "y": 300.0},
		{"type": "ingot", "x": 900.0, "y": 500.0},
		{"type": "riceball", "x": 1300.0, "y": 200.0},
		{"type": "trash", "x": 1550.0, "y": 650.0},
	]
	for spec in drop_specs:
		g._add_drop(spec.type, Vector2(spec.x, spec.y))
	# 跑一次 _update_drops 讓落點陰影依高度定出縮放/深淺（delta=0 不位移）
	g._update_drops(0.0)
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img1: Image = get_viewport().get_texture().get_image()
	img1.save_png("res://_cap_beggar_01.png")
	print("BEGGAR_SHOT_SAVED _cap_beggar_01.png ", img1.get_width(), "x", img1.get_height())

	# ② 結算面板：直接呼叫 _end() 觸發 show_result_panel。
	g.score = 860
	g.riceball_count = 4
	g.max_combo_count = 18
	g.max_combo_mult = 2.6
	g.trash_caught = 2
	g._end()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img2: Image = get_viewport().get_texture().get_image()
	img2.save_png("res://_cap_beggar_02.png")
	print("BEGGAR_SHOT_SAVED _cap_beggar_02.png ", img2.get_width(), "x", img2.get_height())

	get_tree().quit()
