extends Node
## windowed 截圖端湯 3D 版（P3b 壽司店改版）：①②第一人稱視角在同一位置對著兩個
## 相差≥60°的 yaw（證明滑鼠視角/玩家旋轉真的會轉動鏡頭朝向）③吧台+師傅+顧客近覽
## ④結算面板。跑法：Godot（非 headless）res://test/CaptureSoupCarry3D.tscn -- smoke
const SCENE := preload("res://src/screens/Minigames/SoupCarry.tscn")

func _ready() -> void:
	var g = SCENE.instantiate()
	get_tree().root.add_child.call_deferred(g)
	if not OS.get_cmdline_user_args().has("smoke"):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	g = get_tree().root.get_node("SoupCarry")

	# ①② 同一位置、兩個相差 110° 的 yaw：站在桌區中央空地，先望向壽司吧台方向，
	# 再轉向側牆方向，證明玩家 yaw(=滑鼠視角驅動的同一個旋轉量)真的會轉動畫面朝向。
	g._target_idx = 0
	g._player.position = Vector3(0.0, 0.0, 0.5)
	g._player.rotation.y = deg_to_rad(20.0)
	g._cam.rotation.x = 0.0
	for i in 15:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img1: Image = get_viewport().get_texture().get_image()
	img1.save_png("res://_cap_soup3d_01.png")
	print("SOUP3D_SHOT_SAVED _cap_soup3d_01.png yaw=20 ", img1.get_width(), "x", img1.get_height())

	g._player.rotation.y = deg_to_rad(130.0)
	for i in 15:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img1b: Image = get_viewport().get_texture().get_image()
	img1b.save_png("res://_cap_soup3d_01b.png")
	print("SOUP3D_SHOT_SAVED _cap_soup3d_01b.png yaw=130 ", img1b.get_width(), "x", img1b.get_height())

	# ③ 吧台+師傅+顧客近覽：暫停 _running(否則 _process 的 _update_look 每幀把
	# _cam.rotation.x 蓋回 _pitch=0，蓋掉這裡手動設的角度)，截完再恢復。
	g._running = false
	var orig_cam_pos: Vector3 = g._cam.position
	var orig_cam_rot: Vector3 = g._cam.rotation
	var orig_player_pos: Vector3 = g._player.position
	var orig_player_rot: float = g._player.rotation.y
	g._player.position = Vector3(0.0, 0.0, 1.5)
	g._player.rotation.y = 0.0
	g._cam.position = Vector3(0, 1.75, 0)
	g._cam.rotation.x = deg_to_rad(10.0)
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img3: Image = get_viewport().get_texture().get_image()
	img3.save_png("res://_cap_soup3d_03_counter.png")
	print("SOUP3D_SHOT_SAVED _cap_soup3d_03_counter.png ", img3.get_width(), "x", img3.get_height())
	g._cam.position = orig_cam_pos
	g._cam.rotation = orig_cam_rot
	g._player.position = orig_player_pos
	g._player.rotation.y = orig_player_rot
	g._running = true

	# ④ 結算面板：直接灌分數呼叫 _end_game() 觸發 show_result_panel。
	g.income = 720
	g.delivered_count = 8
	g.failed_count = 0
	g.total_spill = 40.0
	g.total_collision = 0
	g.total_bonus = 90
	g._end_game()
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img2: Image = get_viewport().get_texture().get_image()
	img2.save_png("res://_cap_soup3d_02.png")
	print("SOUP3D_SHOT_SAVED _cap_soup3d_02.png ", img2.get_width(), "x", img2.get_height())

	get_tree().quit()
