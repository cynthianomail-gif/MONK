extends CanvasLayer
## C-2：所有對話按 ESC（"cancel" action）可快轉整段對話。
## 常駐掛載：GameManager._ready() 建立一次、掛在 root 下（同 DialogueHistoryPanel 慣例），
## layer=99（低於 DialogueHistoryPanel 的 100）、process_mode ALWAYS，用 _input()（而非 _unhandled_input）在 Dialogic 自己的
## GUI 輸入層之前攔截 ESC，同一顆鍵不會再穿透去開選單/其他畫面。
##
## 方案（3 行）：
## 1) 「快轉」而非「跳到結尾」——切 Dialogic 內建 Inputs.auto_skip.enabled=true 且
##    time_per_event 設極短(0.02s)，事件（含 [signal]/set_flag）照常一個一個真的執行，
##    只是不停下來等玩家看，flag/signal 100% 不漏（跳到結尾的 end_timeline 才會漏 signal）。
## 2) 選項（Choice）事件本身不監聽 auto_skip 用的 dialogic_action 訊號、只認真的按鈕點擊，
##    Dialogic 原生設計就是「快轉遇到選項會自然停下」，不必額外寫暫停邏輯；玩家選完、
##    下一個文字事件開始時 auto_skip 仍是 enabled，會自動繼續快轉。
## 3) ESC 只是「開關」：再按一次 ESC 關閉快轉恢復正常步調；對話結束（timeline_ended）
##    強制關閉快轉，不讓狀態漏到下一段對話。
##
## 與 DialogueHistoryPanel（Tab 回想面板）的互動：面板開啟時 ESC 不觸發快轉，讓面板
## 自己的 _input 處理（面板開啟中會吞掉所有按鍵，見 DialogueHistoryPanel.gd）。
## 實測 Godot _input() 派送順序＝同一幀內「後 add_child 的節點先收到」，且不因某節點呼叫
## set_input_as_handled() 而跳過其他節點的 _input()；本控制器由 GameManager 在
## DialogueHistoryPanel 之後才 add_child，故本控制器的 _input 會先於面板執行——這裡直接
## 檢查 history.visible（面板尚未來得及處理本次按鍵前就已是最新狀態）即可正確判斷。

const HINT_TEXT := "▶▶ 快轉中（再按 ESC 恢復）"

var _hint: Label

func _ready() -> void:
	layer = 99  # 略低於 DialogueHistoryPanel(100)，純視覺疊層順序，與輸入判定順序無關
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hint()
	if Dialogic.has_subsystem("Inputs"):
		Dialogic.Inputs.auto_skip.toggled.connect(_on_skip_toggled)
	Dialogic.timeline_ended.connect(_on_timeline_ended)


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("cancel", false, true):
		return
	if Dialogic.current_timeline == null:
		return
	# 回想面板開著：讓它自己處理這次按鍵（面板開啟中會吞掉所有輸入），本控制器不搶。
	var history := GameManager.dialogue_history
	if is_instance_valid(history) and history.visible:
		return
	get_viewport().set_input_as_handled()
	AudioManager.play_sfx("ui_cancel")
	_toggle_skip()


func _toggle_skip() -> void:
	var inputs := Dialogic.Inputs
	inputs.auto_skip.time_per_event = 0.02
	inputs.auto_skip.enabled = not inputs.auto_skip.enabled


func _on_timeline_ended() -> void:
	if Dialogic.has_subsystem("Inputs") and Dialogic.Inputs.auto_skip.enabled:
		Dialogic.Inputs.auto_skip.enabled = false


func _on_skip_toggled(enabled: bool) -> void:
	if is_instance_valid(_hint):
		_hint.visible = enabled


func _build_hint() -> void:
	_hint = Label.new()
	_hint.text = HINT_TEXT
	_hint.visible = false
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_hint.offset_left = -320.0; _hint.offset_top = 16.0
	_hint.offset_right = -16.0; _hint.offset_bottom = 48.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_size_override("font_size", 20)
	_hint.add_theme_color_override("font_color", Color(0.98, 0.9, 0.6, 1))
	_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_hint.add_theme_constant_override("shadow_offset_x", 1)
	_hint.add_theme_constant_override("shadow_offset_y", 1)
	_hint.add_theme_constant_override("shadow_outline_size", 4)
	add_child(_hint)
