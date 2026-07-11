extends Node
## 2026-07-11 改版：原「滑鼠自由視角」測試已隨滑鼠視角整個拿掉而失去驗證對象
## （使用者實機回饋滑鼠視角時好時壞，拍板探索地圖整個不用滑鼠轉視角，只留 Q/E
## 鍵盤轉視角）。保留檔名 TestMouseLook（沿用 _qa_run_tests.ps1 既有登記，避免動
## 批次腳本），內容改寫為驗證這次改版的兩件事：
## 1) 滑鼠視角確實被拿乾淨（CameraRig 不再有 _input/_unhandled_input、mouse_mode
##    全程 VISIBLE）、Q/E 鍵盤轉視角照常運作（含 MenuShell 開啟時仍會鎖住）。
## 2) 對話（Dialogic）進行中，鍵盤轉視角＋玩家 WASD 移動＋漫遊敵人巡邏／追擊
##    全部鎖住，對話結束後恢復（原本只有滑鼠視角會被 UI 擋、鍵盤旋轉/玩家移動
##    完全沒檢查對話狀態，是本次一併修正的缺口）。
## 涵蓋神社街／軍火庫（MapScreen 子節點）與地下遊藝場（獨立場景樹）三處 CameraRig。

const ROAMING_ENEMY := preload("res://src/screens/MapScreen/RoamingEnemy.gd")

