extends Node
## 佈局調整模式（debug-only）：讓不會用 Godot 的使用者在遊戲內即時拖曳/微調
## 2D CanvasItem（Sprite2D/TextureRect/Control/Node2D 皆可）的位置。
##
## 只在 OS.is_debug_build() 生效（正式版無感，_ready 直接跳過所有註冊）。
## 3D 場景（探索街景）不在範圍——只服務 2D CanvasItem。
##
## `（反引號，備用 F8）：切換調整模式（開/關）。⚠從編輯器跑時 F8 會被「停止執行」
## 快捷鍵搶走直接關遊戲（使用者實測），反引號才是主鍵。開啟時：
##   - 顯示角落操作說明小卡
##   - get_tree().paused = true（凍住遊戲方便對準；與①暫停頁共存規則：
##     F8 模式開啟時 ESC 不再開暫停頁，見 MinigameBase._is_layout_tuner_active）
##   - 一次畫出 LayoutStore.live_entries() 所有登記/樣板節點的框＋名牌
##     （綠框＝可自由拖曳；琥珀框＝容器排版/樣板元件，不可拖，見 v2 spec A 務實版）
##   - 滑鼠左鍵點擊 → 命中測試選中最上層 CanvasItem（面積最小者優先，避免選到背景）
##   - 命中綠框（已登記且 free）：拖曳/微調後即時 LayoutStore.capture()（並 apply_group）
##   - 命中琥珀框（容器/樣板）：不進入拖曳，資訊卡顯示「樣板/容器」提示
##   - 命中未登記的一般 CanvasItem：維持舊行為可拖，資訊卡標「未登記，移動不會存檔」
##   - 滑鼠右鍵 → 在滑鼠下的重疊候選之間循環切換選取
##
## ⚠2026-07-07 修正：命中測試改從 get_tree().root 整棵樹遞迴收集（含所有 CanvasLayer，
## 例如 Dialogic 對話框/立繪、BattleUI 教學小窗、HUD、暫停頁——這些都掛在自己的
## CanvasLayer 或直接掛在 root 下，不在 current_scene 底下，之前掃不到）；輸入改用
## _input()（GUI 階段之前）攔截，避免點在 Control（對話框本身）上時被 GUI 系統
## 先吃掉、輪不到 _unhandled_input。
## S（備用 F9）：v2 存檔改呼叫 LayoutStore.save()（寫 res://_layout_overrides.json）。
## 舊的 res://_layout_tuning.json 匯出機制已淘汰（不再寫入）。

## 舊式匯出路徑（v2 前）：不再由 `S` 鍵觸發（見 _input），但 save_tuning() 函式本身保留，
## 供「未登記節點」的臨時量測仍可手動呼叫（測試亦沿用它驗證 old_pos/new_pos/delta 記錄邏輯）。
const OUTPUT_PATH := "res://_layout_tuning.json"
const NUDGE_STEP := 1.0
const NUDGE_STEP_FAST := 10.0

## 琥珀框（容器/樣板元件）與綠框（可自由拖曳）的顏色，v2 全框標註用。
const COLOR_FREE := Color(0.25, 0.95, 0.35, 0.95)
const COLOR_TEMPLATE := Color(1.0, 0.72, 0.15, 0.95)
const COLOR_UNTRACKED := Color(0.55, 0.75, 1.0, 0.6)

var tuning_active: bool = false
var _debug_enabled: bool = false

var _overlay: CanvasLayer
var _info_card: Label
var _highlight_box: Panel
var _selected: CanvasItem = null
var _selected_start_pos: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

## 選取節點對應的 LayoutStore 登記資訊（v2）：{"key":String,"group":String,"free":bool}
## 或空字典（未登記的舊式量測物件，維持「移動不會存檔」行為）。
var _selected_entry: Dictionary = {}

## v2 全框標註：進調整模式時建立的一批 {"box":Panel,"label":Label,"key":String} 記錄，
## 隨 _selected 變化而各自更新邊框粗細，關閉時整批清除。
var _entry_boxes: Array = []

## 右鍵循環切換用：上一次命中測試在滑鼠下找到的所有候選（依面積排序），
## 與目前在其中選取的 index。滑鼠移動或重新左鍵選取時會重建。
var _cycle_candidates: Array = []
var _cycle_index: int = 0

