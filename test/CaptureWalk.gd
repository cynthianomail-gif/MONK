extends Node
## 走正式流程進西門街，模擬按住前進鍵，連拍數張看「實際移動中」的無戒
## （測 CharacterBody 位移 + walk 動畫 + 相機跟隨 + root-motion 漂移）。

func _ready() -> void:
	await get_tree().process_frame
	get_tree().current_scene = null
	GameManager.new_game()
	SceneRouter.go_to_map()
	var map: Node = await _wait("MapScreen")
	if map == null:
		push_error("CAP FAIL"); get_tree().quit(1); return
	for i in 30:
		await get_tree().process_frame
	# 模擬按住「上」(進入畫面、背對相機方向) 前進
	Input.action_press("ui_up")
	# 取樣跨越舊定格點(1.07s≈64幀)，確認第二輪步態仍在動
	var shots := [40, 75, 95, 130]
	var idx := 0
	var frame := 0
	var total: int = shots[shots.size() - 1] + 1
	for i in total:
		await get_tree().process_frame
		frame += 1
		if idx < shots.size() and frame == shots[idx]:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://_walk_ingame_%d.png" % idx)
			print("WALK_SHOT ", idx)
			idx += 1
	Input.action_release("ui_up")
	var player := map.get_node_or_null("Player") as Node3D
	if player:
		print("PLAYER moved to=", player.global_position)
	print("WALK_DONE")
	get_tree().quit(0)

func _wait(n: String, mx: int = 600) -> Node:
	for i in mx:
		await get_tree().process_frame
		var cs := get_tree().current_scene
		if cs and cs.name == n: return cs
	return null
