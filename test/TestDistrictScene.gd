extends Node
func _ready() -> void:
	var areas: Dictionary = JsonLoader.load_json("res://data/areas.json")
	var locs: Dictionary = JsonLoader.load_json("res://data/map_locations.json")
	var ds := (load("res://src/screens/MapScreen/DistrictScene.tscn") as PackedScene).instantiate()
	add_child(ds)
	await get_tree().process_frame
	var ximen: Dictionary = areas["ximen"]
	var xlocs := _by_district(locs, "ximen")
	# period 3：ximen_mrt(1,2,3) 開、wannian_mall(0,1,2) 不開 → 1 地點 + 1 邊界 = 2
	ds.setup(ximen, xlocs, 3)
	await get_tree().process_frame
	if ds.portal_count() != 2: return _fail("西門 period3 應為 2，實得 %d" % ds.portal_count())
	# period 1：兩地點都開 + 1 邊界 = 3
	ds.setup(ximen, xlocs, 1)
	await get_tree().process_frame
	if ds.portal_count() != 3: return _fail("西門 period1 應為 3，實得 %d" % ds.portal_count())
	print("TEST PASS: DistrictScene 傳送點閘門 OK")
	get_tree().quit(0)
func _by_district(locs: Dictionary, d: String) -> Array:
	var out: Array = []
	for id in locs:
		var l: Dictionary = locs[id].duplicate(); l["id"] = id
		if l.district == d: out.append(l)
	return out
func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m); get_tree().quit(1)
