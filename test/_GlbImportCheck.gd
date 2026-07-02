extends SceneTree
## headless 驗證 GLB 能被 Godot GLTFDocument 正常解析（不需進 editor import 管線）。
## 跑法：Godot_..._console.exe --headless --path D:/monk/MONK --script res://test/_GlbImportCheck.gd -- <絕對或res://路徑>

func _init():
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("GLB_CHECK_ERROR no path arg")
		quit(1)
		return
	var path := args[0]
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(path, state)
	if err != OK:
		print("GLB_CHECK_ERROR append_from_file err=", err, " path=", path)
		quit(1)
		return
	var scene := doc.generate_scene(state)
	if scene == null:
		print("GLB_CHECK_ERROR generate_scene null path=", path)
		quit(1)
		return
	print("GLB_CHECK_OK path=", path, " meshes=", state.get_meshes().size(), " nodes=", state.get_nodes().size(), " anims=", state.get_animations().size())
	quit(0)
