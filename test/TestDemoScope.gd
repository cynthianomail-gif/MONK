extends Node
## headless 測試：DEMO 範圍收尾（ch1 為最後一章、打完不掉進空 ch2）＋小遊戲觸發都存在。
## 跑法：Godot --headless res://test/TestDemoScope.tscn

var ok := true

func _ready() -> void:
	await get_tree().process_frame
	_test_demo_cap()
	_test_minigame_triggers()
	print("DEMO_SCOPE_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		ok = false
		print("FAIL: ", msg)

func _test_demo_cap() -> void:
	var m := MainQuestManager
	_check(m.demo_last_chapter() == "ch01_ares", "demo 最後一章＝ch01_ares (got %s)" % m.demo_last_chapter())
	GameManager.player.flags.erase("ares_purified")
	_check(not m.is_demo_complete(), "ares 未超渡 → demo 未完成")
	GameManager.set_flag("ares_purified", true)
	_check(m.is_demo_complete(), "ares_purified → demo 完成（不再跑 ch2）")
	GameManager.player.flags.erase("ares_purified")

func _test_minigame_triggers() -> void:
	var q: Dictionary = JsonLoader.load_json("res://data/quests.json")
	for qid in q:
		if String(qid).begins_with("_"):
			continue
		for s in q[qid].get("stages", []):
			if s.has("trigger_minigame"):
				var mid := String(s.trigger_minigame)
				var path := "res://src/screens/Minigames/%s.tscn" % mid.to_pascal_case()
				_check(ResourceLoader.exists(path), "%s 觸發的小遊戲 %s 存在（%s）" % [qid, mid, path])