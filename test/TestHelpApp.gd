extends Node
## headless 測試：K3「說明」app —— 驗證 MenuShell 註冊、節點存在、四區塊標題文字。
## 跑法：Godot --headless res://test/TestHelpApp.tscn

var ok: bool = true

func _ready() -> void:
	await get_tree().process_frame
	_test_menu_registration()
	await _test_app_content()
	print("HELP_APP_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		ok = false
		print("FAIL: ", msg)

func _test_menu_registration() -> void:
	var shell = load("res://src/ui/menu/MenuShell.tscn").instantiate()
	shell.set("pause_game", false)
	get_tree().root.add_child(shell)
	shell._show_device("phone")
	var phone_pages: Array = shell._devices["phone"]["pages"]
	var titles := []
	for p in phone_pages:
		titles.append(p.title)
	_check("說明" in titles, "MenuShell phone 裝置含「說明」頁")
	var idx: int = titles.find("說明")
	if idx != -1:
		shell._show_page(idx)
	shell.queue_free()

func _test_app_content() -> void:
	var app = load("res://src/ui/menu/pages/HelpApp.gd").new()
	get_tree().root.add_child(app)
	await get_tree().process_frame
	_check(is_instance_valid(app), "HelpApp 節點存在且存活")

	# 四區塊標題文字：遞迴收集所有 Label 文字，逐一核對存在。
	var all_texts: Array = []
	_collect_label_texts(app, all_texts)
	_check("鍵位表" in all_texts, "含「鍵位表」區塊標題")
	_check("戰鬥系統" in all_texts, "含「戰鬥系統」區塊標題")
	_check("時段規則" in all_texts, "含「時段規則」區塊標題")
	_check("小遊戲" in all_texts, "含「小遊戲」區塊標題")

	# 鍵位表逐條字樣核對（與程式碼查證出處一致，見 HelpApp.gd 註解）。
	var joined: String = "\n".join(all_texts)
	_check(joined.find("W / A / S / D") != -1, "鍵位表含 WASD 移動")
	_check(joined.find("Shift") != -1, "鍵位表含 Shift 跑步")
	_check(joined.find("E") != -1, "鍵位表含 E 互動")
	_check(joined.find("Esc") != -1, "鍵位表含 Esc")
	_check(joined.find("Tab") != -1, "鍵位表含 Tab 對話回想")
	_check(joined.find("休息") != -1, "鍵位表含休息說明")

	# 可捲動：根節點下應有 ScrollContainer。
	var found_scroll := false
	for c in app.get_children():
		if c is ScrollContainer:
			found_scroll = true
	_check(found_scroll, "HelpApp 頂層含 ScrollContainer（可捲動）")

	app.queue_free()
	await get_tree().process_frame

func _collect_label_texts(node: Node, out: Array) -> void:
	if node is Label:
		out.append(node.text)
	for c in node.get_children():
		_collect_label_texts(c, out)
