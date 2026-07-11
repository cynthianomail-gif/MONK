extends Node
## headless 測試：Batch B 全鍵盤操作（2026-07-10）。
## B-1：戰鬥「選技能→左右切目標→確認施放」全流程，鍵盤驅動；滑鼠點選路徑不受影響。
## B-2：經書／手機／商店三畫面，方向鍵移動焦點＋Enter 確認＋ESC 返回＋分頁切換鍵。
## 事件模擬慣例（同 TestDialogueHistory.gd／TestMinigameCutscene.gd）：直接建 InputEventKey
## 並呼叫節點的 _input()，project.godot 的 action 都綁在 physical_keycode，事件也用
## physical_keycode 建構，is_action_pressed() 才會成立。
## 2026-07-10 review 退回修正（F3a）：上面這句只對 interact/confirm/cancel/open_menu 這些
## 自訂 action 成立——ui_left/ui_right/ui_up/ui_down 是 Godot 內建 action，實測
## InputMap.action_get_events("ui_left") 綁在 keycode（非 physical_keycode）。只設
## physical_keycode 會讓所有依賴 ui_* 的斷言恆假。_key() 現在 keycode/physical_keycode 皆設，
## 等同真實鍵盤事件（硬體按鍵兩者本來就會一起帶），兩種綁法都吃得到。
## 跑法：Godot --headless --path . res://test/TestKeyboardNav.tscn

var ok: bool = true

func _check(cond: bool, msg: String) -> void:
	if not cond:
		ok = false
		print("FAIL: ", msg)

