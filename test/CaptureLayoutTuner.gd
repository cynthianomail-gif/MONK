extends Node
## GPU 截圖：佈局調整模式選中某 sprite 的高亮框（規格驗收條件④）。
## 跑法（非 headless，需要實際渲染）：
## Godot_console.exe --path D:\monk\MONK res://test/CaptureLayoutTuner.tscn -- smoke
## 輸出：D:\monk\MONK\_cap_layout_tuner.png

func _ready() -> void:
	if not OS.get_cmdline_user_args().has("smoke"):
		return
	var scene := Node2D.new()
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	get_tree().current_scene = scene

	var bg := ColorRect.new()
	bg.color = Color(0.15, 0.13, 0.18)
	bg.size = Vector2(1920, 1080)
	scene.add_child(bg)

	var sp := Sprite2D.new()
	var img := Image.create(180, 180, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.85, 0.6, 0.2, 1.0))
	sp.texture = ImageTexture.create_from_image(img)
	sp.centered = true
	sp.position = Vector2(960, 540)
	scene.add_child(sp)

	await get_tree().process_frame
	LayoutTuner._debug_enabled = true
	LayoutTuner.toggle_tuning()   # F8 開啟
	await get_tree().process_frame
	LayoutTuner._try_select(Vector2(960, 540))
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var out_img: Image = get_viewport().get_texture().get_image()
	out_img.save_png("res://_cap_layout_tuner.png")
	print("LAYOUT_TUNER_SHOT_SAVED res://_cap_layout_tuner.png")
	LayoutTuner.toggle_tuning()
	get_tree().paused = false
	get_tree().quit()
