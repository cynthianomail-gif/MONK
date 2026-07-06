extends Node
## headless 測試：main_quests.json stage.location ＋ quests.json quest.location 兩組
## 死資料欄位接線後的行為（2026-07-06 接線實作）。
## 覆蓋「條件不滿足被擋（含玩家回饋 toast 有出現）→ 條件滿足後放行」兩態。
## 跑法：Godot --headless res://test/TestQuestLocationWiring.tscn

var ok: bool = true
var _last_hint: String = ""
var _hint_count: int = 0

func _ready() -> void:
	await get_tree().process_frame
	EventBus.quest_location_blocked.connect(_on_hint)
	_test_stage_location_district_mapping()
	_test_main_quest_location_gate_blocks_then_passes()
	_test_fail_open_for_unmapped_locations()
	_test_quest_location_gate_blocks_then_passes()
	_test_quest_location_fail_open()
	print("QUEST_LOCATION_WIRING_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		ok = false
		print("FAIL: ", msg)

func _on_hint(hint: String) -> void:
	_last_hint = hint
	_hint_count += 1

# ============================================================
# 主線 stage.location 門檻（MainQuestManager）
# ============================================================

func _test_stage_location_district_mapping() -> void:
	var m := MainQuestManager
	_check(m.stage_location_district("pantheon_security_hq") == "armory",
		"pantheon_security_hq 對應 armory district")
	_check(m.stage_location_district("hermes_logistics") == "",
		"hermes_logistics 尚無對應 district（fail-open 值＝空字串）")
	_check(m.stage_location_district("totally_made_up_place") == "",
		"未知地點對應空字串")

func _test_main_quest_location_gate_blocks_then_passes() -> void:
	var m := MainQuestManager
	var saved_area: String = String(GameManager.player.get("current_area", "shrine"))
	var saved_flags: Dictionary = GameManager.player.flags.duplicate()
	# armory 已解鎖（模擬 c1_intel 之後），但玩家人在 shrine → 應被擋
	GameManager.set_flag("armory_unlocked", true)
	GameManager.player.current_area = "shrine"
	var stage := {"id": "c1_confront", "location": "pantheon_security_hq", "dialogue": "main_ares_lead"}
	_check(not m.stage_location_passed(stage), "人在 shrine、stage 要求 armory → 門檻不通過")
	_hint_count = 0
	_last_hint = ""
	var stage_ok: bool = await m._run_stage(stage)
	_check(stage_ok == false, "_run_stage 在地點不符時回傳 false（中止本章）")
	_check(_hint_count == 1, "地點不符時發出 1 次 quest_location_blocked 提示 (got %d)" % _hint_count)
	_check(_last_hint.find("軍火庫") != -1 or _last_hint.length() > 0, "提示文字非空 (got '%s')" % _last_hint)
	# 玩家移動到 armory 後 → 門檻應通過
	GameManager.player.current_area = "armory"
	_check(m.stage_location_passed(stage), "人在 armory、stage 要求 armory → 門檻通過")
	# 還原
	GameManager.player.current_area = saved_area
	GameManager.player.flags = saved_flags

func _test_fail_open_for_unmapped_locations() -> void:
	var m := MainQuestManager
	var saved_area: String = String(GameManager.player.get("current_area", "shrine"))
	GameManager.player.current_area = "shrine"
	# ch2 的 hermes_logistics 尚未對應任何現行 district → 不該擋（fail-open）
	var stage := {"id": "c2_hub", "desc": "x", "location": "hermes_logistics"}
	_check(m.stage_location_passed(stage), "hermes_logistics 未對應 district → fail-open 通過")
	# armory 尚未解鎖時（armory_unlocked 未設）也不該擋，避免與既有解鎖流程打架
	var saved_flags: Dictionary = GameManager.player.flags.duplicate()
	GameManager.player.flags.erase("armory_unlocked")
	var stage2 := {"id": "c1_confront", "location": "pantheon_security_hq"}
	_check(m.stage_location_passed(stage2), "armory 尚未解鎖時 fail-open 通過（不與 c1_intel 解鎖流程打架）")
	GameManager.player.flags = saved_flags
	GameManager.player.current_area = saved_area

# ============================================================
# 支線 quest.location 門檻（QuestManager）
# ============================================================

func _test_quest_location_gate_blocks_then_passes() -> void:
	var qm := QuestManager
	# 現行資料：ah_ming.location=ximen_mrt(district shrine)，npc_ah_ming 也在 shrine → 通過
	_check(qm.quest_location_passed("ah_ming", "npc_ah_ming"),
		"ah_ming 支線：quest 地點與觸發 NPC 同在 shrine → 通過")
	# 模擬觸發點在不同 district（假設有一天某 NPC 搬到 armory）
	var fake_npcs: Dictionary = qm._npcs.duplicate(true)
	fake_npcs["npc_ah_ming"] = fake_npcs.get("npc_ah_ming", {}).duplicate()
	fake_npcs["npc_ah_ming"]["district"] = "armory"
	var saved_npcs: Dictionary = qm._npcs
	qm._npcs = fake_npcs
	_hint_count = 0
	_check(not qm.quest_location_passed("ah_ming", "npc_ah_ming"),
		"觸發點搬到 armory、quest 仍要求 shrine → 門檻不通過")
	# 透過 trigger_action 走一次，確認會發 toast 提示且不觸發對話
	var saved_active: Dictionary = GameManager.player.active_quests.duplicate()
	GameManager.player.active_quests.erase("ah_ming")
	var timeline_before := Dialogic.current_timeline
	qm.trigger_action("quest_ah_ming", "npc_ah_ming")
	_check(_hint_count == 1, "trigger_action 地點不符時發出 1 次提示 (got %d)" % _hint_count)
	_check(not GameManager.player.active_quests.has("ah_ming"), "地點不符時未推進 active_quests")
	# 還原後應通過
	qm._npcs = saved_npcs
	_check(qm.quest_location_passed("ah_ming", "npc_ah_ming"), "還原觸發點 district 後 → 門檻恢復通過")
	GameManager.player.active_quests = saved_active

func _test_quest_location_fail_open() -> void:
	var qm := QuestManager
	# quest_id 不存在 → district 查詢回傳空字串 → fail-open 通過
	_check(qm.quest_location_passed("no_such_quest", "npc_ah_ming"),
		"不存在的支線 id → fail-open 通過")
	# 觸發點不在 map_npcs.json（例如舊測試直接呼叫，非地圖互動觸發）→ fail-open 通過
	_check(qm.quest_location_passed("ah_ming", "not_a_real_trigger_point"),
		"觸發點不在 map_npcs.json → fail-open 通過")
