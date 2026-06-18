extends Node

const VOWS: Dictionary = {
	"food":  {"name": "飲食戒", "gold_cost": 3000, "karma_gain": 50,
			  "desc": "吃下那碗極品和牛。業障滾燙，但真的太香了。",
			  "effect": "berserker", "cutscene": "break_food", "flag": "broke_food_vow"},
	"lust":  {"name": "色戒", "gold_cost": 5000, "karma_gain": 30,
			  "desc": "Cherry 靠近時，你沒有起身離開。",
			  "effect": "cherry_combat_ally", "cutscene": "break_lust", "flag": "broke_lust_vow"},
	"greed": {"name": "貪戒", "gold_cost": 8000, "karma_gain": 40,
			  "desc": "純金勞力士念珠戴上，你感覺自己是新梵市之王。",
			  "effect": "gold_multiplier", "cutscene": "break_greed", "flag": "broke_greed_vow"}
}

const CONFIRM_DIALOG: String = "res://src/ui/ConfirmDialog.tscn"

func try_trigger(vow_type: String) -> void:
	var vow: Dictionary = VOWS.get(vow_type, {})
	if vow.is_empty():
		return
	if GameManager.get_flag(vow.flag):
		_start_dialogue_or_warn("vow_already_broken")
		return
	_show_confirm(vow, vow_type)

func _show_confirm(vow: Dictionary, vow_type: String) -> void:
	if not ResourceLoader.exists(CONFIRM_DIALOG):
		push_warning("BreakVowSystem: ConfirmDialog 尚未實作")
		return
	var dlg: Node = load(CONFIRM_DIALOG).instantiate()
	get_tree().root.add_child(dlg)
	dlg.setup(vow.desc, "破戒（%d 金）" % vow.gold_cost, "南無阿彌陀佛……離開")
	var ok: bool = await dlg.chose
	dlg.queue_free()
	if ok:
		_execute(vow_type, vow)

func _execute(vow_type: String, vow: Dictionary) -> void:
	if not GameManager.spend_gold(vow.gold_cost):
		_start_dialogue_or_warn("vow_no_gold")
		return
	GameManager.add_karma(vow.karma_gain)
	GameManager.set_flag(vow.flag, true)
	GameManager.set_flag("broke_any_vow", true)
	EventBus.vow_broken.emit(vow_type)
	_apply_effect(vow.effect)
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
		"cherry_combat_ally":
			GameManager.set_flag("cherry_unlocked", true)
		"gold_multiplier":
			GameManager.set_flag("gold_multiplier_active", true)
			GameManager.set_flag("pickpocket_rate_up", true)

func _start_dialogue_or_warn(timeline: String) -> void:
	if ResourceLoader.exists("res://dialogue/%s.dtl" % timeline):
		Dialogic.start(timeline)
	else:
		push_warning("BreakVowSystem: 對話 %s 尚未製作" % timeline)
