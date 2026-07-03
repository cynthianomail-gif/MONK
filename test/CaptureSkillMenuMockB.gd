extends Node
## 改版候選 B：底部橫排卡片列（類手牌）。每張卡＝上方屬性徽章＋技能名＋消耗／下方一行描述，
## 選中卡上浮＋放大＋朱紅描邊，未選中卡降低透明度＋略縮小。純 Control/StyleBox/Tween，
## 疊加在戰鬥場景之上，不修改任何 src/ 程式，只在本擺拍腳本內建構 UI 節點。
## ⚠ 只用視窗版 Godot 跑（headless 會卡 frame_post_draw）：
##   tools/godot/Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureSkillMenuMockB.tscn

const BATTLE := "res://src/screens/BattleScreen/BattleScreen.tscn"
const INK_RED := Color(0.82, 0.18, 0.13)
const GOLD := Color(0.788, 0.659, 0.38)
const BG_CARD := Color(0.13, 0.13, 0.14, 0.95)

const ATTR_GLYPH := {
	"physical": {"ch": "拳", "color": Color(0.85, 0.85, 0.85)},
	"karma":    {"ch": "業", "color": INK_RED},
	"merit":    {"ch": "功", "color": GOLD},
	"support":  {"ch": "護", "color": Color(0.75, 0.75, 0.78)},
}

const SKILL_IDS := ["basic_punch", "arhat_strike", "vajra_glare", "ascetic_temper", "iron_shirt"]
const SELECTED_INDEX := 2

var _skills: Dictionary = {}

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await get_tree().process_frame

	_skills = JsonLoader.load_json("res://data/skills.json")
	await _capture_mock_b()

	print("CAPTURE_SKILLMENU_MOCK_B_DONE")
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
	card.custom_minimum_size = Vector2(300, 220) if is_selected else Vector2(280, 190)
	card.pivot_offset = card.custom_minimum_size * 0.5
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(14)
	if is_selected:
		sb.bg_color = Color(0.18, 0.1, 0.1, 0.98)
		sb.set_border_width_all(3)
		sb.border_color = INK_RED
		sb.shadow_color = Color(0.82, 0.18, 0.13, 0.35)
		sb.shadow_size = 14
	else:
		sb.bg_color = BG_CARD
		sb.set_border_width_all(1)
		sb.border_color = Color(0.3, 0.3, 0.32)
	card.set("theme_override_styles/panel", sb)
	card.modulate = Color(1, 1, 1, 1.0) if is_selected else Color(0.72, 0.72, 0.72, 1.0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	card.add_child(vbox)

	# 上方：屬性徽章置中
	var dtype: String = sk.get("damage_type", "physical")
	var glyph: Dictionary = ATTR_GLYPH.get(dtype, ATTR_GLYPH["physical"])
	var badge_wrap := CenterContainer.new()
	vbox.add_child(badge_wrap)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(56, 56)
	var badge_sb := StyleBoxFlat.new()
	badge_sb.bg_color = Color(0.05, 0.05, 0.06)
	badge_sb.set_corner_radius_all(28)
	badge_sb.set_border_width_all(2)
	badge_sb.border_color = glyph.color
	badge.set("theme_override_styles/panel", badge_sb)
	var badge_lbl := Label.new()
	badge_lbl.text = glyph.ch
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_lbl.add_theme_font_size_override("font_size", 24)
	badge_lbl.add_theme_color_override("font_color", glyph.color)
	badge.add_child(badge_lbl)
	badge_wrap.add_child(badge)

	# 技能名（置中）
	var name_lbl := Label.new()
	name_lbl.text = sk.get("name", "")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", Color(0.98, 0.98, 0.95) if is_selected else Color(0.82, 0.82, 0.82))
	vbox.add_child(name_lbl)

	# 消耗（置中，金色）
	var cost_lbl := Label.new()
	cost_lbl.text = _cost_text(sk.get("cost", {}))
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 16)
	cost_lbl.add_theme_color_override("font_color", GOLD if is_selected else Color(0.6, 0.6, 0.56))
	vbox.add_child(cost_lbl)

	# 分隔線
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# 描述（置中、自動換行）
	var desc_lbl := Label.new()
	desc_lbl.text = sk.get("description", "")
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.add_theme_color_override("font_color", Color(0.68, 0.68, 0.7) if is_selected else Color(0.5, 0.5, 0.52))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)

	return card

func _build_menu_overlay(parent: Node) -> void:
	var title_host := Control.new()
	title_host.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_host.offset_top = 30
	title_host.offset_bottom = 70
	parent.add_child(title_host)
	var title := Label.new()
	title.text = "▼ 技能（候選 B：橫排卡片）"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", INK_RED)
	title.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	title.offset_left = -560
	title.offset_top = 0
	title.offset_right = -40
	title_host.add_child(title)

	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	host.offset_top = -280
	host.offset_bottom = -30
	parent.add_child(host)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(hbox)

	for i in SKILL_IDS.size():
		var sk: Dictionary = _skills.get(SKILL_IDS[i], {})
		var card := _build_card(sk, i == SELECTED_INDEX)
		var wrap := CenterContainer.new()
		wrap.add_child(card)
		hbox.add_child(wrap)

func _capture_mock_b() -> void:
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
	inst.ui.skill_menu.visible = false
	var overlay_layer := CanvasLayer.new()
	svc.add_child(overlay_layer)
	_build_menu_overlay(overlay_layer)
	for i in 6:
		await get_tree().process_frame
	await _save(svc, "res://_skillmenu_mock_b.png")
	await _free_viewport(svc)
