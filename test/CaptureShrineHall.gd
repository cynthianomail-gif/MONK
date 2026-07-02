extends Node
## windowed 截圖：玩家傳到鳥居前，近看神社本殿精模（hero 地標驗收）。
const SCENE := preload("res://src/screens/MapScreen/MapScreen.tscn")

func _ready() -> void:
	GameManager.new_game()
	var s := SCENE.instantiate()
	get_tree().root.add_child.call_deferred(s)
	if not OS.get_cmdline_user_args().has("smoke"):
		return
	for i in 30:
		await get_tree().process_frame
	# 先清漫遊敵人：傳送點在鬼的巡邏區內，不清會被追到直接進戰鬥(只剩讀取頁)
	for e in get_tree().get_nodes_in_group("roaming_enemy"):
		e.queue_free()
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		player.global_position = Vector3(0, 0.1, -19.0)
	for i in 90:
		await get_tree().process_frame   # 等相機 lerp 跟上
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://_shrine_hall_closeup.png")
	print("CAP_HALL_SAVED _shrine_hall_closeup.png")
	get_tree().quit()