## 本次 session 被移動過的節點記錄：node_path(String,唯一鍵) -> 記錄 dict。
## 僅供「未登記節點」的除錯量測參考用（v2 不再落 JSON，登記節點一律走 LayoutStore）。
var _moved: Dictionary = {}

func _ready() -> void:
	_debug_enabled = OS.is_debug_build()
	if not _debug_enabled:
		return
	# 本節點常駐監聽 F8/F9，process_mode 維持預設即可——調整模式開啟時我們自己把
	# get_tree().paused=true，但 LayoutTuner 自己必須設 ALWAYS 才能在暫停中繼續收
	# F8（關閉）/F9（存檔）與拖曳輸入。
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 用 _input（GUI 分派之前的階段）而非 _unhandled_input：調整模式要能點中
	# Dialogic 對話框、BattleUI 小窗等 Control——這些節點自己會在 GUI 階段吃掉
	# 滑鼠事件，事件永遠到不了 _unhandled_input。_input 在 GUI 之前收到同一個
	# event 物件，我們判斷完自己要不要處理，要處理就 set_input_as_handled()
	# 阻止繼續派送（含阻止穿透給下面的 GUI/遊戲邏輯）；不處理的一律放行，
	# 不影響平時遊戲操作。
	set_process_input(true)
	set_process_unhandled_input(false)

func _input(event: InputEvent) -> void:
	if not _debug_enabled:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		# 開關主鍵＝`（數字 1 左邊的反引號）。F8 保留當備用：從編輯器跑（尤其內嵌視窗）時
		# F8 是編輯器「停止執行」快捷鍵，會被編輯器攔走直接關遊戲（使用者實測踩到），
		# 反引號編輯器不佔用，兩種跑法都安全。
		if event.keycode == KEY_QUOTELEFT or event.keycode == KEY_F8:
			toggle_tuning()
			get_viewport().set_input_as_handled()
			return
		# 儲存＝S（調整模式中遊戲已暫停，不會跟移動鍵打架）；F9 備用（編輯器 F9=中斷點，同理讓位）。
		# v2：改存 LayoutStore（res://_layout_overrides.json），淘汰舊 _layout_tuning.json 匯出。
		if (event.keycode == KEY_S or event.keycode == KEY_F9) and tuning_active:
			LayoutStore.save()
			_refresh_info_card()
			get_viewport().set_input_as_handled()
			return
	# 調整模式關閉時：上面兩個開關鍵以外的一切輸入全部放行（不呼叫 set_input_as_handled），
	# 平時遊戲操作（含點擊 Dialogic 對話框推進劇情）完全不受影響。
	if not tuning_active:
		return
	if event is InputEventKey and event.pressed and _selected != null and _can_drag_selection():
		var step := NUDGE_STEP_FAST if event.shift_pressed else NUDGE_STEP
		var moved := true
		match event.keycode:
			KEY_LEFT:
				_apply_move(_selected, Vector2(-step, 0.0))
			KEY_RIGHT:
				_apply_move(_selected, Vector2(step, 0.0))
			KEY_UP:
				_apply_move(_selected, Vector2(0.0, -step))
			KEY_DOWN:
				_apply_move(_selected, Vector2(0.0, step))
			_:
				moved = false
		if moved:
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_try_select(event.position)
		else:
			_dragging = false
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_cycle_select(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging and _selected != null and _can_drag_selection():
		_set_pos(_selected, event.position + _drag_offset)
		_refresh_highlight()
		_refresh_info_card()
		get_viewport().set_input_as_handled()

## 切換調整模式。開啟：建說明卡 UI + paused=true；關閉：清掉 UI + 選取 + paused=false。
func toggle_tuning() -> void:
	if tuning_active:
		_disable_tuning()
	else:
		_enable_tuning()

func _enable_tuning() -> void:
	tuning_active = true
	get_tree().paused = true
	_build_overlay()

func _disable_tuning() -> void:
	tuning_active = false
	_dragging = false
	_selected = null
	_selected_entry = {}
	_cycle_candidates = []
	_cycle_index = 0
	_entry_boxes.clear()
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_info_card = null
	_highlight_box = null
	get_tree().paused = false

func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.name = "LayoutTunerOverlay"
	_overlay.layer = 4096   # 最上層，蓋過遊戲內任何 UI（含暫停頁 layer=110）
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_overlay)

	_build_entry_boxes()

	_info_card = Label.new()
	_info_card.process_mode = Node.PROCESS_MODE_ALWAYS
	_info_card.position = Vector2(24, 24)
	_info_card.add_theme_font_size_override("font_size", 20)
	_info_card.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	_info_card.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_info_card.add_theme_constant_override("outline_size", 6)
	_overlay.add_child(_info_card)
	_refresh_info_card()

	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = Color(1, 0.85, 0.2, 0.95)
	box.set_border_width_all(3)
	var panel := Panel.new()
	panel.name = "HighlightBox"
	panel.add_theme_stylebox_override("panel", box)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	_overlay.add_child(panel)
	_highlight_box = panel