func _ready() -> void:
	GameManager.new_game()

	# --- MapScreen（神社街）---
	var ms_scene := load("res://src/screens/MapScreen/MapScreen.tscn") as PackedScene
	var ms := ms_scene.instantiate()
	add_child(ms)
	await get_tree().process_frame
	await get_tree().process_frame

	var rig := _find_rig(ms)
	if rig == null:
		return _fail("MapScreen(神社街) 找不到 CameraRig")

	# 1) 滑鼠視角拿乾淨：不再有處理滑鼠的虛函式、游標全程可見。
	if rig.has_method("_input"):
		return _fail("CameraRig 不該再有 _input()（滑鼠視角處理應已整個移除）")
	if rig.has_method("_unhandled_input"):
		return _fail("CameraRig 不該再有 _unhandled_input()（Esc 切換滑鼠視角應已移除）")
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		return _fail("探索中游標應全程可見，實際 mouse_mode=%d" % Input.mouse_mode)
	print("MOUSELOOK: 滑鼠視角處理已移除、游標可見 OK")

	# 2) Q/E 鍵盤轉視角照常。
	var yaw_before: float = rig._yaw
	Input.action_press("cam_left")
	for i in 6:
		await get_tree().physics_frame
	Input.action_release("cam_left")
	if is_equal_approx(rig._yaw, yaw_before):
		return _fail("按住 cam_left(Q) 後 yaw 沒有變化（before=%.4f after=%.4f）" % [yaw_before, rig._yaw])
	print("KEYLOOK: yaw %.4f -> %.4f（神社街，cam_left 6 個 physics frame）" % [yaw_before, rig._yaw])

	# 3) 開 MenuShell → Q/E 應被鎖住（沿用 _blocking_ui_present 既有判準）。
	var menu_shell_scene := load("res://src/ui/menu/MenuShell.tscn") as PackedScene
	var shell := menu_shell_scene.instantiate()
	shell.name = "MenuShell"
	shell.pause_game = false
	ms.add_child(shell)
	await get_tree().process_frame
	var yaw_locked: float = rig._yaw
	Input.action_press("cam_left")
	for i in 6:
		await get_tree().physics_frame
	Input.action_release("cam_left")
	if not is_equal_approx(rig._yaw, yaw_locked):
		return _fail("MenuShell 開啟時 cam_left 不該再轉 yaw")
	print("KEYLOOK: MenuShell 開啟時鍵盤轉視角鎖住 OK")
	shell.close()
	await get_tree().process_frame

	# --- 4) 對話中鎖住：鍵盤轉視角＋玩家移動＋漫遊敵人 ---
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return _fail("找不到玩家節點")
	player.global_position = Vector3(0.0, 1.2, 6.0)
	await get_tree().physics_frame

	# 貼一隻漫遊敵人在玩家身邊，驗證對話中不會偷偷追／觸發遭遇戰。
	var enemy: Node3D = ROAMING_ENEMY.new()
	ms.get_node("World").get_child(0).add_child(enemy)
	enemy.setup({
		"enemy_id": "street_punk", "model": "street_punk",
		"patrol_center": {"x": player.global_position.x, "z": player.global_position.z},
		"patrol_radius": 4.0,
	})
	var enemy_caught := false
	enemy.caught_player.connect(func(_id): enemy_caught = true)
	await get_tree().physics_frame
	await get_tree().physics_frame

	ms._on_trigger_entered("npc_liaochen")
	ms._interact()
	var waited := 0
	while waited < 12 and Dialogic.current_timeline == null:
		await get_tree().process_frame
		waited += 1
	if Dialogic.current_timeline == null:
		return _fail("liaochen_hub 對話未能啟動，無法驗證對話中鎖住")

	var yaw_in_dialogue: float = rig._yaw
	# 只比對水平(x/z)：垂直 y 會因重力自然下墜到地板，那是預期物理行為（PlayerController
	# 對話中只鎖水平輸入，仍照常套用重力＋move_and_slide()），不是本測試要驗證的對象。
	var pos_xz_in_dialogue := Vector2(player.global_position.x, player.global_position.z)
	var enemy_pos_in_dialogue: Vector3 = enemy.global_position
	Input.action_press("cam_left")
	Input.action_press("ui_right")
	for i in 12:
		await get_tree().physics_frame
	Input.action_release("cam_left")
	Input.action_release("ui_right")

	if not is_equal_approx(rig._yaw, yaw_in_dialogue):
		return _fail("對話中 cam_left 不該轉 yaw（before=%.4f after=%.4f）" % [yaw_in_dialogue, rig._yaw])
	var pos_xz_after := Vector2(player.global_position.x, player.global_position.z)
	if not pos_xz_after.is_equal_approx(pos_xz_in_dialogue):
		return _fail("對話中 WASD 不該水平移動玩家（before=%s after=%s）" % [pos_xz_in_dialogue, pos_xz_after])
	if not enemy.global_position.is_equal_approx(enemy_pos_in_dialogue):
		return _fail("對話中漫遊敵人不該繼續移動（before=%s after=%s）" % [enemy_pos_in_dialogue, enemy.global_position])
	if enemy_caught:
		return _fail("對話中不該觸發 caught_player（敵人不該在對話中追到玩家）")
	print("DIALOGUE-LOCK: 對話中鍵盤轉視角／玩家移動／漫遊敵人皆鎖住 OK")

	# skip_ending=true：同步清掉 current_timeline，不必等 ending timeline 播完
	# （同 TestDialogueHistory.gd 慣例；不加 true 的話 current_timeline 要再等好幾幀
	# ending timeline 跑完才會歸 null，逐幀等會不必要地拖長且不穩定）。
	await Dialogic.end_timeline(true)
	await get_tree().process_frame

	# 5) 對話結束後恢復：鍵盤轉視角與玩家移動都應能再次生效。
	var yaw_after_dialogue: float = rig._yaw
	var pos_xz_after_dialogue := Vector2(player.global_position.x, player.global_position.z)
	Input.action_press("cam_left")
	Input.action_press("ui_right")
	for i in 12:
		await get_tree().physics_frame
	Input.action_release("cam_left")
	Input.action_release("ui_right")
	if is_equal_approx(rig._yaw, yaw_after_dialogue):
		return _fail("對話結束後 cam_left 應恢復能轉 yaw")
	var pos_xz_final := Vector2(player.global_position.x, player.global_position.z)
	if pos_xz_final.is_equal_approx(pos_xz_after_dialogue):
		return _fail("對話結束後 WASD 應恢復能水平移動玩家")
	print("DIALOGUE-LOCK: 對話結束後鍵盤轉視角／玩家移動皆恢復 OK")

	enemy.queue_free()
	ms.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	# --- 6) 軍火庫（MapScreen 的另一區）：滑鼠視角移除＋Q/E 照常 ---
	GameManager.player.current_area = "armory"
	GameManager.set_flag("armory_unlocked", true)
	var ms2 := ms_scene.instantiate()
	add_child(ms2)
	await get_tree().process_frame
	await get_tree().process_frame
	var rig2 := _find_rig(ms2)
	if rig2 == null:
		return _fail("MapScreen(軍火庫) 找不到 CameraRig")
	if rig2.has_method("_input"):
		return _fail("軍火庫 CameraRig 不該再有 _input()")
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		return _fail("軍火庫游標應全程可見，實際 mouse_mode=%d" % Input.mouse_mode)
	var yaw2_before: float = rig2._yaw
	Input.action_press("cam_right")
	for i in 6:
		await get_tree().physics_frame
	Input.action_release("cam_right")
	if is_equal_approx(rig2._yaw, yaw2_before):
		return _fail("軍火庫：按住 cam_right(E) 後 yaw 沒有變化")
	print("KEYLOOK: 軍火庫 yaw %.4f -> %.4f OK" % [yaw2_before, rig2._yaw])
	ms2.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	# --- 7) 地下遊藝場：獨立場景樹（非 MapScreen 子節點），CameraRig 仍須自理 ---
	var parlor := (load("res://src/screens/MapScreen/environments/UndergroundParlor.tscn") as PackedScene).instantiate()
	add_child(parlor)
	await get_tree().process_frame
	await get_tree().process_frame
	var rig3 := _find_rig(parlor)
	if rig3 == null:
		return _fail("地下遊藝場找不到 CameraRig")
	if rig3.has_method("_input"):
		return _fail("地下遊藝場 CameraRig 不該再有 _input()")
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		return _fail("地下遊藝場游標應全程可見，實際 mouse_mode=%d" % Input.mouse_mode)
	var yaw3_before: float = rig3._yaw
	Input.action_press("cam_right")
	for i in 6:
		await get_tree().physics_frame
	Input.action_release("cam_right")
	if is_equal_approx(rig3._yaw, yaw3_before):
		return _fail("地下遊藝場：按住 cam_right(E) 後 yaw 沒有變化")
	print("KEYLOOK: 地下遊藝場 yaw %.4f -> %.4f OK" % [yaw3_before, rig3._yaw])

	parlor.queue_free()
	await get_tree().process_frame
	print("TEST PASS: 鍵盤轉視角（Q/E＋MenuShell鎖住）／滑鼠視角已移除／對話中移動與視角鎖住＋恢復／三場景 OK")
	get_tree().quit(0)

func _find_rig(root: Node) -> Node:
	if root.name == "CameraRig" and root.get_script() != null:
		return root
	for c in root.get_children():
		var r := _find_rig(c)
		if r != null:
			return r
	return null

func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m)
	get_tree().quit(1)
