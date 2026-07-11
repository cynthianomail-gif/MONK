extends Node
## 2026-07-10 QC 修正（圈圈校位）診斷／證據截圖：俯視整條街，把每個 LocationTrigger 的
## 金環位置疊上文字標籤(location_id)，方便肉眼比對「圈圈是否落在對應建築門口/物件中心」。
## 直接用真實 MapScreen 場景(GameManager.new_game()+SCENE.instantiate())，
## 圈圈＝真正遊戲內灑的 LocationTrigger，不是另外畫的示意圖。
## 跑：Godot..._console.exe --headless --path D:/monk/MONK res://test/CaptureLocationOverview.tscn -- smoke <area>
## <area> 省略＝shrine；armory 需要先解鎖(此腳本會自動 set_flag armory_unlocked)。
##
## 輸出：D:/monk/_location_overview/<area>_top.png（俯視全景，含標籤）
## 另外對每個觸發點各拍一張近距俯視特寫（半徑約 6 米範圍），方便單點核對圈圈是否貼準門口，
## 檔名＝<area>_close_<location_id>.png。

const SCENE := preload("res://src/screens/MapScreen/MapScreen.tscn")
const OUT_DIR := "D:/monk/_location_overview/"

func _ready() -> void:
	if not OS.get_cmdline_user_args().has("smoke"):
		return
	var args := OS.get_cmdline_user_args()
	var area := "shrine"
	for a in args:
		if a == "armory":
			area = "armory"
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	GameManager.new_game()
	if area == "armory":
		GameManager.set_flag("armory_unlocked", true)
		GameManager.player.current_area = "armory"
	var s := SCENE.instantiate()
	get_tree().root.add_child.call_deferred(s)
	for i in 100:
		await get_tree().process_frame
	# 清漫遊敵人：干擾截圖但不影響觸發器位置本身（同 CaptureBoundaryAudit 慣例）。
	for e in get_tree().get_nodes_in_group("roaming_enemy"):
		e.queue_free()
	await get_tree().process_frame

	var triggers := get_tree().get_nodes_in_group("location_trigger")
	print("LOCATION_OVERVIEW: area=%s triggers=%d" % [area, triggers.size()])
	# 每個觸發器頭上加文字標籤（純視覺，測試結束隨場景釋放，不留存到遊戲內）。
	for t in triggers:
		var lbl := Label3D.new()
		lbl.text = String(t.location_id)
		lbl.font_size = 42
		lbl.pixel_size = 0.01
		lbl.modulate = Color(1, 1, 1)
		lbl.outline_size = 12
		lbl.outline_modulate = Color(0, 0, 0, 1)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.position = Vector3(0, 3.0, 0)
		t.add_child(lbl)

	var cam := Camera3D.new()
	get_tree().root.add_child(cam)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	cam.fov = 70
	cam.make_current()

	# 全景俯視（涵蓋整個 L 形街道；armory 是直街）
	if area == "shrine":
		cam.position = Vector3(-9, 50, -11)
	else:
		cam.position = Vector3(0, 46, -12)
	for i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT_DIR + "%s_top.png" % area)
	print("LOCATION_OVERVIEW_SAVED %s_top.png %dx%d" % [area, img.get_width(), img.get_height()])

	# 逐點近距特寫（俯視，高度拉高避免屋頂近距穿模造成的黑塊誤判）
	for t in triggers:
		var pos: Vector3 = t.global_position
		cam.position = Vector3(pos.x, pos.y + 22.0, pos.z)
		for i in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img2: Image = get_viewport().get_texture().get_image()
		var fname := "%s_close_%s.png" % [area, String(t.location_id)]
		img2.save_png(OUT_DIR + fname)
		print("LOCATION_CLOSE_SAVED %s" % fname)

	# 逐點玩家視角特寫（站在觸發點旁 1.5 米、眼高 1.6、面向觸發點）＝玩家實際會看到的畫面。
	cam.rotation_degrees = Vector3(-5, 0, 0)
	for t in triggers:
		var pos: Vector3 = t.global_position
		cam.position = Vector3(pos.x, pos.y + 1.6, pos.z + 2.2)
		cam.look_at(Vector3(pos.x, pos.y + 1.0, pos.z), Vector3.UP)
		for i in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img3: Image = get_viewport().get_texture().get_image()
		var fname3 := "%s_eye_%s.png" % [area, String(t.location_id)]
		img3.save_png(OUT_DIR + fname3)
		print("LOCATION_EYE_SAVED %s" % fname3)

	# 額外：對指定觸發點做 4 方向 yaw 掃描（同 CaptureBoundaryAudit 慣例），
	# 不猜測店面朝向，四個方向都拍，確保看得到對應建築。
	var scan_ids := ["batting_entrance", "bowling_entrance"]
	for t in triggers:
		if not scan_ids.has(String(t.location_id)):
			continue
		var pos: Vector3 = t.global_position
		cam.position = Vector3(pos.x, pos.y + 1.6, pos.z)
		for yaw in [0, 90, 180, 270]:
			cam.rotation_degrees = Vector3(0, yaw, 0)
			for i in 6:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var imgy: Image = get_viewport().get_texture().get_image()
			var fnamey := "%s_scan_%s_yaw%d.png" % [area, String(t.location_id), yaw]
			imgy.save_png(OUT_DIR + fnamey)
			print("LOCATION_SCAN_SAVED %s" % fnamey)

	# 額外：打擊場周邊區域俯視（評估 batting_entrance 是否卡進隨機店家的牆體）。
	if area == "shrine":
		cam.rotation_degrees = Vector3(-90, 0, 0)
		cam.position = Vector3(-6.0, 34, -21.0)
		cam.fov = 60
		for i in 10:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var imgb: Image = get_viewport().get_texture().get_image()
		imgb.save_png(OUT_DIR + "shrine_batting_area_top.png")
		print("LOCATION_BATTING_AREA_SAVED")

	# 額外：鐵叔周邊區域高空俯視（避開屋頂近距穿模），供評估候選新座標。
	if area == "armory":
		cam.rotation_degrees = Vector3(-90, 0, 0)
		cam.position = Vector3(-2, 40, -16)
		cam.fov = 60
		for i in 10:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img4: Image = get_viewport().get_texture().get_image()
		img4.save_png(OUT_DIR + "armory_forge_area_top.png")
		print("LOCATION_FORGE_AREA_SAVED")

	print("LOCATION_OVERVIEW_DONE")
	get_tree().quit()