## v2 驗收條件③：進調整模式一次畫出所有可調節點的框＋名牌。
## 綠框＝LayoutStore.live_entries() 裡 free==true（可自由拖曳的登記塊）；
## 琥珀框＝free==false 的登記節點，或另外掃全樹找到的 layout_template meta 節點
## （EnemyPanel 血條/立繪等樣板元件，純標註不可拖）。
func _build_entry_boxes() -> void:
	_entry_boxes.clear()
	for entry in LayoutStore.live_entries():
		var node: CanvasItem = entry.get("node")
		if node == null or not is_instance_valid(node):
			continue
		_add_entry_box(node, entry.get("key", ""), entry.get("free", true))
	var template_nodes: Array = []
	_collect_template_nodes(get_tree().root, template_nodes)
	for t in template_nodes:
		_add_entry_box(t.node, t.key, false)

## 掃全樹找出掛了 layout_template meta 的節點（EnemyPanel 血條/立繪等樣板標註）。
## 排除 overlay 自己；沒有可見性限制——樣板節點就算暫時 0 面積也標註一下，方便除錯。
func _collect_template_nodes(node: Node, out: Array) -> void:
	if node == _overlay:
		return
	if node is CanvasItem and node.has_meta("layout_template"):
		out.append({"node": node, "key": node.get_meta("layout_template")})
	for c in node.get_children():
		_collect_template_nodes(c, out)

func _add_entry_box(node: CanvasItem, key: String, free: bool) -> void:
	var color := COLOR_FREE if free else COLOR_TEMPLATE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = color
	sb.set_border_width_all(2)
	var box := Panel.new()
	box.name = "EntryBox_%s" % key.replace("/", "_")
	box.add_theme_stylebox_override("panel", sb)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay.add_child(box)

	var tag := Label.new()
	tag.process_mode = Node.PROCESS_MODE_ALWAYS
	tag.text = key
	tag.add_theme_font_size_override("font_size", 13)
	tag.add_theme_color_override("font_color", Color.BLACK)
	var tag_bg := StyleBoxFlat.new()
	tag_bg.bg_color = Color(color.r, color.g, color.b, 0.85)
	tag_bg.set_content_margin_all(3)
	tag.add_theme_stylebox_override("normal", tag_bg)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(tag)

	_entry_boxes.append({"box": box, "label": tag, "key": key, "node": node, "free": free})
	_update_entry_box_rect(_entry_boxes[-1])

func _update_entry_box_rect(rec: Dictionary) -> void:
	var node: CanvasItem = rec.get("node")
	var box: Panel = rec.get("box")
	var tag: Label = rec.get("label")
	if node == null or not is_instance_valid(node) or box == null or not is_instance_valid(box):
		return
	var rect := _get_screen_rect(node)
	box.position = rect.position
	box.size = rect.size
	if tag != null and is_instance_valid(tag):
		tag.position = rect.position + Vector2(0, -20)

## 選中變化時：選中的登記框加粗以區別（其餘維持細框）。
func _refresh_entry_box_selection() -> void:
	for rec in _entry_boxes:
		var box: Panel = rec.get("box")
		if box == null or not is_instance_valid(box):
			continue
		var is_sel: bool = _selected != null and rec.get("node") == _selected
		var free: bool = rec.get("free", true)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = COLOR_FREE if free else COLOR_TEMPLATE
		sb.set_border_width_all(4 if is_sel else 2)
		box.add_theme_stylebox_override("panel", sb)

func _process(_delta: float) -> void:
	if not tuning_active or _entry_boxes.is_empty():
		return
	for rec in _entry_boxes:
		_update_entry_box_rect(rec)

