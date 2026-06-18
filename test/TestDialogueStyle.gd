extends Node

## #8 P5 VN 對話版面 樣式驗證（headless，不啟動 Dialogic — 沿用本專案對話測試慣例）
##  1. monk_dialogue_style.tres 換成 VN 文字框層＋獨立立繪層、移除內嵌立繪文字框
##  2. 立繪層排在文字框層之後（z 在上，胸像壓在框左緣前方）
##  3. VN 文字框 overrides：box_panel/name_label_box_panel 指向專案自製 StyleBox、
##     兩個 self_modulate 設白（不染色，讓 StyleBox 顏色如實顯示）
##  4. monk_textbox_panel.tres：StyleBoxFlat，skew(斜切)＋border(金邊)＋shadow(霓虹)＋近黑底
##  5. monk_nametag_panel.tres：StyleBoxFlat，skew＋金色底
##  6. speaker_bust_layer.tscn：含 SPEAKER 模式立繪容器（免 join 事件、自動跟說話者）
## 以 main scene 跑，autoload 在線。

const STYLE_PATH := "res://src/ui/dialogue_style/monk_dialogue_style.tres"
const TEXTBOX_PANEL := "res://src/ui/dialogue_style/monk_textbox_panel.tres"
const NAMETAG_PANEL := "res://src/ui/dialogue_style/monk_nametag_panel.tres"
const BUST_LAYER := "res://src/ui/dialogue_style/speaker_bust_layer.tscn"
const CHOICE_NORMAL := "res://src/ui/dialogue_style/monk_choice_normal.tres"
const CHOICE_HOVER := "res://src/ui/dialogue_style/monk_choice_hover.tres"
const VN_TEXTBOX := "vn_textbox_layer"
const VN_CHOICE := "vn_choice_layer"
const OLD_TEXTBOX := "textbox_with_speaker_portrait"

var ok := true

func _ready() -> void:
	await get_tree().process_frame
	_test_style_layers()
	_test_textbox_overrides()
	_test_textbox_stylebox()
	_test_nametag_stylebox()
	_test_bust_layer()
	_test_choice_stylebox()
	_test_choice_overrides()
	print("DIALOGUE_STYLE_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  [PASS] ", msg)
	else:
		push_error("  [FAIL] " + msg)
		ok = false

func _layer_paths(style) -> Array:
	var out: Array = []
	for id in style.layer_list:
		out.append(String(style.get_layer_info(id).path))
	return out

func _test_style_layers() -> void:
	if not ResourceLoader.exists(STYLE_PATH):
		_check(false, "樣式檔存在：%s" % STYLE_PATH); return
	var style = load(STYLE_PATH)
	_check(style != null and style is DialogicStyle, "樣式載入為 DialogicStyle")
	if style == null:
		return
	var paths := _layer_paths(style)
	var joined := "\n".join(PackedStringArray(paths))
	_check(joined.contains(VN_TEXTBOX), "含 VN 文字框層 vn_textbox_layer")
	_check(joined.contains("speaker_bust_layer"), "含獨立立繪層 speaker_bust_layer")
	_check(not joined.contains(OLD_TEXTBOX), "已移除內嵌立繪文字框 textbox_with_speaker_portrait")
	var idx_box := -1
	var idx_bust := -1
	for i in paths.size():
		if String(paths[i]).contains(VN_TEXTBOX): idx_box = i
		if String(paths[i]).contains("speaker_bust_layer"): idx_bust = i
	_check(idx_box >= 0 and idx_bust > idx_box, "立繪層排在文字框層之後（畫在上層）")

func _test_textbox_overrides() -> void:
	if not ResourceLoader.exists(STYLE_PATH):
		return
	var style = load(STYLE_PATH)
	if style == null:
		return
	var box_id := ""
	for id in style.layer_list:
		if String(style.get_layer_info(id).path).contains(VN_TEXTBOX):
			box_id = id
	_check(box_id != "", "找到 VN 文字框層 id")
	if box_id == "":
		return
	var ov: Dictionary = style.get_layer_info(box_id).overrides
	_check(String(ov.get("box_panel", "")) == TEXTBOX_PANEL, "box_panel 指向 monk_textbox_panel")
	_check(String(ov.get("name_label_box_panel", "")) == NAMETAG_PANEL, "name_label_box_panel 指向 monk_nametag_panel")
	_check(String(ov.get("box_color_use_global", "")) == "false", "box_color_use_global=false（用自訂色）")
	_check(str_to_var(String(ov.get("box_color_custom", "Color(0,0,0,1)"))) == Color(1, 1, 1, 1),
		"box self_modulate 設白（顏色烤進 StyleBox、不被染色）")
	_check(str_to_var(String(ov.get("name_label_box_modulate", "Color(0,0,0,1)"))) == Color(1, 1, 1, 1),
		"名牌 self_modulate 設白")

