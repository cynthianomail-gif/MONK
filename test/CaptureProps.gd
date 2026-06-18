extends Node
## Phase 3 道具驗證截圖：載入街景、把玩家偏右站好框住近處販賣機，存 PNG 再退出。
## 跑法：Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureProps.tscn

func _ready() -> void:
	var proto: Node = load("res://test/StreetProto.tscn").instantiate()
	get_tree().root.add_child.call_deferred(proto)
	for i in 40:
		await get_tree().process_frame
	var pl := get_tree().get_first_node_in_group("player")
	if pl:
		(pl as Node3D).global_position = Vector3(0.5, 1.2, 2.0)
	# 等街景＋粒子/霧/glow 收斂
	for i in 170:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://_proto_preview_v8_props.png")
	print("PROPS_SHOT_DONE ", img.get_width(), "x", img.get_height())
	get_tree().quit()
