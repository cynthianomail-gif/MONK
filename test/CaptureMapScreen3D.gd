extends Node
## windowed 截圖：神社區 3D 街 + 玩家上墨 + HUD。
const SCENE := preload("res://src/screens/MapScreen/MapScreen.tscn")
func _ready() -> void:
	GameManager.new_game()
	var s := SCENE.instantiate()
	get_tree().root.add_child.call_deferred(s)
	if not OS.get_cmdline_user_args().has("smoke"):
		return
	for i in 60:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://_mapscreen3d_shot.png")
	print("CAP_MAP3D_SAVED _mapscreen3d_shot.png ", img.get_width(), "x", img.get_height())
	get_tree().quit()
