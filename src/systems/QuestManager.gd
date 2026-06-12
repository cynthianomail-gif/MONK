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
	Dialogic.timeline_ended.connect(
		func(): _advance_quest(quest_id, stage, q),
		CONNECT_ONE_SHOT
	)

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
		GameManager.player.skills_unlocked.append(s.unlock_skill)
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
