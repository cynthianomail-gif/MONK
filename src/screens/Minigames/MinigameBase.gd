extends Node2D
class_name MinigameBase
## 所有小遊戲的共用基底。
## 子類負責玩法與計分，結束時呼叫 finish(result)；
## 由 SceneRouter.finish_minigame 統一套用獎勵、回報結果、返回地圖。
##
## result 契約：
##   { "id": String, "score": int, "win": bool,
##     "gold": int, "merit": int, "karma": int }
## 小遊戲本身不直接改 GameManager 狀態（保持純邏輯、好測試）。

const RESULT_TEMPLATE := {
	"id": "", "score": 0, "win": false,
	"gold": 0, "merit": 0, "karma": 0,
}

var _finished: bool = false

## 子類覆寫，回傳本小遊戲的 id（與場景檔名 to_snake_case 對應）。
func minigame_id() -> String:
	return ""

## 把 result 補齊預設欄位後回傳（子類組 result 時可用）。
func make_result(fields: Dictionary) -> Dictionary:
	var r := RESULT_TEMPLATE.duplicate(true)
	for k in fields:
		r[k] = fields[k]
	if r.id == "":
		r.id = minigame_id()
	return r

## 結束小遊戲：交給 SceneRouter 套用獎勵並返回地圖。重複呼叫只生效一次。
func finish(result: Dictionary) -> void:
	if _finished:
		return
	_finished = true
	var r := make_result(result)
	if Engine.has_singleton("SceneRouter") or get_node_or_null("/root/SceneRouter") != null:
		SceneRouter.finish_minigame(r)
	else:
		# 測試情境下沒有 autoload：直接發訊號讓測試接住。
		minigame_finished.emit(r)

signal minigame_finished(result: Dictionary)

## 子類覆寫：重置內部狀態、重開一局。由「再玩一次」呼叫。
## 不得重新扣打工時段（那是進場時做的事，restart 不會碰到）、不得重複發獎勵
## （獎勵只在最終「離開」時，依最後一局的 result 結算一次）。
func restart() -> void:
	pass

## 依 result.win 播 minigame_<id>_win / minigame_<id>_lose 過場短片，
## 停最後一幀後「留在畫面上當結算底圖」（2026-07-07 使用者拍板：不淡出、不露出
## 小遊戲本身的畫面）；overlay 存進 _end_cutscene_overlay，「再玩一次」時才淡出移除、
## 「離開」時隨場景切換一起釋放（overlay 是 current_scene 的子節點）。
## 找不到素材（缺檔）或沒有 SceneRouter autoload（測試情境）時安全跳過，不擋結算面板。
func _play_end_cutscene(result: Dictionary) -> void:
	var id := minigame_id()
	if id == "":
		return
	if not (Engine.has_singleton("SceneRouter") or get_node_or_null("/root/SceneRouter") != null):
		return
	var suffix := "win" if bool(result.get("win", false)) else "lose"
	_end_cutscene_overlay = await SceneRouter.play_minigame_cutscene("minigame_%s_%s" % [id, suffix])

## 淡出移除停在最後一幀的結尾過場（fire-and-forget；「再玩一次」重開新局時呼叫）。
func _dismiss_end_cutscene() -> void:
	if _end_cutscene_overlay != null:
		SceneRouter.dismiss_minigame_cutscene(_end_cutscene_overlay)
		_end_cutscene_overlay = null

# ════════════════════════════════════════════════════════════════
# 共用結算面板：遊戲結束不直接 finish()，先停在這裡讓玩家選
# 「再玩一次」（呼叫 restart()，面板關閉，不觸發任何獎勵/切場）
# 或「離開」（此刻才 finish(result)，套用獎勵並返回）。
# ════════════════════════════════════════════════════════════════

const PANEL_BG := Color(0.129, 0.106, 0.086)       # #211b16
const PANEL_BORDER := Color(0.788, 0.588, 0.180)   # #c9962e
const PANEL_GOLD := Color(0.941, 0.753, 0.290)     # #f0c04a
const PANEL_TEXT := Color(0.909, 0.863, 0.761)     # #e8dcc2

var _result_layer: CanvasLayer
var _end_cutscene_overlay: CanvasLayer = null   # 停在最後一幀的結尾過場（結算底圖）
var _result_pending: Dictionary = {}
var _result_btn_idx: int = 0
var _result_buttons: Array[Button] = []
var _result_leave_label: String = "離開"

