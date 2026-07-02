extends Node
## 驗證神社街兩塊新招牌（保齡球館/打擊場）看得到、位置沒穿模。
## 跑法：Godot_console.exe --path D:\monk\MONK res://test/CaptureMinigameSigns.tscn -- smoke
const SHRINE := preload("res://src/screens/MapScreen/environments/ShrineStreet.gd")

const SHOTS := [
	["res://_sign_bowling.png", Vector3(-1.0, 2.4, -6.0), Vector3(5.9, 2.6, -9.0)],
	["res://_sign_batting.png", Vector3(1.0, 2.4, -18.0), Vector3(-5.9, 2.6, -21.0)],
	["res://_sign_sidestreet.png", Vector3(-6.5, 2.6, -13.0), Vector3(-14.0, 1.2, -9.4)],
	["res://_sign_shrinefront.png", Vector3(1.5, 2.2, -22.5), Vector3(1.8, 1.2, -26.5)],
]

func _ready() -> void:
	if not OS.get_cmdline_user_args().has("smoke"):
		return
	for entry in SHOTS:
		var root := Node3D.new()
		get_tree().root.add_child.call_deferred(root)
		await get_tree().process_frame
		var shrine := SHRINE.new()
		root.add_child(shrine)
		var cam := Camera3D.new()
		cam.fov = 60.0
		cam.current = true
		root.add_child(cam)
		cam.position = entry[1]
		cam.look_at(entry[2], Vector3.UP)
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(String(entry[0]))
		print("SIGN_SHOT_SAVED ", entry[0])
		root.queue_free()
		await get_tree().process_frame
	get_tree().quit()
