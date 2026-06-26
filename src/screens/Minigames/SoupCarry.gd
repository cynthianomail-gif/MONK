extends "res://src/screens/Minigames/MinigameBase.gd"
## 端湯改版：2D 俯視限時送味增湯。WASD 八向移動；晃動由玩家加速/急停/急轉驅動
## (deadzone 平穩走安全)；拿碗→送目標桌→結算→回吧台拿下一碗；75s 總結算。
## 純邏輯(step_slosh/settle_payout/reset_bowl/build_result)抽出可測。

# ── 可調常數(playtest 再調) ──
const GAME_TIME := 75.0
const MAX_SPEED := 320.0
const ACCEL := 1700.0
const STEADY_SPEED_MULT := 0.45
const STEADY_SLOSH_MULT := 0.30
const WET_SLOSH_MULT := 1.8
const SLOSH_DEADZONE := 600.0
const SLOSH_FACTOR := 0.020
const SLOSH_DAMP := 3.2
const SLOSH_MAX := 30.0
const SPILL_THRESHOLD := 12.0
const SPILL_RATE := 7.0
const BUMP_IMPULSE := 9.0
const COLLISION_PENALTY := 10

# ── 佈局(1920x1080 空間，對齊地圖、playtest 微調) ──
const MAP_PATH := "res://assets/art_direction/new_ink_shrine_style/minigames/minigame_sushi_shop_topdown_map_concept.png"
const PLAYER_TEX := "res://assets/art_direction/new_ink_shrine_style/minigames/minigame_wujie_topdown_carry_soup_game_ready.png"
const PICKUP_POS := Vector2(280, 250)
const TABLES: Array[Vector2] = [Vector2(720,420),Vector2(1180,380),Vector2(1520,640),Vector2(900,760),Vector2(1360,900),Vector2(560,830)]
const OBSTACLES: Array[Dictionary] = [{"pos": Vector2(980,540), "size": Vector2(220,90)}]
const WET_ZONES: Array[Vector2] = [Vector2(820,600)]
const WET_R := 110.0
const TABLE_R := 72.0
const PICKUP_R := 80.0
const PLAYER_R := 34.0

# ── 每碗狀態(純邏輯) ──
var soup_amount := 100.0
var soup_slosh := 0.0
var soup_velocity := 0.0
var collision_penalty := 0
# ── 全局結算 ──
var income := 0
var delivered_count := 0
var failed_count := 0
var total_spill := 0.0
var total_collision := 0
var total_bonus := 0
var low_streak := 0

# ── 場景/流程 ──
var _player: Sprite2D
var _vel := Vector2.ZERO
var _accel_mag := 0.0
var _running := false
var _time_left := GAME_TIME
var _target_idx := -1
var _carrying := true
var _bump_cd := 0.0
var _summary_up := false
var _hud: Control
var _target_ring: Node2D
var _toast: Label

func minigame_id() -> String:
	return "soup_carry"

# ════ 純邏輯(可測) ════

## 推進晃動一幀。accel_mag=玩家本幀加速度大小；wet=在濕滑區；steady=按緩步鍵。
func step_slosh(delta: float, accel_mag: float, wet: bool, steady: bool) -> void:
	var factor := SLOSH_FACTOR * (WET_SLOSH_MULT if wet else 1.0) * (STEADY_SLOSH_MULT if steady else 1.0)
	if accel_mag > SLOSH_DEADZONE:
		soup_velocity += (accel_mag - SLOSH_DEADZONE) * factor * delta
	soup_velocity *= exp(-SLOSH_DAMP * delta)
	soup_slosh += soup_velocity
	soup_slosh = clampf(soup_slosh, -SLOSH_MAX, SLOSH_MAX)
	if absf(soup_slosh) > SPILL_THRESHOLD:
		var spill := (absf(soup_slosh) - SPILL_THRESHOLD) * SPILL_RATE * delta
		soup_amount = maxf(soup_amount - spill, 0.0)

## 撞到桌/障礙/牆：晃一下 + 扣款。
func bump() -> void:
	soup_velocity += BUMP_IMPULSE * (1.0 if soup_velocity >= 0.0 else -1.0)
	collision_penalty += COLLISION_PENALTY

## 送達結算當前碗，回傳 payout(int) 並累計。
func settle_payout() -> int:
	var spill_percent := 100.0 - soup_amount
	var base := 100.0
	var penalty := spill_percent
	var payout: float
	if spill_percent >= 70.0:
		payout = 0.0
		failed_count += 1
	elif spill_percent >= 40.0:
		payout = base * 0.5 - penalty
	else:
		payout = base - penalty
	var bonus := 0
	if spill_percent <= 5.0:
		bonus += 20
	if spill_percent < 10.0:
		low_streak += 1
		if low_streak % 3 == 0:
			bonus += 50
	else:
		low_streak = 0
	payout += bonus
	payout = maxf(payout - float(collision_penalty), 0.0)
	delivered_count += 1
	income += int(payout)
	total_spill += spill_percent
	total_collision += collision_penalty
	total_bonus += bonus
	return int(payout)

