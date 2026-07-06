extends Node
## 端湯 3D 版場景冒煙 + 結構性驗證：instantiate 進幀不崩、桌位/出餐口/玩家/相機
## 節點存在、E 互動距離判定純邏輯、restart 重置乾淨。純邏輯計分斷言留給 TestSoupCarry.gd。
## 跑法：Godot --headless res://test/TestSoupCarry3D.tscn

const SCENE := preload("res://src/screens/Minigames/SoupCarry.tscn")

var ok := true

func _ready() -> void:
	await _test_scene_smoke()
	print("SOUP3D_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		ok = false
		print("FAIL: ", msg)

func _test_scene_smoke() -> void:
	var g = SCENE.instantiate()
	get_tree().root.add_child.call_deferred(g)
	for i in 5:
		await get_tree().process_frame

	# 場景結構：3D 世界節點、玩家、相機、目標箭頭都建立成功
	_check(g._world is Node3D, "soup3d world root is Node3D")
	_check(g._player is Node3D, "soup3d player node built")
	_check(g._cam is Camera3D, "soup3d camera built")
	_check(g._tray is Node3D and g._bowl is Node3D, "soup3d tray+bowl built")
	_check(g._target_arrow is Sprite3D, "soup3d target arrow built")

	# 桌位：規格要求 6-8 桌
	_check(g.TABLES.size() >= 6 and g.TABLES.size() <= 8, "soup3d has 6-8 tables (got %d)" % g.TABLES.size())
	_check(g._target_idx >= 0 and g._target_idx < g.TABLES.size(), "soup3d assigns valid target table on start")

	# 顧客：P3b 改成壽司店固定坐姿顧客(吧台4+桌邊3=7)，不再走動；另有師傅站吧台後
	_check(g._npcs.size() >= 4, "soup3d has >=4 seated customers (got %d)" % g._npcs.size())
	_check(g._chef is Node3D, "soup3d chef built behind counter")

	# 75 秒計時
	_check(g.GAME_TIME == 75.0, "soup3d game time = 75s")

	# E 互動距離判定（純邏輯：_near_pickup/_near_table 由玩家位置與門檻算出，
	# 不依賴實際輸入事件，直接操控 position 後呼叫 _check_proximity 驗證）。
	g._player.position = g.PICKUP_POS
	g._carrying = false
	g._check_proximity()
	_check(g._near_pickup == true, "soup3d near pickup when standing on it")
	g._player.position = g.PICKUP_POS + Vector3(20, 0, 20)
	g._check_proximity()
	_check(g._near_pickup == false, "soup3d not near pickup when far away")
	g._carrying = true
	g._target_idx = 0
	g._player.position = g.TABLES[0]
	g._check_proximity()
	_check(g._near_table == true, "soup3d near target table when standing on it")
	g._player.position = g.TABLES[0] + Vector3(20, 0, 20)
	g._check_proximity()
	_check(g._near_table == false, "soup3d not near table when far away")

	# restart：歸零全局結算、玩家歸位出餐口
	g.income = 999
	g.delivered_count = 5
	g.failed_count = 2
	g.total_spill = 123.0
	g.total_collision = 40
	g.total_bonus = 70
	g.low_streak = 3
	g._finished = true
	g._player.position = Vector3(100, 0, 100)
	g.restart()
	_check(g.income == 0 and g.delivered_count == 0 and g.failed_count == 0, "soup3d restart resets global tally")
	_check(g.total_spill == 0.0 and g.total_collision == 0 and g.total_bonus == 0, "soup3d restart resets spill/collision/bonus")
	_check(g.low_streak == 0, "soup3d restart resets streak")
	_check(g._finished == false, "soup3d restart clears _finished flag")
	_check(g._player.position.distance_to(g.PICKUP_POS) < 0.01, "soup3d restart returns player to pickup")
	_check(g.soup_amount == 100.0, "soup3d restart resets bowl via reset_bowl")

	_check(is_instance_valid(g), "soup3d instance still alive after smoke")
	g.queue_free()
	await get_tree().process_frame
