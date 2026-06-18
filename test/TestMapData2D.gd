extends Node
## 驗證 areas/locations 已加 2D 欄位，型別正確。
func _ready() -> void:
	var areas: Dictionary = JsonLoader.load_json("res://data/areas.json")
	var locs: Dictionary = JsonLoader.load_json("res://data/map_locations.json")
	for aid in areas:
		var a: Dictionary = areas[aid]
		for k in ["scene_2d", "scene_spawn", "map_pos"]:
			if not a.has(k): return _fail("area %s 缺 %s" % [aid, k])
		if not (a.scene_spawn.has("x") and a.scene_spawn.has("y")): return _fail("area %s scene_spawn 缺 x/y" % aid)
	for lid in locs:
		var l: Dictionary = locs[lid]
		for k in ["scene_pos", "interior_2d"]:
			if not l.has(k): return _fail("loc %s 缺 %s" % [lid, k])
		if not (l.scene_pos.has("x") and l.scene_pos.has("y")): return _fail("loc %s scene_pos 缺 x/y" % lid)
	print("TEST PASS: 2D 地圖資料欄位齊全")
	get_tree().quit(0)
func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m); get_tree().quit(1)
