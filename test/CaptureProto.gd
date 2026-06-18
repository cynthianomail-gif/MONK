extends Node
## 視窗版自動截圖：載入街景原型、等畫面穩定後存一張 PNG 再退出。
## 跑法：Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureProto.tscn

func _ready() -> void:
	var proto: Node = load("res://test/StreetProto.tscn").instantiate()
	get_tree().root.add_child.call_deferred(proto)
	# 等街景建好＋畫面穩定（粒子/霧/SSR 收斂）
	for i in 180:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://_street_shot.png")
	print("STREET_SHOT_DONE ", img.get_width(), "x", img.get_height())
	get_tree().quit()