func _test_textbox_stylebox() -> void:
	if not ResourceLoader.exists(TEXTBOX_PANEL):
		_check(false, "文字框 StyleBox 存在：%s" % TEXTBOX_PANEL); return
	var sb = load(TEXTBOX_PANEL)
	_check(sb != null and sb is StyleBoxFlat, "文字框 StyleBox 為 StyleBoxFlat")
	if sb == null or not (sb is StyleBoxFlat):
		return
	_check(sb.skew.x > 0.0, "文字框有斜切 skew.x>0")
	_check(sb.border_width_left > 0 and sb.border_width_top > 0 \
		and sb.border_width_right > 0 and sb.border_width_bottom > 0, "文字框四邊有金邊")
	_check(sb.shadow_size > 0, "文字框有霓虹光暈 shadow_size>0")
	_check(sb.bg_color.a > 0.5 and sb.bg_color.r < 0.2, "文字框底為近黑半透")

func _test_nametag_stylebox() -> void:
	if not ResourceLoader.exists(NAMETAG_PANEL):
		_check(false, "名牌 StyleBox 存在：%s" % NAMETAG_PANEL); return
	var sb = load(NAMETAG_PANEL)
	_check(sb != null and sb is StyleBoxFlat, "名牌 StyleBox 為 StyleBoxFlat")
	if sb == null or not (sb is StyleBoxFlat):
		return
	_check(sb.skew.x > 0.0, "名牌有斜切 skew.x>0")
	_check(sb.bg_color.r > 0.6 and sb.bg_color.g > 0.5 and sb.bg_color.b < 0.5, "名牌底為金色")

func _find_container(n: Node):
	if n is DialogicNode_PortraitContainer:
		return n
	for c in n.get_children():
		var r = _find_container(c)
		if r != null:
			return r
	return null

func _test_bust_layer() -> void:
	if not ResourceLoader.exists(BUST_LAYER):
		_check(false, "立繪層場景存在：%s" % BUST_LAYER); return
	var scene = load(BUST_LAYER)
	_check(scene != null and scene is PackedScene, "立繪層場景載入為 PackedScene")
	if scene == null or not (scene is PackedScene):
		return
	var inst: Node = scene.instantiate()
	var con = _find_container(inst)
	_check(con != null, "立繪層含 DialogicNode_PortraitContainer")
	if con != null:
		_check(con.mode == DialogicNode_PortraitContainer.PositionModes.SPEAKER,
			"立繪容器為 SPEAKER 模式（免 join、自動跟說話者）")
		_check(con.size_mode == DialogicNode_PortraitContainer.SizeModes.FIT_SCALE_HEIGHT,
			"size_mode=FIT_SCALE_HEIGHT")
		_check(con.origin_anchor == DialogicNode_PortraitContainer.OriginAnchors.BOTTOM_LEFT,
			"origin_anchor=BOTTOM_LEFT（錨左下）")
	inst.free()

func _test_choice_stylebox() -> void:
	for path in [CHOICE_NORMAL, CHOICE_HOVER]:
		if not ResourceLoader.exists(path):
			_check(false, "選項 StyleBox 存在：%s" % path); continue
		var sb = load(path)
		_check(sb is StyleBoxFlat, "選項 StyleBox 為 StyleBoxFlat：%s" % path.get_file())
		if sb is StyleBoxFlat:
			_check(sb.skew.x > 0.0, "選項 StyleBox 有斜切：%s" % path.get_file())
	if ResourceLoader.exists(CHOICE_HOVER):
		var hv = load(CHOICE_HOVER)
		if hv is StyleBoxFlat:
			_check(hv.shadow_size > 0, "選項 hover 有霓虹光暈 shadow_size>0")

func _test_choice_overrides() -> void:
	if not ResourceLoader.exists(STYLE_PATH):
		return
	var style = load(STYLE_PATH)
	if style == null:
		return
	var cid := ""
	for id in style.layer_list:
		if String(style.get_layer_info(id).path).contains(VN_CHOICE):
			cid = id
	_check(cid != "", "找到 VN 選項層 id")
	if cid == "":
		return
	var ov: Dictionary = style.get_layer_info(cid).overrides
	_check(String(ov.get("boxes_stylebox_normal", "")) == CHOICE_NORMAL, "選項 normal stylebox 指向 monk_choice_normal")
	_check(String(ov.get("boxes_stylebox_hovered", "")) == CHOICE_HOVER, "選項 hover stylebox 指向 monk_choice_hover")
	_check(String(ov.get("text_color_use_global", "")) == "false", "選項文字用自訂色")