## 測試專用旗標：跳過結尾過場短片，讓 show_result_panel 同幀內直接建面板
## （見 test/TestResultPanel.gd _make_game()）。真正遊戲流程一律播放，預設 false。
var suppress_end_cutscene: bool = false

signal result_panel_shown(rating: String, rows: Array)
signal result_panel_leave(result: Dictionary)
signal result_panel_restart()

## 顯示共用結算面板。title=遊戲名；rating=評級大字（金色）；
## rows=[{label, value}] 明細列；result=最終 result dict（離開時才真正 finish）。
## leave_label 可覆寫「離開」鈕文字（21 點用「離開賭桌」）。
##
## 結尾流程（2026-07-07 定版，取代 2026-07-04 規格第 4 節的「面板出現時移除過場」）：
## 依 result.win 播 minigame_<id>_win / _lose 過場 → 停最後一幀「留著當底」→
## 結算面板疊在其上（不再露出小遊戲畫面）→「再玩一次」才淡出過場回到遊戲、
## 「離開」隨場景切換帶走。9 個小遊戲的 _end() 都只呼叫這個函式，掛在這裡＝全部接好。
func show_result_panel(title: String, rating: String, rows: Array, result: Dictionary, leave_label: String = "離開") -> void:
	if not suppress_end_cutscene:
		await _play_end_cutscene(result)
	_close_result_panel()
	_result_pending = result
	_result_leave_label = leave_label
	_result_btn_idx = 0
	_result_buttons.clear()

	_result_layer = CanvasLayer.new()
	# 過場 overlay 在 layer 128（SceneRouter.play_minigame_cutscene）；結算面板要
	# 疊在停格的最後一幀之上，layer 必須更高（舊值 100 會被過場整層蓋住）。
	_result_layer.layer = 200
	add_child(_result_layer)

	var dim := ColorRect.new()
	# 底下是 win/lose 過場停格時，壓暗調淡讓最後一幀看得見；沒過場（缺檔/測試）時
	# 底下是小遊戲畫面，維持原本較深的壓暗。
	dim.color = Color(0, 0, 0, 0.45 if _end_cutscene_overlay != null else 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_result_layer.add_child(dim)

	var panel := Panel.new()
	var panel_w := 620.0
	var panel_h := 300.0 + rows.size() * 40.0
	panel.position = Vector2(960.0 - panel_w * 0.5, 540.0 - panel_h * 0.5)
	panel.size = Vector2(panel_w, panel_h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = PANEL_BORDER
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	_result_layer.add_child(panel)
	# 佈局工具 v2（P4）：結算面板整塊登記為自由定位塊（父節點 _result_layer 是
	# CanvasLayer，非 Container，is_free()==true）。9 款小遊戲共用同一支
	# show_result_panel，掛在這裡就等於全部接好。
	LayoutStore.register(panel, "minigame/common/result_panel")

	var title_l := Label.new()
	title_l.text = title
	title_l.position = Vector2(0, 24)
	title_l.size = Vector2(panel_w, 44)
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_l.add_theme_font_size_override("font_size", 30)
	title_l.add_theme_color_override("font_color", PANEL_TEXT)
	panel.add_child(title_l)

	var rating_l := Label.new()
	rating_l.text = rating
	rating_l.position = Vector2(0, 72)
	rating_l.size = Vector2(panel_w, 68)
	rating_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rating_l.add_theme_font_size_override("font_size", 52)
	rating_l.add_theme_color_override("font_color", PANEL_GOLD)
	panel.add_child(rating_l)

	var row_y := 150.0
	for row in rows:
		var d: Dictionary = row
		var name_l := Label.new()
		name_l.text = String(d.get("label", ""))
		name_l.position = Vector2(48, row_y)
		name_l.size = Vector2(panel_w * 0.5 - 48.0, 34)
		name_l.add_theme_font_size_override("font_size", 24)
		name_l.add_theme_color_override("font_color", PANEL_TEXT)
		panel.add_child(name_l)
		var val_l := Label.new()
		val_l.text = String(d.get("value", ""))
		val_l.position = Vector2(panel_w * 0.5, row_y)
		val_l.size = Vector2(panel_w * 0.5 - 48.0, 34)
		val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_l.add_theme_font_size_override("font_size", 24)
		val_l.add_theme_color_override("font_color", PANEL_TEXT)
		panel.add_child(val_l)
		row_y += 40.0

	var btn_y := panel_h - 84.0
	var btn_w := 240.0
	var btn_gap := 24.0
	var total_w := btn_w * 2 + btn_gap
	var btn_x0 := (panel_w - total_w) * 0.5
	var replay_btn := _make_result_button("再玩一次", Vector2(btn_x0, btn_y), Vector2(btn_w, 56))
	replay_btn.pressed.connect(_on_result_restart)
	panel.add_child(replay_btn)
	_result_buttons.append(replay_btn)
	var leave_btn := _make_result_button(leave_label, Vector2(btn_x0 + btn_w + btn_gap, btn_y), Vector2(btn_w, 56))
	leave_btn.pressed.connect(_on_result_leave)
	panel.add_child(leave_btn)
	_result_buttons.append(leave_btn)

	_result_refresh_selection()
	result_panel_shown.emit(rating, rows)

## 結算/暫停共用按鈕。兩種樣式存在 meta（sb_normal/sb_selected），刷新時從 meta 取——
## ⚠不能用 get_theme_stylebox("normal") 讀回：那會讀到上一輪刷新蓋上去的 override，
## 按鈕被選過一次後就永遠長得像選中（2026-07-07 使用者回報「兩顆都亮」的根因）。
func _make_result_button(text: String, pos: Vector2, size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 26)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.06, 0.05, 0.95)
	normal.border_color = PANEL_BORDER.darkened(0.35)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	var sel := normal.duplicate() as StyleBoxFlat
	sel.bg_color = Color(0.24, 0.16, 0.07, 0.98)
	sel.border_color = PANEL_GOLD
	sel.set_border_width_all(3)
	b.set_meta("sb_normal", normal)
	b.set_meta("sb_selected", sel)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", sel)
	b.add_theme_stylebox_override("pressed", sel)
	b.add_theme_stylebox_override("focus", sel)
	b.add_theme_color_override("font_color", PANEL_TEXT)
	b.add_theme_color_override("font_hover_color", PANEL_GOLD)
	b.add_theme_color_override("font_pressed_color", PANEL_GOLD)
	# 滑鼠移到哪顆，鍵盤選取就跟到哪顆（結算面板與暫停頁各自的清單都查）。
	b.mouse_entered.connect(func() -> void:
		var ridx := _result_buttons.find(b)
		if ridx >= 0:
			if ridx != _result_btn_idx:
				_result_btn_idx = ridx
				_result_refresh_selection()
			return
		var pidx := _pause_buttons.find(b)
		if pidx >= 0 and pidx != _pause_btn_idx:
			_pause_btn_idx = pidx
			_pause_refresh_selection())
	return b

## 依選取索引刷新一組按鈕：選中＝金框金字亮底，未選＝暗框暖字。結算/暫停共用。
func _refresh_button_selection(buttons: Array[Button], sel_idx: int) -> void:
	for i in buttons.size():
		var b := buttons[i]
		var selected: bool = i == sel_idx
		b.add_theme_stylebox_override("normal",
			b.get_meta("sb_selected") if selected else b.get_meta("sb_normal"))
		b.add_theme_color_override("font_color", PANEL_GOLD if selected else PANEL_TEXT)

func _result_refresh_selection() -> void:
	_refresh_button_selection(_result_buttons, _result_btn_idx)

func is_result_panel_open() -> bool:
	return _result_layer != null and is_instance_valid(_result_layer)

func _unhandled_input(event: InputEvent) -> void:
	# 確保常駐監聽節點存在（暫停中的一切輸入都靠它，見上方 _PauseWatcher 說明）。
	# 這裡是 MinigameBase 自身的 _unhandled_input，只有未暫停時才會被引擎呼叫，
	# 剛好符合「在遊戲第一次收到輸入前把 watcher 準備好」的需求。
	_ensure_pause_watcher()

	# cancel 開暫停頁：只在「未暫停、結算面板未開」時由這裡處理；
	# 暫停中的 cancel（恢復）與暫停選單本身的鍵盤導覽全部交給 _PauseWatcher，
	# 因為 MinigameBase 本體在暫停中收不到 _unhandled_input（PROCESS_MODE_INHERIT 被凍結）。
	if event.is_action_pressed("cancel") and not is_result_panel_open() and not is_paused_menu_open():
		if _maybe_open_pause_menu():
			get_viewport().set_input_as_handled()
			return

	if not is_result_panel_open():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_A:
				_result_btn_idx = maxi(0, _result_btn_idx - 1)
				_result_refresh_selection()
				get_viewport().set_input_as_handled()
			KEY_RIGHT, KEY_D:
				_result_btn_idx = mini(_result_buttons.size() - 1, _result_btn_idx + 1)
				_result_refresh_selection()
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if _result_btn_idx >= 0 and _result_btn_idx < _result_buttons.size():
					_result_buttons[_result_btn_idx].pressed.emit()
				get_viewport().set_input_as_handled()
	elif event.is_action_pressed("confirm"):
		if _result_btn_idx >= 0 and _result_btn_idx < _result_buttons.size():
			_result_buttons[_result_btn_idx].pressed.emit()
		get_viewport().set_input_as_handled()

## 暫停選單鍵盤導覽（由 _PauseWatcher 呼叫，暫停中仍可運作）。
func _pause_nav(delta: int) -> void:
	_pause_btn_idx = clampi(_pause_btn_idx + delta, 0, _pause_buttons.size() - 1)
	_pause_refresh_selection()

func _pause_activate_selected() -> void:
	if _pause_btn_idx >= 0 and _pause_btn_idx < _pause_buttons.size():
		_pause_buttons[_pause_btn_idx].pressed.emit()

func _on_result_restart() -> void:
	_close_result_panel()
	_dismiss_end_cutscene()   # 淡出停格的結尾過場，露出重開的新局
	result_panel_restart.emit()
	restart()

func _on_result_leave() -> void:
	var r := _result_pending
	_close_result_panel()
	result_panel_leave.emit(r)
	finish(r)

func _close_result_panel() -> void:
	if _result_layer != null and is_instance_valid(_result_layer):
		_result_layer.queue_free()
	_result_layer = null
	_result_buttons.clear()

# --- 共用體感（畫面震動＋頓幀；HUD 都在 CanvasLayer 上不受震動影響）---

## 畫面震動：搖場景根節點（強度遞減的隨機偏移）。命中/撞擊瞬間用。
func shake(strength: float = 12.0, dur: float = 0.25) -> void:
	var steps := maxi(int(dur / 0.04), 2)
	var tw := create_tween()
	for i in steps:
		var falloff := 1.0 - float(i) / float(steps)
		var off := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength * falloff
		tw.tween_property(self, "position", off, 0.04)
	tw.tween_property(self, "position", Vector2.ZERO, 0.04)

## 頓幀（hit-stop）：重擊瞬間全域慢動作一瞬，強化打擊感。
## dur=真實秒數；重入保護（已在頓幀中就跳過）。
func hit_stop(dur: float = 0.06, slow: float = 0.05) -> void:
	if Engine.time_scale < 1.0:
		return
	Engine.time_scale = slow
	await get_tree().create_timer(dur, true, false, true).timeout   # ignore_time_scale
	Engine.time_scale = 1.0

# --- 共用 FX（Codex fx_* 圖，additive 疊加、縮放+淡出後自清；缺圖靜默跳過）---

const FX_ART := "res://assets/art_direction/new_ink_shrine_style/minigames/parlor/"

## 命中爆點：飛鏢釘靶/保齡球撞瓶的瞬間。fx_scale＝最終 scale（圖 1254px 見方）。
func spawn_fx_burst(pos: Vector2, fx_scale: float) -> void:
	_spawn_fx("fx_impact_burst_game_ready.png", pos, fx_scale, 0.12, 0.28)

## 贏錢金光：結算/紅心/全倒的慶祝閃光，停留久一點。
func spawn_fx_sparkle(pos: Vector2, fx_scale: float) -> void:
	_spawn_fx("fx_gold_sparkle_game_ready.png", pos, fx_scale, 0.18, 0.75)

func _spawn_fx(file: String, pos: Vector2, fx_scale: float, grow_t: float, fade_t: float) -> void:
	var path := FX_ART + file
	if not ResourceLoader.exists(path):
		return
	var s := Sprite2D.new()
	s.texture = load(path)
	s.position = pos
	s.scale = Vector2.ONE * fx_scale * 0.45
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	add_child(s)
	var tw := create_tween()
	tw.tween_property(s, "scale", Vector2.ONE * fx_scale, grow_t) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(s, "modulate:a", 0.0, grow_t + fade_t)
	tw.tween_callback(s.queue_free)

# ════════════════════════════════════════════════════════════════
# ESC 暫停頁：全部 9 款小遊戲共用。get_tree().paused=true 凍結子類的
# _process/tween/timer（皆為預設 PROCESS_MODE_INHERIT）——這是我們要的效果，
# 所以 MinigameBase 自己（場景根節點）絕對不能整個設成 PROCESS_MODE_ALWAYS，
# 那樣會連帶讓所有 INHERIT 的子節點（=幾乎整個場景）在暫停中繼續跑，凍結就失效了。
# 做法：另開一個「常駐輸入監聽節點」_PauseWatcher（獨立 Node，process_mode=ALWAYS），
# 只有它在暫停中還能收 _unhandled_input；暫停 UI（CanvasLayer/Panel/Button）也各自
# 標記 ALWAYS 才能被點擊/收鍵盤。除此之外的場景樹維持預設，凍結行為不受影響。
#
# 邊界（見規格）：
#   - 結算面板開著時 ESC 不觸發暫停（已經結束了，is_result_panel_open() 擋下）。
#   - intro 過場播放中 ESC 是跳過短片的既有行為（CutsceneScreen 自己處理
#     "cancel"/滑鼠點擊），不屬於本機制；本機制只在過場 overlay 不存在時才接手
#     "cancel"（用目前場景是否還疊著過場 overlay 判斷，見 _is_intro_playing）。
#   - LayoutTuner 的 F8 調整模式開啟時，ESC 不開暫停頁（LayoutTuner.tuning_active）。
# ════════════════════════════════════════════════════════════════

const PAUSE_BG := Color(0, 0, 0, 0.72)

var _pause_layer: CanvasLayer
var _pause_btn_idx: int = 0
var _pause_buttons: Array[Button] = []
var _pause_watcher: Node

signal paused_opened()
signal paused_closed()

func is_paused_menu_open() -> bool:
	return _pause_layer != null and is_instance_valid(_pause_layer)

## intro 過場播放中：SceneRouter.go_to_minigame 播放期間，current_scene 底下會疊著
## 一個「有 play 方法＋finished 訊號」的 CutsceneScreen overlay（見 play_minigame_cutscene）。
## 存在期間 ESC 應該走過場自己的跳過邏輯，不搶著開暫停頁。
func _is_intro_playing() -> bool:
	var root := get_tree().current_scene
	if root == null:
		return false
	return _find_cutscene_overlay(root) != null

func _find_cutscene_overlay(node: Node) -> Node:
	if node != self and node.has_method("play") and node.has_signal("finished"):
		return node
	for c in node.get_children():
		var found := _find_cutscene_overlay(c)
		if found != null:
			return found
	return null

func _is_layout_tuner_active() -> bool:
	var lt := get_node_or_null("/root/LayoutTuner")
	return lt != null and bool(lt.get("tuning_active"))

## 常駐輸入監聽節點：process_mode=ALWAYS，暫停中仍會收到 _unhandled_input
## （MinigameBase 本體暫停中就凍結了，收不到），負責暫停選單開著時的全部輸入：
## cancel 恢復、↑↓/WS 切換選項、Enter/Space/confirm 觸發選中項、滑鼠已由
## Button 自己的 pressed 訊號處理（Button 也標了 PROCESS_MODE_ALWAYS）。
class _PauseWatcher extends Node:
	var owner_game: Node

	func _unhandled_input(event: InputEvent) -> void:
		if owner_game == null or not is_instance_valid(owner_game):
			return
		if not owner_game.is_paused_menu_open():
			return
		if event.is_action_pressed("cancel"):
			owner_game._close_pause_menu()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.pressed and not event.echo:
			match event.keycode:
				KEY_UP, KEY_W:
					owner_game._pause_nav(-1)
					get_viewport().set_input_as_handled()
				KEY_DOWN, KEY_S:
					owner_game._pause_nav(1)
					get_viewport().set_input_as_handled()
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					owner_game._pause_activate_selected()
					get_viewport().set_input_as_handled()
		elif event.is_action_pressed("confirm"):
			owner_game._pause_activate_selected()
			get_viewport().set_input_as_handled()

func _ensure_pause_watcher() -> void:
	if _pause_watcher != null and is_instance_valid(_pause_watcher):
		return
	_pause_watcher = _PauseWatcher.new()
	_pause_watcher.owner_game = self
	_pause_watcher.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_watcher.name = "_PauseWatcher"
	add_child(_pause_watcher)

## 未暫停狀態下的 cancel：判斷是否該開啟暫停頁。呼叫端（_unhandled_input）
## 已在遊戲未暫停時才會走到這裡（暫停中的 cancel 由 _PauseWatcher 接手處理）。
func _maybe_open_pause_menu() -> bool:
	if is_result_panel_open():
		return false
	if _is_layout_tuner_active():
		return false
	if _is_intro_playing():
		return false
	_open_pause_menu()
	return true

func _open_pause_menu() -> void:
	if is_paused_menu_open():
		return
	_ensure_pause_watcher()
	_pause_btn_idx = 0
	_pause_buttons.clear()

	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 110
	_pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_layer)

	var dim := ColorRect.new()
	dim.color = PAUSE_BG
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_layer.add_child(dim)

	var panel := Panel.new()
	var panel_w := 420.0
	var panel_h := 320.0
	panel.position = Vector2(960.0 - panel_w * 0.5, 540.0 - panel_h * 0.5)
	panel.size = Vector2(panel_w, panel_h)
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = PANEL_BORDER
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	_pause_layer.add_child(panel)
	# 佈局工具 v2（P4）：暫停面板整塊登記為自由定位塊（父節點 _pause_layer 是
	# CanvasLayer，非 Container，is_free()==true）。9 款小遊戲共用，掛這裡全部接好。
	LayoutStore.register(panel, "minigame/common/pause_panel")

	var title_l := Label.new()
	title_l.text = "暫停"
	title_l.position = Vector2(0, 28)
	title_l.size = Vector2(panel_w, 44)
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_l.add_theme_font_size_override("font_size", 34)
	title_l.add_theme_color_override("font_color", PANEL_GOLD)
	title_l.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.add_child(title_l)

	var labels := ["繼續", "再試一次", "離開"]
	var btn_w := 280.0
	var btn_h := 56.0
	var btn_gap := 18.0
	var btn_x := (panel_w - btn_w) * 0.5
	var btn_y0 := 108.0
	for i in labels.size():
		var b := _make_result_button(labels[i], Vector2(btn_x, btn_y0 + i * (btn_h + btn_gap)), Vector2(btn_w, btn_h))
		b.process_mode = Node.PROCESS_MODE_ALWAYS
		match i:
			0: b.pressed.connect(_on_pause_resume)
			1: b.pressed.connect(_on_pause_restart)
			2: b.pressed.connect(_on_pause_leave)
		panel.add_child(b)
		_pause_buttons.append(b)

	get_tree().paused = true
	_pause_refresh_selection()
	paused_opened.emit()

