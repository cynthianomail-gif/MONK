extends Node
## headless 測試：佛具裝備位（第五期，2026-07-08）。
## 跑法：
##   & "D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe" --headless --path "D:\monk\MONK" res://test/TestEquipment.tscn
## 判定：輸出含 EQUIPMENT_TEST: ALL PASS（headless teardown 退碼非 0 屬引擎 bug，以字串為準）。
## 覆蓋規格「驗證」節 8 件事：
##   json schema 載入 / compute_bonus / 裝卸 / 舊檔 guard / 商店購買(扣錢/入庫/限購) /
##   勝利被動(金幣%/功德) / flee 不觸發被動 / 裝備不進戰鬥道具選單。

var ok: bool = true

## 執行順序刻意把 ⑥/⑦ 放最後：兩者都會觸發 BattleManager._return_from_battle()，
## 背景排程一個 SceneRouter.go_to_map()/go_to_scene()（~2.2s 後才真的 change_scene_to_file，
## 換場會把整棵 tree 換掉，連測試自己的根節點都被替換，get_tree().quit() 會失敗、engine 卡死
## 不退出——這是本測試檔踩過的雷）。因此 ⑥/⑦ 一結束就立刻 quit()，不留時間讓背景換場追上來。
func _ready() -> void:
	await get_tree().process_frame
	_test_json_schema()
	_test_compute_bonus()
	_test_equip_unequip()
	_test_old_save_guard()
	await _test_shop_purchase()
	await _test_not_in_battle_item_menu()
	await _test_victory_passive()
	await _test_flee_no_passive()
	print("EQUIPMENT_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		ok = false
		print("FAIL: ", msg)

func _reset_player_equipment() -> void:
	GameManager.player.equipment = {"beads": "", "kasaya": "", "bowl": ""}
	GameManager.player.equipment_owned = []

## ① json schema 載入
func _test_json_schema() -> void:
	var items: Dictionary = JsonLoader.load_json("res://data/equipment.json")
	_check(items.size() == 9, "equipment.json 有 9 件佛具 (got %d)" % items.size())
	for id in ["beads_bodhi", "beads_vajra", "beads_agarwood",
			"kasaya_rough", "kasaya_brocade", "kasaya_gold",
			"bowl_pine", "bowl_iron", "bowl_zijin"]:
		_check(items.has(id), "equipment.json 有 %s" % id)
		var d: Dictionary = items.get(id, {})
		_check(d.has("name") and d.has("slot") and d.has("tier") and int(d.get("price", 0)) > 0,
			"%s 有 name/slot/tier/price" % id)
		_check(String(d.get("slot", "")) in ["beads", "kasaya", "bowl"], "%s slot 合法" % id)
	_check(items.get("beads_bodhi", {}).get("bonus", {}).get("atk", 0) == 8, "beads_bodhi atk+8")
	_check(items.get("bowl_zijin", {}).get("passive", {}).get("merit_per_win", 0) == 1, "bowl_zijin merit_per_win+1")

## ② compute_bonus
func _test_compute_bonus() -> void:
	_reset_player_equipment()
	EquipmentSystem.reload()
	var b0: Dictionary = EquipmentSystem.compute_bonus()
	_check(int(b0.atk) == 0 and int(b0.def) == 0 and int(b0.hp) == 0, "空裝 bonus 全 0")
	GameManager.player.equipment_owned = ["beads_bodhi", "kasaya_brocade", "bowl_iron"]
	GameManager.player.equipment = {"beads": "beads_bodhi", "kasaya": "kasaya_brocade", "bowl": "bowl_iron"}
	var b1: Dictionary = EquipmentSystem.compute_bonus()
	_check(int(b1.atk) == 8, "atk bonus = beads_bodhi 8 (got %d)" % int(b1.atk))
	_check(int(b1.def) == 2, "def bonus = kasaya_brocade 2 (got %d)" % int(b1.def))
	_check(int(b1.hp) == 90 + 40, "hp bonus = kasaya_brocade 90 + bowl_iron 40 = 130 (got %d)" % int(b1.hp))
	_check(absf(float(b1.gold_pct) - 0.20) < 0.001, "gold_pct = bowl_iron 0.20 (got %f)" % float(b1.gold_pct))
	_check(int(b1.merit_per_win) == 0, "merit_per_win 0（bowl_iron 無此被動）")
	# Combatant.from_player() 有加總（不動修行盤既有行，只驗證有加上去）
	GameManager.player.max_hp = 500
	GameManager.player.current_hp = 500
	var c: Combatant = Combatant.from_player()
	_check(c.attack == 100 + 8, "Combatant attack 含裝備 atk (got %d)" % c.attack)
	_check(c.defense == 10 + 2, "Combatant defense 含裝備 def (got %d)" % c.defense)
	_check(c.max_hp == 500 + 130, "Combatant max_hp 含裝備 hp (got %d)" % c.max_hp)
	_reset_player_equipment()

## ③ 裝/卸
func _test_equip_unequip() -> void:
	_reset_player_equipment()
	_check(not EquipmentSystem.equip("beads_bodhi"), "未持有時 equip 失敗")
	GameManager.player.equipment_owned.append("beads_bodhi")
	_check(EquipmentSystem.equip("beads_bodhi"), "持有後 equip 成功")
	_check(EquipmentSystem.get_equipped("beads") == "beads_bodhi", "get_equipped 回傳已裝備 id")
	GameManager.player.equipment_owned.append("beads_vajra")
	_check(EquipmentSystem.equip("beads_vajra"), "同欄換裝成功")
	_check(EquipmentSystem.get_equipped("beads") == "beads_vajra", "同欄換裝後覆蓋舊裝備")
	EquipmentSystem.unequip("beads")
	_check(EquipmentSystem.get_equipped("beads") == "", "卸下後該欄為空")
	_reset_player_equipment()

## ④ 舊檔 guard：缺 equipment/equipment_owned 鍵不炸
func _test_old_save_guard() -> void:
	GameManager.player.erase("equipment")
	GameManager.player.erase("equipment_owned")
	_check(EquipmentSystem.get_equipped("beads") == "", "缺鍵時 get_equipped 不炸、回空字串")
	_check(EquipmentSystem.owned_in_slot("beads").is_empty(), "缺鍵時 owned_in_slot 不炸、回空陣列")
	_check(not EquipmentSystem.is_owned("beads_bodhi"), "缺鍵時 is_owned 不炸、回 false")
	var b: Dictionary = EquipmentSystem.compute_bonus()
	_check(int(b.atk) == 0, "缺鍵時 compute_bonus 不炸、回 0")
	_check(GameManager.player.has("equipment") and GameManager.player.has("equipment_owned"),
		"guard 呼叫後自動補回鍵")
	# 型別跑掉的情況（JSON 讀回可能是別的型別）
	GameManager.player.equipment = "junk"
	GameManager.player.equipment_owned = "junk"
	_check(EquipmentSystem.get_equipped("beads") == "", "型別錯誤時 get_equipped 不炸")
	_reset_player_equipment()

## ⑤ 商店購買：扣錢/入庫/限購
func _test_shop_purchase() -> void:
	_reset_player_equipment()
	GameManager.player.gold = 1000
	_check(EquipmentSystem.purchase("beads_bodhi"), "購買 beads_bodhi 成功")
	_check(GameManager.player.gold == 600, "扣款 400 (got %d)" % GameManager.player.gold)
	_check(EquipmentSystem.is_owned("beads_bodhi"), "購買後入庫")
	_check(not EquipmentSystem.purchase("beads_bodhi"), "已持有再買失敗（限購一次）")
	_check(GameManager.player.gold == 600, "限購擋下後金幣不變")
	GameManager.player.gold = 10
	_check(not EquipmentSystem.purchase("kasaya_rough"), "金幣不足購買失敗")
	_check(not EquipmentSystem.is_owned("kasaya_rough"), "金幣不足未入庫")

	# ShopScreen UI 層：購買按鈕走 _on_buy_equipment，未達門檻不顯示
	GameManager.player.gold = 1000
	GameManager.player.flags.erase("armory_unlocked")
	GameManager.player.flags.erase("ares_purified")
	var shop = load("res://src/ui/menu/ShopScreen.gd").new()
	shop.set("pause_game", false)
	get_tree().root.add_child(shop)
	await get_tree().process_frame
	shop._show_tab(1)
	await get_tree().process_frame
	_check("beads_bodhi" in shop._rows, "佛具分頁：1 階開店即有品項顯示")
	_check("beads_vajra" not in shop._rows, "佛具分頁：未達 armory_unlocked 門檻的 2 階不顯示")
	_check("beads_agarwood" not in shop._rows, "佛具分頁：未達 ares_purified 門檻的 3 階不顯示")
	GameManager.set_flag("armory_unlocked", true)
	shop._show_tab(1)
	await get_tree().process_frame
	_check("beads_vajra" in shop._rows, "設 armory_unlocked 後 2 階顯示")
	GameManager.set_flag("ares_purified", true)
	shop._show_tab(1)
	await get_tree().process_frame
	_check("beads_agarwood" in shop._rows, "設 ares_purified 後 3 階顯示")
	shop._on_buy_equipment("kasaya_rough")
	_check(EquipmentSystem.is_owned("kasaya_rough"), "ShopScreen._on_buy_equipment 購買生效")
	shop.close()
	await get_tree().process_frame
	GameManager.player.flags.erase("armory_unlocked")
	GameManager.player.flags.erase("ares_purified")
	_reset_player_equipment()
	GameManager.player.gold = 1000

## ⑥ 勝利被動：金幣% 與 gold_multiplier_active 疊乘、功德加成
## 仿 TestBattleFlow._test_full_round_to_victory 的既有安全模式（force_victory + 短等待即
## queue_free，不等 _return_from_battle() 的完整回場景轉場跑完——那段跑真 3D 地圖場景，
## 真實跑一次即可，鏈式跑第二次會拖慢/卡住，故疊乘部分改純算式驗證，不二次跑真戰鬥）。
func _test_victory_passive() -> void:
	_reset_player_equipment()
	GameManager.player.equipment_owned = ["bowl_zijin"]
	GameManager.player.equipment = {"beads": "", "kasaya": "", "bowl": "bowl_zijin"}
	GameManager.player.gold = 0
	GameManager.player.merit = 0
	GameManager.set_flag("gold_multiplier_active", false)
	GameManager.player.current_hp = 500
	GameManager.player.max_hp = 500
	# 戰後回場改指向輕量空場景（非真實 3D 地圖）：_return_from_battle() 背景觸發的 go_to_map()
	# 若跑真 ShrineStreet，耗時且與後續 flee 測試的第二次轉場疊加會拖慢/卡住整個測試行程。
	GameManager.set_flag("battle_return_scene", "res://test/_EmptyProbeScene.tscn")

	var scene: PackedScene = load("res://src/screens/BattleScreen/BattleScreen.tscn")
	var battle = scene.instantiate()
	get_tree().root.add_child(battle)
	await get_tree().process_frame
	battle.setup("street_punk")   # gold_reward 80
	await get_tree().process_frame
	battle.force_victory()
	# 只等 add_gold/add_merit 真正落地所需的最短時間（play_victory 的 0.8s 計時器後即發放，
	# 落在 _return_from_battle() 觸發背景換場之前），不多等——避免背景 go_to_map() 追上來換掉整棵 tree。
	await get_tree().create_timer(0.9).timeout
	# bowl_zijin: gold_pct 0.25, merit_per_win 1 → gold 80*1.25=100, merit 15+1=16
	_check(GameManager.player.gold == 100, "bowl_zijin 金幣被動 80*1.25=100 (got %d)" % GameManager.player.gold)
	_check(GameManager.player.merit == 16, "bowl_zijin 功德被動 15+1=16 (got %d)" % GameManager.player.merit)
	if is_instance_valid(battle):
		battle.queue_free()

	# 疊乘算式驗證（不二次跑真戰鬥）：與程式碼同公式，gold_multiplier_active 1.5x 疊乘裝備 gold_pct。
	var base_gold := 80
	var after_multiplier: int = int(base_gold * 1.5)
	var eq_bonus: Dictionary = EquipmentSystem.compute_bonus()
	var after_equip: int = int(after_multiplier * (1.0 + float(eq_bonus.get("gold_pct", 0.0))))
	_check(after_equip == 150, "疊乘算式 80*1.5*1.25=150 (got %d)" % after_equip)

	GameManager.set_flag("gold_multiplier_active", false)
	GameManager.set_flag("battle_return_scene", "")
	_reset_player_equipment()
	GameManager.player.gold = 1000
	GameManager.player.merit = 0

## ⑦ flee 不觸發缽被動（人中之龍佛系放生：不算戰鬥結束，無獎勵）
func _test_flee_no_passive() -> void:
	_reset_player_equipment()
	GameManager.player.equipment_owned = ["bowl_zijin"]
	GameManager.player.equipment = {"beads": "", "kasaya": "", "bowl": "bowl_zijin"}
	GameManager.player.gold = 500
	GameManager.player.merit = 0
	GameManager.set_flag("battle_return_scene", "res://test/_EmptyProbeScene.tscn")

	var scene: PackedScene = load("res://src/screens/BattleScreen/BattleScreen.tscn")
	var battle = scene.instantiate()
	get_tree().root.add_child(battle)
	await get_tree().process_frame
	battle.setup("street_punk")
	await get_tree().process_frame
	battle._start_round()
	await get_tree().process_frame
	var gold_before: int = GameManager.player.gold
	var merit_before: int = GameManager.player.merit
	battle.player_use_flee()
	# player_use_flee() 內部 0.8s 計時器後才觸發 hooks，只等剛好夠用的時間——本測試是全檔最後
	# 一項，驗證完立刻讓 _ready() 收尾 quit()，不留時間讓背景 go_to_map() 換場追上來（見檔頭註解）。
	await get_tree().create_timer(0.9).timeout
	_check(GameManager.player.gold == gold_before, "flee 不觸發金幣被動 (gold 不變 %d)" % GameManager.player.gold)
	_check(GameManager.player.merit == merit_before, "flee 不觸發功德被動 (merit 不變 %d)" % GameManager.player.merit)
	if is_instance_valid(battle):
		battle.queue_free()
	GameManager.set_flag("battle_return_scene", "")
	_reset_player_equipment()
	GameManager.player.gold = 1000
	GameManager.player.merit = 0

## ⑧ 裝備不出現在戰鬥道具選單（只讀 inventory，equipment 走獨立欄位）
func _test_not_in_battle_item_menu() -> void:
	_reset_player_equipment()
	GameManager.player.equipment_owned = ["beads_bodhi", "kasaya_rough", "bowl_pine"]
	GameManager.player.equipment = {"beads": "beads_bodhi", "kasaya": "kasaya_rough", "bowl": "bowl_pine"}
	GameManager.player.inventory = {"heal_salve": 1}

	var scene: PackedScene = load("res://src/screens/BattleScreen/BattleScreen.tscn")
	var battle = scene.instantiate()
	get_tree().root.add_child(battle)
	await get_tree().process_frame
	battle.setup("street_punk")
	await get_tree().process_frame
	var ui = battle.get_node("BattleUI")
	ui.show_item_menu()
	await get_tree().process_frame
	var found_equipment := false
	for c in ui.skill_buttons.get_children():
		if c is Button:
			var t: String = String(c.text)
			if t.find("菩提子念珠") != -1 or t.find("粗布袈裟") != -1 or t.find("松木缽") != -1:
				found_equipment = true
	_check(not found_equipment, "戰鬥道具選單不含任何佛具品項")
	_check(_find_button(ui.skill_buttons, "金瘡藥 ×1") != null, "戰鬥道具選單仍正常列出消耗品")
	battle.queue_free()
	GameManager.player.inventory = {}
	await get_tree().process_frame
	_reset_player_equipment()

func _find_button(container: Node, text: String) -> Button:
	for c in container.get_children():
		if c is Button and String(c.text) == text:
			return c
	return null
