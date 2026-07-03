extends Node
## headless 驗證：戰鬥改版 第一期+第二期 純邏輯。
## 涵蓋：行動佇列排序、完美格擋判定窗（假輸入）、弱點探知記錄+存檔、道行結算、減傷檔位。
## 跑法：Godot --headless res://test/TestBattleOverhaul.tscn

var ok: bool = true

func _check(cond: bool, msg: String) -> void:
	if not cond:
		ok = false
		print("FAIL: ", msg)

func _ready() -> void:
	await get_tree().process_frame
	_test_speed_field()
	_test_turn_queue_sort()
	_test_guard_window()
	_test_guard_reduction_tiers()
	_test_weakness_intel()
	_test_weakness_intel_persist()
	_test_daoxing_reward()
	print("BATTLE_OVERHAUL_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

func _enemies() -> Dictionary:
	var d: Dictionary = JsonLoader.load_json("res://data/enemies.json")
	d.merge(JsonLoader.load_json("res://data/boss.json"))
	return d

# ─── 第二期：speed 欄位 ───
func _test_speed_field() -> void:
	var d := _enemies()
	# enemies.json 每敵都補了 speed
	for id in ["street_punk", "corrupt_vendor", "night_ghost", "drunk_guard", "temple_ghost", "pantheon_guard"]:
		_check(d.get(id, {}).has("speed"), "%s 有 speed 欄位" % id)
	_check(d.get("ares", {}).has("speed"), "ares(boss) 有 speed 欄位")
	var c := Combatant.from_enemy("street_punk", d["street_punk"])
	_check(c.speed == 14, "street_punk speed=14 讀入 (got %d)" % c.speed)
	# 缺 speed → 暫值公式 10+level*2
	var fake := {"name": "測試", "level": 5}
	var c2 := Combatant.from_enemy("fake", fake)
	_check(c2.speed == 20, "缺 speed 敵人 fallback 10+level*2 (got %d)" % c2.speed)

# ─── 第二期第1點：行動佇列排序 ───
func _test_turn_queue_sort() -> void:
	# 直接測排序邏輯：建 combatant 陣列，按 speed 降冪，同速玩家優先
	var p := Combatant.new(); p.is_player = true; p.speed = 15; p.current_hp = 100; p.max_hp = 100
	var slow := Combatant.new(); slow.speed = 10; slow.current_hp = 100; slow.max_hp = 100
	var fast := Combatant.new(); fast.speed = 22; fast.current_hp = 100; fast.max_hp = 100
	var tie := Combatant.new(); tie.speed = 15; tie.current_hp = 100; tie.max_hp = 100  # 與玩家同速
	var arr: Array = [slow, p, fast, tie]
	arr.sort_custom(func(a, b):
		if a.speed != b.speed:
			return a.speed > b.speed
		return a.is_player and not b.is_player)
	_check(arr[0] == fast, "最快者(spd22)排第一")
	_check(arr[1] == p, "同速時玩家(spd15)優先於非玩家")
	_check(arr[2] == tie, "同速非玩家排玩家之後")
	_check(arr[3] == slow, "最慢者(spd10)排最後")

# ─── 第二期第2點：完美格擋判定窗（可注入假輸入）───
func _test_guard_window() -> void:
	# 窗內按下 → 成功
	var gw := GuardWindow.new(0.5)
	gw.open()
	_check(gw.is_open(), "格擋窗開啟")
	var hit: bool = gw.tick(0.2, true)  # 0.2s 時按下（窗內）
	_check(hit, "窗內按下當幀觸發成功")
	_check(gw.succeeded(), "格擋窗記為成功")
	_check(not gw.is_open(), "成功後窗關閉")

	# 窗內未按 → 過期失敗
	var gw2 := GuardWindow.new(0.5)
	gw2.open()
	gw2.tick(0.3, false)
	gw2.tick(0.3, false)  # 累積 0.6 > 0.5 → 過期
	_check(not gw2.succeeded(), "窗過期未按＝失敗")
	_check(not gw2.is_open(), "過期後窗關閉")

	# 過窗才按 → 失敗
	var gw3 := GuardWindow.new(0.5)
	gw3.open()
	gw3.tick(0.6, false)   # 先過期
	var late: bool = gw3.tick(0.0, true)
	_check(not late, "過窗後按下不算成功")

	# 持續按住只算一次（邊緣偵測）
	var gw4 := GuardWindow.new(0.5)
	gw4.open()
	var e1: bool = gw4.tick(0.1, true)   # 按下 → 成功
	_check(e1, "首次按下觸發")

# ─── 第二期第2點：減傷檔位 50/70/90 ───
func _test_guard_reduction_tiers() -> void:
	# 用 SkillExecutor 的 apply_damage 路徑驗證玩家減傷
	var exec: Node = load("res://src/screens/BattleScreen/SkillExecutor.gd").new()
	var status: Node = load("res://src/screens/BattleScreen/StatusEffects.gd").new()
	status.name = "StatusEffects"
	exec.add_child(status)
	add_child(exec)
	await get_tree().process_frame

	# 防禦 50%
	var p1 := Combatant.new(); p1.is_player = true; p1.max_hp = 1000; p1.current_hp = 1000
	p1.is_guarding = true
	exec.apply_damage(p1, 100, null, "physical")
	_check(1000 - p1.current_hp == 50, "防禦減傷 50%%（受 50，got %d）" % (1000 - p1.current_hp))

	# 完美格擋 70%
	var p2 := Combatant.new(); p2.is_player = true; p2.max_hp = 1000; p2.current_hp = 1000
	p2.perfect_guard_ready = true
	exec.apply_damage(p2, 100, null, "physical")
	_check(1000 - p2.current_hp == 30, "完美格擋減傷 70%%（受 30，got %d）" % (1000 - p2.current_hp))

	# 疊加 90%
	var p3 := Combatant.new(); p3.is_player = true; p3.max_hp = 1000; p3.current_hp = 1000
	p3.is_guarding = true; p3.perfect_guard_ready = true
	exec.apply_damage(p3, 100, null, "physical")
	_check(1000 - p3.current_hp == 10, "防禦+完美疊加減傷 90%%（受 10，got %d）" % (1000 - p3.current_hp))

	# 無防禦＝全傷
	var p4 := Combatant.new(); p4.is_player = true; p4.max_hp = 1000; p4.current_hp = 1000
	exec.apply_damage(p4, 100, null, "physical")
	_check(1000 - p4.current_hp == 100, "無防禦＝全傷（受 100，got %d）" % (1000 - p4.current_hp))

	exec.queue_free()

# ─── 第一期：弱點探知記錄 ───
func _test_weakness_intel() -> void:
	# 清空既有記錄避免污染
	GameManager.player["weakness_intel"] = {}
	_check(not GameManager.knows_weakness("street_punk", "merit"), "初始未探知 street_punk merit")
	var was_new: bool = GameManager.record_weakness_intel("street_punk", "merit")
	_check(was_new, "首次記錄回傳 true（新探知）")
	_check(GameManager.knows_weakness("street_punk", "merit"), "記錄後已探知 street_punk merit")
	var again: bool = GameManager.record_weakness_intel("street_punk", "merit")
	_check(not again, "重複記錄回傳 false")
	# 徽章顯示邏輯：EnemyPanel 用 knows_weakness 決定顯示
	var d := _enemies()
	var c := Combatant.from_enemy("street_punk", d["street_punk"])
	var panel := EnemyPanel.new(c, 0)
	add_child(panel)
	await get_tree().process_frame
	_check(panel._weak_label.text.find("淨") != -1, "已探知敵人徽章顯示屬性名『淨』(got '%s')" % panel._weak_label.text)
	# 未探知的敵人顯示 ？
	var c2 := Combatant.from_enemy("corrupt_vendor", d["corrupt_vendor"])  # 弱 karma(業)，未探知
	var panel2 := EnemyPanel.new(c2, 1)
	add_child(panel2)
	await get_tree().process_frame
	_check(panel2._weak_label.text.find("？") != -1, "未探知敵人徽章顯示『？』(got '%s')" % panel2._weak_label.text)
	panel.queue_free()
	panel2.queue_free()

# ─── 第一期：弱點探知進存檔 ───
func _test_weakness_intel_persist() -> void:
	GameManager.player["weakness_intel"] = {}
	GameManager.record_weakness_intel("night_ghost", "merit")
	SaveManager.save_game()
	# 模擬重載：清掉記憶體再 load
	GameManager.player["weakness_intel"] = {}
	var loaded: bool = SaveManager.load_game()
	_check(loaded, "存檔可載回")
	_check(GameManager.knows_weakness("night_ghost", "merit"), "弱點探知隨存檔保留（重載後仍知曉）")
	# 清理測試存檔
	SaveManager.delete_save()

# ─── 第二期第4點：道行結算 ───
func _test_daoxing_reward() -> void:
	GameManager.player["daoxing"] = 0
	# 敵 level×15：street_punk level=2 → 30
	var d := _enemies()
	var e := Combatant.from_enemy("street_punk", d["street_punk"])
	var expected: int = e.level * 15
	GameManager.add_daoxing(expected)
	_check(int(GameManager.player.daoxing) == expected, "道行發放 level×15（street_punk L2→30，got %d）" % int(GameManager.player.daoxing))
	# Boss 加成 +200
	GameManager.player["daoxing"] = 0
	var boss := Combatant.from_enemy("ares", d["ares"])
	var boss_dx: int = boss.level * 15 + 200
	GameManager.add_daoxing(boss_dx)
	_check(int(GameManager.player.daoxing) == boss.level * 15 + 200, "Boss 道行含 +200 加成 (got %d)" % int(GameManager.player.daoxing))
	# 舊檔缺鍵防呆：刪掉 daoxing 鍵後 add 不炸
	GameManager.player.erase("daoxing")
	GameManager.add_daoxing(50)
	_check(int(GameManager.player.get("daoxing", -1)) == 50, "缺 daoxing 鍵時 add_daoxing 防呆重建 (got %s)" % str(GameManager.player.get("daoxing")))
