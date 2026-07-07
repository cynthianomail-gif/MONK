extends Node
## 破戒系統（2026-07-07 改版：成就式自動觸發）。
## 舊設計＝走近誘惑點/對話分支彈「破戒（N 金）」金錢確認框，金額不足會靜默失敗；
## 使用者拍板改為：完成對應支線後自動觸發（像成就解鎖），不花錢、不彈確認框、
## 不再走近 NPC 就跳窗。演出照舊：業障上身＋內心戲獨白（vow_break_<type>）＋
## 破戒過場（break_<type>）。「櫻解鎖為戰鬥後援」效果已依使用者決定移除。

const VOWS: Dictionary = {
	"food":  {"name": "飲食戒", "karma_gain": 50,
			  "effect": "berserker", "cutscene": "break_food", "flag": "broke_food_vow"},
	"lust":  {"name": "色戒", "karma_gain": 30,
			  "effect": "", "cutscene": "break_lust", "flag": "broke_lust_vow"},
	"greed": {"name": "貪戒", "karma_gain": 40,
			  "effect": "gold_multiplier", "cutscene": "break_greed", "flag": "broke_greed_vow"}
}

## 支線 id → 對應破戒。require_flag 非空＝該支線要以特定分支收尾才破
## （cherry_debt 只有「帶櫻逃跑」分支會破色戒；還錢/談判收尾不破）。
const QUEST_VOWS: Dictionary = {
	"ah_zhong":    {"vow": "food",  "require_flag": ""},
	"zheng_ma":    {"vow": "greed", "require_flag": ""},
	"cherry_debt": {"vow": "lust",  "require_flag": "cherry_escape"},
}

func _ready() -> void:
	EventBus.quest_updated.connect(_on_quest_updated)

func _on_quest_updated(quest_id: String, status: String) -> void:
	if status != "completed":
		return
	var m: Dictionary = QUEST_VOWS.get(quest_id, {})
	if m.is_empty():
		return
	if String(m.require_flag) != "" and not GameManager.get_flag(String(m.require_flag)):
		return
	# quest_updated 是在支線收尾對話 timeline_ended 的連鎖裡發出的——延一幀再起
	# 獨白 timeline，避免在 Dialogic 收尾流程中重入 Dialogic.start。
	trigger.call_deferred(String(m.vow))

## 破戒（冪等：該戒已破過就靜默跳過）。公開供測試或未來劇情事件直呼。
func trigger(vow_type: String) -> void:
	var vow: Dictionary = VOWS.get(vow_type, {})
	if vow.is_empty():
		return
	if GameManager.get_flag(vow.flag):
		return
	GameManager.add_karma(vow.karma_gain)
	GameManager.set_flag(vow.flag, true)
	GameManager.set_flag("broke_any_vow", true)
	EventBus.vow_broken.emit(vow_type)
	_apply_effect(String(vow.effect))
	SkillUnlockManager.check_unlocks()
	# 破戒當下的內心戲獨白（vow_break_<type>），播完再進過場。
	var monologue: String = "vow_break_%s" % vow_type
	if ResourceLoader.exists("res://dialogue/%s.dtl" % monologue):
		Dialogic.start(monologue)
		await Dialogic.timeline_ended
	SceneRouter.play_cutscene(vow.cutscene, "map")

func _apply_effect(eff: String) -> void:
	match eff:
		"berserker":
			GameManager.set_flag("buff_berserker_days", 3)
		"gold_multiplier":
			GameManager.set_flag("gold_multiplier_active", true)
			GameManager.set_flag("pickpocket_rate_up", true)
