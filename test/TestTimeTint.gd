extends Node
func _ready() -> void:
	var ds := (load("res://src/screens/MapScreen/DistrictScene.tscn") as PackedScene).instantiate()
	add_child(ds); await get_tree().process_frame
	ds.apply_period_tint(0)
	var morn: Color = ds.get_node("TimeTint").color
	ds.apply_period_tint(3)
	var night: Color = ds.get_node("TimeTint").color
	if morn == night: return _fail("時段未改變調色")
	if night.v >= morn.v: return _fail("夜應比上午暗")
	print("TEST PASS: 時段調色 OK")
	get_tree().quit(0)
func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m); get_tree().quit(1)
