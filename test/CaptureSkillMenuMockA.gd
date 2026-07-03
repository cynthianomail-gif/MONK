extends Node
## 改版候選 A：直列卡片列表。每張卡＝屬性徽章(左) + 技能名+消耗(右上) + 一行描述(右下)，
## 選中卡放大 1.06＋朱紅描邊＋左側金色強調條。純 Control/StyleBox/Tween 疊加在戰鬥場景之上，
## 不修改任何 src/ 程式，只在本擺拍腳本內建構 UI 節點。
## ⚠ 只用視窗版 Godot 跑（headless 會卡 frame_post_draw）：
##   tools/godot/Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureSkillMenuMockA.tscn

const BATTLE := "res://src/screens/BattleScreen/BattleScreen.tscn"
const INK_RED := Color(0.82, 0.18, 0.13)
const GOLD := Color(0.788, 0.659, 0.38)
const BG_DARK := Color(0.08, 0.08, 0.09, 0.96)
const BG_CARD := Color(0.14, 0.14, 0.15, 0.95)

# 屬性徽章對照（damage_type → 顯示字＋色）：物理/karma/merit/support 用既有素材字型渲染的 CJK 字，
# 不新增圖片素材。色調維持水墨黑白＋朱紅／金，不另闢色系。
const ATTR_GLYPH := {
	"physical": {"ch": "拳", "color": Color(0.85, 0.85, 0.85)},
	"karma":    {"ch": "業", "color": INK_RED},
	"merit":    {"ch": "功", "color": GOLD},
	"support":  {"ch": "護", "color": Color(0.75, 0.75, 0.78)},
}

# 真實技能資料（data/skills.json，苦行職，涵蓋各消耗/屬性種類）。選中態展示第 3 項（金剛怒目）。
const SKILL_IDS := ["basic_punch", "arhat_strike", "vajra_glare", "ascetic_temper", "iron_shirt"]
const SELECTED_INDEX := 2

var _skills: Dictionary = {}

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await get_tree().process_frame

	_skills = JsonLoader.load_json("res://data/skills.json")
	await _capture_mock_a()

	print("CAPTURE_SKILLMENU_MOCK_A_DONE")
	get_tree().quit(0)

func _new_viewport() -> SubViewport:
	var svc := SubViewport.new()
	svc.size = Vector2i(1920, 1080)
	svc.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_tree().root.add_child.call_deferred(svc)
	return svc

func _save(svc: SubViewport, out_path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	svc.get_texture().get_image().save_png(out_path)
	print("SAVED ", out_path)

func _free_viewport(svc: SubViewport) -> void:
	svc.queue_free()
	await get_tree().process_frame

func _cost_text(cost: Dictionary) -> String:
	var parts: Array = []
	if cost.get("karma", 0) > 0:
		parts.append("業障%d" % cost.karma)
	if cost.get("merit", 0) > 0:
		parts.append("功德%d" % cost.merit)
	if cost.get("hp", 0) > 0:
		parts.append("HP%d%%" % int(cost.hp * 100))
	if cost.get("gold_required", 0) > 0:
		parts.append("需金%d" % cost.gold_required)
	return "、".join(parts) if not parts.is_empty() else "無消耗"

func _build_card(sk: Dictionary, is_selected: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(560, 92)
	card.pivot_offset = Vector2(0, 46)
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_CARD
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(12)
	if is_selected:
		sb.set_border_width_all(3)
		sb.border_color = INK_RED
		sb.bg_color = Color(0.18, 0.1, 0.1, 0.97)
	else:
		sb.set_border_width_all(1)
		sb.border_color = Color(0.32, 0.32, 0.34)
	card.set("theme_override_styles/panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	card.add_child(hbox)

	# 左側金色強調條（僅選中態）
	if is_selected:
		var accent := ColorRect.new()
		accent.color = GOLD
		accent.custom_minimum_size = Vector2(5, 0)
		hbox.add_child(accent)

	# 屬性徽章：圓形 StyleBox + CJK 字
	var dtype: String = sk.get("damage_type", "physical")
	var glyph: Dictionary = ATTR_GLYPH.get(dtype, ATTR_GLYPH["physical"])
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(60, 60)
	var badge_sb := StyleBoxFlat.new()
	badge_sb.bg_color = Color(0.05, 0.05, 0.06)
	badge_sb.set_corner_radius_all(30)
	badge_sb.set_border_width_all(2)
	badge_sb.border_color = glyph.color
	badge.set("theme_override_styles/panel", badge_sb)
	var badge_lbl := Label.new()
	badge_lbl.text = glyph.ch
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_lbl.add_theme_font_size_override("font_size", 26)
	badge_lbl.add_theme_color_override("font_color", glyph.color)
	badge.add_child(badge_lbl)
	hbox.add_child(badge)

	# 右側文字區：名稱＋消耗（同一行）／描述（第二行）
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(vbox)

	var top_row := HBoxContainer.new()
	vbox.add_child(top_row)
	var name_lbl := Label.new()
	name_lbl.text = sk.get("name", "")
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.add_theme_color_override("font_color", Color(0.98, 0.98, 0.95) if is_selected else Color(0.85, 0.85, 0.85))
	top_row.add_child(name_lbl)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)
	var cost_lbl := Label.new()
	cost_lbl.text = _cost_text(sk.get("cost", {}))
	cost_lbl.add_theme_font_size_override("font_size", 18)
	cost_lbl.add_theme_color_override("font_color", GOLD if is_selected else Color(0.65, 0.65, 0.6))
	top_row.add_child(cost_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = sk.get("description", "")
	desc_lbl.add_theme_font_size_override("font_size", 16)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.72) if is_selected else Color(0.55, 0.55, 0.57))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)

	return card

func _build_menu_overlay(parent: Node) -> void:
	var host := PanelContainer.new()
	host.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	host.offset_left = -600
	host.offset_top = 40
	host.offset_right = -40
	host.offset_bottom = 700
	var host_sb := StyleBoxFlat.new()
	host_sb.bg_color = BG_DARK
	host_sb.set_corner_radius_all(8)
	host_sb.set_content_margin_all(20)
	host.set("theme_override_styles/panel", host_sb)
	parent.add_child(host)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	host.add_child(vbox)

	var title := Label.new()
	title.text = "▼ 技能（候選 A：直列卡片）"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", INK_RED)
	vbox.add_child(title)

	for i in SKILL_IDS.size():
		var sk: Dictionary = _skills.get(SKILL_IDS[i], {})
		vbox.add_child(_build_card(sk, i == SELECTED_INDEX))

func _capture_mock_a() -> void:
	var svc := _new_viewport()
	await get_tree().process_frame
	var inst: Node = (load(BATTLE) as PackedScene).instantiate()
	svc.add_child(inst)
	await get_tree().process_frame
	inst.setup("pantheon_guard")
	for i in 24:
		await get_tree().process_frame
	GameManager.player.karma = 100
	GameManager.player.merit = 100
	# 隱藏現有的技能子選單（避免與 mockup 疊圖），只保留戰鬥場景背景/立繪/敵人/指令選單作底。
	inst.ui.skill_menu.visible = false
	var overlay_layer := CanvasLayer.new()
	svc.add_child(overlay_layer)
	_build_menu_overlay(overlay_layer)
	for i in 6:
		await get_tree().process_frame
	await _save(svc, "res://_skillmenu_mock_a.png")
	await _free_viewport(svc)
