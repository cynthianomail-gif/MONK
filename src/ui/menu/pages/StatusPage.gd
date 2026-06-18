extends Control
## 經書·狀態頁：三角雷達(三職修為) + 業障↔功德拔河條 + 數值卡。

const GOLD := Color(0.788, 0.659, 0.38)
const WARM := Color(0.92, 0.89, 0.82)
const DIM := Color(0.5, 0.47, 0.42)
const KARMA_COL := Color(0.886, 0.29, 0.29)
const MERIT_COL := Color(0.937, 0.624, 0.153)

const RADAR_SIZE := Vector2(380, 360)
const AXES := [
	{"job": "ascetic", "name": "苦行", "dir": Vector2(0, -1)},
	{"job": "chanter", "name": "念經", "dir": Vector2(-0.866, 0.5)},
	{"job": "beggar",  "name": "化緣", "dir": Vector2(0.866, 0.5)},
]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 32)
	add_child(hb)
	hb.add_child(_build_radar())
	hb.add_child(_build_side())

# --- 三角雷達 ---
func _build_radar() -> Control:
	var wrap := VBoxContainer.new()
	var holder := Control.new()
	holder.custom_minimum_size = RADAR_SIZE
	wrap.add_child(holder)

	var c := RADAR_SIZE * 0.5
	var r := 130.0
	var mastery: Dictionary = SkillUnlockManager.get_job_mastery()

	# 外框三角 + 中環
	holder.add_child(_ring(c, r, 1.0, GOLD.darkened(0.3)))
	holder.add_child(_ring(c, r, 0.5, GOLD.darkened(0.55)))

	# 修為多邊形
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	for a in AXES:
		var m: Dictionary = mastery[a.job]
		var v: float = float(m.unlocked) / float(maxi(1, m.total))
		pts.append(c + a.dir * r * v)
	poly.polygon = pts
	poly.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.35)
	holder.add_child(poly)
	var outline := Line2D.new()
	outline.points = pts
	outline.closed = true
	outline.width = 2.0
	outline.default_color = GOLD
	holder.add_child(outline)

	# 軸標籤
	for a in AXES:
		var m: Dictionary = mastery[a.job]
		var lbl := Label.new()
		lbl.text = "%s %d/%d" % [a.name, m.unlocked, m.total]
		lbl.add_theme_color_override("font_color", WARM)
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.position = c + a.dir * (r + 22) - Vector2(36, 12)
		holder.add_child(lbl)

	var caption := Label.new()
	caption.text = "三職修為"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_color_override("font_color", DIM)
	caption.add_theme_font_size_override("font_size", 20)
	wrap.add_child(caption)
	return wrap

func _ring(c: Vector2, r: float, scale: float, col: Color) -> Line2D:
	var line := Line2D.new()
	var pts := PackedVector2Array()
	for a in AXES:
		pts.append(c + a.dir * r * scale)
	line.points = pts
	line.closed = true
	line.width = 1.0
	line.default_color = col
	return line

# --- 右側：拔河 + 數值卡 ---
func _build_side() -> Control:
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 16)
	var p: Dictionary = GameManager.player

	# 業障 ↔ 功德 拔河
	var head := HBoxContainer.new()
	var kl := Label.new()
	kl.text = "業障 %d" % p.karma
	kl.add_theme_color_override("font_color", KARMA_COL)
	kl.add_theme_font_size_override("font_size", 24)
	kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ml := Label.new()
	ml.text = "功德 %d" % p.merit
	ml.add_theme_color_override("font_color", MERIT_COL)
	ml.add_theme_font_size_override("font_size", 24)
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(kl); head.add_child(ml)
	vb.add_child(head)

	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 28)
	bar.add_theme_constant_override("separation", 0)
	var total: float = float(maxi(1, p.karma + p.merit))
	var kr := ColorRect.new(); kr.color = KARMA_COL
	kr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kr.size_flags_stretch_ratio = maxf(0.001, p.karma / total)
	var mr := ColorRect.new(); mr.color = MERIT_COL
	mr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mr.size_flags_stretch_ratio = maxf(0.001, p.merit / total)
	bar.add_child(kr); bar.add_child(mr)
	vb.add_child(bar)

	var caption := Label.new()
	caption.text = "善惡拔河（業障 ↔ 功德）"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_color_override("font_color", DIM)
	caption.add_theme_font_size_override("font_size", 18)
	vb.add_child(caption)

	# 數值卡格
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.add_child(_card("HP", "%d / %d" % [p.current_hp, p.max_hp]))
	grid.add_child(_card("金幣", str(p.gold)))
	grid.add_child(_card("技能", _skill_count_text()))
	grid.add_child(_card("成就", _achievement_count_text()))
	vb.add_child(grid)
	return vb

func _card(title: String, value: String) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(260, 88)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.043, 0.043, 0.043, 1)
	sb.border_color = GOLD.darkened(0.4)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(12)
	pc.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	var t := Label.new(); t.text = title
	t.add_theme_color_override("font_color", DIM)
	t.add_theme_font_size_override("font_size", 18)
	var v := Label.new(); v.text = value
	v.add_theme_color_override("font_color", WARM)
	v.add_theme_font_size_override("font_size", 30)
	vb.add_child(t); vb.add_child(v)
	pc.add_child(vb)
	return pc

func _skill_count_text() -> String:
	var m: Dictionary = SkillUnlockManager.get_job_mastery()
	var learned: int = m.ascetic.unlocked + m.chanter.unlocked + m.beggar.unlocked
	var heat: int = SkillUnlockManager.get_heat_skill_ids().size()
	return "%d / %d" % [learned + heat, m.ascetic.total + m.chanter.total + m.beggar.total + heat]

func _achievement_count_text() -> String:
	return "%d / %d" % [AchievementSystem.unlocked_count(), AchievementSystem.total()]
