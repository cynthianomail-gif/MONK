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
	"cherry_dialogue":     "與 櫻 說話",
	"quest_ah_ming":       "街頭藝人阿明",
	"wooden_fish_replay":  "再切磋一場木魚",
	"quest_rei":           "迷路的背包客澪",
	"quest_zheng_ma":      "佛具店水野",
	"quest_jie":           "電玩少年小傑",
	"quest_ah_zhong":      "老廚師阿忠師傅",
	"quest_david":         "失業工程師大衛",
	"quest_cherry_debt":   "櫻的債",
	"quest_cai_ma":        "媽媽桑蔡媽",
	"quest_grandma":       "老香客陳阿嬤",
	"quest_lao_wang":      "流浪漢老王"
}

const JOB_NAMES: Dictionary = {
	"ascetic": "苦行僧", "chanter": "念經僧", "beggar": "化緣僧"
}

@onready var stats_label: Label       = %StatsLabel
@onready var prompt: PanelContainer   = %InteractionPrompt
@onready var prompt_label: RichTextLabel = %PromptLabel
@onready var action_menu: PanelContainer = %ActionMenu
@onready var menu_title: Label        = %MenuTitle
@onready var menu_buttons: VBoxContainer = %MenuButtons
@onready var toast_label: Label       = %Toast

const MINIMAP := preload("res://src/screens/MapScreen/Minimap.gd")

const PROMPT_FADE_IN: float = 0.25
const PROMPT_FADE_OUT: float = 0.2
const KEY_COLOR: String = "#d12e21"      # 朱紅：按鍵強調
const TEXT_COLOR: String = "#f5f2e8"     # 近白：提示文字

var _toast_tween: Tween = null
var _prompt_tween: Tween = null
var _minimap: Control = null
var _action_hints: Control = null

func _ready() -> void:
	prompt.visible = false
	prompt.modulate.a = 0.0
	action_menu.visible = false
	toast_label.visible = false
	_add_minimap()
	_add_action_hints()
	GameManager.stat_changed.connect(func(_k, _v): update_stats())
	GameManager.job_changed.connect(func(_j): update_stats())
	EventBus.skill_unlocked.connect(func(n): show_toast("新技能解鎖：%s" % n))
	EventBus.skill_learnable.connect(func(n): show_toast("可學新招：%s（去經書習得）" % n))
	update_stats()
	_register_layout_tunables()

## 佈局工具 v2（P2）：地圖 HUD 上可自由定位的塊登記進 LayoutStore（父節點皆為
## MapHUD 這個 CanvasLayer，非 Container，is_free() 皆為 true）。
## 見 docs/superpowers/specs/2026-07-07-layout-tuner-v2-design.md（P2 擴充）。
## 注意：小地圖是 _add_minimap() 在本函式之前動態 add_child 進來的，此時已存在。
func _register_layout_tunables() -> void:
	LayoutStore.register(stats_label, "map/stats_label")
	LayoutStore.register(prompt, "map/interaction_prompt")
	LayoutStore.register(action_menu, "map/action_menu")
	LayoutStore.register(toast_label, "map/toast")
	if _minimap != null:
		LayoutStore.register(_minimap, "map/minimap")
	if _action_hints != null:
		LayoutStore.register(_action_hints, "map/action_hints")

func update_stats() -> void:
	var p: Dictionary = GameManager.player
	stats_label.text = "%s（%s）\nHP　%d / %d\n業障 %d ｜ 功德 %d\n金幣 %d" % [
		p.name, JOB_NAMES.get(p.job, p.job),
		p.current_hp, p.max_hp, p.karma, p.merit, p.gold
	]

## action_text 例：「與了塵對話」「進入保齡球館」——本函式負責套朱紅〔E〕前綴＋淡入。
func show_prompt(action_text: String) -> void:
	prompt_label.text = "[center][color=%s]〔E〕[/color][color=%s]%s[/color][/center]" % [
		KEY_COLOR, TEXT_COLOR, action_text
	]
	if prompt.visible and prompt.modulate.a > 0.0:
		return  # 已顯示中（例如換了目標但仍在範圍內）：文字更新即可，不重播淡入
	prompt.visible = true
	_play_prompt_tween(1.0, PROMPT_FADE_IN)

func hide_prompt() -> void:
	if not prompt.visible:
		return
	_play_prompt_tween(0.0, PROMPT_FADE_OUT, true)

func _play_prompt_tween(target_alpha: float, duration: float, hide_when_done: bool = false) -> void:
	if _prompt_tween:
		_prompt_tween.kill()
	_prompt_tween = create_tween()
	_prompt_tween.tween_property(prompt, "modulate:a", target_alpha, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if hide_when_done:
		_prompt_tween.tween_callback(func(): prompt.visible = false)

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
	_minimap = mm

## 左側常駐操作提示列（2026-07-10：使用者實機回饋「不知道 M 開選單/Shift 跑步/A·D 轉視角」，
## 半透明低調鍵帽＋中文說明，三行）。鍵位事實：open_menu=M（project.godot 77）、
## sprint=Shift（PlayerController.gd 執行期註冊）、cam_left/cam_right=Q/E（CameraRig.gd 執行期
## 註冊；2026-07-10 D-1 鍵位定案由 A/D 改 Q/E，避開與 ui_left/right(WASD 移動) 的鍵位重疊）。
func _add_action_hints() -> void:
	var box := VBoxContainer.new()
	box.name = "ActionHints"
	box.anchor_left = 0.0; box.anchor_right = 0.0
	box.anchor_top = 1.0; box.anchor_bottom = 1.0
	# 疊在 StatsLabel（bottom-left，y範圍 -200~-24）正上方，留 10px 間距避免重疊。
	box.offset_left = 20.0; box.offset_top = -300.0
	box.offset_right = 260.0; box.offset_bottom = -210.0
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.modulate.a = 0.72
	add_child(box)
	box.add_child(_hint_row(["M"], "經書"))
	box.add_child(_hint_row(["Shift"], "跑步"))
	box.add_child(_hint_row(["◀Q", "E▶"], "轉視角"))
	_action_hints = box

## 單行提示：一或多個鍵帽（StyleBoxFlat 圓角深底＋描邊字）＋中文說明。
func _hint_row(keys: Array, desc_text: String) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	for k in keys:
		row.add_child(_key_cap(String(k)))
	var desc := Label.new()
	desc.text = desc_text
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc.add_theme_color_override("font_color", Color(TEXT_COLOR))
	desc.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.03, 1.0))
	desc.add_theme_constant_override("outline_size", 4)
	desc.add_theme_font_size_override("font_size", 18)
	desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(desc)
	return row

## 鍵帽樣式：圓角深底＋朱紅描邊，字白色＋描邊保證可讀。
func _key_cap(key_text: String) -> Control:
	var pc := PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.06, 0.78)
	sb.border_color = Color(KEY_COLOR)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8.0; sb.content_margin_right = 8.0
	sb.content_margin_top = 2.0; sb.content_margin_bottom = 2.0
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(32.0, 0.0)
	var lbl := Label.new()
	lbl.text = key_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_color_override("font_color", Color(TEXT_COLOR))
	lbl.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.03, 1.0))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_font_size_override("font_size", 16)
	pc.add_child(lbl)
	return pc
