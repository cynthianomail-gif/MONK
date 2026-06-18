extends Node
## 視窗截圖：走正式流程進西門街，存玩家 3D 無戒的畫面。
## 跑法（非 headless）：Godot_..._console.exe --path D:/monk/MONK res://test/CapturePlayer.tscn

func _ready() -> void:
	await get_tree().process_frame
	get_tree().current_scene = null
	GameManager.new_game()
	SceneRouter.go_to_map()
	var map: Node = await _wait("MapScreen")
	if map == null:
		push_error("CAP FAIL: MapScreen 未載入"); get_tree().quit(1); return
	for i in 150:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	# 診斷：玩家/相機位置 + 玩家頭頂投影到螢幕
	var player := map.get_node_or_null("Player") as Node3D
	var cam := get_viewport().get_camera_3d()
	if player:
		print("PLAYER pos=", player.global_position)
		var head := player.global_position + Vector3(0, 1.6, 0)
		print("HEAD screen=", cam.unproject_position(head), " behind=", cam.is_position_behind(head))
	if cam:
		print("CAM pos=", cam.global_position, " rotdeg=", cam.global_rotation_degrees)
	var rig := map.get_node_or_null("CameraRig")
	if rig:
		print("RIG path=", rig.get_path())
		print("RIG target_path=", rig.target_path, " resolved=", rig.get_node_or_null(rig.target_path))
		print("RIG _target=", rig._target, " rig.global_position=", rig.global_position)
	print("MAP children=", map.get_children())
	get_viewport().get_texture().get_image().save_png("res://_player3d_ximen.png")
	print("PLAYER_CAP_DONE")
	get_tree().quit(0)

func _wait(n: String, mx: int = 600) -> Node:
	for i in mx:
		await get_tree().process_frame
		var cs := get_tree().current_scene
		if cs and cs.name == n: return cs
	return null
