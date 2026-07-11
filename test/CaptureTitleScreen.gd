extends Node
## windowed 截 TitleScreen 畫面（背景圖 + BGM 接線視覺驗收），存專案根目錄。
## 跑法：Godot_console.exe --path D:\monk\MONK --resolution 1920x1080 res://test/CaptureTitleScreen.tscn -- smoke

func _ready() -> void:
	if not OS.get_cmdline_user_args().has("smoke"):
		return
	var g: Control = (load("res://src/screens/TitleScreen/TitleScreen.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(g)
	for i in 20:
		await get_tree().process_frame
	await _shot("res://_title_screen_bg_shot.png")
	get_tree().quit()

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(path)
	print("TITLE_SHOT_SAVED ", path, " ", img.get_width(), "x", img.get_height())
