extends VBoxContainer
## 手機「設定」頁：主/BGM/SFX 音量、全螢幕、文字速度。即時套用＋寫檔（SettingsManager）。

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
