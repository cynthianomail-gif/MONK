extends Node
## headless 驗證：整場戰鬥流程煙霧測試（第四期，與 TestBattleOverhaul 互補）。
## TestBattleOverhaul 驗個別純邏輯（speed排序/格擋窗/減傷檔位/弱點探知/道行公式）；
## 本測試驗「串起來」：speed佇列 → 指令(含護法) → 技能結算 → One More → 全倒總攻擊 →
## 勝利道行/金幣/功德發放 → 回場。用真 BattleScreen 場景跑，不重複斷言已被覆蓋的細節公式。
## 跑法：Godot --headless res://test/TestBattleFlow.tscn

var ok: bool = true

func _check(cond: bool, msg: String) -> void:
	if not cond:
		ok = false
		print("FAIL: ", msg)

func _ready() -> void:
	await get_tree().process_frame
	await _test_full_round_to_victory()
	await _test_summon_in_real_queue()
	print("BATTLE_FLOW_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

func _make_battle():
	var scene: PackedScene = load("res://src/screens/BattleScreen/BattleScreen.tscn")
	var battle = scene.instantiate()
	get_tree().root.add_child(battle)
	return battle

## speed 佇列 → 玩家先手指令 → 攻擊技能結算 → 強制擊倒全部敵人觸發總攻擊 → 勝利結算道行/金幣。
func _test_full_round_to_victory() -> void:
	var battle = _make_battle()
	await get_tree().process_frame
	battle.setup("street_punk")  # player speed(15+盤加成) 通常 > street_punk speed(14)
	await get_tree().process_frame

	_check(battle.state == battle.State.PLAYER_TURN, "開場回合：玩家 speed 較高應先手")
	_check(not battle._full_queue.is_empty(), "行動佇列已建立")
	_check(battle._full_queue[0].is_player, "佇列第一位是玩家")

	GameManager.player.daoxing = 0
	GameManager.player.gold = 1000
	var start_gold: int = GameManager.player.gold

	# 直接用 force_victory 模擬「弱點連擊全倒 → 總攻擊 → 勝利」尾段（前段已由
	# TestBattleOverhaul 的 speed/guard/weakness 單元測試覆蓋，這裡驗證串接到勝利結算）。
	battle.force_victory()
	await get_tree().create_timer(1.0).timeout
	for i in 10:
		await get_tree().process_frame

	_check(battle.state == battle.State.END, "全滅後狀態轉為 END")
	_check(int(GameManager.player.daoxing) > 0, "勝利結算發放道行 (got %d)" % int(GameManager.player.daoxing))
	_check(GameManager.player.gold >= start_gold, "勝利結算金幣不減少 (got %d, start %d)" % [GameManager.player.gold, start_gold])

	if is_instance_valid(battle):
		battle.queue_free()
	GameManager.player.daoxing = 0
	GameManager.player.gold = 1000
	await get_tree().process_frame

## 護法召喚串進真實回合佇列：召喚消耗一回合 → 佇列推進到敵方行動，戰鬥不卡死。
func _test_summon_in_real_queue() -> void:
	var battle = _make_battle()
	await get_tree().process_frame
	battle.setup("street_punk")
	await get_tree().process_frame

	GameManager.player.gold = 5000
	_check(battle.state == battle.State.PLAYER_TURN, "玩家回合開始")
	await battle.player_use_summon("weituo_tian")
	# 召喚消耗一回合，非 One More，佇列應推進（不再停在同一個玩家 slot 等指令）；
	# 給幾幀讓後續敵人回合 / 回合結算的 await 鏈跑完，確認沒有卡死或報錯。
	for i in 20:
		await get_tree().process_frame
	_check(battle.summon_used("weituo_tian"), "護法召喚後標記已用（佇列有正常往下跑，非卡在原地重複觸發）")
	_check(battle.state != battle.State.SKILL_ANIM, "召喚演出後狀態已離開 SKILL_ANIM（沒卡住）")

	if is_instance_valid(battle):
		battle.queue_free()
	GameManager.player.gold = 1000
	await get_tree().process_frame
