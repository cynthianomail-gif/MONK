extends Node
## windowed 兩連拍：預設視角 → 旋轉 90° 後，各截一張（驗證視角旋轉＋小地圖街道/羅盤跟轉）。
const SCENE := preload("res://src/screens/MapScreen/MapScreen.tscn")

func _ready() -> void:
	GameManager.new_game()
	var s := SCENE.instantiate()
	get_tree().root.add_child.call_deferred(s)
	if not OS.get_cmdline_user_args().has("smoke"):
		return
	for i in 60:
		await get_tree().process_frame
	await _snap("res://_camrot_a_default.png")
	var rig := _find_rig(s)
	if rig == null:
		print("CAP_CAMROT_FAIL rig not found")
		get_tree().quit(1)
		return
	rig._yaw = PI * 0.5
	for i in 40:
		await get_tree().process_frame
	await _snap("res://_camrot_b_rot90.png")
	rig._yaw = PI
	for i in 40:
		await get_tree().process_frame
	await _snap("res://_camrot_c_rot180.png")
	print("CAP_CAMROT_SAVED 3 shots")
	get_tree().quit()

func _snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(path)

func _find_rig(root: Node) -> Node:
	if root.get_script() != null and root.name == "CameraRig":
		return root
	for c in root.get_children():
		var r := _find_rig(c)
		if r != null:
			return r
	return null