func _refresh_info_card() -> void:
	if _info_card == null:
		return
	var lines := [
		"【佈局調整模式】` 關閉（數字1左邊）／點選拖曳／右鍵 切換重疊物件／方向鍵微調 1px、Shift+方向鍵 10px／S 儲存",
	]
	if _selected != null and is_instance_valid(_selected):
		lines.append("已選中：%s @ %s" % [String(_selected.get_path()), _get_pos(_selected)])
		if not _selected_entry.is_empty() and not _selected_entry.get("free", true):
			var key: String = _selected_entry.get("key", "")
			lines.append("⚠程式控制位置（樣板/動態/會動元件）：%s——要調整請告訴 Claude" % key)
		elif not _selected_entry.is_empty():
			lines.append("已登記：%s（可拖曳，S 存檔永久生效）" % _selected_entry.get("key", ""))
		elif _is_in_container(_selected):
			lines.append("⚠此物件由容器排版，移動可能無效；未登記，移動不會存檔")
		else:
			lines.append("⚠未登記，移動不會存檔（僅供臨時量測）")
	else:
		lines.append("尚未選中任何節點（點擊畫面上的物件）")
	_info_card.text = "\n".join(lines)

func _is_in_container(node: CanvasItem) -> bool:
	var parent := node.get_parent()
	return parent != null and parent is Container

## v2：查出節點的 LayoutStore 登記資訊。優先看 layout_key（LayoutStore.register 過的
## 自由塊，可拖）；否則看 layout_template（EnemyPanel 血條/立繪等樣板標註，不可拖）；
## 都沒有則回空字典（走舊式「未登記」路徑）。
func _lookup_entry(node: CanvasItem) -> Dictionary:
	if node == null:
		return {}
	if node.has_meta("layout_key"):
		var key: String = node.get_meta("layout_key")
		for entry in LayoutStore.live_entries():
			if entry.get("key", "") == key:
				return entry
		# 節點掛了 meta 但 LayoutStore._live 裡沒有（理論上不該發生，保底仍視為已登記）。
		return {"key": key, "group": "", "free": LayoutStore.is_free(node), "node": node}
	if node.has_meta("layout_template"):
		var tkey: String = node.get_meta("layout_template")
		return {"key": tkey, "group": "", "free": false, "node": node}
	return {}

## 目前選取節點是否允許拖曳/微調：未登記（舊式量測物件）或已登記且 free==true 皆可拖；
## 已登記但 free==false（容器/樣板）不可拖。
func _can_drag_selection() -> bool:
	if _selected_entry.is_empty():
		return true
	return _selected_entry.get("free", true)

func _refresh_highlight() -> void:
	if _highlight_box == null:
		return
	if _selected == null or not is_instance_valid(_selected):
		_highlight_box.visible = false
		return
	var rect := _get_screen_rect(_selected)
	_highlight_box.visible = true
	_highlight_box.position = rect.position
	_highlight_box.size = rect.size

## 命中測試：在 viewport 座標下找滑鼠下方所有候選 CanvasItem（掃全樹，見
## _collect_candidates），取面積最小者（否則永遠選到覆蓋全螢幕的背景層）。
## 同時記錄完整候選清單＋排序供右鍵循環切換使用。
func _try_select(mouse_pos: Vector2) -> void:
	var candidates: Array = []
	_collect_candidates(get_tree().root, mouse_pos, candidates)
	candidates.sort_custom(_candidate_less)
	_cycle_candidates = candidates
	_cycle_index = 0
	if candidates.is_empty():
		_selected = null
		_selected_entry = {}
		_dragging = false
	else:
		_selected = candidates[0].node
		_selected_entry = _lookup_entry(_selected)
		_selected_start_pos = _get_pos(_selected)
		_dragging = _can_drag_selection()
		# v3：_drag_offset 是 viewport 座標系下的偏移（節點螢幕原點 − 滑鼠位置），
		# 拖曳時 mouse_pos + _drag_offset 才能還原「節點應該在的螢幕位置」，
		# 再交給 _set_pos 換算回巢狀節點的 local 座標。
		_drag_offset = _get_screen_pos(_selected) - mouse_pos
	_refresh_highlight()
	_refresh_info_card()
	_refresh_entry_box_selection()

