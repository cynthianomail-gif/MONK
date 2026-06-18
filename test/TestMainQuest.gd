extends Node
## headless 測試：MainQuestManager 主線推進引擎 ＋ 第 1 章資料完整性。
## 跑法：Godot --headless res://test/TestMainQuest.tscn

var ok: bool = true

func _ready() -> void:
	await get_tree().process_frame
	_test_data_integrity()
	_test_chapter_gating()
	_test_completion_and_rewards()
	print("MAIN_QUEST_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		ok = false
		print("FAIL: ", msg)

func _reset_flags() -> void:
	GameManager.player.flags = {}
	GameManager.player.gold = 1000
	GameManager.player.merit = 0
	GameManager.player.karma = 0

func _test_data_integrity() -> void:
	var mq: Dictionary = JsonLoader.load_json("res://data/main_quests.json")
	for k in mq.keys():
		if String(k).begins_with("_"):
			mq.erase(k)  # _schema / _demo 等 meta key
	_check(mq.size() == 12, "main_quests 12 章 (got %d)" % mq.size())
	_check(mq.has("ch01_ares"), "有 ch01_ares")
	var c1: Dictionary = mq.get("ch01_ares", {})
	_check(c1.get("stages", []).size() >= 3, "ch01 至少 3 stage")
	_check(c1.get("complete_flag", "") == "ares_purified", "ch01 complete_flag=ares_purified")
	# 第 1 章引用的資產都解析得到
	var enemies: Dictionary = JsonLoader.load_json("res://data/enemies.json")
	enemies.merge(JsonLoader.load_json("res://data/boss.json"))
	_check(enemies.has("pantheon_guard"), "敵兵 pantheon_guard 已補")
	_check(enemies.has("ares"), "Boss ares 在 boss.json")
	_check(not enemies.get("ares", {}).has("unlock_ending"), "ares 已移除 unlock_ending bug")
	_check(ResourceLoader.exists("res://dialogue/main_ares_lead.dtl"), "對話 main_ares_lead.dtl 存在")
	var cuts: Dictionary = JsonLoader.load_json("res://data/cutscenes.json")
	_check(cuts.has("ares_intro"), "過場 ares_intro 已補")
	_check(cuts.has("opening_temple_falls"), "過場 opening_temple_falls 仍在")
	# 成就（十二因緣）對齊 12 章 complete_flag
	var ach: Dictionary = JsonLoader.load_json("res://data/achievements.json")
	_check(ach.get("ignorance", {}).get("unlock_flag", "") == "ares_purified", "成就 無明 綁 ares_purified")

func _test_chapter_gating() -> void:
	_reset_flags()
	_check(MainQuestManager.current_chapter_id() == "ch01_ares", "起手第 1 章 = ch01_ares (got %s)" % MainQuestManager.current_chapter_id())
	_check(not MainQuestManager.is_all_cleared(), "起手未全破")

func _test_completion_and_rewards() -> void:
	_reset_flags()
	var gold0: int = GameManager.player.gold
	var merit0: int = GameManager.player.merit
	MainQuestManager._complete_chapter("ch01_ares")
	_check(bool(GameManager.get_flag("ares_purified")), "通章設 ares_purified")
	_check(GameManager.player.gold == gold0 + 1000, "獎勵 gold +1000 (got +%d)" % (GameManager.player.gold - gold0))
	_check(GameManager.player.merit == merit0 + 10, "獎勵 merit +10 (got +%d)" % (GameManager.player.merit - merit0))
	_check(MainQuestManager.current_chapter_id() == "ch02_hermes", "完成後推進到 ch02_hermes (got %s)" % MainQuestManager.current_chapter_id())
