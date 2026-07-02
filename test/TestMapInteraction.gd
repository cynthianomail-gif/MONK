extends Node
## 驗證新互動模型：走近顯提示（不直接跳選單）、多動作按 E 跳小選單、離開清空。
func _ready() -> void:
	GameManager.new_game()
	var ms := (load("res://src/screens/MapScreen/MapScreen.tscn") as PackedScene).instantiate()
	add_child(ms)
	await get_tree().process_frame
	await get_tree().process_frame
	var hud: Node = ms.get_node("HUD")

	# 1) 走近 了塵（4 動作）→ 顯示提示、不直接跳選單
	ms._on_trigger_entered("npc_liaochen")
	if not hud.prompt.visible: return _fail("走近應顯示提示")
	if hud.action_menu.visible: return _fail("走近不應直接跳選單")
	if ms._current_actions.size() != 4: return _fail("了塵應 4 動作，實 %d" % ms._current_actions.size())

	# 2) 按 E（多動作）→ 跳「該人」小選單（4 動作 + 離開 = 5 顆鈕）
	ms._interact()
	if not hud.action_menu.visible: return _fail("多動作按 E 應跳選單")
	if hud.menu_buttons.get_child_count() != 5: return _fail("選單應 5 顆鈕(4+離開)，實 %d" % hud.menu_buttons.get_child_count())
	hud.hide_action_menu()

	# 3) 走近單一動作 NPC → _current_actions 只 1 項（結構驗證，不實際 perform 以免連鎖換場）
	ms._on_trigger_entered("npc_ah_ming")
	if ms._current_actions.size() != 1: return _fail("阿明應單一動作，實 %d" % ms._current_actions.size())

	# 4) 離開 → 清空提示與當前點
	ms._on_trigger_exited("npc_ah_ming")
	if ms._current_loc != "" or hud.prompt.visible: return _fail("離開應清空提示與當前點")

	print("TEST PASS: 地圖互動(走近提示/多動作選單/離開清空) OK")
	get_tree().quit(0)

func _fail(m: String) -> void:
	push_error("TEST FAIL: %s" % m); get_tree().quit(1)
