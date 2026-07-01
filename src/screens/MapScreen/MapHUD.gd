extends CanvasLayer

## 3D 探索地圖 HUD（Step 1 佔位版，Step 4 換成霓虹風格元件）

const ACTION_LABELS: Dictionary = {
	"main_quest":          "繼續修行（主線）",
	"armory_npc":          "與鐵叔搭話",
	"random_encounter":    "尋找麻煩（遭遇戰）",
	"beggar_minigame":     "化緣挑戰",
	"shop":                "購物",
	"rest":                "休息",
	"save":                "存檔",
	"job_switch":          "職業切換",
	"cherry_dialogue":     "與 Cherry 說話",
	"food_break_trigger":  "和牛的香氣……（破飲食戒）",
	"greed_break_trigger": "金色的誘惑……（破貪戒）",
	"lust_break_trigger":  "留下來……（破色戒）",
	"quest_ah_ming":       "街頭藝人阿明",
	"quest_rei":           "迷路的背包客澪",
	"quest_zheng_ma":      "佛具店鄭媽",
	"quest_jie":           "電玩少年小傑",
	"quest_ah_zhong":      "老廚師阿忠師傅",
	"quest_david":         "失業工程師大衛",
	"quest_cherry_debt":   "Cherry 的債",
	"quest_cai_ma":        "媽媽桑蔡媽",
	"quest_grandma":       "老香客陳阿嬤",
	"quest_lao_wang":      "流浪漢老王"
}

const JOB_NAMES: Dictionary = {
	"ascetic": "苦行僧", "chanter": "念經僧", "beggar": "化緣僧"
}

@onready var time_label: Label        = %TimeLabel
@onready var stats_label: Label       = %StatsLabel
@onready var prompt: Label            = %InteractionPrompt
@onready var action_menu: PanelContainer = %ActionMenu
@onready var menu_title: Label        = %MenuTitle
@onready var menu_buttons: VBoxContainer = %MenuButtons
@onready var toast_label: Label       = %Toast

const MINIMAP := preload("res://src/screens/MapScreen/Minimap.gd")
const QUEST_MARKERS := preload("res://src/screens/MapScreen/QuestMarkers.gd")

var _toast_tween: Tween = null

func _ready() -> void:
	prompt.visible = false
	action_menu.visible = false
	toast_label.visible = false
	_add_quest_markers()
	_add_minimap()
	GameManager.stat_changed.connect(func(_k, _v): update_stats())
	GameManager.job_changed.connect(func(_j): update_stats())
	EventBus.skill_unlocked.connect(func(n): show_toast("新技能解鎖：%s" % n))
	EventBus.skill_learnable.connect(func(n): show_toast("可學新招：%s（去經書習得）" % n))
	update_stats()

func set_time(day: int, period_name: String) -> void:
	time_label.text = "第 %d 天 ｜ %s" % [day, period_name]

func update_stats() -> void:
	var p: Dictionary = GameManager.player
	stats_label.text = "%s（%s）\nHP　%d / %d\n業障 %d ｜ 功德 %d\n金幣 %d" % [
		p.name, JOB_NAMES.get(p.job, p.job),
		p.current_hp, p.max_hp, p.karma, p.merit, p.gold
	]

func show_prompt(text: String) -> void:
	prompt.text = text
	prompt.visible = true

func hide_prompt() -> void:
	prompt.visible = false

func show_action_menu(title: String, actions: Array, callback: Callable) -> void:
	menu_title.text = title
	_clear_buttons()
	for action in actions:
		var btn := Button.new()
		btn.text = ACTION_LABELS.get(action, action)
		btn.pressed.connect(callback.bind(action), CONNECT_ONE_SHOT)
		menu_buttons.add_child(btn)
	var close_btn := Button.new()
	close_btn.text = "離開"
	close_btn.pressed.connect(hide_action_menu)
	menu_buttons.add_child(close_btn)
	action_menu.visible = true

func hide_action_menu() -> void:
	action_menu.visible = false
	_clear_buttons()

func open_job_menu() -> void:
	menu_title.text = "職業切換"
	_clear_buttons()
	for job in JOB_NAMES:
		var btn := Button.new()
		btn.text = JOB_NAMES[job]
		btn.pressed.connect(func():
			GameManager.switch_job(job)
			show_toast("切換為 %s" % JOB_NAMES[job])
			hide_action_menu()
		)
		menu_buttons.add_child(btn)
	action_menu.visible = true

func show_toast(text: String) -> void:
	toast_label.text = text
	toast_label.visible = true
	toast_label.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(func(): toast_label.visible = false)

func _clear_buttons() -> void:
	for c in menu_buttons.get_children():
		c.queue_free()

## 右上角小地圖（雷達式，標地標＋任務地點）。
func _add_minimap() -> void:
	var mm: Control = MINIMAP.new()
	mm.name = "Minimap"
	mm.anchor_left = 1.0; mm.anchor_right = 1.0
	mm.anchor_top = 0.0; mm.anchor_bottom = 0.0
	# 右上角、時間標籤(top-right)下方，避免重疊。
	mm.offset_left = -164.0; mm.offset_top = 60.0
	mm.offset_right = -16.0; mm.offset_bottom = 208.0
	add_child(mm)

## NPC 頭上任務「！」（螢幕空間投影）。放最底層，讓選單/toast 蓋在上面。
func _add_quest_markers() -> void:
	var qm: Control = QUEST_MARKERS.new()
	qm.name = "QuestMarkers"
	add_child(qm)
	move_child(qm, 0)
