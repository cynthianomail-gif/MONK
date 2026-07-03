class_name TurnOrderBar
extends HBoxContainer

## 行動順序條（第一期，左上）：把行動佇列渲染成橫排圓 chip。
## 當前行動者放大＋朱紅底＋金邊；後續回合用虛線/半透明。
## 純 Control 繪製，不新增圖片素材。BattleManager 每次佇列變動呼叫 render()。

const INK_RED := Color("#C93A2E")
const GOLD := Color(0.788, 0.659, 0.38)
const DIM := Color(0.18, 0.18, 0.2)

func _init() -> void:
	add_theme_constant_override("separation", 10)
	alignment = BoxContainer.ALIGNMENT_BEGIN

## queue：Array[Combatant]，按行動順序。current_idx＝目前行動者在 queue 的索引。
func render(queue: Array, current_idx: int = 0) -> void:
	for c in get_children():
		c.queue_free()
	for i in queue.size():
		var combatant = queue[i]
		if combatant == null:
			continue
		add_child(_make_chip(combatant, i == current_idx))

func _make_chip(combatant, is_current: bool) -> Control:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", _chip_style(combatant, is_current))
	var sz: float = 62.0 if is_current else 48.0
	chip.custom_minimum_size = Vector2(sz, sz)

	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 24 if is_current else 18)
	# chip 顯示名字首字（玩家＝「戒」、敵＝顯示名首字）
	var nm: String = combatant.display_name
	lbl.text = nm.substr(0, 1) if nm.length() > 0 else "?"
	var fg: Color = Color(0.98, 0.98, 0.95) if (is_current or combatant.is_player) else Color(0.75, 0.75, 0.78)
	lbl.add_theme_color_override("font_color", fg)
	chip.add_child(lbl)

	# 當前行動者：脈動放大一下（純 Tween）
	if is_current:
		chip.pivot_offset = Vector2(sz * 0.5, sz * 0.5)
		var tw := chip.create_tween().set_loops()
		tw.tween_property(chip, "scale", Vector2(1.08, 1.08), 0.5).set_trans(Tween.TRANS_SINE)
		tw.tween_property(chip, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)
	return chip

func _chip_style(combatant, is_current: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(40)   # 圓 chip
	if is_current:
		sb.bg_color = INK_RED
		sb.set_border_width_all(3)
		sb.border_color = GOLD
	elif combatant.is_player:
		sb.bg_color = Color(0.10, 0.10, 0.12, 0.9)
		sb.set_border_width_all(2)
		sb.border_color = GOLD
	else:
		sb.bg_color = DIM
		sb.set_border_width_all(1)
		sb.border_color = Color(0.5, 0.5, 0.5)
	sb.set_content_margin_all(4)
	return sb
