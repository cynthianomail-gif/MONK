extends Node
## Phase 3 道具展示截圖：自訂壓低相機沿右側人行道看「販賣機→立牌→腳踏車」一列。
## 跑法：Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CapturePropsHero.tscn

func _ready() -> void:
	var proto: Node = load("res://test/StreetProto.tscn").instantiate()
	get_tree().root.add_child.call_deferred(proto)
	for i in 40:
		await get_tree().process_frame
	# 自訂展示相機（壓低、沿右側人行道斜看，蓋過 rig 相機）
	var cam := Camera3D.new()
	cam.fov = 60.0
	get_tree().root.add_child(cam)
	cam.global_position = Vector3(-0.3, 1.6, -8.0)
	cam.look_at(Vector3(5.8, 0.8, -11.0), Vector3.UP)   # 從街上側看右側人行道道具列
	cam.make_current()
	for i in 150:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://_proto_preview_v8_props.png")
	print("PROPS_HERO_DONE ", img.get_width(), "x", img.get_height())
	get_tree().quit()
