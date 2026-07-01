extends Node

var _quests: Dictionary = {}

func _ready() -> void:
	_quests = JsonLoader.load_json("res://data/quests.json")

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
