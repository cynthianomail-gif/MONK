extends Node
## 驗收擷取：手機「設定」頁新增的「儲存進度」／「回主選單」兩鈕＋未儲存離開三選一確認框。
## 走正式 src/ 程式碼（MenuShell 實例 → 開手機裝置 → 設定頁），不是另造 mockup。
## ⚠ 只用視窗版 Godot 跑（headless 會卡 frame_post_draw）：
##   tools/godot/Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureSettingsExit.tscn

const MENU_SHELL := preload("res://src/ui/menu/MenuShell.tscn")

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await get_tree().process_frame

	await _capture_settings_page()
	await _capture_exit_confirm_dialog()

	print("CAPTURE_SETTINGS_EXIT_DONE")
	get_tree().quit(0)

func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SAVED ", path)

func _open_settings_shell() -> Node:
	var shell = MENU_SHELL.instantiate()
	shell.set("pause_game", false)
	get_tree().root.add_child(shell)
	for i in 4:
		await get_tree().process_frame
	shell._show_device("phone")
	await get_tree().process_frame
	var pages: Array = shell._devices["phone"]["pages"]
	var idx := -1
	for i in pages.size():
		if pages[i].title == "設定":
			idx = i
			break
	shell._show_page(idx)
	for i in 6:
		await get_tree().process_frame
	return shell

## 設定頁本體：MenuShell → 手機裝置 → 設定頁籤，呈現既有四項設定＋新的兩顆按鈕。
func _capture_settings_page() -> void:
	var shell := await _open_settings_shell()
	await _save("res://_settings_page.png")
	shell.queue_free()
	await get_tree().process_frame

## 未儲存離開確認框：直接用 SettingsApp 真實流程觸發（造一筆未儲存變更 → 按「回主選單」）。
func _capture_exit_confirm_dialog() -> void:
	var shell := await _open_settings_shell()

	GameManager.new_game()
	SaveManager._last_saved_snapshot = SaveManager._player_snapshot()
	GameManager.player.gold += 999  # 製造一筆未儲存變更

	var settings_page: Node = shell._content.get_child(0)
	var exit_btn: Button = _find_button_by_text(settings_page, "回主選單")
	if exit_btn != null:
		exit_btn.pressed.emit()
	for i in 6:
		await get_tree().process_frame

	await _save("res://_settings_exit_confirm.png")
	var dlg := get_tree().root.get_node_or_null("ExitConfirmDialog")
	if dlg != null:
		dlg.queue_free()
	shell.queue_free()
	await get_tree().process_frame

func _find_button_by_text(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for c in node.get_children():
		var found := _find_button_by_text(c, text)
		if found != null:
			return found
	return null
