class_name BattleTutorial
extends Control

## 教學小視窗（P5 摩爾加納風格）：左上角了塵小立繪＋台詞框，戰鬥中逐步講解系統。
## 只在 tutorial_battle 旗標開著時觸發，每個教學點只播一次；顯示期間暫停戰鬥流程推進，
## 玩家按確認鍵（interact/confirm，沿用戰鬥既有確認輸入）才繼續。
##
## 用法：BattleManager 在對應時機呼叫 await tutorial.show_point(point_id)。
## show_point() 若非教學戰或該點已播過，立即回傳（不擋流程）。

const PORTRAIT_PATH := "res://assets/2d/portraits/npcs/bust/npc_liaochen.png"
const PORTRAIT_PATH_SMILE := "res://assets/2d/portraits/npcs/bust/npc_liaochen_smile.png"
const GOLD := Color(0.788, 0.659, 0.38)
const INK_RED := Color(0.82, 0.18, 0.13)
const PANEL_BG := Color(0.07, 0.05, 0.04, 0.96)

## 教學點文案（≤60 字，逐步講解：回合制→指令選單→弱點/One More→完美格擋→收尾）。
const POINTS := {
	"intro": {
		"title": "回合順序",
		"text": "戰鬥依「敏捷」輪流行動，我方快過對方，會先出手。",
	},
	"menu": {
		"title": "指令選單",
		"text": "攻擊：免費近身；技能：耗業障/功德；防禦：減傷；道具：自我施放。",
	},
	"weakness": {
		"title": "弱點！",
		"text": "打中弱點會觸發「如來爆擊」，佛祖保佑再來一擊，可以立刻再行動一次，一路打到對方全倒。",
	},
	"guard": {
		"title": "完美格擋",
		"text": "敵人出招前會有紅色警示，這時按下「E」，能大幅減傷。",
	},
	"victory": {
		"title": "初試身手",
		"text": "修行才剛開始。往後遇上的，可不會這麼簡單。",
	},
}

signal point_shown(point_id: String)

var _shown: Dictionary = {}   # point_id -> true，本場已播過
var _panel: PanelContainer
var _portrait: TextureRect
var _title_label: Label
var _text_label: Label
var _hint_label: Label
var _waiting: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	visible = false
	_build()

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(24, 24)
	_panel.custom_minimum_size = Vector2(560, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_border_width_all(2)
	sb.border_color = GOLD
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(16)
	sb.shadow_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.35)
	sb.shadow_size = 8
	_panel.set("theme_override_styles/panel", sb)
	add_child(_panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	_panel.add_child(hbox)

	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(84, 84)
	_portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_set_portrait(PORTRAIT_PATH)
	hbox.add_child(_portrait)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(vbox)

	var name_row := HBoxContainer.new()
	vbox.add_child(name_row)
	var name_lbl := Label.new()
	name_lbl.text = "了塵"
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", GOLD)
	name_row.add_child(name_lbl)
	var sep := Label.new()
	sep.text = "　"
	name_row.add_child(sep)
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", INK_RED)
	name_row.add_child(_title_label)

	_text_label = Label.new()
	_text_label.add_theme_font_size_override("font_size", 20)
	_text_label.add_theme_color_override("font_color", Color(0.94, 0.94, 0.92))
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(420, 0)
	vbox.add_child(_text_label)

	_hint_label = Label.new()
	_hint_label.text = "（按 確認 繼續）"
	_hint_label.add_theme_font_size_override("font_size", 14)
	_hint_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.62))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(_hint_label)

## 依教學點切換小立繪（目前只有 victory 用 smile，其餘維持 default）。
func _set_portrait(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var full: Texture2D = load(path)
	var atlas := AtlasTexture.new()
	atlas.atlas = full
	# 只取上半身（頭肩）當小頭像：原圖 1383x1504，取頂部約 62% 高度置中裁切。
	var w: float = full.get_width()
	var h: float = full.get_height()
	atlas.region = Rect2(0, 0, w, h * 0.62)
	_portrait.texture = atlas

## 顯示指定教學點，await 直到玩家按確認鍵才回傳。非教學戰、未知 id、或已播過 → 立即回傳不擋流程。
func show_point(point_id: String) -> void:
	if not GameManager.get_flag("tutorial_battle"):
		return
	if _shown.get(point_id, false):
		return
	if not POINTS.has(point_id):
		return
	_shown[point_id] = true
	var data: Dictionary = POINTS[point_id]
	_title_label.text = "－%s" % data.title
	_text_label.text = String(data.text)
	_set_portrait(PORTRAIT_PATH_SMILE if point_id == "victory" else PORTRAIT_PATH)
	visible = true
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.15)
	point_shown.emit(point_id)
	_waiting = true
	await _wait_for_confirm()
	_waiting = false
	var out := create_tween()
	out.tween_property(self, "modulate:a", 0.0, 0.15)
	await out.finished
	visible = false
	if point_id == "victory":
		GameManager.set_flag("tutorial_battle", false)

## 逐幀輪詢確認鍵（同 BattleManager._run_guard_window 的做法：headless 無鍵盤時
## 靠測試注入 _test_force_confirm 推進，不會卡死自動化測試）。
var _test_force_confirm: bool = false
func inject_confirm() -> void:
	_test_force_confirm = true

func _wait_for_confirm() -> void:
	while true:
		await get_tree().process_frame
		if _test_force_confirm:
			_test_force_confirm = false
			return
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("confirm"):
			return

func has_shown(point_id: String) -> bool:
	return _shown.get(point_id, false)