func reset_bowl() -> void:
	soup_amount = 100.0
	soup_slosh = 0.0
	soup_velocity = 0.0
	collision_penalty = 0

func rating_text() -> String:
	if income >= 700: return "神之端湯"
	elif income >= 500: return "穩如老僧"
	elif income >= 300: return "勉強上工"
	return "湯比業障還重"

func build_result() -> Dictionary:
	return make_result({"score": income, "win": income >= 300, "gold": income, "merit": 0})

# ════ 流程 ════

func _ready() -> void:
	_build_scene()
	_build_hud()
	_start_game()

func _start_game() -> void:
	_running = true
	_time_left = GAME_TIME
	reset_bowl()
	_carrying = true
	_assign_target()

func _assign_target() -> void:
	_target_idx = randi() % TABLES.size()

func _process(delta: float) -> void:
	if not _running:
		return
	_bump_cd = maxf(_bump_cd - delta, 0.0)
	_time_left -= delta
	if _time_left <= 0.0:
		_end_game()
		return
	_move_player(delta)
	if _carrying:
		if _target_idx >= 0 and _player.position.distance_to(TABLES[_target_idx]) < TABLE_R:
			var pay := settle_payout()
			AudioManager.play_sfx("gold_collect" if pay > 0 else "wooden_fish_tap")
			_flash_toast("+%d" % pay if pay > 0 else "作廢")
			_carrying = false
	else:
		if _player.position.distance_to(PICKUP_POS) < PICKUP_R:
			reset_bowl()
			_carrying = true
			_assign_target()
	_update_hud()

func _move_player(delta: float) -> void:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var steady := Input.is_key_pressed(KEY_SHIFT)
	var top := MAX_SPEED * (STEADY_SPEED_MULT if steady else 1.0)
	var prev := _vel
	_vel = _vel.move_toward(dir * top, ACCEL * delta)
	_accel_mag = (_vel - prev).length() / maxf(delta, 0.0001)
	var nxt := _player.position + _vel * delta
	var hit := false
	if nxt.x < PLAYER_R or nxt.x > 1920.0 - PLAYER_R or nxt.y < PLAYER_R or nxt.y > 1080.0 - PLAYER_R:
		hit = true
	for o in OBSTACLES:
		var pad: Vector2 = o.size * 0.5 + Vector2(PLAYER_R, PLAYER_R)
		if Rect2(o.pos - pad, pad * 2.0).has_point(nxt):
			hit = true
			break
	if hit:
		if _bump_cd <= 0.0 and _carrying:
			bump()
			_bump_cd = 0.3
		_vel *= -0.25
	else:
		_player.position = nxt
	if absf(_vel.x) > 5.0:
		_player.flip_h = _vel.x < 0.0
	# 只有端著碗才會晃
	if _carrying:
		var wet := false
		for w in WET_ZONES:
			if _player.position.distance_to(w) < WET_R:
				wet = true
				break
		step_slosh(delta, _accel_mag, wet, steady)
		if _player.has_node("Bowl"):
			(_player.get_node("Bowl") as Node2D).rotation = deg_to_rad(soup_slosh)

func _end_game() -> void:
	_running = false
	_show_summary()

# ════ 視覺 ════

func _build_scene() -> void:
	var bg := Sprite2D.new()
	bg.centered = false
	if ResourceLoader.exists(MAP_PATH):
		bg.texture = load(MAP_PATH)
		var sz: Vector2 = bg.texture.get_size()
		bg.scale = Vector2(1920.0 / sz.x, 1080.0 / sz.y)
	else:
		var cr := ColorRect.new(); cr.size = Vector2(1920, 1080); cr.color = Color(0.12, 0.11, 0.10); add_child(cr)
	add_child(bg)
	add_child(_ring(PICKUP_POS, PICKUP_R, Color(0.4, 0.8, 0.5, 0.22)))   # 出餐口
	for t in TABLES:
		add_child(_ring(t, TABLE_R, Color(0.8, 0.7, 0.4, 0.18)))
	for w in WET_ZONES:
		add_child(_ring(w, WET_R, Color(0.4, 0.6, 0.9, 0.16)))
	_target_ring = _ring(Vector2.ZERO, TABLE_R, Color(1.0, 0.84, 0.0, 0.5))
	_target_ring.visible = false
	add_child(_target_ring)
	_player = Sprite2D.new()
	if ResourceLoader.exists(PLAYER_TEX):
		_player.texture = load(PLAYER_TEX)
		var ps: Vector2 = _player.texture.get_size()
		_player.scale = Vector2(150.0 / ps.x, 150.0 / ps.x)
	_player.position = PICKUP_POS
	add_child(_player)
	var mk := _ring(Vector2.ZERO, 50.0, Color(1.0, 0.92, 0.55, 0.42))  # 玩家底部柔光「你在這」
	mk.z_index = -1
	_player.add_child(mk)