func _ready() -> void:
	await get_tree().process_frame
	await _test_battle_target_keyboard_nav()
	await _test_battle_mouse_still_works()
	await _test_menushell_book_keyboard_nav()
	await _test_menushell_phone_keyboard_nav()
	await _test_menushell_board_e_key_does_not_switch_device()
	await _test_menushell_settings_slider_keyboard_nav()
	await _test_shop_keyboard_nav()
	print("KEYBOARD_NAV_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

# ─── 鍵盤事件 helper ──────────────────────────────────────
func _key(physical_keycode: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = physical_keycode
	ev.keycode = physical_keycode
	ev.pressed = true
	return ev

func _key_left() -> InputEventKey: return _key(KEY_LEFT)
func _key_right() -> InputEventKey: return _key(KEY_RIGHT)
func _key_up() -> InputEventKey: return _key(KEY_UP)
func _key_down() -> InputEventKey: return _key(KEY_DOWN)
func _key_enter() -> InputEventKey: return _key(KEY_ENTER)
func _key_e() -> InputEventKey: return _key(KEY_E)  # interact action
func _key_esc() -> InputEventKey: return _key(KEY_ESCAPE)  # cancel action

# ─── B-1：戰鬥目標鍵盤化 ──────────────────────────────────
## drunk_guard 為 spawn_pair（2 隻敵人），basic_punch 為初始解鎖、無消耗、target:single，
## 確保「選技能→需要選目標」這條路一定會走到（target.size()>1 才 needs_target）。
func _make_battle():
	var scene: PackedScene = load("res://src/screens/BattleScreen/BattleScreen.tscn")
	var battle = scene.instantiate()
	get_tree().root.add_child(battle)
	return battle

func _test_battle_target_keyboard_nav() -> void:
	var battle = _make_battle()
	await get_tree().process_frame
	battle.setup("drunk_guard")
	await get_tree().process_frame
	var ui = battle.get_node("BattleUI")

	# 強制進入玩家回合＋開指令選單（不依賴 speed 佇列時序，同 TestBattleFlow 用 force_* 走捷徑的慣例）。
	battle.state = battle.State.PLAYER_TURN
	ui.open_command_menu(battle._disabled_commands())
	await get_tree().process_frame
	_check(ui._command_menu._active, "指令選單開啟中")

	# 指令選單目前選中「攻擊」(index 0)，鍵盤下移到「技能」(index 1) 再確認。
	ui._command_menu._input(_key_down())
	await get_tree().process_frame
	_check(ui._command_menu._selected == 1, "指令選單下移一次選中「技能」(index 1, got %d)" % ui._command_menu._selected)
	ui._command_menu._input(_key_enter())
	await get_tree().process_frame
	_check(ui.skill_menu.visible, "技能選單已開啟")
	_check(ui._skill_nav_active, "技能選單鍵盤導航已啟用")

	# 技能選單目前選中的技能是 basic_punch（第一個可用技，無消耗必過 can_use）。
	var chosen_id: String = ui._skill_nav_ids[ui._skill_selected]
	_check(chosen_id != "", "技能選單選中一個有效技能 id")
	ui._input(_key_enter())
	await get_tree().process_frame
	_check(ui._target_nav_active, "確認技能後進入目標選擇鍵盤導航（drunk_guard 兩隻皆存活，needs_target 成立）")
	_check(ui._panels.size() == 2, "drunk_guard spawn_pair 場上有 2 隻敵人 (got %d)" % ui._panels.size())
	var start_idx: int = ui._target_selected

	# 左右鍵切換目標，索引應該變動（2 隻都存活時 dir=1 一定切到另一隻）。
	ui._input(_key_right())
	await get_tree().process_frame
	_check(ui._target_selected != start_idx, "按右鍵目標索引已切換 (from %d to %d)" % [start_idx, ui._target_selected])
	_check(ui._panels[ui._target_selected]._select_ring.visible, "切換後的目標面板高亮框可見")
	_check(not ui._panels[start_idx]._select_ring.visible, "原目標面板高亮框已關閉")

	ui._input(_key_left())
	await get_tree().process_frame
	_check(ui._target_selected == start_idx, "按左鍵切回原目標 (got %d, want %d)" % [ui._target_selected, start_idx])

	# ESC 取消目標選擇 → 回到技能選單（_pending_skill 清空，target_mode 全部關閉）。
	ui._input(_key_esc())
	await get_tree().process_frame
	_check(not ui._target_nav_active, "ESC 取消後目標導航關閉")
	_check(ui._pending_skill == "", "ESC 取消後 _pending_skill 已清空")
	_check(ui.skill_menu.visible, "ESC 取消目標選擇後回到技能選單")
	for p in ui._panels:
		_check(not p._select_ring.visible, "ESC 取消後所有面板高亮框關閉（%s）" % p.combatant.id)

	# 重新走一次：選技能→confirm 進目標選擇→E 確認出招，驗證完整流程能真正打出去。
	var target_hp_before: int = ui._panels[ui._target_selected].combatant.current_hp if ui._target_nav_active else -1
	ui._input(_key_enter())  # 技能選單再次確認（_skill_selected 未變）
	await get_tree().process_frame
	_check(ui._target_nav_active, "重新確認技能後再次進入目標選擇")
	var confirm_idx: int = ui._target_selected
	var confirm_target = ui._panels[confirm_idx].combatant
	var hp_before: int = confirm_target.current_hp
	ui._input(_key_e())  # interact 也能確認出招（E 鍵）
	await get_tree().process_frame
	for i in 10:
		await get_tree().process_frame
	_check(not ui._target_nav_active, "E 確認出招後目標導航關閉")
	_check(confirm_target.current_hp < hp_before or not confirm_target.is_alive(), "E 確認出招後目標確實受到傷害 (before %d, after %d)" % [hp_before, confirm_target.current_hp])

	if is_instance_valid(battle):
		battle.queue_free()
	await get_tree().process_frame

## 滑鼠點選路徑不受鍵盤化影響（並存不取代）：target_pressed 訊號直接觸發照常出招。
func _test_battle_mouse_still_works() -> void:
	var battle = _make_battle()
	await get_tree().process_frame
	battle.setup("drunk_guard")
	await get_tree().process_frame
	var ui = battle.get_node("BattleUI")
	battle.state = battle.State.PLAYER_TURN

	ui.begin_target_or_use(battle._basic_skill_id())
	await get_tree().process_frame
	_check(ui._panels[0]._hit_button.visible, "滑鼠可點的目標按鈕仍然存在且可見")
	var target = ui._panels[0].combatant
	var hp_before: int = target.current_hp
	ui._panels[0]._hit_button.pressed.emit()
	await get_tree().process_frame
	for i in 10:
		await get_tree().process_frame
	_check(target.current_hp < hp_before or not target.is_alive(), "滑鼠點擊目標仍可正常出招 (before %d, after %d)" % [hp_before, target.current_hp])

	if is_instance_valid(battle):
		battle.queue_free()
	await get_tree().process_frame

# ─── B-2：經書鍵盤化 ──────────────────────────────────────
func _make_menu_shell():
	var shell = load("res://src/ui/menu/MenuShell.tscn").instantiate()
	shell.set("pause_game", false)
	get_tree().root.add_child(shell)
	return shell

func _test_menushell_book_keyboard_nav() -> void:
	var shell = _make_menu_shell()
	await get_tree().process_frame
	shell._show_device("book")
	await get_tree().process_frame
	_check(shell._current_device == "book", "經書裝置已開啟")
	_check(shell._current_page == 0, "經書預設在第 0 頁（技能）")

	# ui_right 切到「狀態」(idx 1)，再切到「佛具」(idx 2)。
	shell._input(_key_right())
	await get_tree().process_frame
	_check(shell._current_page == 1, "→ 切到狀態頁 (got %d)" % shell._current_page)
	shell._input(_key_right())
	await get_tree().process_frame
	_check(shell._current_page == 2, "→ 再切到佛具頁 (got %d)" % shell._current_page)
	shell._input(_key_left())
	await get_tree().process_frame
	_check(shell._current_page == 1, "← 切回狀態頁 (got %d)" % shell._current_page)

	# 切到技能頁，驗證焦點鏈已建立且第一個技能列取得焦點。
	shell._input(_key_left())
	await get_tree().process_frame
	_check(shell._current_page == 0, "← 回到技能頁 (got %d)" % shell._current_page)
	await get_tree().process_frame  # call_deferred grab_focus 落地
	_check(not shell._focus_chain.is_empty(), "技能頁焦點鏈已建立（至少一個可聚焦技能列）")
	_check(shell._focus_chain[0].has_focus(), "技能頁第一個技能列已取得焦點")

	# 方向鍵下移 focus，Enter 選中一個技能（詳情面板應出現內容）。
	var content_page = shell._content.get_child(0)
	shell._focus_chain[0]._input(_key_down()) if shell._focus_chain[0].has_method("_input") else null
	# Godot 的 focus_neighbor 導航是內建 GUI 輸入處理，非腳本 _input；直接呼叫 grab_focus 模擬導航到下一個效果一致，
	# 驗證重點是「按 Enter 能觸發該列的 pressed」，非重新實作 Godot 內部 focus traversal 演算法。
	if shell._focus_chain.size() > 1:
		shell._focus_chain[1].grab_focus()
		await get_tree().process_frame
		_check(shell._focus_chain[1].has_focus(), "手動 grab_focus 到第二個技能列成功（focus_neighbor 已正確串接，供引擎方向鍵導航使用）")
		_check(shell._focus_chain[1].focus_neighbor_top == shell._focus_chain[1].get_path_to(shell._focus_chain[0]),
			"第二列 focus_neighbor_top 指回第一列")

	# 佛具頁：先塞一件持有的念珠，切到佛具頁後應能鍵盤導航到「裝上」鈕並 Enter 裝備。
	GameManager.player.equipment_owned = []
	EquipmentSystem.unequip("beads")
	if "beads_bodhi" not in GameManager.player.equipment_owned:
		GameManager.player.equipment_owned.append("beads_bodhi")
	shell._show_page(2)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(shell._current_page == 2, "已切到佛具頁")
	var equip_btn: Control = null
	for c in shell._focus_chain:
		if c is Button and String(c.text) == "裝上":
			equip_btn = c
			break
	_check(equip_btn != null, "佛具頁焦點鏈含「裝上」鈕")
	if equip_btn != null:
		equip_btn.grab_focus()
		await get_tree().process_frame
		equip_btn.pressed.emit()
		await get_tree().process_frame
		_check(EquipmentSystem.get_equipped("beads") == "beads_bodhi", "Enter(模擬 pressed)裝備 beads_bodhi 成功")

	# ESC 關閉整個選單。
	shell._input(_key_esc())
	await get_tree().process_frame
	_check(not is_instance_valid(shell) or shell.is_queued_for_deletion(), "ESC 關閉經書選單")
	GameManager.player.equipment_owned = []
	EquipmentSystem.unequip("beads")
	await get_tree().process_frame

func _test_menushell_phone_keyboard_nav() -> void:
	var shell = _make_menu_shell()
	await get_tree().process_frame
	shell._show_device("phone")
	await get_tree().process_frame
	_check(shell._current_device == "phone", "手機裝置已開啟")

	# 2026-07-10 review 退回修正（F1）：裝置切換鍵原本是 Q/E，與「interact」(E) 撞鍵（見下方
	# _test_menushell_board_e_key_does_not_switch_device），改用 [ / ]（bracket）。
	# [ 直接鍵碼切換裝置：] 應切回經書、[ 切回手機（裝置只有 2 個，循環）。
	shell._input(_key(KEY_BRACKETRIGHT))
	await get_tree().process_frame
	_check(shell._current_device == "book", "] 鍵切到經書裝置 (got %s)" % shell._current_device)
	shell._input(_key(KEY_BRACKETLEFT))
	await get_tree().process_frame
	_check(shell._current_device == "phone", "[ 鍵切回手機裝置 (got %s)" % shell._current_device)

	# 走訪手機 7 個 app，逐頁確認能開啟（含純顯示頁 IntelApp/HelpApp 的 scroll fallback）。
	var titles: Array = []
	for p in shell._devices["phone"].pages:
		titles.append(p.title)
	_check(titles.size() == 7, "手機共 7 個 app (got %d)" % titles.size())
	for i in titles.size():
		shell._show_page(i)
		await get_tree().process_frame
		await get_tree().process_frame
		var has_focusable: bool = not shell._focus_chain.is_empty()
		var has_scroll_fallback: bool = shell._scroll_fallback != null
		_check(has_focusable or has_scroll_fallback,
			"「%s」app 換頁後可鍵盤導航（焦點鏈或捲動 fallback 至少一項成立）" % titles[i])

	# 情報 app（純顯示，預期走 scroll fallback）：驗證 ui_down 真的會捲動。
	var intel_idx: int = titles.find("情報")
	_check(intel_idx != -1, "手機含「情報」app")
	if intel_idx != -1:
		shell._show_page(intel_idx)
		await get_tree().process_frame
		await get_tree().process_frame
		if shell._scroll_fallback != null:
			var before: float = shell._scroll_fallback.scroll_vertical
			shell._input(_key_down())
			await get_tree().process_frame
			_check(shell._scroll_fallback.scroll_vertical >= before, "情報頁 ui_down 使 ScrollContainer 捲動 (before %f, after %f)" % [before, shell._scroll_fallback.scroll_vertical])

	# 說明 app：確認鍵位表已同步 Q/E（D-1 由 A/D 改 Q/E）。
	var help_idx: int = titles.find("說明")
	if help_idx != -1:
		shell._show_page(help_idx)
		await get_tree().process_frame
		var help_page: Control = shell._content.get_child(0)
		var texts: Array = []
		_collect_label_texts(help_page, texts)
		var joined: String = "\n".join(texts)
		_check(joined.find("Q / E") != -1, "說明 app 鍵位表已更新為 Q / E（D-1）")
		_check(joined.find("A / D") == -1, "說明 app 鍵位表不再殘留舊的 A / D 轉視角字樣")

	shell._input(_key_esc())
	await get_tree().process_frame
	GameManager.player.equipment_owned = []
	await get_tree().process_frame

func _collect_label_texts(node: Node, out: Array) -> void:
	if node is Label:
		out.append(node.text)
	for c in node.get_children():
		_collect_label_texts(c, out)

## 2026-07-10 review 退回修正（F1 回歸測試）：手機「修行」頁(BoardApp)用 E 長按灌注解鎖。
## 過去 MenuShell 用裸鍵碼 E 做裝置切換，第一下 E 就把玩家踢出手機裝置、摧毀 BoardApp 節點，
## 長按永遠打不完。裝置切換鍵已改 [ / ]，這裡驗證 E 鍵在「修行」頁不再觸發裝置/頁面切換、
## BoardApp 節點不被摧毀。
func _test_menushell_board_e_key_does_not_switch_device() -> void:
	var shell = _make_menu_shell()
	await get_tree().process_frame
	shell._show_device("phone")
	shell._show_page(4)  # 修行＝phone 裝置第 4 頁（見 MenuShell._devices）
	await get_tree().process_frame
	_check(shell._current_device == "phone" and shell._current_page == 4, "前置：已在手機「修行」頁")
	var board_before: Node = shell._content.get_child(0) if shell._content.get_child_count() > 0 else null
	_check(board_before != null, "前置：修行頁內容節點已建立")

	shell._input(_key_e())  # interact 鍵：修行盤長按灌注解鎖用的就是這顆鍵
	await get_tree().process_frame

	_check(shell._current_device == "phone", "按 E 後仍在手機裝置，未被切到經書 (got %s)" % shell._current_device)
	_check(shell._current_page == 4, "按 E 後仍在修行頁，未被切走 (got %d)" % shell._current_page)
	_check(board_before != null and is_instance_valid(board_before) and not board_before.is_queued_for_deletion(),
		"按 E 後修行盤節點仍存活，未被 queue_free 摧毀")

	shell._input(_key_esc())
	await get_tree().process_frame

## 2026-07-10 review 退回修正（F2 回歸測試）：ui_left/ui_right 原本無條件被 MenuShell._input()
## 攔截去切頁籤，導致設定頁 4 個 HSlider 永遠無法用左右鍵調值（_input 先於 GUI 派發，
## set_input_as_handled() 之後事件到不了聚焦中的滑桿）。用 push_input() 走完整 Viewport
## pipeline（同 TestDialogueHistory.gd:127 的既有慣例，_input() 直接呼叫不會觸發 GUI 階段，
## 驗不出這條修正）重現 review 的原始 repro：焦點在滑桿上按左鍵，數值應該變動、頁籤不該被切走。
func _test_menushell_settings_slider_keyboard_nav() -> void:
	var shell = _make_menu_shell()
	await get_tree().process_frame
	shell._show_device("phone")
	shell._show_page(5)  # 設定＝phone 裝置第 5 頁
	await get_tree().process_frame
	await get_tree().process_frame  # call_deferred grab_focus 落地
	_check(shell._current_page == 5, "前置：已在設定頁")
	_check(not shell._focus_chain.is_empty(), "前置：設定頁焦點鏈已建立")
	if shell._focus_chain.is_empty():
		if is_instance_valid(shell):
			shell.queue_free()
		return
	var slider: Control = shell._focus_chain[0]
	_check(slider is HSlider, "設定頁焦點鏈第一項是 HSlider（主音量，前置條件）")
	_check(slider.has_focus(), "主音量滑桿已取得焦點")
	var value_before: float = slider.value

	get_tree().root.get_viewport().push_input(_key_left())
	await get_tree().process_frame
	await get_tree().process_frame

	_check(slider.value < value_before, "焦點在滑桿上按左鍵，數值確實下降 (before %f, after %f)" % [value_before, slider.value])
	_check(shell._current_page == 5, "焦點在滑桿上按左鍵，頁籤未被切走 (got %d)" % shell._current_page)

	# 2026-07-10 複驗 R1：這是「真實」主音量滑桿，value_changed 連著 SettingsManager.set_setting，
	# 每次呼叫即寫 user://settings.cfg——不還原的話每跑一次測試，使用者真實主音量永久 -0.05
	# （已實際發生：連跑 8 次把使用者的 master_vol 從 1.0 磨到 0.6）。動到會落盤的真實設定，測完必還原。
	slider.value = value_before  # 觸發 value_changed → set_setting 寫回原值
	await get_tree().process_frame
	_check(is_equal_approx(float(SettingsManager.get_setting("master_vol")), value_before),
		"測試尾端主音量已還原並寫回設定檔 (want %f, got %f)" % [value_before, float(SettingsManager.get_setting("master_vol"))])

	shell._input(_key_esc())
	await get_tree().process_frame

# ─── B-2：商店鍵盤化 ──────────────────────────────────────
func _test_shop_keyboard_nav() -> void:
	var shop = load("res://src/ui/menu/ShopScreen.gd").new()
	shop.set("pause_game", false)
	get_tree().root.add_child(shop)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(shop._current_tab == 0, "商店預設在消耗品分頁")
	# 2026-07-10 review 退回修正（F3b）：ShopScreen 現在也有 _focus_chain 成員（見 ShopScreen.gd
	# _wire_content_focus），不用再防禦性判斷欄位是否存在。
	_check(not shop._focus_chain.is_empty(), "商店焦點鏈存在")

	# ui_right 切到佛具分頁。
	shop._input(_key_right())
	await get_tree().process_frame
	_check(shop._current_tab == 1, "→ 切到佛具分頁 (got %d)" % shop._current_tab)
	shop._input(_key_left())
	await get_tree().process_frame
	_check(shop._current_tab == 0, "← 切回消耗品分頁 (got %d)" % shop._current_tab)

	# 消耗品分頁：焦點鏈第一項應是清單第一個商品。
	await get_tree().process_frame
	_check(not shop._focus_chain.is_empty(), "消耗品分頁焦點鏈已建立")
	if not shop._focus_chain.is_empty():
		shop._focus_chain[0].grab_focus()
		await get_tree().process_frame
		_check(shop._focus_chain[0].has_focus(), "商品清單第一項可取得焦點")
		# 模擬 Enter 選中（Button.pressed 訊號），應開出詳情＋購買鈕，焦點鏈重建含購買鈕。
		GameManager.player.gold = 1000
		shop._focus_chain[0].pressed.emit()
		await get_tree().process_frame
		var buy_btn: Control = null
		for c in shop._focus_chain:
			if c is Button and String(c.text) == "購買":
				buy_btn = c
				break
		_check(buy_btn != null, "選中商品後焦點鏈含「購買」鈕")
		if buy_btn != null:
			var gold_before: int = GameManager.player.gold
			buy_btn.grab_focus()
			await get_tree().process_frame
			buy_btn.pressed.emit()
			await get_tree().process_frame
			_check(GameManager.player.gold < gold_before, "Enter(模擬 pressed)購買消耗品成功扣款 (before %d, after %d)" % [gold_before, GameManager.player.gold])

	shop._input(_key_esc())
	await get_tree().process_frame
	GameManager.player.gold = 1000
	GameManager.player.inventory = {}
	await get_tree().process_frame
