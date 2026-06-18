extends Control
## 經書·技能頁：三職分組列出技能，顯示學習狀態（🔒未達 / ✦可學 / ✓已學），
## 可學的招提供「習得」鈕。真相源＝SkillUnlockManager.get_unlock_state()。

const GOLD := Color(0.788, 0.659, 0.38)
const WARM := Color(0.92, 0.89, 0.82)
const DIM := Color(0.5, 0.47, 0.42)
const LOCKED := Color(0.45, 0.43, 0.4)
const LEARNABLE := Color(0.55, 0.78, 0.95)   # 可學＝冷亮藍
const LEARNED := Color(0.55, 0.82, 0.55)     # 已學＝綠

const JOB_ORDER := ["ascetic", "chanter", "beggar"]
const JOB_NAMES := {"ascetic": "苦行僧", "chanter": "念經僧", "beggar": "化緣僧"}

var _skills: Dictionary = {}
var _detail_box: VBoxContainer
var _rows: Dictionary = {}        # skill_id -> Button
var _selected: String = ""

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_skills = JsonLoader.load_json("res://data/skills.json")
	_build()

func _build() -> void:
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 24)
	add_child(hb)

	# 左：技能清單（捲動）
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	for job in JOB_ORDER:
		var header := Label.new()
		header.text = "— %s —" % JOB_NAMES[job]
		header.add_theme_color_override("font_color", GOLD)
		header.add_theme_font_size_override("font_size", 26)
		list.add_child(header)
		for skill_id in _skills:
			if _skills[skill_id].get("job", "") != job:
				continue
			list.add_child(_skill_row(skill_id))

	# 右：詳情
	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_child(detail_panel)
	_detail_box = VBoxContainer.new()
	_detail_box.add_theme_constant_override("separation", 10)
	detail_panel.add_child(_detail_box)
	_show_detail("")  # 提示

func _skill_row(skill_id: String) -> Button:
	var btn := Button.new()
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color_hover", GOLD)
	var sid: String = skill_id
	btn.pressed.connect(func() -> void: _select(sid))
	_rows[skill_id] = btn
	_style_row(skill_id)
	return btn

func _style_row(skill_id: String) -> void:
	var btn: Button = _rows[skill_id]
	var st: Dictionary = SkillUnlockManager.get_unlock_state(skill_id)
	var data: Dictionary = _skills[skill_id]
	var prefix := ""
	var col := WARM
	if st.kind == "heat":
		prefix = "【處決】"; col = GOLD
	elif st.learned:
		prefix = "✓ "; col = WARM
	elif st.learnable:
		prefix = "✦ "; col = LEARNABLE
	else:
		prefix = "🔒 "; col = LOCKED
	var suffix := ""
	if st.kind == "behavior" and not st.condition_met:
		suffix = "  (%d/%d)" % [st.current, st.target]
	btn.text = "%s%s%s" % [prefix, data.get("name", skill_id), suffix]
	btn.add_theme_color_override("font_color", col)

func _select(skill_id: String) -> void:
	_selected = skill_id
	_show_detail(skill_id)

func _show_detail(skill_id: String) -> void:
	for c in _detail_box.get_children():
		c.queue_free()
	if skill_id == "":
		var hint := Label.new()
		hint.text = "選擇左側技能以檢視詳情。"
		hint.add_theme_color_override("font_color", DIM)
		hint.add_theme_font_size_override("font_size", 22)
		_detail_box.add_child(hint)
		return
	var d: Dictionary = _skills[skill_id]
	var st: Dictionary = SkillUnlockManager.get_unlock_state(skill_id)
	_add_label(d.get("name", skill_id), 34, GOLD)
	_add_label("%s ｜ %s" % [JOB_NAMES.get(d.get("job", ""), ""), _type_text(d)], 20, DIM)
	_add_label("消耗：%s" % _cost_text(d.get("cost", {})), 20, WARM)
	var desc := _add_label(d.get("description", ""), 22, WARM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(700, 0)
	_detail_box.add_child(_hsep())
	# 學習狀態
	if st.kind == "heat":
		_add_label("滿值處決技：戰鬥中達條件自動發動。", 20, GOLD)
	elif st.learned:
		_add_label("✓ 已學會", 22, LEARNED)
		if st.label != "" and st.label != "初始解鎖":
			_add_label("習得方式：%s" % st.label, 18, DIM)
	elif st.learnable:
		_add_label("✦ 可習得", 22, LEARNABLE)
		_add_label("條件已達成：%s" % st.label, 18, DIM)
		var learn_btn := Button.new()
		learn_btn.text = "習得"
		learn_btn.add_theme_font_size_override("font_size", 24)
		var sid: String = skill_id
		learn_btn.pressed.connect(func() -> void: _on_learn(sid))
		_detail_box.add_child(learn_btn)
	else:
		_add_label("🔒 未達", 22, LOCKED)
		_add_label("解鎖條件：%s" % st.label, 20, WARM)
		if st.kind == "behavior":
			_add_progress(st.current, st.target)

func _on_learn(skill_id: String) -> void:
	if SkillUnlockManager.learn_skill(skill_id):
		_style_row(skill_id)
		_show_detail(skill_id)

func _add_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	_detail_box.add_child(l)
	return l

func _add_progress(current: int, target: int) -> void:
	var bar := ProgressBar.new()
	bar.max_value = target
	bar.value = current
	bar.custom_minimum_size = Vector2(400, 24)
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	_detail_box.add_child(bar)
	_add_label("進度 %d / %d" % [current, target], 18, DIM)

func _type_text(d: Dictionary) -> String:
	var dt: String = d.get("damage_type", "")
	var map := {"physical": "物理", "karma": "業障", "merit": "功德",
		"support": "輔助", "passive": "被動"}
	return map.get(dt, dt)

func _cost_text(cost: Dictionary) -> String:
	if cost.is_empty():
		return "無"
	var parts: Array = []
	for k in cost:
		match k:
			"karma": parts.append("業障 %d" % int(cost[k]))
			"merit": parts.append("功德 %d" % int(cost[k]))
			"hp": parts.append("HP %d%%" % int(float(cost[k]) * 100))
			"gold_required": parts.append("持金 %d" % int(cost[k]))
			_: parts.append("%s %s" % [k, str(cost[k])])
	return "、".join(parts)

func _hsep() -> Control:
	var line := ColorRect.new()
	line.color = GOLD.darkened(0.5)
	line.custom_minimum_size = Vector2(0, 2)
	return line
