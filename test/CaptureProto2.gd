extends Node
## 第二視角自動截圖：把玩家移到街中段換構圖，存 _street_shot2.png。
## 跑法：Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureProto2.tscn

func _ready() -> void:
	var proto: Node = load("res://test/StreetProto.tscn").instantiate()
	get_tree().root.add_child.call_deferred(proto)
	for i in 40:
		await get_tree().process_frame
	var pl := get_tree().get_first_node_in_group("player")
	if pl:
		(pl as Node3D).global_position = Vector3(2.0, 1.2, -15.0)
	for i in 170:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://_street_shot2.png")
	print("STREET_SHOT2_DONE ", img.get_width(), "x", img.get_height())
	get_tree().quit()
