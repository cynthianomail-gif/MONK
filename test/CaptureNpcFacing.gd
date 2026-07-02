extends Node
## 驗證用截圖：把玩家挪到路中段，看兩側 NPC 是否轉向街道中央 + 走近提示。
const SCENE := preload("res://src/screens/MapScreen/MapScreen.tscn")
func _ready() -> void:
	GameManager.new_game()
	var s := SCENE.instantiate()
	get_tree().root.add_child.call_deferred(s)
	for i in 60:
		await get_tree().process_frame
	# 挪到 z=-6（阿明 4.5,-5 與 澪 -4.5,-6 之間），觸發澪的走近提示
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		player.global_position = Vector3(-2.4, 1.2, -6.0)
	for i in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://_npc_facing_shot.png")
	print("CAP_FACING_SAVED ", img.get_width(), "x", img.get_height())
	get_tree().quit()
