extends CanvasLayer
## 對話回想 log（backlog）：對話進行中按 Tab 開關可捲動歷史面板，列出
## 「說話者（金字）：台詞（白字）」由舊到新，開啟自動捲到最底。
## 讀 Dialogic.History.get_simple_history()（Text/Choice 條目），自行維護一份
## 跨 timeline 保留的顯示用清單（上限 200，new_game 清空）。
## 常駐掛載：由 GameManager 於 _ready() 建立一次、掛在 root 下（CanvasLayer，layer=100，
## process_mode ALWAYS），不依賴任何特定畫面（MapScreen/BattleScreen 都能用）。
## 風格比照 ShopScreen/monk_textbox_panel：近黑底＋金框、金色名字＋白字台詞。

const GOLD := Color(0.957, 0.851, 0.541)
const PANEL_BG := Color(0.08, 0.075, 0.07, 1.0)
const WARM := Color(0.941, 0.913, 0.847)
const DIM := Color(0.55, 0.52, 0.46)

const MAX_ENTRIES := 200

## 顯示用清單：每筆 {speaker: String, text: String}。speaker 可為空字串（無名旁白/選項）。
var entries: Array[Dictionary] = []

var _scroll: ScrollContainer
var _log_box: VBoxContainer
var _panel: PanelContainer

## 上一次讀取 simple_history_content 的長度，避免重複把同筆條目加兩次。
var _last_seen_count: int = 0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()
	if Dialogic.has_subsystem("History"):
		Dialogic.History.simple_history_enabled = true
		if Dialogic.History.simple_history_changed.is_connected(_on_simple_history_changed):
			Dialogic.History.simple_history_changed.disconnect(_on_simple_history_changed)
		Dialogic.History.simple_history_changed.connect(_on_simple_history_changed)


func _input(event: InputEvent) -> void:
	var is_tab := false
	if event is InputEventKey and event.pressed and not event.echo:
		is_tab = event.keycode == KEY_TAB

	if visible:
		# 開啟期間吞掉全部輸入（對話不能被推進）：在 Dialogic 的文字框/選項層之前攔截。
		get_viewport().set_input_as_handled()
		if is_tab:
			AudioManager.play_sfx("ui_cancel")
			close()
		return

	if not is_tab:
		return
	if Dialogic.current_timeline == null:
		return

	get_viewport().set_input_as_handled()
	AudioManager.play_sfx("ui_select")
	open()


## 開啟期間吞掉所有輸入（對話不能被推進）：靠本節點的 CanvasLayer 蓋在最上層 +
## 本身 process_mode ALWAYS + set_input_as_handled 攔截；文字框在下層收不到已handled事件。
func open() -> void:
	_sync_from_history()
	visible = true
	call_deferred("_scroll_to_bottom")


func close() -> void:
	visible = false


## 把 Dialogic.History 的 simple_history_content 同步進本地顯示清單（累加式，
## 只處理新增的部分），並重繪 log_box。
func _sync_from_history() -> void:
	if not Dialogic.has_subsystem("History"):
		return
	var raw: Array = Dialogic.History.get_simple_history()
	for i in range(_last_seen_count, raw.size()):
		_append_entry(raw[i])
	_last_seen_count = raw.size()
	_redraw()


func _on_simple_history_changed() -> void:
	# 對話進行中即時累積，不等開面板才補讀（visible 時也要即時更新捲動）。
	if not Dialogic.has_subsystem("History"):
		return
	var raw: Array = Dialogic.History.get_simple_history()
	for i in range(_last_seen_count, raw.size()):
		_append_entry(raw[i])
	_last_seen_count = raw.size()
	if visible:
		_redraw()
		call_deferred("_scroll_to_bottom")


## 把一筆 Dialogic simple_history 條目轉成 {speaker, text} 並塞進 entries（上限 200，
## 超過從最舊的開始丟棄）。
func _append_entry(info: Dictionary) -> void:
	var speaker := ""
	var text := ""
	match String(info.get("event_type", "")):
		"Text":
			if info.has("character") and info["character"]:
				speaker = String(info["character"])
			text = String(info.get("text", ""))
		"Choice":
			speaker = ""
			text = "-> " + String(info.get("text", ""))
		"Character":
			speaker = ""
			text = String(info.get("text", ""))
		_:
			text = String(info.get("text", ""))

	if text == "":
		return

	entries.append({"speaker": speaker, "text": text})
	while entries.size() > MAX_ENTRIES:
		entries.pop_front()


## new_game 呼叫：清空跨 timeline 的顯示清單與 Dialogic 側的 simple_history_content。
func clear_log() -> void:
	entries.clear()
	_last_seen_count = 0
	if Dialogic.has_subsystem("History"):
		Dialogic.History.simple_history_content = []
	if is_instance_valid(_log_box):
		_redraw()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5; _panel.anchor_top = 0.5
	_panel.anchor_right = 0.5; _panel.anchor_bottom = 0.5
	_panel.offset_left = -560; _panel.offset_top = -380
	_panel.offset_right = 560; _panel.offset_bottom = 380
	_panel.add_theme_stylebox_override("panel", _frame_style(PANEL_BG, GOLD, 3))
	add_child(_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	_panel.add_child(root)

	var title := Label.new()
	title.text = "對話回想"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", GOLD)
	root.add_child(title)

	var sep := ColorRect.new()
	sep.color = GOLD.darkened(0.4)
	sep.custom_minimum_size = Vector2(0, 2)
	root.add_child(sep)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_scroll)

	_log_box = VBoxContainer.new()
	_log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_box.add_theme_constant_override("separation", 8)
	_scroll.add_child(_log_box)

	var hint := Label.new()
	hint.text = "Tab 關閉"
	hint.add_theme_color_override("font_color", DIM)
	hint.add_theme_font_size_override("font_size", 18)
	root.add_child(hint)


func _redraw() -> void:
	for c in _log_box.get_children():
		c.queue_free()
	for e in entries:
		_log_box.add_child(_make_row(e))


func _make_row(e: Dictionary) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)

	var speaker := String(e.get("speaker", ""))
	if speaker != "":
		var name_lbl := Label.new()
		name_lbl.text = speaker
		name_lbl.add_theme_font_size_override("font_size", 18)
		name_lbl.add_theme_color_override("font_color", GOLD)
		row.add_child(name_lbl)

	var text_lbl := Label.new()
	text_lbl.text = String(e.get("text", ""))
	text_lbl.add_theme_font_size_override("font_size", 22)
	text_lbl.add_theme_color_override("font_color", WARM)
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(text_lbl)

	return row


func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _frame_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(20)
	return sb
