extends Node
## 邊界破綻診斷截圖：把玩家相機直接擺到街道端點/轉角，8 方向 yaw 掃描
## （另加 pitch 上仰極限），輸出到 D:\monk\_boundary_audit\ 供逐張檢查穿幫
## （虛空/地板邊緣/天空縫/未收尾街端/建築背面鏤空）。
## 跑：Godot_..._win64.exe --path D:/monk/MONK res://test/CaptureBoundaryAudit.tscn -- smoke
##
## 做法＝直接 instantiate 環境腳本＋手動相機（同 CaptureArmoryDistrict.gd 慣例），
## 不經 MapScreen/CameraRig，避免 spring-arm 碰撞與滑鼠捕捉干擾，換得座標/角度
## 完全可控的系統性掃描。ShrineStreet 需要 GameManager.new_game() 供 period 讀值。

const SHRINE := preload("res://src/screens/MapScreen/environments/ShrineStreet.gd")
const ARMORY := preload("res://src/screens/MapScreen/environments/ArmoryDistrict.gd")
const PARLOR := preload("res://src/screens/MapScreen/environments/UndergroundParlor.gd")

const OUT_DIR := "D:/monk/_boundary_audit/"
const EYE_H := 1.6   # 玩家視線高度

# 每個場景的巡檢點：[名稱, Vector3 位置]
const SHRINE_POINTS := [
	["south_entrance", Vector3(0, EYE_H, 7.0)],       # 主街南口(spawn 附近)
	["north_torii", Vector3(0, EYE_H, -26.5)],        # 主街北端鳥居前
	["junction", Vector3(-5.0, EYE_H, -13.0)],        # 主街/支街轉彎口
	["west_end", Vector3(-28.5, EYE_H, -13.0)],       # 支街西端
	["main_ne_corner", Vector3(5.0, EYE_H, -27.0)],   # 主街東北角
	["main_sw_corner", Vector3(-5.0, EYE_H, 7.5)],    # 主街西南角(南口內側)
]
const ARMORY_POINTS := [
	["entrance", Vector3(0, EYE_H, 1.5)],             # 入口
	["forge_front", Vector3(0, EYE_H, -19.5)],        # 熔鑄爐前
	["mid_east", Vector3(8.5, EYE_H, -12.0)],         # 東側邊界
	["mid_west", Vector3(-8.5, EYE_H, -12.0)],        # 西側邊界
]
const PARLOR_POINTS := [
	["center", Vector3(0, EYE_H, 0)],
	["ne_corner", Vector3(4.5, EYE_H, -6.5)],
	["sw_corner", Vector3(-4.5, EYE_H, 6.5)],
	["north_wall", Vector3(0, EYE_H, -6.5)],
]

const YAWS := [0, 45, 90, 135, 180, 225, 270, 315]   # deg，0=-Z(北)
const PITCH_NORMAL := 0.0
const PITCH_UP := 15.0        # 上仰極限只在 4 個對角方向抽查，省張數

var _shot_count := 0

func _ready() -> void:
	GameManager.new_game()
	if not OS.get_cmdline_user_args().has("smoke"):
		return
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	await _capture_scene("shrine", SHRINE.new(), SHRINE_POINTS)
	await _capture_scene("armory", ARMORY.new(), ARMORY_POINTS)
	await _capture_scene("parlor", PARLOR.new(), PARLOR_POINTS)
	print("CAP_BOUNDARY_DONE %d shots" % _shot_count)
	get_tree().quit()

func _capture_scene(scene_name: String, env: Node3D, points: Array) -> void:
	var root := Node3D.new()
	get_tree().root.add_child.call_deferred(root)
	await get_tree().process_frame
	await get_tree().process_frame
	root.add_child(env)
	var cam := Camera3D.new()
	cam.fov = 55.0
	root.add_child(cam)
	cam.current = true
	for i in 20:
		await get_tree().process_frame
	# 清漫遊敵人：座標可能落在巡邏區，敵人 AI 追逐會干擾截圖但不影響地形本身，
	# 清掉求乾淨畫面（同 CaptureShrineHall.gd 既有慣例）。
	for e in get_tree().get_nodes_in_group("roaming_enemy"):
		e.queue_free()
	await get_tree().process_frame
	for pt in points:
		var pname: String = pt[0]
		var pos: Vector3 = pt[1]
		cam.global_position = pos
		for yaw in YAWS:
			cam.rotation_degrees = Vector3(PITCH_NORMAL, yaw, 0)
			await get_tree().process_frame
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img: Image = get_viewport().get_texture().get_image()
			var fname := "%s_%s_yaw%d_pitch0.png" % [scene_name, pname, yaw]
			img.save_png(OUT_DIR + fname)
			_shot_count += 1
			if yaw % 90 == 0:   # 上仰極限只在 4 正方向抽查
				cam.rotation_degrees = Vector3(PITCH_UP, yaw, 0)
				await get_tree().process_frame
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var img2: Image = get_viewport().get_texture().get_image()
				var fname2 := "%s_%s_yaw%d_pitch15.png" % [scene_name, pname, yaw]
				img2.save_png(OUT_DIR + fname2)
				_shot_count += 1
	root.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
