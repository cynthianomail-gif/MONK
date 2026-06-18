extends Node
## headless 驗證分區切換：①西門區載入 XimenStreet＋只建 ximen 觸發
## ②travel_to 切到萬華佔位＋換成該區觸發 ③current_area 寫進 player（存檔保得住）。
## 跑法：Godot_..._console.exe --headless --path D:/monk/MONK res://test/TestMapArea.tscn

func _ready() -> void:
	await get_tree().process_frame
	get_tree().current_scene = null  # 脫離 current_scene，SceneRouter 換場時才不會釋放本測試
	GameManager.new_game()  # current_area=ximen, spawn 西門

	# ① 進西門
	SceneRouter.go_to_map()
	var map: Node = await _wait_for_scene("MapScreen")
	if map == null:
		return _fail("MapScreen 未載入")
	await get_tree().process_frame
	var env := map.get_node_or_null("Environment")
	if env == null or env.get_child_count() == 0:
		return _fail("Environment 未掛環境")
	if not (env.get_child(0).name.begins_with("XimenStreet")):
		return _fail("西門區未載 XimenStreet，實際=%s" % env.get_child(0).name)
	var ximen_triggers := get_tree().get_nodes_in_group("location_trigger").size()
	print("TEST: 西門觸發數 = %d" % ximen_triggers)
	if ximen_triggers != 2:
		return _fail("西門觸發數應為 2（ximen_mrt+wannian_mall），實得 %d" % ximen_triggers)

	# ② 快速移動到萬華（佔位）—— 等「新的」MapScreen 實例（換場中舊實例同名仍在）
	var old_map := map
	map.travel_to("wanhua_old")
	map = await _wait_for_new_scene("MapScreen", old_map)
	if map == null:
		return _fail("travel 後 MapScreen 未載入")
	await get_tree().process_frame
	if GameManager.player.current_area != "wanhua_old":
		return _fail("current_area 未更新為 wanhua_old")
	env = map.get_node_or_null("Environment")
	if env == null or env.get_child_count() == 0 or not env.get_child(0).name.begins_with("PlaceholderArea"):
		return _fail("萬華區未載 PlaceholderArea")
	var wanhua_triggers := get_tree().get_nodes_in_group("location_trigger").size()
	print("TEST: 萬華觸發數 = %d" % wanhua_triggers)
	if wanhua_triggers != 2:  # old_temple + zen_bbq
		return _fail("萬華觸發數應為 2（old_temple+zen_bbq），實得 %d" % wanhua_triggers)

	# ③ 存檔→改值→讀檔，current_area 應還原
	SaveManager.save_game()
	GameManager.player.current_area = "ximen"
	SaveManager.load_game()
	if GameManager.player.current_area != "wanhua_old":
		return _fail("讀檔未還原 current_area")

	print("TEST PASS: 分區切換 ①②③ 全通過")
	get_tree().quit(0)

func _wait_for_scene(scene_name: String, max_frames: int = 600) -> Node:
	for i in max_frames:
		await get_tree().process_frame
		var cs := get_tree().current_scene
		if cs and cs.name == scene_name:
			return cs
	return null

func _wait_for_new_scene(scene_name: String, old: Node, max_frames: int = 600) -> Node:
	for i in max_frames:
		await get_tree().process_frame
		var cs := get_tree().current_scene
		if cs and cs != old and cs.name == scene_name:
			return cs
	return null

func _fail(msg: String) -> void:
	push_error("TEST FAIL: %s" % msg)
	get_tree().quit(1)
