extends Node
## windowed 截圖：神社街上路人 NPC(轉向街心) + 路上漫遊敵人(3 隻)。
## 跑：Godot_..._win64.exe --path D:/monk/MONK res://test/CaptureRoamingScene.tscn -- smoke
const SCENE := preload("res://src/screens/MapScreen/MapScreen.tscn")
func _ready() -> void:
	GameManager.new_game()
	var s := SCENE.instantiate()
	get_tree().root.add_child.call_deferred(s)
	if not OS.get_cmdline_user_args().has("smoke"):
		return
	for i in 60:
		await get_tree().process_frame
	# 玩家留在街口(default_spawn ~z=6)，敵人在街道前方 z=-8~-20 巡邏＝入鏡但不觸發追擊
	for i in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://_roaming_scene_shot.png")
	var n := get_tree().get_nodes_in_group("roaming_enemy").size()
	print("CAP_ROAMING_SAVED %dx%d enemies=%d" % [img.get_width(), img.get_height(), n])
	get_tree().quit()
