extends Node
## headless 測試：敵人圖鑑（weakness_intel UI 出口，K1 2026-07-08）。
## 跑法：Godot --headless res://test/TestBestiary.tscn
## 驗三件事：①戰鬥開打記錄 enemies_seen（含複數敵人同場、跨 save/load 存活、舊存檔缺欄位不炸）
## ②IntelApp 敵人區塊：已遭遇+已知弱點顯示屬性名／已遭遇未知顯示？？？／未遭遇不列
## ③record_enemy_seen / knows_weakness API 正確。
## 不碰真實存檔：只操作 GameManager.player 記憶體 dict 與 JSON.stringify/parse 往返（不寫 user://）。

var ok := true

func _check(cond: bool, msg: String) -> void:
	if not cond:
		ok = false
		print("FAIL: ", msg)

func _ready() -> void:
	await get_tree().process_frame
	_test_record_and_guard()
	await _test_battle_records_enemies_seen()
	_test_serialize_roundtrip()
	_test_old_save_missing_field()
	await _test_intel_app_ui()
	print("BESTIARY_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

## ─── a) record_enemy_seen / has_seen_enemy 基本行為 ───────────────
func _test_record_and_guard() -> void:
	GameManager.new_game()
	_check(GameManager.player.enemies_seen.is_empty(), "new_game 後 enemies_seen 為空")
	GameManager.record_enemy_seen("street_punk")
	_check(GameManager.has_seen_enemy("street_punk"), "record 後 has_seen_enemy==true")
	_check(not GameManager.has_seen_enemy("corrupt_vendor"), "未記錄的敵人 has_seen_enemy==false")
	# 重複記錄不重複塞入
	GameManager.record_enemy_seen("street_punk")
	var cnt := 0
	for e in GameManager.player.enemies_seen:
		if e == "street_punk":
			cnt += 1
	_check(cnt == 1, "重複 record 不重複塞入 (got %d)" % cnt)

## ─── b) 真實戰鬥 setup() → enemies_seen 有記錄，含複數敵人同場（spawn_pair/ally_id）───
func _test_battle_records_enemies_seen() -> void:
	GameManager.new_game()
	var scene: PackedScene = load("res://src/screens/BattleScreen/BattleScreen.tscn")
	var battle = scene.instantiate()
	get_tree().root.add_child(battle)
	await get_tree().process_frame

	# drunk_guard: spawn_pair=true → 同 base_id 兩隻，enemies_seen 仍只 1 筆（去重）。
	battle.setup("drunk_guard")
	await get_tree().process_frame
	_check(GameManager.has_seen_enemy("drunk_guard"), "drunk_guard 戰鬥開打後已記錄")
	_check(battle.enemy_combatants.size() == 2, "drunk_guard spawn_pair 場上兩隻 (got %d)" % battle.enemy_combatants.size())
	var dg_cnt := 0
	for e in GameManager.player.enemies_seen:
		if e == "drunk_guard":
			dg_cnt += 1
	_check(dg_cnt == 1, "spawn_pair 兩隻同 base_id 只記一筆 (got %d)" % dg_cnt)
	battle.queue_free()
	await get_tree().process_frame

	# tutorial_punk: ally_id=tutorial_punk_lookout → 異質同場兩種敵人都要記錄。
	GameManager.new_game()
	var battle2 = scene.instantiate()
	get_tree().root.add_child(battle2)
	await get_tree().process_frame
	battle2.setup("tutorial_punk")
	await get_tree().process_frame
	_check(GameManager.has_seen_enemy("tutorial_punk"), "tutorial_punk 已記錄")
	_check(GameManager.has_seen_enemy("tutorial_punk_lookout"), "ally_id tutorial_punk_lookout 也已記錄")
	_check(not GameManager.has_seen_enemy("night_ghost"), "未遭遇的 night_ghost 仍未記錄")
	battle2.queue_free()
	await get_tree().process_frame

## ─── c) 跨 save/load 存活：JSON 序列化往返（不碰真實 user:// 存檔）───────
func _test_serialize_roundtrip() -> void:
	GameManager.new_game()
	GameManager.record_enemy_seen("street_punk")
	GameManager.record_enemy_seen("corrupt_vendor")
	var json_str := JSON.stringify(GameManager.player)
	var parsed = JSON.parse_string(json_str)
	_check(parsed is Dictionary, "序列化後可解析回 Dictionary")
	if parsed is Dictionary:
		var seen: Array = parsed.get("enemies_seen", [])
		_check(seen.size() == 2, "序列化保留 2 筆 enemies_seen (got %d)" % seen.size())
		_check("street_punk" in seen and "corrupt_vendor" in seen, "序列化內容正確")
		# 模擬「載入」：把解析結果餵回 player（等同 SaveManager.load 的合併邏輯精神）
		GameManager.player = parsed
		_check(GameManager.has_seen_enemy("street_punk"), "load 後 has_seen_enemy 仍正確")

## ─── d) 舊存檔缺 enemies_seen 欄位 → guard 補欄位、不炸、圖鑑顯示空列表 ───────
func _test_old_save_missing_field() -> void:
	GameManager.new_game()
	var legacy_player: Dictionary = GameManager.player.duplicate(true)
	legacy_player.erase("enemies_seen")  # 模擬舊存檔（沒有這個鍵）
	GameManager.player = legacy_player
	_check(not GameManager.player.has("enemies_seen"), "前置：模擬舊存檔缺 enemies_seen 鍵")

	# 呼叫任一走 _ensure_battle_keys() 的 API 不應報錯，且會補回欄位
	GameManager.record_enemy_seen("street_punk")
	_check(GameManager.player.has("enemies_seen"), "guard 補回 enemies_seen 鍵")
	_check(typeof(GameManager.player.enemies_seen) == TYPE_ARRAY, "補回的 enemies_seen 是 Array")
	_check(GameManager.has_seen_enemy("street_punk"), "補欄位後仍可正常記錄查詢")

	# 另一支：has_seen_enemy 在缺欄位時查詢也不炸（走 guard），回傳 false
	GameManager.new_game()
	var legacy2: Dictionary = GameManager.player.duplicate(true)
	legacy2.erase("enemies_seen")
	GameManager.player = legacy2
	_check(not GameManager.has_seen_enemy("street_punk"), "缺欄位時查詢不炸、回傳 false")
	_check(GameManager.player.has("enemies_seen"), "查詢後 guard 補回欄位")
	_check(GameManager.player.enemies_seen.is_empty(), "補回後圖鑑應為空列表")

## ─── e) IntelApp UI：已遭遇+已知弱點顯示屬性名／已遭遇未知顯示？？？／未遭遇不列 ───
func _test_intel_app_ui() -> void:
	GameManager.new_game()
	# street_punk 弱 merit：只探知後才顯示「淨」，否則「？？？」
	GameManager.record_enemy_seen("street_punk")
	GameManager.record_enemy_seen("tutorial_punk_lookout")  # 已遭遇但無弱點（weaknesses:[]）
	# corrupt_vendor 完全不遭遇 → 不應出現在文字內容中

	var app = load("res://src/ui/menu/pages/IntelApp.gd").new()
	get_tree().root.add_child(app)
	for i in 3:
		await get_tree().process_frame

	var all_text := _collect_labels_text(app)
	_check("櫻木町混混" in all_text, "已遭遇 street_punk 的中文名有列出")
	_check("把風的小混混" in all_text, "已遭遇 tutorial_punk_lookout 的中文名有列出")
	_check("黑心攤販" not in all_text, "未遭遇的 corrupt_vendor 完全不列")
	_check("？？？" in all_text, "未探知弱點顯示？？？（street_punk 尚未探知 merit）")
	_check("弱點：無" in all_text, "無弱點的 tutorial_punk_lookout 顯示「弱點：無」")

	# 探知 street_punk 的 merit 弱點後 → 顯示屬性名「淨」
	GameManager.record_weakness_intel("street_punk", "merit")
	app.queue_free()
	await get_tree().process_frame
	var app2 = load("res://src/ui/menu/pages/IntelApp.gd").new()
	get_tree().root.add_child(app2)
	for i in 3:
		await get_tree().process_frame
	var all_text2 := _collect_labels_text(app2)
	_check("弱點：淨" in all_text2, "探知 merit 後顯示屬性名「弱點：淨」(text=%s)" % all_text2.substr(0, 0))
	app2.queue_free()
	await get_tree().process_frame

func _collect_labels_text(node: Node) -> String:
	var out := ""
	for c in node.get_children():
		if c is Label:
			out += (c as Label).text + "\n"
		out += _collect_labels_text(c)
	return out
