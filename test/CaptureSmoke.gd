extends Node
## 煙霧驗證 GPU 截圖：街景走近互動提示（淡入後）／了塵 hub 對話選項／街景全景（無常駐黃字）／主線戰鬥進入畫面。
## ⚠ 只用視窗版 Godot 跑（headless 會卡 frame_post_draw）：
##   tools/godot/Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureSmoke.tscn

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await get_tree().process_frame

	await _capture_prompt_and_panorama()
	await _capture_liaochen_hub()
	await _capture_battle_entry()

	print("CAPTURE_SMOKE_DONE")
	get_tree().quit(0)

func _wait_for_scene(scene_name: String, max_frames: int = 600) -> Node:
	for i in max_frames:
		await get_tree().process_frame
		var cs := get_tree().current_scene
		if cs and cs.name == scene_name:
			return cs
	return null

func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SAVED ", path)

# 1) 街景全景 + 走近了塵觸發互動提示（淡入後穩定狀態）同一個場景連拍兩張。
func _capture_prompt_and_panorama() -> void:
	get_tree().current_scene = null  # 脫離 current_scene，換場時才不會釋放本截圖器
	GameManager.new_game()
	SceneRouter.go_to_map()
	var map: Node = await _wait_for_scene("MapScreen")
	if map == null:
		push_error("CAP FAIL: MapScreen 未載入")
		get_tree().quit(1)
		return
	for i in 60:
		await get_tree().process_frame
	# 全景先拍（尚未走近任何觸發點，確認零常駐黃字/名牌）
	await _save("res://_smoke_shrine_panorama.png")

	# 走近了塵觸發互動提示，等淡入 tween(0.25s) 跑完再拍
	map._on_trigger_entered("npc_liaochen")
	for i in 30:
		await get_tree().process_frame
	await _save("res://_smoke_prompt_fadein.png")

	# 保留 map 供下一段使用（了塵 hub 對話）
	set_meta("map", map)

# 2) 了塵 hub 對話選項畫面（4 功能 + 離開）
func _capture_liaochen_hub() -> void:
	var map: Node = get_meta("map", null)
	if map == null:
		push_error("CAP FAIL: 前一段 map 遺失")
		return
	map._interact()
	for i in range(30):
		if Dialogic.current_timeline != null:
			break
		await get_tree().process_frame
	if Dialogic.current_timeline == null:
		push_error("CAP FAIL: 了塵按 E 應啟動對話")
		return
	# liaochen_hub.dtl 開場有 join + 一行敘事 + 一行了塵開場白，才輪到選項畫面。
	# headless/GPU 擺拍模式下文字不會自動前進，需手動 handle_next_event() 推進兩次
	# （同 CaptureJobDialogue.gd 慣例），才能截到 4 選項+離開的畫面。
	for i in 2:
		await get_tree().create_timer(0.5).timeout
		if Dialogic.current_timeline != null:
			Dialogic.handle_next_event()
	for i in 40:
		await get_tree().process_frame
	await _save("res://_smoke_liaochen_hub.png")
	Dialogic.end_timeline()
	await get_tree().process_frame

# 3) 主線戰鬥進入畫面：pantheon_guard（c1_armory_breach 用敵）。
func _capture_battle_entry() -> void:
	var svc := SubViewport.new()
	svc.size = Vector2i(1920, 1080)
	svc.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_tree().root.add_child.call_deferred(svc)
	await get_tree().process_frame
	var inst: Node = (load("res://src/screens/BattleScreen/BattleScreen.tscn") as PackedScene).instantiate()
	svc.add_child(inst)
	await get_tree().process_frame
	inst.setup("pantheon_guard")
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	svc.get_texture().get_image().save_png("res://_smoke_battle_entry.png")
	print("SAVED res://_smoke_battle_entry.png")
	svc.queue_free()
	await get_tree().process_frame
