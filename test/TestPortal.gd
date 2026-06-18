extends Node
var _got := ""
func _ready() -> void:
	var p := (load("res://src/screens/MapScreen/Portal.tscn") as PackedScene).instantiate()
	add_child(p)
	await get_tree().process_frame
	p.setup_location("old_temple", "破舊古廟")
	if p.kind != "location": return _fail("setup_location kind 錯")
	if p.payload != "old_temple": return _fail("payload 錯")
	p.triggered.connect(func(pl): _got = pl)
	p.trigger()
	if _got != "old_temple": return _fail("trigger 未發 payload")
	p.setup_edge("ximen", "往西門")
	if p.kind != "edge" or p.payload != "ximen": return _fail("setup_edge 錯")
	print("TEST PASS: Portal setup/trigger OK")
	get_tree().quit(0)
func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m); get_tree().quit(1)
