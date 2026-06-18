extends Node
## headless 結構驗證 Hd2dStreet：環境/地面（Task 1）→ 建築（Task 2）
## → 後製 camera_attributes（Task 5）→ 氛圍（Task 6）逐 task 擴充。
## 跑法：Godot_..._console.exe --headless --path D:/monk/MONK res://test/TestHd2dStreet.tscn

const Hd2dStreet := preload("res://src/screens/MapScreen/environments/Hd2dStreet.gd")

func _ready() -> void:
	await get_tree().process_frame
	var street := Hd2dStreet.new()
	get_tree().root.add_child(street)
	for i in 3:
		await get_tree().process_frame

	var ground := street.get_node_or_null("Ground")
	if ground == null or not (ground is MeshInstance3D):
		return _fail("無 Ground MeshInstance3D")

	var we := _find_we(street)
	if we == null:
		return _fail("無 WorldEnvironment")
	if we.environment == null:
		return _fail("WorldEnvironment.environment 為 null")
	if not we.environment.glow_enabled:
		return _fail("glow 未開")

	print("TEST PASS: Hd2dStreet 環境＋地面＋glow OK")
	get_tree().quit(0)

func _find_we(n: Node) -> WorldEnvironment:
	for c in n.get_children():
		if c is WorldEnvironment:
			return c
	return null

func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m)
	get_tree().quit(1)
