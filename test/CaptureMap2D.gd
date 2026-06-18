extends Node
## 視窗截圖：進 2D 地圖，拍 街景／走路捲動／城市地圖／地點內景。
func _ready() -> void:
	await get_tree().process_frame
	get_tree().current_scene = null
	GameManager.new_game()
	SceneRouter.go_to_map()
	var map: Node = await _wait("MapScreen")
	if map == null:
		push_error("CAP FAIL"); get_tree().quit(1); return
	for i in 30: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_map2d_street.png")
	print("SHOT street")

	Input.action_press("ui_right")
	for i in 45: await get_tree().process_frame
	Input.action_release("ui_right")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_map2d_walk.png")
	print("SHOT walk")

	map.show_city_map()
	for i in 10: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_map2d_city.png")
	print("SHOT city")
	map.get_node("CityMap").visible = false

	map._on_location_entered("wannian_mall")
	for i in 10: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_map2d_interior.png")
	print("SHOT interior")
	get_tree().quit(0)
func _wait(n: String, mx := 600) -> Node:
	for i in mx:
		await get_tree().process_frame
		var cs := get_tree().current_scene
		if cs and cs.name == n: return cs
	return null