## 右鍵：在上次命中測試留下的候選清單中，依序切換到下一個（循環回第一個）。
## 若滑鼠位置與上次不同（候選清單可能已經過期），先重新收集一次再切換，
## 確保永遠是「滑鼠目前位置」下的候選在循環。
func _cycle_select(mouse_pos: Vector2) -> void:
	var candidates: Array = []
	_collect_candidates(get_tree().root, mouse_pos, candidates)
	candidates.sort_custom(_candidate_less)
	if candidates.is_empty():
		_cycle_candidates = []
		_cycle_index = 0
		_selected = null
		_selected_entry = {}
		_refresh_highlight()
		_refresh_info_card()
		_refresh_entry_box_selection()
		return
	# 若候選集合與目前記錄的一致（同一群重疊物件），單純前進 index 循環；
	# 否則視為新的一群，從頭開始。
	var same_set := candidates.size() == _cycle_candidates.size()
	if same_set:
		for i in candidates.size():
			if candidates[i].node != _cycle_candidates[i].node:
				same_set = false
				break
	_cycle_candidates = candidates
	if same_set:
		_cycle_index = (_cycle_index + 1) % _cycle_candidates.size()
	else:
		_cycle_index = 0
	_selected = _cycle_candidates[_cycle_index].node
	_selected_entry = _lookup_entry(_selected)
	_selected_start_pos = _get_pos(_selected)
	_dragging = _can_drag_selection() and _dragging
	# v3：切換選取候選後 drag_offset 也要用 viewport 座標系重算（見 _try_select 註解）。
	_drag_offset = _get_screen_pos(_selected) - mouse_pos
	_refresh_highlight()
	_refresh_info_card()
	_refresh_entry_box_selection()

## 從 root 整棵樹遞迴收集命中候選（含所有 CanvasLayer 底下的 Node2D/Control，
## 例如 Dialogic 對話框/立繪掛在自己的 CanvasLayer、BattleUI 教學小窗、HUD、
## 暫停頁等，過去只掃 current_scene 完全掃不到這些）。排除：LayoutTuner 自己的
## overlay UI、不可見節點（visible=false 或任何祖先不可見）、面積為 0 者。
func _collect_candidates(node: Node, mouse_pos: Vector2, out: Array, depth: int = 0) -> void:
	if node == _overlay:
		return
	if node is CanvasItem:
		if not node.visible:
			return
		if node is Node2D or node is Control:
			var rect := _get_screen_rect(node)
			if rect.size.x > 0.0 and rect.size.y > 0.0 and rect.has_point(mouse_pos):
				out.append({
					"node": node, "area": rect.size.x * rect.size.y, "depth": depth,
					"tracked": _is_tracked(node),
				})
	for c in node.get_children():
		_collect_candidates(c, mouse_pos, out, depth + 1)

## v2：節點是否為 LayoutStore 登記節點（layout_key meta）或樣板標註節點
## （layout_template meta，見 EnemyPanel 的血條/立繪標註）——這兩類命中測試優先於
## 一般未登記節點（規格 3b：「優先命中已登記/已標註的節點」）。
func _is_tracked(node: CanvasItem) -> bool:
	return node.has_meta("layout_key") or node.has_meta("layout_template")

## 排序：已登記/已標註節點優先於一般節點；同一優先層內，面積相同時
## （常見於 Container 與其唯一/撐滿子節點的 rect 完全重合，例如
## VBoxContainer 只包一個 Label 時兩者 rect 一致）優先選較深層的節點——使用者
## 想調的通常是實際內容節點（Label/Sprite），不是外層排版容器。
func _candidate_less(a: Dictionary, b: Dictionary) -> bool:
	var a_tracked: bool = a.get("tracked", false)
	var b_tracked: bool = b.get("tracked", false)
	if a_tracked != b_tracked:
		return a_tracked  # tracked=true 排前面（sort_custom 由小到大，true 視為「較小」）
	if a.area != b.area:
		return a.area < b.area
	return a.depth > b.depth

