extends Node
## 驗證 MapScreen 3D 接線：區場景載入、觸發點灑對、鐵叔 flag 分歧。
func _ready() -> void:
	var ms_scene := load("res://src/screens/MapScreen/MapScreen.tscn") as PackedScene
	if ms_scene == null: return _fail("MapScreen.tscn missing")
	if not ResourceLoader.exists("res://dialogue/armory_worker_locked.dtl"): return _fail("armory_worker_locked.dtl missing")
	if not ResourceLoader.exists("res://dialogue/armory_worker_freed.dtl"): return _fail("armory_worker_freed.dtl missing")

	# 1) 神社區：載 ShrineStreet + 灑 15 個 shrine 個別互動點（每 NPC/店/功能一點＋賽錢箱
	#    ＋打擊場/保齡球館入口，2026-07-03 從地下遊藝場搬過來）
	GameManager.new_game()
	var ms := ms_scene.instantiate()
	add_child(ms)
	await get_tree().process_frame
	await get_tree().process_frame
	var world: Node = ms.get_node("World")
	if world.get_child_count() == 0: return _fail("World 沒載入環境")
	var env: Node = world.get_child(0)
	if not String(env.name).contains("ShrineStreet"): return _fail("shrine 應載 ShrineStreet，實為 %s" % env.name)
	var trigs := get_tree().get_nodes_in_group("location_trigger")
	if trigs.size() != 15: return _fail("神社區應 15 觸發點，實 %d" % trigs.size())
	ms.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	# 2) 軍火庫：載 ArmoryDistrict + 2 觸發點（鐵叔＋地下遊藝場入口）
	GameManager.player.current_area = "armory"
	GameManager.set_flag("armory_unlocked", true)
	var ms2 := ms_scene.instantiate()
	add_child(ms2)
	await get_tree().process_frame
	await get_tree().process_frame
	var env2: Node = ms2.get_node("World").get_child(0)
	if not String(env2.name).contains("ArmoryDistrict"): return _fail("armory 應載 ArmoryDistrict，實為 %s" % env2.name)
	var trigs2 := get_tree().get_nodes_in_group("location_trigger")
	if trigs2.size() != 2: return _fail("軍火庫應 2 觸發點（鐵叔＋遊藝場入口），實 %d" % trigs2.size())

	# 3) 鐵叔 flag 分歧
	if not ms2.has_method("armory_npc_timeline"): return _fail("MapScreen 缺 armory_npc_timeline")
	GameManager.set_flag("ares_purified", false)
	if String(ms2.call("armory_npc_timeline")) != "armory_worker_locked": return _fail("阿瑞斯前應 locked")
	GameManager.set_flag("ares_purified", true)
	if String(ms2.call("armory_npc_timeline")) != "armory_worker_freed": return _fail("阿瑞斯後應 freed")
	ms2.queue_free()

	print("TEST PASS: MapScreen 3D 接線 OK")
	get_tree().quit(0)

func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m); get_tree().quit(1)
