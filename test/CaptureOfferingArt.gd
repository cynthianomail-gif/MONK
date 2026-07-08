extends Node
## windowed 截圖香火投擲（2026-07-08 Codex 美術接線校位）：
## ①進行中（背景+賽錢箱+銅錢+力度計框）②判定窗疊框（驗視覺與判定對位）③銅錢落投入口。
## 跑法：Godot（非 headless）res://test/CaptureOfferingArt.tscn -- smoke
const SCENE := preload("res://src/screens/Minigames/OfferingToss.tscn")

func _ready() -> void:
	var s := SCENE.instantiate()
	get_tree().root.add_child.call_deferred(s)
	if not OS.get_cmdline_user_args().has("smoke"):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var g = get_tree().root.get_node("OfferingToss")

	# ① 進行中：力度條拉到甜蜜點高度，看框窗/填充/刻度對位
	g._phase = "done"  # 停住 _process/輸入，手動擺畫面
	g._gauge_fill.size.y = 300.0 * g.POWER_SWEET
	g._gauge_fill.position.y = 760.0 - g._gauge_fill.size.y
	await _shot("_cap_offering_01.png")

	# ② 判定窗疊框：hit 窗（綠）與 perfect 窗（金）畫在判定座標上，
	#    直接目視賽錢箱開口是否罩住窗（視覺=判定）
	var overlay := Node2D.new()
	overlay.z_index = 100
	var hit_rect := ColorRect.new()
	hit_rect.position = Vector2(g.START_POS.x - g.BOX_HALF_W, g.BOX_MOUTH_Y - g.MOUTH_HALF_H)
	hit_rect.size = Vector2(g.BOX_HALF_W * 2.0, g.MOUTH_HALF_H * 2.0)
	hit_rect.color = Color(0.2, 1.0, 0.3, 0.35)
	overlay.add_child(hit_rect)
	var perfect_rect := ColorRect.new()
	perfect_rect.position = Vector2(g.START_POS.x - g.PERFECT_HALF_W, g.BOX_MOUTH_Y - g.PERFECT_HALF_H)
	perfect_rect.size = Vector2(g.PERFECT_HALF_W * 2.0, g.PERFECT_HALF_H * 2.0)
	perfect_rect.color = Color(1.0, 0.85, 0.2, 0.55)
	overlay.add_child(perfect_rect)
	g.add_child(overlay)
	await _shot("_cap_offering_02_judge.png")
	overlay.queue_free()

	# ③ 銅錢正落投入口中心
	g._coin.position = Vector2(g.START_POS.x, g.BOX_MOUTH_Y)
	g._coin.scale = Vector2.ONE * 0.45  # 飛行終點的縮放
	await _shot("_cap_offering_03_land.png")

	get_tree().quit()

func _shot(path: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://" + path)
	print("OFFERING_SHOT_SAVED ", path, " ", img.get_width(), "x", img.get_height())