## 取得節點在 viewport 座標系下的螢幕矩形（供命中測試與高亮框用）。
## Control：get_global_rect() 本身就是換算到 viewport 座標（含所在 CanvasLayer 的
## transform，Godot 內部已處理）。Node2D：優先用 Sprite2D/TextureRect 貼圖大小換算，
## 用 get_global_transform_with_canvas() 取得含 CanvasLayer transform 的座標，
## 不假設節點跟 LayoutTuner 在同一個 canvas（不同 CanvasLayer 各自 transform 可能不同，
## 雖然本專案目前各層 layer transform 皆為 identity，仍照正規做法換算避免日後踩雷）。
## 沒有貼圖資訊的當作一個點，給個保底小矩形（避免完全選不到）。
func _get_screen_rect(node: CanvasItem) -> Rect2:
	if node is Control:
		return (node as Control).get_global_rect()
	if node is Node2D:
		var n2d := node as Node2D
		var local_rect := Rect2(Vector2(-8, -8), Vector2(16, 16))
		if node is Sprite2D and (node as Sprite2D).texture != null:
			var tex_size: Vector2 = (node as Sprite2D).texture.get_size() * n2d.scale
			var sp := node as Sprite2D
			local_rect = Rect2(-tex_size * 0.5 if sp.centered else Vector2.ZERO, tex_size)
		var xform := n2d.get_global_transform_with_canvas()
		var p0 := xform * local_rect.position
		var p1 := xform * (local_rect.position + Vector2(local_rect.size.x, 0.0))
		var p2 := xform * (local_rect.position + Vector2(0.0, local_rect.size.y))
		var p3 := xform * (local_rect.position + local_rect.size)
		var min_pt := Vector2(min(min(p0.x, p1.x), min(p2.x, p3.x)), min(min(p0.y, p1.y), min(p2.y, p3.y)))
		var max_pt := Vector2(max(max(p0.x, p1.x), max(p2.x, p3.x)), max(max(p0.y, p1.y), max(p2.y, p3.y)))
		return Rect2(min_pt, max_pt - min_pt)
	return Rect2()

func _get_pos(node: CanvasItem) -> Vector2:
	if node is Control:
		return (node as Control).position
	if node is Node2D:
		return (node as Node2D).position
	return Vector2.ZERO

## 2026-07-07（v3）：節點原點在 viewport(螢幕) 座標系下的位置。用於算滑鼠拖曳
## offset 與傳給 _set_pos 的目標座標——跟 local position 不同，巢狀節點
## （父節點不在原點/有旋轉縮放）兩者會不一樣，混用就是巢狀拖曳跳位的根因。
func _get_screen_pos(node: CanvasItem) -> Vector2:
	if node is Control:
		return (node as Control).get_global_rect().position
	if node is Node2D:
		return (node as Node2D).get_global_transform_with_canvas() * Vector2.ZERO
	return Vector2.ZERO

## 2026-07-07 修正（v3）：拖曳目標一律以「viewport(螢幕)座標」傳入（滑鼠位置＋
## _drag_offset，或方向鍵微調的 _get_pos 結果＋位移——後者本來就是 local，見下方
## 特別處理）。巢狀節點（父節點不在原點/有旋轉縮放，例如化緣 _monk_sprite 掛在
## _bowl_node 底下）不能把 viewport 座標直接塞進 local position，否則會跳位。
## 做法：把 viewport 座標換算到父節點座標系（Node2D 用
## get_global_transform_with_canvas().affine_inverse()；Control 用父層的
## get_global_transform_with_canvas() 反變換，Control.position 是相對父 rect 左上角
## 的 local 座標，用同一套變換換算等效）。
func _set_pos(node: CanvasItem, pos: Vector2) -> void:
	if node is Control:
		var c := node as Control
		var parent := c.get_parent()
		if parent is CanvasItem and (parent as CanvasItem).is_inside_tree():
			var inv := (parent as CanvasItem).get_global_transform_with_canvas().affine_inverse()
			c.position = inv * pos
		else:
			c.position = pos
	elif node is Node2D:
		var n2d := node as Node2D
		var parent2 := n2d.get_parent()
		if parent2 is CanvasItem and (parent2 as CanvasItem).is_inside_tree():
			var inv2 := (parent2 as CanvasItem).get_global_transform_with_canvas().affine_inverse()
			n2d.position = inv2 * pos
		else:
			n2d.position = pos
	_record_move(node)
	_capture_if_registered(node)