func _close_pause_menu() -> void:
	if _pause_layer != null and is_instance_valid(_pause_layer):
		_pause_layer.queue_free()
	_pause_layer = null
	_pause_buttons.clear()
	get_tree().paused = false

func _pause_refresh_selection() -> void:
	_refresh_button_selection(_pause_buttons, _pause_btn_idx)

func _on_pause_resume() -> void:
	_close_pause_menu()
	paused_closed.emit()

func _on_pause_restart() -> void:
	_close_pause_menu()
	paused_closed.emit()
	restart()

## 離開：中途放棄，不套用獎勵（不是 result 面板的「離開」，那個才會 finish 套獎勵）。
## 直接返回地圖／原場景，並清乾淨 SceneRouter 的 _minigame_context，避免污染下一局。
func _on_pause_leave() -> void:
	_close_pause_menu()
	paused_closed.emit()
	if get_node_or_null("/root/SceneRouter") != null:
		var ctx: Dictionary = SceneRouter._minigame_context
		var return_scene := String(ctx.get("return_scene", ""))
		SceneRouter._minigame_context = {}
		SceneRouter._active_minigame = ""
		if return_scene != "" and ResourceLoader.exists(return_scene):
			SceneRouter.go_to_scene(return_scene)
		else:
			SceneRouter.go_to_map()
	else:
		# 測試情境下沒有 SceneRouter autoload：發訊號讓測試接住，不套用獎勵。
		minigame_finished.emit({})
