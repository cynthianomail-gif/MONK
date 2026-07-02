extends Node
## windowed 拍保齡球「滾動中（速度尾焰）」與「撞瓶瞬間（爆點）」兩張，存專案根目錄。
## 跑法：Godot_console.exe --path D:\monk\MONK res://test/CaptureBowlingRoll.tscn -- smoke

func _ready() -> void:
	if not OS.get_cmdline_user_args().has("smoke"):
		return
	var g: Node = (load("res://src/screens/Minigames/Bowling.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(g)
	for i in 15:
		await get_tree().process_frame
	g.hooked = true          # 曲球（順便看勾軌）
	g._update_type_label()
	g._roll()
	for f in 25:             # 滾到半途
		await get_tree().process_frame
	await _shot("res://_bowling_roll_shot.png")
	for f in 28:             # 剛撞瓶（0.85s 滾動＋爆點淡出中）
		await get_tree().process_frame
	await _shot("res://_bowling_impact_shot.png")
	get_tree().quit()

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(path)
	print("BOWL_SHOT_SAVED ", path, " ", img.get_width(), "x", img.get_height())
