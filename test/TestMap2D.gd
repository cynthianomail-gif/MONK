extends Node
func _ready() -> void:
	await get_tree().process_frame
	get_tree().current_scene = null
	GameManager.new_game()
	SceneRouter.go_to_map()
	var map: Node = await _wait("MapScreen")
	if map == null: return _fail("MapScreen 未載入")
	await get_tree().process_frame
	var ds := map.get_node_or_null("DistrictScene")
	if ds == null: return _fail("無 DistrictScene")
	if ds.portal_count() <= 0: return _fail("街景無傳送點")
	map.travel_to("wanhua_old")
	var map2: Node = await _wait("MapScreen")
	if map2 == null: return _fail("換區後 MapScreen 未載入")
	await get_tree().process_frame
	if String(GameManager.player.current_area) != "wanhua_old": return _fail("travel_to 未換區")
	print("TEST PASS: Map2D 載入/傳送點/換區 OK")
	get_tree().quit(0)
func _wait(n: String, mx := 600) -> Node:
	for i in mx:
		await get_tree().process_frame
		var cs := get_tree().current_scene
		if cs and cs.name == n: return cs
	return null
func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m); get_tree().quit(1)
