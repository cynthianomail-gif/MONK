extends Node
## headless 測試：鄭媽佛具店道具系統（資料 / 背包 / 戰鬥道具 / UI 煙霧 / 購買 / gate）。
## 跑法：
##   & "D:\monk\tools\godot\Godot_v4.5-stable_win64_console.exe" --headless --path "D:\monk\MONK" res://test/TestShop.tscn
## 判定：輸出含 SHOP_TEST: ALL PASS（headless teardown 退碼非 0 屬引擎 bug，以字串為準）。

var ok: bool = true

func _ready() -> void:
	await get_tree().process_frame
	_test_items_data()
	_test_inventory()
	await _test_battle_items()
	await _test_battle_ui_items()
	await _test_shop_purchase()
	_test_shop_gate()
	print("SHOP_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		ok = false
		print("FAIL: ", msg)

func _test_items_data() -> void:
	var items: Dictionary = JsonLoader.load_json("res://data/items.json")
	_check(items.size() == 3, "items.json 有 3 道具 (got %d)" % items.size())
	for id in ["heal_salve", "karma_crystal", "amulet"]:
		_check(items.has(id), "items.json 有 %s" % id)
		var d: Dictionary = items.get(id, {})
		_check(d.has("name") and int(d.get("price", 0)) > 0, "%s 有 name+price" % id)
		_check(d.get("effect", {}).has("kind"), "%s effect 有 kind" % id)
	_check(items.get("amulet", {}).get("effect", {}).get("kind", "") == "shield", "amulet effect.kind == shield")

func _test_inventory() -> void:
	var gm := GameManager
	gm.player.inventory = {}
	_check(gm.item_count("heal_salve") == 0, "空背包 count 0")
	gm.add_item("heal_salve")
	gm.add_item("heal_salve", 2)
	_check(gm.item_count("heal_salve") == 3, "add_item 累加 = 3 (got %d)" % gm.item_count("heal_salve"))
	_check(gm.consume_item("heal_salve"), "consume_item 有貨回 true")
	_check(gm.item_count("heal_salve") == 2, "consume 後 = 2")
	gm.player.inventory = { "amulet": 1 }
	_check(gm.consume_item("amulet"), "consume 最後一個回 true")
	_check(gm.item_count("amulet") == 0 and not gm.player.inventory.has("amulet"), "歸 0 即 erase 鍵")
	_check(not gm.consume_item("amulet"), "空貨 consume 回 false")
	# 舊存檔無 inventory 鍵：helper 防呆
	gm.player.erase("inventory")
	_check(gm.item_count("heal_salve") == 0, "缺 inventory 鍵 → count 0（不崩）")
	gm.add_item("karma_crystal")
	_check(gm.item_count("karma_crystal") == 1, "缺鍵時 add_item 自建 inventory")
	# JSON 讀回是 float：item_count 必須夾回 int（專案已知雷）
	gm.player.inventory = { "heal_salve": 3.0 }
	_check(gm.item_count("heal_salve") == 3 and typeof(gm.item_count("heal_salve")) == TYPE_INT, "float 值讀回為 int")
	gm.player.inventory = {}

func _test_battle_items() -> void:
	var scene: PackedScene = load("res://src/screens/BattleScreen/BattleScreen.tscn")
	var battle = scene.instantiate()
	get_tree().root.add_child(battle)
	await get_tree().process_frame
	battle.setup("street_punk")
	await get_tree().process_frame
	# _apply_item_effect: heal（明確設 max_hp，避免外部狀態影響 heal 夾值）
	battle.player_combatant.max_hp = 500
	battle.player_combatant.current_hp = 100
	battle._apply_item_effect({ "kind": "heal", "value": 200 })
	_check(battle.player_combatant.current_hp == 300, "heal 道具 +200 (got %d)" % battle.player_combatant.current_hp)
	# karma
	GameManager.player.karma = 0
	battle._apply_item_effect({ "kind": "karma", "value": 40 })
	_check(GameManager.player.karma == 40, "karma 道具 +40 (got %d)" % GameManager.player.karma)
	# shield → golden_body buff
	battle._apply_item_effect({ "kind": "shield", "value": 250, "duration": 3 })
	_check(battle.player_combatant.has_buff("golden_body"), "shield 道具上 golden_body buff")
	# player_use_item：消耗 + 套效果 + 消耗一回合（佇列推進）
	# 用真回合佇列驅動：_start_round 讓玩家在佇列最前，再用道具。
	GameManager.player.inventory = { "heal_salve": 1 }
	battle.player_combatant.current_hp = 100
	battle._start_round()
	await get_tree().process_frame
	_check(battle.state == battle.State.PLAYER_TURN, "回合開始為玩家回合（speed 玩家先手）")
	battle.player_use_item("heal_salve")
	_check(GameManager.item_count("heal_salve") == 0, "player_use_item 消耗道具")
	_check(battle.player_combatant.current_hp == 300, "player_use_item 套用 heal")
	# 道具消耗一回合 → 佇列推進到敵人（或回合結算後重開）；不再停在同一玩家 slot
	await get_tree().create_timer(0.8).timeout   # 讓後續敵人回合在 live 節點上跑完再 free
	# 非 PLAYER_TURN：不消耗
	GameManager.player.inventory = { "heal_salve": 1 }
	battle.state = battle.State.ENEMY_TURN
	battle.player_use_item("heal_salve")
	_check(GameManager.item_count("heal_salve") == 1, "非 PLAYER_TURN 時 player_use_item 不消耗")
	battle.queue_free()
	GameManager.player.inventory = {}
	GameManager.player.karma = 0
	await get_tree().process_frame

func _find_button(container: Node, text: String) -> Button:
	for c in container.get_children():
		if c is Button and String(c.text) == text:
			return c
	return null

func _test_battle_ui_items() -> void:
	var scene: PackedScene = load("res://src/screens/BattleScreen/BattleScreen.tscn")
	var battle = scene.instantiate()
	get_tree().root.add_child(battle)
	await get_tree().process_frame
	battle.setup("street_punk")
	await get_tree().process_frame
	var ui = battle.get_node("BattleUI")
	# 道具改為 CommandMenu 頂層指令（第一期）：show_item_menu() 開子選單。
	# 空背包：show_item_menu() 走 _has_usable_items()=false → 退回指令選單，不列道具。
	GameManager.player.inventory = {}
	ui.show_item_menu()
	await get_tree().process_frame
	_check(_find_button(ui.skill_buttons, "金瘡藥 ×2") == null, "空背包不列出道具")
	_check(not ui._has_usable_items(), "空背包 _has_usable_items 為 false")
	# 有道具：子選單列出該道具 + 返回
	GameManager.player.inventory = { "heal_salve": 2 }
	_check(ui._has_usable_items(), "有道具時 _has_usable_items 為 true")
	ui.show_item_menu()
	await get_tree().process_frame
	_check(_find_button(ui.skill_buttons, "金瘡藥 ×2") != null, "子選單列出 金瘡藥 ×2")
	_check(_find_button(ui.skill_buttons, "← 返回") != null, "子選單有返回鈕（UI 去冗字後文案簡化為「← 返回」）")
	battle.queue_free()
	GameManager.player.inventory = {}
	await get_tree().process_frame

func _test_shop_purchase() -> void:
	var shop = load("res://src/ui/menu/ShopScreen.gd").new()
	shop.set("pause_game", false)   # 測試不暫停 tree
	get_tree().root.add_child(shop)
	await get_tree().process_frame
	_check(is_instance_valid(shop), "ShopScreen 實例化不崩")
	# 金幣足：扣款 + 入袋（第四期道具漲價：heal_salve 220／amulet 500）
	GameManager.player.gold = 1000
	GameManager.player.inventory = {}
	shop._on_buy("heal_salve")   # price 220
	_check(GameManager.player.gold == 780, "買 heal_salve 扣 220 (got %d)" % GameManager.player.gold)
	_check(GameManager.item_count("heal_salve") == 1, "買後入袋 1")
	# 金幣不足：不扣、不入袋
	GameManager.player.gold = 100
	shop._on_buy("amulet")   # price 500
	_check(GameManager.player.gold == 100, "不足: 金幣不變")
	_check(GameManager.item_count("amulet") == 0, "不足: 未入袋")
	shop.close()
	GameManager.player.gold = 1000
	GameManager.player.inventory = {}
	await get_tree().process_frame

func _test_shop_gate() -> void:
	# gate 判定為純旗標：未設 → 視為未開店；設了 → 開店
	GameManager.player.flags.erase("zheng_ma_shop_unlocked")
	_check(not GameManager.get_flag("zheng_ma_shop_unlocked"), "無旗標時 shop gate 關閉")
	GameManager.set_flag("zheng_ma_shop_unlocked", true)
	_check(GameManager.get_flag("zheng_ma_shop_unlocked"), "設旗標後 shop gate 開啟")
	# MapScreen preload 了 ShopScreen 腳本（接線存在性）
	var ms_script := load("res://src/screens/MapScreen/MapScreen.gd")
	_check(ms_script != null, "MapScreen.gd 可載入（含 SHOP_SCREEN preload，無 parse error）")
	GameManager.player.flags.erase("zheng_ma_shop_unlocked")  # 還原狀態（與其他測試一致）