func _ring(c: Vector2, r: float, col: Color) -> Node2D:
	var n := Node2D.new()
	n.position = c
	var pts := PackedVector2Array()
	for i in 20:
		pts.append(Vector2(r, 0).rotated(TAU * i / 20.0))
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = col
	n.add_child(p)
	return n

var _hud_time: Label
var _hud_income: Label
var _hud_state: Label
var _hud_streak: Label
var _meter_fill: ColorRect

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hud)
	_hud_time = _label(Vector2(48, 32), 48, Color(0.96, 0.96, 0.94))
	_hud_income = _label(Vector2(48, 96), 40, Color(1.0, 0.84, 0.0))
	_hud_state = _label(Vector2(48, 150), 28, Color(0.85, 0.85, 0.8))
	_hud_streak = _label(Vector2(48, 192), 26, Color(0.9, 0.6, 0.4))
	# 晃動 meter
	var mbg := ColorRect.new()
	mbg.position = Vector2(1500, 40); mbg.size = Vector2(340, 36)
	mbg.color = Color(0, 0, 0, 0.5)
	_hud.add_child(mbg)
	_meter_fill = ColorRect.new()
	_meter_fill.position = Vector2(1504, 44); _meter_fill.size = Vector2(0, 28)
	_hud.add_child(_meter_fill)
	var mlabel := _label(Vector2(1500, 84), 22, Color(0.8, 0.8, 0.78))
	mlabel.text = "湯晃動"

func _label(pos: Vector2, size: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.07, 0.05, 0.03))
	l.add_theme_constant_override("outline_size", 5)
	_hud.add_child(l)
	return l

func _update_hud() -> void:
	_hud_time.text = "⏱ %d" % ceili(_time_left)
	_hud_income.text = "收入 %d" % income
	if _carrying:
		_hud_state.text = "送往第 %d 桌　湯量 %d%%" % [_target_idx + 1, int(soup_amount)]
		_target_ring.visible = true
		_target_ring.position = TABLES[_target_idx]
		_target_ring.modulate.a = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.006)
	else:
		_hud_state.text = "回吧台拿下一碗"
		_target_ring.visible = false
	_hud_streak.text = ("連續完美 ×%d" % low_streak) if low_streak > 0 else ""
	# meter
	var frac := clampf(absf(soup_slosh) / SLOSH_MAX, 0.0, 1.0)
	_meter_fill.size.x = 332.0 * frac
	_meter_fill.color = Color(0.4, 0.85, 0.4) if frac < 0.5 else (Color(0.95, 0.8, 0.3) if frac < 0.8 else Color(0.95, 0.35, 0.3))

func _flash_toast(text: String) -> void:
	if _toast == null:
		_toast = _label(Vector2(900, 500), 56, Color(1.0, 0.9, 0.3))
		_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.text = text
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 0.0, 0.9)

func _show_summary() -> void:
	_summary_up = true
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.04, 0.03, 0.82)
	layer.add_child(dim)
	var avg_spill := total_spill / float(maxi(delivered_count, 1))
	var lines := [
		"── 結算 ──",
		"送達 %d 碗　作廢 %d 碗" % [delivered_count - failed_count, failed_count],
		"平均灑出 %d%%" % int(avg_spill),
		"碰撞扣款 %d" % total_collision,
		"bonus +%d" % total_bonus,
		"",
		"淨收入 %d" % income,
		rating_text(),
		"",
		"（任意鍵繼續）",
	]
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.position = Vector2(760, 320)
	vb.add_theme_constant_override("separation", 14)
	layer.add_child(vb)
	for i in lines.size():
		var l := Label.new()
		l.text = lines[i]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 60 if i == 6 else (44 if i == 7 else 32))
		l.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0) if i == 6 or i == 7 else Color(0.92, 0.92, 0.88))
		vb.add_child(l)
	AudioManager.play_sfx("merit_chime")
	get_tree().create_timer(3.5).timeout.connect(func(): finish(build_result()))

func _input(event: InputEvent) -> void:
	if _summary_up and (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		finish(build_result())
