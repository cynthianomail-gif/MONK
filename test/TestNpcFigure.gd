extends Node
## NpcFigure：缺檔優雅略過(不 crash、_model null)、元件可實例化。
func _ready() -> void:
	var NF := load("res://src/screens/MapScreen/npc_figure.gd")
	if NF == null: return _fail("npc_figure.gd 載入失敗")
	var fig: Node3D = NF.new()
	add_child(fig)
	fig.setup("definitely_missing_model")
	await get_tree().process_frame
	if fig.get("_model") != null: return _fail("缺檔應略過、_model 應為 null")
	print("TEST PASS: NpcFigure 缺檔優雅略過")
	get_tree().quit(0)
func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m); get_tree().quit(1)
