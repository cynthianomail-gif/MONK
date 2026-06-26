extends Node
## windowed 截圖端湯改版：地圖 + 無戒 + 目標桌高亮 + HUD(時間/收入/晃動 meter)。
const SCENE := preload("res://src/screens/Minigames/SoupCarry.tscn")
func _ready() -> void:
	var s := SCENE.instantiate()
	get_tree().root.add_child.call_deferred(s)
	if not OS.get_cmdline_user_args().has("smoke"):
		return
	for i in 70:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://_soupcarry_shot.png")
	print("SOUP_SHOT_SAVED _soupcarry_shot.png ", img.get_width(), "x", img.get_height())
	get_tree().quit()
