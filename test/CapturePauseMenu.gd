extends Node
## GPU 截圖：ESC 暫停頁（規格驗收條件④）。跑法（非 headless，需要實際渲染）：
## Godot_console.exe --path D:\monk\MONK res://test/CapturePauseMenu.tscn -- smoke
## 輸出：D:\monk\MONK\_cap_pause_menu.png

func _ready() -> void:
	if not OS.get_cmdline_user_args().has("smoke"):
		return
	var gs = load("res://src/screens/Minigames/BeggarChallenge.gd")
	var g = gs.new()
	g.auto_start = false
	g.suppress_end_cutscene = true
	get_tree().root.add_child.call_deferred(g)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene = g
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	g._unhandled_input(ev)
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://_cap_pause_menu.png")
	print("PAUSE_MENU_SHOT_SAVED res://_cap_pause_menu.png")
	get_tree().paused = false
	get_tree().quit()
