extends VBoxContainer
## 手機「設定」頁：主/BGM/SFX 音量、全螢幕、文字速度。即時套用＋寫檔（SettingsManager）。
## 2026-07-11 加「儲存」／「回主選單」：儲存＝開既有 SaveSlotPicker(save 模式)讓玩家選槽
## （沿用 MapScreen._open_save_slot_picker 的既有呼叫慣例，不重造存檔 UI）；回主選單＝走
## SceneRouter.go_to_title()，若偵測到本局有「未儲存進度」（SaveManager.has_unsaved_changes()，
## 全量序列化快照比對，見 SaveManager.gd）先跳三選一確認框（ExitConfirmDialog），已儲存則
## 直接回標題不打斷玩家。

const SAVE_SLOT_PICKER := preload("res://src/ui/SaveSlotPicker.gd")
const EXIT_CONFIRM_DIALOG := preload("res://src/ui/ExitConfirmDialog.gd")

const GOLD := Color(0.788, 0.659, 0.38)
const WARM := Color(0.92, 0.89, 0.82)

func _ready() -> void:
	add_theme_constant_override("separation", 18)
	var title := Label.new()
	title.text = "設定"
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_font_size_override("font_size", 30)
	add_child(title)

	_add_slider("主音量", "master_vol", 0.0, 1.0, 0.05)
	_add_slider("背景音樂", "bgm_vol", 0.0, 1.0, 0.05)
	_add_slider("音效", "sfx_vol", 0.0, 1.0, 0.05)
	_add_fullscreen_toggle()
	_add_slider("文字速度", "text_speed", 0.5, 2.0, 0.1)

	var sep := HSeparator.new()
	add_child(sep)
	_add_action_button("儲存進度", _on_save_pressed)
	_add_action_button("回主選單", _on_exit_pressed)

func _add_slider(label_text: String, key: String, mn: float, mx: float, step: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(180, 0)
	lbl.add_theme_color_override("font_color", WARM)
	lbl.add_theme_font_size_override("font_size", 22)
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = mn
	slider.max_value = mx
	slider.step = step
	slider.value = float(SettingsManager.get_setting(key))
	slider.custom_minimum_size = Vector2(360, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var k := key
	slider.value_changed.connect(func(v: float) -> void: SettingsManager.set_setting(k, v))
	row.add_child(slider)
	add_child(row)

func _add_fullscreen_toggle() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var lbl := Label.new()
	lbl.text = "全螢幕"
	lbl.custom_minimum_size = Vector2(180, 0)
	lbl.add_theme_color_override("font_color", WARM)
	lbl.add_theme_font_size_override("font_size", 22)
	row.add_child(lbl)
	var cb := CheckButton.new()
	cb.button_pressed = bool(SettingsManager.get_setting("fullscreen"))
	cb.toggled.connect(func(on: bool) -> void: SettingsManager.set_setting("fullscreen", on))
	row.add_child(cb)
	add_child(row)

func _add_action_button(text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(240, 52)
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", GOLD)
	btn.pressed.connect(callback)
	add_child(btn)

## 「儲存」：開既有 SaveSlotPicker(save 模式)，玩家選槽即落檔（沿用 MapScreen 慣例）。
## 加到 get_tree().root（而非本頁子節點）：MenuShell 換頁/關閉時會把本頁 queue_free 掉，
## picker 掛在 root 底下才不會被連坐清掉，跟 MapScreen._open_save_slot_picker 同慣例。
func _on_save_pressed() -> void:
	var picker := SAVE_SLOT_PICKER.new()
	get_tree().root.add_child(picker)
	picker.closed.connect(func() -> void:
		if is_instance_valid(picker):
			picker.queue_free()
	)
	picker.open("save")

## 「回主選單」：無未儲存變更→直接回標題；有→先跳三選一確認框。
func _on_exit_pressed() -> void:
	if not SaveManager.has_unsaved_changes():
		_go_to_title()
		return
	var dlg := EXIT_CONFIRM_DIALOG.new()
	get_tree().root.add_child(dlg)
	dlg.choice_made.connect(func(choice: String) -> void:
		if is_instance_valid(dlg):
			dlg.queue_free()
		match choice:
			"save":
				_open_save_then_exit()
			"discard":
				_go_to_title()
			"cancel":
				pass  # 留在設定頁，不動任何檔、不換場。
	)
	dlg.open()

## 確認框選「儲存並離開」：開 SlotPicker(save)，玩家實際選槽存檔成功（slot_chosen）才回標題；
## 玩家在 picker 上按 Esc／取消（只觸發 closed，不觸發 slot_chosen）＝放棄離開，留在設定頁。
func _open_save_then_exit() -> void:
	var picker := SAVE_SLOT_PICKER.new()
	get_tree().root.add_child(picker)
	# slot_chosen 只在玩家實際選槽存檔成功時才觸發，才回標題；Esc／取消只觸發 closed，
	# 不會走到這裡＝維持在設定頁不回標題。closed 一律負責收尾釋放節點（成功時 _commit_slot
	# 內部 slot_chosen.emit() 之後緊接著也會觸發 closed，兩者不衝突）。
	picker.slot_chosen.connect(func(_n: int) -> void:
		_go_to_title()
	)
	picker.closed.connect(func() -> void:
		if is_instance_valid(picker):
			picker.queue_free()
	)
	picker.open("save")

func _go_to_title() -> void:
	get_tree().paused = false
	SceneRouter.go_to_title()
