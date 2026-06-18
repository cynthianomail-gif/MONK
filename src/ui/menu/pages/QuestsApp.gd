extends Control
## 手機·任務 app（入世）：主線進度＋繼續主線入口、十二因緣成就圖鑑、進行中支線。
## 主線正式入口（古廟「主線」動作保留為世界內備援）。

const GOLD := Color(0.788, 0.659, 0.38)
const WARM := Color(0.92, 0.89, 0.82)
const DIM := Color(0.5, 0.47, 0.42)
const NEAR_BLACK := Color(0.043, 0.043, 0.043, 1.0)
const DONE := Color(0.937, 0.624, 0.153)   # 已超渡＝功德橙金

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 18)
	scroll.add_child(col)

	col.add_child(_main_quest_section())
	col.add_child(_heading("十二因緣"))
	col.add_child(_achievements_section())
	col.add_child(_heading("進行中的支線"))
	col.add_child(_side_quests_section())

# --- 主線 ---
func _main_quest_section() -> Control:
	var panel := _panel()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	# DEMO 版：打完最後一章即顯示試玩版結束，不再導向空的 ch2。
	if MainQuestManager.is_demo_complete():
		vb.add_child(_line("主線 · 第一章已通關", GOLD, 26))
		vb.add_child(_line("戰神阿瑞斯已超渡。試玩版到此結束，完整十二章敬請期待。", DONE, 22))
		return panel

	var cid: String = MainQuestManager.current_chapter_id()
	if cid == "" and MainQuestManager.is_all_cleared():
		vb.add_child(_line("主線 · 十二神超渡", GOLD, 26))
		vb.add_child(_line("十二因緣圓滿，舍利塔已歸位。", DONE, 22))
		return panel
	if cid == "":
		vb.add_child(_line("主線尚未開啟", DIM, 24))
		return panel

	var c: Dictionary = MainQuestManager.get_chapter(cid)
	var stages: Array = c.get("stages", [])
	var idx: int = clampi(MainQuestManager.stage_index(cid), 0, maxi(0, stages.size() - 1))
	var stage_desc: String = ""
	if idx < stages.size():
		stage_desc = String(stages[idx].get("desc", ""))

	vb.add_child(_line("第 %d 章 · %s" % [int(c.get("chapter", 0)), String(c.get("god", ""))], GOLD, 26))
	vb.add_child(_line(String(c.get("title", "")), WARM, 24))
	if stage_desc != "":
		vb.add_child(_line("目前：" + stage_desc, DIM, 20))
	vb.add_child(_line("進度 %d / %d" % [idx + 1, stages.size()], DIM, 20))

	var btn := Button.new()
	btn.text = "繼續主線"
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color", GOLD)
	btn.custom_minimum_size = Vector2(0, 52)
	btn.pressed.connect(_on_continue_pressed)
	vb.add_child(btn)
	return panel

func _on_continue_pressed() -> void:
	# 先關選單解暫停（主線協程要等計時器，暫停中會卡），再推進。
	var shell := get_tree().get_first_node_in_group("menu_shell")
	if shell and shell.has_method("close"):
		shell.close()
	MainQuestManager.continue_story()

# --- 十二因緣成就 ---
func _achievements_section() -> Control:
	var panel := _panel()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	panel.add_child(grid)

	for a in AchievementSystem.get_all():
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(640, 0)
		row.add_theme_constant_override("separation", 10)
		var unlocked: bool = a.unlocked
		var idx := Label.new()
		idx.text = "%02d" % int(a.chapter)
		idx.add_theme_color_override("font_color", DONE if unlocked else DIM)
		idx.add_theme_font_size_override("font_size", 22)
		var nm := Label.new()
		nm.text = "%s · %s" % [String(a.name), _god_short(String(a.desc))]
		nm.add_theme_color_override("font_color", WARM if unlocked else DIM)
		nm.add_theme_font_size_override("font_size", 22)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var st := Label.new()
		st.text = "已超渡" if unlocked else "未超渡"
		st.add_theme_color_override("font_color", DONE if unlocked else DIM)
		st.add_theme_font_size_override("font_size", 20)
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(idx); row.add_child(nm); row.add_child(st)
		grid.add_child(row)

	var cap := Label.new()
	var got: int = AchievementSystem.unlocked_count()
	cap.text = "已證 %d / %d 因緣" % [got, AchievementSystem.total()]
	cap.add_theme_color_override("font_color", DIM)
	cap.add_theme_font_size_override("font_size", 18)
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 6)
	wrap.add_child(panel)
	wrap.add_child(cap)
	return wrap

## 從成就描述「通關第N章 · 超渡XXX」抽出神祇短名。
func _god_short(desc: String) -> String:
	var marker := "超渡"
	var p := desc.find(marker)
	if p == -1:
		return ""
	return desc.substr(p + marker.length())

# --- 支線 ---
func _side_quests_section() -> Control:
	var panel := _panel()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	var active: Dictionary = GameManager.player.get("active_quests", {})
	if active.is_empty():
		vb.add_child(_line("目前沒有進行中的支線。", DIM, 20))
		return panel
	for qid in active:
		vb.add_child(_line("· %s（%s）" % [String(qid), String(active[qid])], WARM, 20))
	return panel

# --- helpers ---
func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", GOLD)
	l.add_theme_font_size_override("font_size", 24)
	return l

func _line(text: String, col: Color, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	return l

func _panel() -> PanelContainer:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = NEAR_BLACK
	sb.border_color = GOLD.darkened(0.4)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(16)
	pc.add_theme_stylebox_override("panel", sb)
	return pc
