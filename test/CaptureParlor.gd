extends Node
## 地下遊藝場視覺驗收截圖（4 角度）＋軍火庫街入口門面（1 張）。
## 跑：...console.exe --path D:/monk/MONK res://test/CaptureParlor.tscn -- smoke
const PARLOR := preload("res://src/screens/MapScreen/environments/UndergroundParlor.tscn")
const ARMORY := preload("res://src/screens/MapScreen/environments/ArmoryDistrict.tscn")

func _ready() -> void:
	if not OS.get_cmdline_user_args().has("smoke"):
		return
	# ── 房間 4 角度 ──
	var s := PARLOR.instantiate()
	get_tree().root.add_child.call_deferred(s)
	for i in 60:
		await get_tree().process_frame
	await _shot("res://_parlor_spawn.png")            # 玩家預設相機（進場視角）
	var cam := Camera3D.new()
	cam.fov = 55.0
	get_tree().root.add_child(cam)
	cam.make_current()
	cam.fov = 85.0
	await _place(cam, Vector3(0, 4.4, 4.8), Vector3(0, 0.4, -2.0))  # 高角俯瞰（要在天花板 y=5 之下）
	await _shot("res://_parlor_over.png")
	cam.fov = 55.0
	await _place(cam, Vector3(0, 2.8, 4.6), Vector3(0, 1.0, -6.0))  # 朝北：飛鏢牆+賭桌+籠/球道
	await _shot("res://_parlor_north.png")
	await _place(cam, Vector3(0, 2.6, -5.2), Vector3(0, 1.2, 7.0))  # 朝南：出口門
	await _shot("res://_parlor_south.png")
	await _place(cam, Vector3(-1.0, 1.9, 0.8), Vector3(-3.2, 1.5, -2.6))  # 荷官特寫（拉遠避免貼桌）
	await _shot("res://_parlor_dealer.png")
	await _place(cam, Vector3(0, 1.75, -4.6), Vector3(0, 1.75, -7.0))     # 飛鏢靶特寫
	await _shot("res://_parlor_darts.png")
	await _place(cam, Vector3(-3.2, 2.6, -0.6), Vector3(-3.2, 0.9, -1.8)) # 輪盤面俯視特寫
	await _shot("res://_parlor_dealer.png")
	cam.queue_free()
	s.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	# ── 軍火庫街入口門面（直載環境，無 MapScreen＝無敵人/觸發點）──
	var a := ARMORY.instantiate()
	get_tree().root.add_child.call_deferred(a)
	for i in 60:
		await get_tree().process_frame
	var cam2 := Camera3D.new()
	cam2.fov = 55.0
	get_tree().root.add_child(cam2)
	cam2.make_current()
	await _place(cam2, Vector3(1.2, 2.6, -6.8), Vector3(5.2, 1.4, -10.5))  # 看東側樓梯口
	await _shot("res://_parlor_door.png")
	print("CAP_PARLOR done")
	get_tree().quit()

func _place(cam: Camera3D, pos: Vector3, target: Vector3) -> void:
	cam.global_position = pos
	cam.look_at(target)
	for i in 8:
		await get_tree().process_frame

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(path)
	print("CAP_PARLOR_SAVED ", path)
