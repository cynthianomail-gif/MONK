extends Node
## 驗證滑鼠自由視角（2026-07-05 FPS 式改版）：
## 1) 探索中應處於捕捉狀態（_ready 後自動捕捉）——判準用 rig._captured（邏輯狀態，
##    非 Input.mouse_mode 讀回值：headless 無真實視窗，OS 層 mouse_mode 寫入會被
##    靜默忽略、讀回恆為 VISIBLE，這是engine限制不是本次改動的 bug，CameraRig 已
##    改記自己的 _captured 供兩邊一致判斷；GPU 實機另以 _capture_camerarotate 系列
##    截圖佐證）
## 2) 注入 InputEventMouseMotion 給 CameraRig._unhandled_input → yaw 真的改變
## 3) 開 MenuShell → 滑鼠自動釋放；close() 後恢復捕捉
## 4) 軍火庫／地下遊藝場（後者是獨立場景樹，非 MapScreen 子節點）同樣接得到滑鼠視角
## 5) Esc（toggle_mouse_look）手動切換：關閉後注入滑鼠移動 yaw 應不再變動

func _ready() -> void:
	GameManager.new_game()

	# --- 1)+2) MapScreen（神社街）---
	var ms_scene := load("res://src/screens/MapScreen/MapScreen.tscn") as PackedScene
	var ms := ms_scene.instantiate()
	add_child(ms)
	await get_tree().process_frame
	await get_tree().process_frame

	var rig := _find_rig(ms)
	if rig == null:
		return _fail("MapScreen(神社街) 找不到 CameraRig")
	if not rig._captured:
		return _fail("探索中應自動捕捉滑鼠，實際 _captured=false")

	var yaw_before: float = rig._yaw
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(120.0, 0.0)
	rig._unhandled_input(motion)
	if is_equal_approx(rig._yaw, yaw_before):
		return _fail("注入滑鼠移動後 yaw 沒有變化（before=%.4f after=%.4f）" % [yaw_before, rig._yaw])
	print("MOUSELOOK: yaw %.4f -> %.4f（神社街，滑鼠水平移動 120px）" % [yaw_before, rig._yaw])

	# pitch clamp 檢查：狂灌極端 Y 位移，pitch 不該超出 [-35,15]
	var pitch_motion := InputEventMouseMotion.new()
	pitch_motion.relative = Vector2(0.0, -100000.0)
	for i in 20:
		rig._unhandled_input(pitch_motion)
	if rig._pitch_offset_deg > 15.01:
		return _fail("pitch clamp 上界失效：%.2f" % rig._pitch_offset_deg)
	var pitch_motion_down := InputEventMouseMotion.new()
	pitch_motion_down.relative = Vector2(0.0, 100000.0)
	for i in 40:
		rig._unhandled_input(pitch_motion_down)
	if rig._pitch_offset_deg < -35.01:
		return _fail("pitch clamp 下界失效：%.2f" % rig._pitch_offset_deg)
	print("MOUSELOOK: pitch clamp OK（%.2f 度）" % rig._pitch_offset_deg)

	# --- 3) 開 MenuShell → 滑鼠應自動釋放 ---
	var menu_shell_scene := load("res://src/ui/menu/MenuShell.tscn") as PackedScene
	var shell := menu_shell_scene.instantiate()
	shell.name = "MenuShell"
	shell.pause_game = false   # 測試不暫停整棵樹，避免干擾其餘 await
	ms.add_child(shell)
	await get_tree().process_frame
	rig._refresh_mouse_capture()
	if rig._captured:
		return _fail("MenuShell 開啟時應釋放滑鼠捕捉，實際 _captured=true")
	var yaw_locked: float = rig._yaw
	rig._unhandled_input(motion)
	if not is_equal_approx(rig._yaw, yaw_locked):
		return _fail("MenuShell 開啟時滑鼠移動不該再轉 yaw")
	print("MOUSELOOK: MenuShell 開啟時滑鼠自動釋放＋yaw 鎖住 OK")

	# 3b) MenuShell 開著時按 Esc 關選單，不該順便把 _mouse_look_enabled 切掉
	# （否則選單關閉後視角會卡死不會轉——這是本次修正的一個邊角案例）。
	var esc_ev := InputEventKey.new()
	esc_ev.physical_keycode = KEY_ESCAPE
	esc_ev.pressed = true
	rig._unhandled_input(esc_ev)   # 模擬選單開著時使用者按 Esc（真正關選單由 MenuShell 自己的 _input 處理，這裡只驗證 rig 沒誤切）
	if not rig._mouse_look_enabled:
		return _fail("MenuShell 開啟時按 Esc 不該影響 _mouse_look_enabled")
	print("MOUSELOOK: MenuShell 開啟時 Esc 不誤切開關 OK")

	shell.close()
	await get_tree().process_frame
	rig._refresh_mouse_capture()
	if not rig._captured:
		return _fail("MenuShell 關閉後應恢復捕捉，實際 _captured=false")
	print("MOUSELOOK: MenuShell 關閉後恢復捕捉 OK")

	# --- 5) Esc 手動關閉 ---
	var toggle_ev := InputEventKey.new()
	toggle_ev.physical_keycode = KEY_ESCAPE
	toggle_ev.pressed = true
	rig._unhandled_input(toggle_ev)
	if rig._captured:
		return _fail("Esc 手動關閉後應釋放捕捉，實際 _captured=true")
	var yaw_after_toggle_off: float = rig._yaw
	rig._unhandled_input(motion)
	if not is_equal_approx(rig._yaw, yaw_after_toggle_off):
		return _fail("Esc 關閉滑鼠視角後，滑鼠移動不該再轉 yaw")
	rig._unhandled_input(toggle_ev)   # 切回開啟，避免影響後續場景
	if not rig._captured:
		return _fail("Esc 再按一次應恢復捕捉，實際 _captured=false")
	print("MOUSELOOK: Esc 手動切換 OK")

	ms.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	# --- 4) 軍火庫（同 MapScreen，換 area）---
	GameManager.player.current_area = "armory"
	GameManager.set_flag("armory_unlocked", true)
	var ms2 := ms_scene.instantiate()
	add_child(ms2)
	await get_tree().process_frame
	await get_tree().process_frame
	var rig2 := _find_rig(ms2)
	if rig2 == null:
		return _fail("MapScreen(軍火庫) 找不到 CameraRig")
	if not rig2._captured:
		return _fail("軍火庫探索中應自動捕捉滑鼠")
	var yaw2_before: float = rig2._yaw
	rig2._unhandled_input(motion)
	if is_equal_approx(rig2._yaw, yaw2_before):
		return _fail("軍火庫：注入滑鼠移動後 yaw 沒有變化")
	print("MOUSELOOK: 軍火庫 yaw %.4f -> %.4f OK" % [yaw2_before, rig2._yaw])
	ms2.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	# --- 4) 地下遊藝場：獨立場景樹（非 MapScreen 子節點），CameraRig 仍須自理 ---
	var parlor := (load("res://src/screens/MapScreen/environments/UndergroundParlor.tscn") as PackedScene).instantiate()
	add_child(parlor)
	await get_tree().process_frame
	await get_tree().process_frame
	var rig3 := _find_rig(parlor)
	if rig3 == null:
		return _fail("地下遊藝場找不到 CameraRig")
	if not rig3._captured:
		return _fail("地下遊藝場探索中應自動捕捉滑鼠")
	var yaw3_before: float = rig3._yaw
	rig3._unhandled_input(motion)
	if is_equal_approx(rig3._yaw, yaw3_before):
		return _fail("地下遊藝場：注入滑鼠移動後 yaw 沒有變化")
	print("MOUSELOOK: 地下遊藝場 yaw %.4f -> %.4f OK" % [yaw3_before, rig3._yaw])

	parlor.queue_free()
	await get_tree().process_frame
	print("TEST PASS: 滑鼠自由視角（捕捉/UI自動釋放/pitch clamp/Esc切換/三場景）OK")
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
