extends Node
var _picked := ""
func _ready() -> void:
	var areas: Dictionary = JsonLoader.load_json("res://data/areas.json")
	var cm := (load("res://src/screens/MapScreen/CityMap.tscn") as PackedScene).instantiate()
	add_child(cm); await get_tree().process_frame
	cm.district_selected.connect(func(a): _picked = a)
	cm.setup(areas)
	await get_tree().process_frame
	if not cm.is_locked("linsen"): return _fail("林森應為鎖定")
	if cm.is_locked("ximen"): return _fail("西門不應鎖")
	cm.pick("ximen")
	if _picked != "ximen": return _fail("選區未發 district_selected")
	cm.pick("linsen")
	if _picked != "ximen": return _fail("鎖區不應可選")
	print("TEST PASS: CityMap 鎖區/選區 OK")
	get_tree().quit(0)
func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m); get_tree().quit(1)
