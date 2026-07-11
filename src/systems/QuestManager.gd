extends Node

## c1_armory_gate（了塵修練門檻，data/main_quests.json）前置支線：了塵在 main_ch1_intel
## 點名的三位（大村 ah_zhong／水野 zheng_ma／源造 lao_wang），各自的支線完成後都會讓對應
## 技能（sound_wave/great_compassion_shield/lions_roar）在經書「可習得」，任兩位湊到修練
## 火候即可放行 gate（見 skill-learning-system-design.md「湊法」段）。硬編碼於此非資料驅動
## 欄位，因為目前僅 ch1 這一個 gate 有此設計；未來若其他章節出現同型門檻，屆時再抽成通用欄位。
const C1_ARMORY_GATE_CHAPTER := "ch01_ares"
const C1_ARMORY_GATE_STAGE_ID := "c1_armory_gate"
const C1_ARMORY_GATE_QUESTS := ["ah_zhong", "zheng_ma", "lao_wang"]
const C1_ARMORY_GATE_NEED := 2

var _quests: Dictionary = {}
var _npcs: Dictionary = {}       # map_npcs.json：現行 3D 互動點，供 location 門檻查 district
var _locations: Dictionary = {}  # map_locations.json：quest.location 值查 district 用

func _ready() -> void:
	_quests = JsonLoader.load_json("res://data/quests.json")
	_npcs = JsonLoader.load_json("res://data/map_npcs.json")
	_locations = JsonLoader.load_json("res://data/map_locations.json")

## quest.location（map_locations.json 的舊 2D 地點 id）所在的 district。
## 對不上就回傳 ""（fail-open：不擋，因為那是資料尚未跟上的訊號，不該卡支線）。純函式，供測試。
func quest_location_district(quest_id: String) -> String:
	var q: Dictionary = _quests.get(quest_id, {})
	var loc_id := String(q.get("location", ""))
	if loc_id == "":
		return ""
	return String(_locations.get(loc_id, {}).get("district", ""))

## 觸發支線的互動點（NPC id，如 npc_ah_ming）所在的 district。對不上就回傳 ""。純函式，供測試。
func trigger_point_district(location: String) -> String:
	return String(_npcs.get(location, {}).get("district", ""))

## 支線的地點門檻是否通過：
## - quest 沒填 location，或 location 對不上 map_locations.json（fail-open）→ 通過。
## - 觸發點（NPC）對不上 map_npcs.json（如非地圖互動觸發、舊測試直呼）→ fail-open 通過。
## - 兩邊都查得到 district → 要求兩個 district 相同（現行所有支線 NPC 都在 shrine，
##   目前恆為 true；此檢查是為未來把某支線 NPC 放進其他 district 時提供真正防呆）。
## 純函式，供測試。
func quest_location_passed(quest_id: String, location: String) -> bool:
	var quest_dist := quest_location_district(quest_id)
	if quest_dist == "":
		return true
	var trigger_dist := trigger_point_district(location)
	if trigger_dist == "":
		return true
	return trigger_dist == quest_dist

func trigger_action(action: String, _location: String) -> void:
	var quest_id: String = action.replace("quest_", "")
	var q: Dictionary = _quests.get(quest_id, {})
	if q.is_empty():
		push_warning("QuestManager: 找不到支線 %s" % quest_id)
		return
	# 前置條件檢查
	if q.has("require_flag") and not GameManager.get_flag(q.require_flag):
		return
	if q.has("require_completed") and q.require_completed not in GameManager.player.completed_quests:
		return
	if not quest_location_passed(quest_id, _location):
		EventBus.quest_location_blocked.emit("這件事不是在這裡辦的")
		return
	var stage: int = GameManager.player.active_quests.get(quest_id, 0)
	if stage >= q.stages.size():
		return
	var dialogue: String = q.stages[stage].get("dialogue", "")
	if not _timeline_exists(dialogue):
		push_warning("QuestManager: 對話 %s 尚未製作（Step 7）" % dialogue)
		return
	Dialogic.start(dialogue)
	# 該 stage 若帶 trigger_minigame：對話結束後先玩小遊戲，
	# 由 SceneRouter 依結果套用 win/lose，再推進 stage。
	if q.stages[stage].has("trigger_minigame"):
		Dialogic.timeline_ended.connect(
			func(): _start_stage_minigame(quest_id, stage, q),
			CONNECT_ONE_SHOT
		)
	else:
		Dialogic.timeline_ended.connect(
			func(): _advance_quest(quest_id, stage, q),
			CONNECT_ONE_SHOT
		)

