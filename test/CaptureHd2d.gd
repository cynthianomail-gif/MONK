extends Node
## 視窗版自動截圖：載入 HD-2D 原型→等畫面穩定→存 PNG→退出。
## 跑法：Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureHd2d.tscn
## DOF/glow/霓虹只有 GPU 視窗渲得出來，故用「視窗版」非 --headless。

func _ready() -> void:
	var proto: Node = load("res://test/Hd2dProto.tscn").instantiate()
	get_tree().root.add_child.call_deferred(proto)
	for i in 180:                          # 等場景建好＋粒子/霧/DOF 收斂
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://_hd2d_shot.png")
	print("HD2D_SHOT_DONE ", img.get_width(), "x", img.get_height())
	get_tree().quit()