## v2：若目前選取的節點是 LayoutStore 登記的自由塊（layout_key meta 且 free），
## 移動後立刻 capture 一次（即時記錄，S 再落 JSON）；若有 group，順便 apply_group
## 讓同群組節點同步（P1 戰鬥的 7 個自由塊皆為 group=""，此路徑暫不會觸發，先接好備用）。
func _capture_if_registered(node: CanvasItem) -> void:
	if node != _selected or _selected_entry.is_empty():
		return
	if not _selected_entry.get("free", true):
		return
	var key: String = _selected_entry.get("key", "")
	if key == "":
		return
	var group: String = _selected_entry.get("group", "")
	LayoutStore.capture(key, group)
	if group != "":
		LayoutStore.apply_group(group)

## 方向鍵微調：維持 local 位移（v3 spec 明定，不必換算到 viewport 座標系，
## 巢狀節點的相對位置本來就該用 local delta 移動，直接設 local position 即可）。
func _apply_move(node: CanvasItem, delta: Vector2) -> void:
	if node is Control:
		(node as Control).position += delta
	elif node is Node2D:
		(node as Node2D).position += delta
	_record_move(node)
	_capture_if_registered(node)
	_refresh_highlight()
	_refresh_info_card()

func _record_move(node: CanvasItem) -> void:
	var path := String(node.get_path())
	var old_pos: Vector2 = _moved.get(path, {}).get("old_pos_v", _selected_start_pos)
	var new_pos := _get_pos(node)
	_moved[path] = {
		"scene_file": _current_scene_file(),
		"node_path": path,
		"node_class": node.get_class(),
		"texture_or_name": _texture_or_name(node),
		"hint": _ancestor_hint(node),
		"in_container": _is_in_container(node),
		"old_pos": [old_pos.x, old_pos.y],
		"new_pos": [new_pos.x, new_pos.y],
		"delta": [new_pos.x - old_pos.x, new_pos.y - old_pos.y],
		"old_pos_v": old_pos,
		"time": Time.get_datetime_string_from_system(),
	}

func _current_scene_file() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return ""
	return scene.scene_file_path

func _texture_or_name(node: CanvasItem) -> String:
	if node is Sprite2D and (node as Sprite2D).texture != null:
		return (node as Sprite2D).texture.resource_path
	if node is TextureRect and (node as TextureRect).texture != null:
		return (node as TextureRect).texture.resource_path
	return node.name

## Dialogic 等動態節點常是 @ 開頭的自動命名（node_path 對人類/未來的 Claude 沒有語意）。
## 額外存一個 hint：往上找最近「名字看起來有意義」的祖先（非 @ 開頭）＋這個節點本身
## 若是 Control 的 name/text（Label 類）/texture 檔名，方便事後對照這節點實際是什麼。
func _ancestor_hint(node: CanvasItem) -> String:
	var parts: Array = []
	var cur: Node = node
	var hops := 0
	while cur != null and hops < 8:
		var nm := String(cur.name)
		if not nm.begins_with("@"):
			parts.push_front(nm)
		cur = cur.get_parent()
		hops += 1
		if parts.size() >= 3:
			break
	var extra := ""
	if node is Label or node is RichTextLabel:
		extra = String(node.get("text")) if node.get("text") != null else ""
	elif node is Sprite2D and (node as Sprite2D).texture != null:
		extra = (node as Sprite2D).texture.resource_path.get_file()
	elif node is TextureRect and (node as TextureRect).texture != null:
		extra = (node as TextureRect).texture.resource_path.get_file()
	var base := "/".join(parts)
	if extra != "":
		return "%s [%s]" % [base, extra]
	return base

## 把 _moved 寫進 JSON（與舊檔合併，同 node_path 以本次為準）。
## 測試可傳自訂 path 寫到暫存位置，避免留檔在 repo。
func save_tuning(path: String = OUTPUT_PATH) -> void:
	var merged: Dictionary = {}
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var txt := f.get_as_text()
			f.close()
			var parsed = JSON.parse_string(txt)
			if parsed is Array:
				for entry in parsed:
					if entry is Dictionary and entry.has("node_path"):
						merged[String(entry.node_path)] = entry
	for k in _moved:
		var e: Dictionary = _moved[k].duplicate()
		e.erase("old_pos_v")
		merged[k] = e
	var out_arr: Array = []
	for k in merged:
		out_arr.append(merged[k])
	var f2 := FileAccess.open(path, FileAccess.WRITE)
	if f2 != null:
		f2.store_string(JSON.stringify(out_arr, "\t"))
		f2.close()
