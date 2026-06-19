extends Node
## 視窗版自動截圖：載入真 3D 西門 hub 原型→等畫面穩定→存 PNG→退出。
## 跑法：Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureXimen3DHub.tscn
## DOF/glow/霓虹只有 GPU 視窗渲得出來，故用「視窗版」非 --headless。

func _ready() -> void:
	var hub: Node = load("res://test/TestXimen3DHub.tscn").instantiate()
	get_tree().root.add_child.call_deferred(hub)
	for i in 180:                          # 等場景建好＋燈光/霧/DOF 收斂
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://_ximen3d_shot.png")
	print("XIMEN3D_SHOT_DONE ", img.get_width(), "x", img.get_height())
	get_tree().quit()
