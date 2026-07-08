extends Control
## 手機·情報 app：萬神殿 12 神情報圖鑑 ＋ 敵人圖鑑雛形。
## 神祇：每位神有蒐集進度條，碎片要逐塊探聽補齊，狀態來源＝GodIntel（碎片純從旗標/完成支線推導）。
## 敵人：戰鬥中探知的 weakness_intel 情報出口——只列「已遭遇」(GameManager.player.enemies_seen)
## 的敵人，顯示已知弱點；未遭遇的敵人完全不列（避免劇透敵人總數）。

const GOLD := Color(0.788, 0.659, 0.38)
const WARM := Color(0.92, 0.89, 0.82)
const DIM := Color(0.5, 0.47, 0.42)
const LOCKED := Color(0.38, 0.36, 0.33)
const FILL := Color(0.937, 0.624, 0.153)   # 進度條已蒐集＝功德橙金
const TRACK := Color(0.18, 0.17, 0.15)
const NEAR_BLACK := Color(0.043, 0.043, 0.043, 1.0)

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
	col.add_theme_constant_override("separation", 12)
	scroll.add_child(col)

	var head := HBoxContainer.new()
	var title := Label.new()
	title.text = "神祇情報"
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_font_size_override("font_size", 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cnt := Label.new()
	cnt.text = "已發現 %d / %d" % [GodIntel.discovered_count(), GodIntel.total()]
	cnt.add_theme_color_override("font_color", DIM)
	cnt.add_theme_font_size_override("font_size", 20)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(title); head.add_child(cnt)
	col.add_child(head)

	for e in GodIntel.get_all():
		col.add_child(_entry(e))

	col.add_child(HSeparator.new())
	col.add_child(_bestiary_section())

## ─── 敵人圖鑑（weakness_intel UI 出口）─────────────────────
func _bestiary_section() -> Control:
	var section := VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 12)

	var seen: Array = GameManager.player.get("enemies_seen", [])
	var head := HBoxContainer.new()
	var title := Label.new()
	title.text = "敵人情報"
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_font_size_override("font_size", 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cnt := Label.new()
	cnt.text = "已遭遇 %d" % seen.size()
	cnt.add_theme_color_override("font_color", DIM)
	cnt.add_theme_font_size_override("font_size", 20)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(title); head.add_child(cnt)
	section.add_child(head)

	if seen.is_empty():
		var empty := Label.new()
		empty.text = "尚未遭遇任何敵人。"
		empty.add_theme_color_override("font_color", LOCKED)
		empty.add_theme_font_size_override("font_size", 18)
		section.add_child(empty)
		return section

	var defs: Dictionary = JsonLoader.load_json("res://data/enemies.json")
	defs.merge(JsonLoader.load_json("res://data/boss.json"))
	for eid in seen:
		section.add_child(_bestiary_entry(String(eid), defs.get(eid, {})))
	return section

func _bestiary_entry(eid: String, data: Dictionary) -> Control:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = NEAR_BLACK
	sb.border_color = GOLD.darkened(0.3)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(14)
	pc.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	pc.add_child(vb)

	var nm := Label.new()
	nm.text = String(data.get("name", eid)) if not data.is_empty() else eid
	nm.add_theme_color_override("font_color", WARM)
	nm.add_theme_font_size_override("font_size", 22)
	vb.add_child(nm)

	var wk := Label.new()
	wk.add_theme_font_size_override("font_size", 18)
	var weaknesses: Array = data.get("weaknesses", [])
	if weaknesses.is_empty():
		wk.text = "弱點：無"
		wk.add_theme_color_override("font_color", DIM)
	else:
		var parts: Array = []
		var known_any := false
		for w in weaknesses:
			if GameManager.knows_weakness(eid, w):
				parts.append(EnemyPanel.ELEM_NAMES.get(w, w))
				known_any = true
			else:
				parts.append("？？？")
		wk.text = "弱點：" + "、".join(parts)
		wk.add_theme_color_override("font_color", FILL if known_any else LOCKED)
	vb.add_child(wk)
	return pc

func _entry(e: Dictionary) -> Control:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = NEAR_BLACK
	sb.border_color = (GOLD.darkened(0.3) if e.discovered else GOLD.darkened(0.7))
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(14)
	pc.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	pc.add_child(vb)

	if not e.discovered:
		var q := Label.new()
		q.text = "？？？　（未探聽）"
		q.add_theme_color_override("font_color", LOCKED)
		q.add_theme_font_size_override("font_size", 22)
		vb.add_child(q)
		return pc

	# 標題列：神名 + 蒐集進度 X/N
	var hb := HBoxContainer.new()
	var nm := Label.new()
	nm.text = String(e.god)
	nm.add_theme_color_override("font_color", WARM)
	nm.add_theme_font_size_override("font_size", 22)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var prog := Label.new()
	prog.text = "情報 %d / %d" % [int(e.got), int(e.total)]
	prog.add_theme_color_override("font_color", FILL if int(e.got) >= int(e.total) else DIM)
	prog.add_theme_font_size_override("font_size", 18)
	prog.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(nm); hb.add_child(prog)
	vb.add_child(hb)

	# 進度條
	vb.add_child(_bar(int(e.got), int(e.total)))

	# 命脈
	var dom := Label.new()
	dom.text = String(e.domain)
	dom.add_theme_color_override("font_color", GOLD)
	dom.add_theme_font_size_override("font_size", 18)
	vb.add_child(dom)

	# 碎片：已解顯示原文，未解顯示 ？？？（待查訪）
	for pcd in e.pieces:
		var l := Label.new()
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 18)
		if pcd.unlocked:
			l.text = "· " + String(pcd.text)
			l.add_theme_color_override("font_color", DIM)
		else:
			l.text = "· ？？？（待查訪）"
			l.add_theme_color_override("font_color", LOCKED)
		vb.add_child(l)
	return pc

func _bar(got: int, total: int) -> Control:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 12)
	bar.add_theme_constant_override("separation", 0)
	var t: int = maxi(1, total)
	var fill := ColorRect.new()
	fill.color = FILL
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.size_flags_stretch_ratio = maxf(0.0001, float(got))
	var rest := ColorRect.new()
	rest.color = TRACK
	rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rest.size_flags_stretch_ratio = maxf(0.0001, float(t - got))
	bar.add_child(fill)
	bar.add_child(rest)
	return bar
