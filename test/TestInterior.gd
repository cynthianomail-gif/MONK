extends Node
func _ready() -> void:
	var li = (load("res://src/screens/MapScreen/LocationInterior.tscn") as PackedScene).instantiate()
	add_child(li)
	await get_tree().process_frame
	var loc := {"name": "破舊古廟", "interior_2d": "res://nonexist.png", "actions": ["main_quest", "save"]}
	var got_actions: Array = []
	li.open(loc, func(_title, actions, _cb): got_actions.assign(actions))
	if got_actions != ["main_quest", "save"]: return _fail("內景未把 actions 交給選單回呼")
	if not li.visible: return _fail("open 後應顯示")
	li.close()
	if li.visible: return _fail("close 後應隱藏")
	print("TEST PASS: LocationInterior open/close OK")
	get_tree().quit(0)
func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m); get_tree().quit(1)
