extends Control
## 螢幕空間任務標記：每幀把「現在有任務」的地點 NPC 頭上投影一個「！」到螢幕。
## （3D Label3D 在本場景會被墨線後製依深度重繪吃掉，改走 HUD 2D 投影＝可靠、遠近都清楚。）
## 世界座標→螢幕用 camera.unproject_position（與 HUD 同一 1920 基準座標系）。

const HEAD_H := 2.8                       # NPC 頭上高度(世界單位)
const YELLOW := Color(1.0, 0.86, 0.12)
const DARK := Color(0.14, 0.05, 0.0, 0.95)
const FSIZE := 46

var _t := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var font := get_theme_default_font()
	var bob := sin(_t * 3.5) * 5.0
	for t in get_tree().get_nodes_in_group("location_trigger"):
		if not (t is Node3D) or not ("loc_data" in t):
			continue
		if not QuestManager.location_has_quest(t.loc_data):
			continue
		var wp: Vector3 = (t as Node3D).global_position + Vector3(0, HEAD_H, 0)
		if cam.is_position_behind(wp):
			continue
		var sp := cam.unproject_position(wp)
		sp.y += bob
		_draw_bang(font, sp)

## 在 sp（NPC 頭頂螢幕座標）畫一個吸睛的「！」：暗底圓角牌 + 黃字墨邊 + 下方小三角指向 NPC。
func _draw_bang(font: Font, sp: Vector2) -> void:
	var text := "!"
	var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FSIZE)
	# 暗底圓（吸睛、與亮背景區隔）
	draw_circle(sp, 20.0, Color(0.1, 0.08, 0.05, 0.6))
	draw_arc(sp, 20.0, 0, TAU, 20, YELLOW, 2.0, true)
	# 下方小三角，指向 NPC 頭
	var tri := PackedVector2Array([sp + Vector2(-7, 17), sp + Vector2(7, 17), sp + Vector2(0, 28)])
	draw_colored_polygon(tri, Color(0.1, 0.08, 0.05, 0.6))
	# 「!」字（置中）：baseline = sp.y + ascent - 半字高
	var pos := Vector2(sp.x - sz.x * 0.5, sp.y + font.get_ascent(FSIZE) * 0.5 - sz.y * 0.30)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FSIZE, 6, DARK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FSIZE, YELLOW)