func _start_stage_minigame(id: String, stage: int, q: Dictionary) -> void:
	var s: Dictionary = q.stages[stage]
	var ctx: Dictionary = {}
	if s.has("win"):
		ctx["quest_win"] = s.win
	if s.has("lose"):
		ctx["quest_lose"] = s.lose
	# 小遊戲結束（獎勵已由 SceneRouter 套用）後推進支線。
	SceneRouter.minigame_finished.connect(
		func(_mid: String, _res: Dictionary): _advance_quest(id, stage, q),
		CONNECT_ONE_SHOT
	)
	SceneRouter.go_to_minigame(s.trigger_minigame, ctx)

func _advance_quest(id: String, stage: int, q: Dictionary) -> void:
	var s: Dictionary = q.stages[stage]
	# 發放獎勵
	if s.has("merit"):
		GameManager.add_merit(s.merit)
	if s.has("karma"):
		GameManager.add_karma(s.karma)
	if s.has("gold"):
		GameManager.add_gold(s.gold)
	if s.has("flag"):
		GameManager.set_flag(s.flag, true)
	if s.has("hp_max_up"):
		GameManager.player.max_hp += s.hp_max_up
	if s.has("unlock_skill"):
		SkillUnlockManager.grant_skill(s.unlock_skill)
	# 推進階段
	var next_stage: int = stage + 1
	if next_stage >= q.stages.size():
		GameManager.player.completed_quests.append(id)
		GameManager.player.active_quests.erase(id)
		EventBus.quest_updated.emit(id, "completed")
	else:
		GameManager.player.active_quests[id] = next_stage
		EventBus.quest_updated.emit(id, "advanced")
	SkillUnlockManager.check_unlocks()

func _timeline_exists(timeline: String) -> bool:
	if timeline.is_empty():
		return false
	return ResourceLoader.exists("res://dialogue/%s.dtl" % timeline)

## 支線「現在可觸發」嗎？（同 trigger_action 的前置檢查：require_flag/require_completed
## 滿足、目前 stage 未完、該 stage 對話已製作）。給 NPC「!」提示與小地圖標記共用。
func is_quest_actionable(quest_id: String) -> bool:
	var q: Dictionary = _quests.get(quest_id, {})
	if q.is_empty():
		return false
	if q.has("require_flag") and not GameManager.get_flag(q.require_flag):
		return false
	if q.has("require_completed") and q.require_completed not in GameManager.player.completed_quests:
		return false
	var stage: int = GameManager.player.active_quests.get(quest_id, 0)
	if stage >= q.stages.size():
		return false
	return _timeline_exists(q.stages[stage].get("dialogue", ""))

## 地點是否有「現在可做」的任務（主線或支線）→ NPC 頭上「!」＋小地圖任務標記。
func location_has_quest(loc_data: Dictionary) -> bool:
	for action in loc_data.get("actions", []):
		var a := String(action)
		if a == "main_quest":
			if not MainQuestManager.is_demo_complete():
				return true
		elif a.begins_with("quest_"):
			if is_quest_actionable(a.replace("quest_", "")):
				return true
	return false

## 地點是否有「現在可推進的主線」（main_quest action，demo 未跑完）——與支線分開判斷，
## 供小地圖／3D 觸發點標記橘色（2026-07-10：主線點統一橘色，跟支線黃/金一眼可分）。
## 2026-07-11：主線卡在 c1_armory_gate 期間，尚未完成的前置支線地點也視為主線目標（橘點），
## 玩家才知道要去哪——否則只看得到了塵本人橘、其他全黃，不知道兩顆黃點哪個才是關鍵。
func location_has_main_quest(loc_data: Dictionary) -> bool:
	for action in loc_data.get("actions", []):
		if String(action) == "main_quest":
			return not MainQuestManager.is_demo_complete()
	var pending := c1_armory_gate_pending_quests()
	if pending.is_empty():
		return false
	for action in loc_data.get("actions", []):
		var a := String(action)
		if a.begins_with("quest_") and a.replace("quest_", "") in pending:
			return true
	return false

## 目前卡 c1_armory_gate 期間，還「有意義」需要玩家去做的前置支線 id 清單（尚未完成者）。
## 未卡在該 gate、或已湊滿 C1_ARMORY_GATE_NEED 位（即使還有第三位沒幫）都回傳空陣列——
## 已湊滿就不該再把玩家追著跑第三位，橘點該讓給了塵本人承接的「下一步」。純函式，供測試。
func c1_armory_gate_pending_quests() -> Array:
	if not MainQuestManager.is_blocked_at_gate(C1_ARMORY_GATE_CHAPTER, C1_ARMORY_GATE_STAGE_ID):
		return []
	var done := 0
	var pending: Array = []
	for qid in C1_ARMORY_GATE_QUESTS:
		if qid in GameManager.player.completed_quests:
			done += 1
		else:
			pending.append(qid)
	if done >= C1_ARMORY_GATE_NEED:
		return []
	return pending
