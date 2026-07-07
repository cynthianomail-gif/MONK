extends "res://src/screens/Minigames/MinigameBase.gd"
## 端湯改版 P3：第一人稱 3D 平衡。WASD 移動、滑鼠左右修正托盤平衡(湯有慣性反向盪)、
## Shift 穩步；出餐口取碗→頭頂金箭頭指目標桌→走到桌邊按 E 上菜→settle_payout 計費→
## 下一碗；75s 總結算，看送幾桌。
## 純邏輯(step_slosh/settle_payout/reset_bowl/build_result/rating_text)全部沿用不改
## 斷言，input 源從 2D 加速度換成 3D 移動加速度+滑鼠修正量。麵館內景照
## UndergroundParlor 的程式化幾何+stylized 材質做法（無 toon/描邊）。

# ── 可調常數(playtest 再調) ──
## ⚠純邏輯常數(SLOSH_*/SPILL_*/BUMP_IMPULSE/COLLISION_PENALTY)與 TestSoupCarry.gd
## 的斷言直接掛鉤(該檔以 2D 時期的像素級 accel_mag 數值(300~4500)寫死期望值)，
## 一律沿用 2D 版原值不改；3D 版改變的只有「餵給 step_slosh 的 accel_mag 怎麼算」
## （見 _move_player 內 move_contrib/mouse_contrib 的換算），數值域刻意换算回
## 同一個像素級量級，讓純邏輯測試不必知道呼叫端是 2D 加速度還是 3D 移動+滑鼠修正。
const GAME_TIME := 75.0
const MAX_SPEED := 3.6             # 3D 世界移動速度(m/s)，與 slosh 常數域無關
const ACCEL := 18.0                # 3D 世界加速度(m/s^2)
const STEADY_SPEED_MULT := 0.45
const STEADY_SLOSH_MULT := 0.30
const WET_SLOSH_MULT := 1.8        # 沿用 2D 值，供 step_slosh 呼叫；3D 版目前恆 wet=false
const SLOSH_DEADZONE := 600.0
const SLOSH_FACTOR := 0.020
const SLOSH_DAMP := 3.2
const SLOSH_MAX := 30.0
const SPILL_THRESHOLD := 12.0
const SPILL_RATE := 7.0
const BUMP_IMPULSE := 9.0
const COLLISION_PENALTY := 10
const MOVE_ACCEL_TO_SLOSH := 190.0 # 3D 加速度(m/s^2)→像素級 accel_mag 換算倍率
const MOUSE_SENS := 0.12           # 滑鼠 x 位移 → 托盤修正量(deg/px)
const MOUSE_TO_SLOSH := 22.0       # 滑鼠位移(px/frame)→像素級 accel_mag 換算倍率
const TILT_RETURN := 2.4           # 修正量鬆手回中速率
const TILT_MAX := 26.0
const E_INTERACT_R := 1.8
# ── FPS 滑鼠視角(P3b 追加) ──
## 滑鼠移動同時做兩件事：X 軸貢獻托盤修正(沿用上面 MOUSE_SENS/MOUSE_TO_SLOSH 那條路)，
## 也拿去轉玩家 yaw(左右環顧)；Y 軸只轉相機 pitch(上下看)，不影響任何純邏輯數值。
const LOOK_YAW_SENS := 0.0028      # 滑鼠 x 位移(px) → yaw 弧度
const LOOK_PITCH_SENS := 0.0022    # 滑鼠 y 位移(px) → pitch 弧度
const PITCH_MAX_DEG := 40.0

# ── 佈局(3D 世界座標，房中心=原點，米制單位)：壽司店 ──
## 版型參考美術概念圖(minigame_sushi_shop_background_concept.png＋_topdown_map_concept.png)：
## 北側(z<0)檜木壽司吧台(展示櫃+師傅在吧台後、面向客人、吧台前 4 張高腳凳)，
## 出餐口就設在吧台展示櫃的一端(廚房窗口，同一道吧台)；南側(z>0)為入口(左右門柱燈+
## 紅暖簾)；客席 5 桌散佈於吧台前方地板，2-2-1 排列同俯視圖。
const HALF_W := 6.5    # 寬 13m
const HALF_D := 8.5    # 深 17m
const WALL_H := 4.2
const COUNTER_Z := -HALF_D + 1.7                       # 壽司吧台中線 z(北牆內側)
const CHEF_POS := Vector3(0.0, 0.0, COUNTER_Z - 0.85)  # 師傅站位(吧台後，面向南)
const PICKUP_POS := Vector3(4.6, 0.0, COUNTER_Z + 1.0) # 出餐口＝吧台東端(廚房窗口)
const COUNTER_SEATS: Array[Vector3] = [
	Vector3(-3.9, 0.0, COUNTER_Z + 1.0), Vector3(-1.9, 0.0, COUNTER_Z + 1.0),
	Vector3(0.1, 0.0, COUNTER_Z + 1.0), Vector3(2.3, 0.0, COUNTER_Z + 1.0),
]
const TABLES: Array[Vector3] = [
	Vector3(-3.6, 0.0, -1.6), Vector3(3.6, 0.0, -1.6),
	Vector3(-3.6, 0.0, 2.4), Vector3(3.6, 0.0, 2.4),
	Vector3(0.0, 0.0, 4.6),
	Vector3(-1.6, 0.0, 0.4), Vector3(1.6, 0.0, 0.4),
]
## 客人：吧台座 4 位＋桌邊 3 位，皆為固定不動的 procedural primitive people
## (膠囊身+球頭+色差衣著，非圖片/GLB)，坐著等餐、idle 呼吸+點頭動畫。
const CUSTOMER_SEATS: Array[Vector3] = [
	Vector3(-3.9, 0.0, COUNTER_Z + 1.0), Vector3(-1.9, 0.0, COUNTER_Z + 1.0),
	Vector3(0.1, 0.0, COUNTER_Z + 1.0), Vector3(2.3, 0.0, COUNTER_Z + 1.0),
	Vector3(-3.6, 0.0, -1.6 + 0.85), Vector3(3.6, 0.0, 2.4 + 0.85), Vector3(0.0, 0.0, 4.6 + 0.85),
]
const NPC_SPEED := 1.1
const NPC_R := 0.7
const PLAYER_R := 0.4

# ── 每碗狀態(純邏輯，不動) ──
var soup_amount := 100.0
var soup_slosh := 0.0
var soup_velocity := 0.0
var collision_penalty := 0
# ── 全局結算(純邏輯，不動) ──
var income := 0
var delivered_count := 0
var failed_count := 0
var total_spill := 0.0
var total_collision := 0
var total_bonus := 0
var low_streak := 0

# ── 場景/流程(3D) ──
## MinigameBase 是 Node2D（其餘 8 個 2D 小遊戲共用 shake()/hit_stop() 等依賴
## Node2D.position，不能改動基底類別）。本遊戲的 3D 內容全掛在 _world 這個
## Node3D 子節點下——Godot 允許 2D 節點掛 3D 子樹，3D 內容照樣經 Camera3D
## 正常渲染進同一個 Viewport，2D 根節點只負責掛 script/繼承鏈。
@export var auto_start: bool = true   # 冒煙測試設 false，只建場景不跑計時迴圈

var _world: Node3D
var _player: Node3D
var _cam: Camera3D
var _tray: Node3D
var _bowl: Node3D
var _vel3 := Vector3.ZERO
var _accel_mag := 0.0
var _running := false
var _time_left := GAME_TIME
var _target_idx := -1
var _carrying := true
var _bump_cd := 0.0
var _tilt := 0.0          # 滑鼠修正的托盤傾斜量(deg)，也是 step_slosh 的視覺回饋
var _mouse_dx := 0.0
var _mouse_look_dx := 0.0   # 本幀滑鼠 x 位移，累積給 _move_player 轉 yaw(與 _mouse_dx 分開累積，互不影響換算)
var _mouse_look_dy := 0.0   # 本幀滑鼠 y 位移，累積給 pitch
var _pitch := 0.0           # 相機俯仰角(rad)，clamp ±PITCH_MAX_DEG
var _npcs: Array = []       # 舊名沿用(測試已知欄位)：現裝的是「固定坐姿顧客」，不再走動
var _chef: Node3D
var _chef_t := 0.0
var _hud: Control
var _target_arrow: Sprite3D
var _toast: Label
var _prompt: Label
var _near_pickup := false
var _near_table := false

func minigame_id() -> String:
	return "soup_carry"

# ════ 純邏輯(可測，簽名/行為不變) ════

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

## 撞到桌/障礙/牆/NPC：晃一下 + 扣款。（純邏輯，測試以此為準，不碰場景樹）
func bump() -> void:
	soup_velocity += BUMP_IMPULSE * (1.0 if soup_velocity >= 0.0 else -1.0)
	collision_penalty += COLLISION_PENALTY

## 覆寫 MinigameBase.shake()：基底搖的是 Node2D.position，不會傳導到掛在 Node3D
## 子樹下的相機；本場景改搖 Camera3D 的局部位置，讓「畫面震動」契約在 3D 下真的有效。
func shake(strength: float = 12.0, dur: float = 0.25) -> void:
	if _cam == null or not is_instance_valid(_cam):
		return
	var base := Vector3(0, 1.55, 0)   # 與 _build 時的相機基準位置一致
	var amp := strength * 0.0025       # 12px → 約 0.03m 的視覺晃動
	var steps := maxi(int(dur / 0.04), 2)
	var tw := create_tween()
	for i in steps:
		var falloff := 1.0 - float(i) / float(steps)
		var off := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * amp * falloff
		tw.tween_property(_cam, "position", base + off, 0.04)
	tw.tween_property(_cam, "position", base, 0.04)

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
	_world = Node3D.new()
	_world.name = "World3D"
	add_child(_world)
	_build_env()
	_build_room()
	_build_tables()
	_build_pickup()
	_build_npcs()
	_build_player()
	_build_hud()
	_register_interact_action()
	paused_opened.connect(_on_paused_opened)
	paused_closed.connect(_on_paused_closed)
	if auto_start:
		_start_game()

func _register_interact_action() -> void:
	if InputMap.has_action("interact"):
		return
	InputMap.add_action("interact")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	InputMap.action_add_event("interact", ev)

func _start_game() -> void:
	_running = true
	_time_left = GAME_TIME
	reset_bowl()
	_carrying = true
	_assign_target()
	if is_inside_tree():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _assign_target() -> void:
	_target_idx = randi() % TABLES.size()

func _process(delta: float) -> void:
	if not _running:
		_update_hud()
		return
	_bump_cd = maxf(_bump_cd - delta, 0.0)
	_time_left -= delta
	if _time_left <= 0.0:
		_end_game()
		return
	_update_look()
	_move_player(delta)
	_update_customers(delta)
	_update_chef(delta)
	_update_tilt(delta)
	_check_proximity()
	_update_hud()

## 覆寫基底：SoupCarry 是唯一的 FPS 滑鼠捕捉小遊戲。呼叫 super 走 MinigameBase
## 共用的暫停頁/結算面板輸入邏輯（cancel 開暫停頁等），游標捕捉/釋放則交給
## _on_paused_opened/_on_paused_closed（見 _ready 內的訊號連接），不在這裡處理，
## 避免暫停面板開著時滑鼠移動事件還被下面的邏輯拿去轉視角。
func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if is_result_panel_open() or is_paused_menu_open():
		return
	if event is InputEventMouseMotion and _running:
		_mouse_dx += event.relative.x
		_mouse_look_dx += event.relative.x
		_mouse_look_dy += event.relative.y
	if event.is_action_pressed("interact") and _running:
		_try_interact()

## 暫停開啟：釋放滑鼠捕捉，讓玩家能點暫停頁的按鈕（否則 MOUSE_MODE_CAPTURED
## 下滑鼠游標是隱藏鎖定的，點不到 UI）。
func _on_paused_opened() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## 暫停關閉（繼續／再試一次）：遊戲仍在跑就重新捕捉滑鼠，恢復 FPS 視角操作。
## 「離開」也會先發這個訊號，但緊接著換場，捕捉與否不影響下一個場景。
func _on_paused_closed() -> void:
	if _running and is_inside_tree():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## FPS 視角：滑鼠 X 轉玩家 yaw(左右環顧，移動方向跟著轉)，Y 轉相機 pitch(上下看，clamp)。
## 與 _mouse_dx(托盤修正/晃動輸入)分開的獨立累積量，兩者互不干擾、互不改變對方的換算。
func _update_look() -> void:
	if _player == null:
		return
	_player.rotation.y -= _mouse_look_dx * LOOK_YAW_SENS
	_pitch = clampf(_pitch - _mouse_look_dy * LOOK_PITCH_SENS, deg_to_rad(-PITCH_MAX_DEG), deg_to_rad(PITCH_MAX_DEG))
	if _cam != null:
		_cam.rotation.x = _pitch
	_mouse_look_dx = 0.0
	_mouse_look_dy = 0.0

func _try_interact() -> void:
	if _carrying and _near_table:
		var pay := settle_payout()
		AudioManager.play_sfx("gold_collect" if pay > 0 else "wooden_fish_tap")
		_flash_toast("+%d" % pay if pay > 0 else "作廢")
		_carrying = false
	elif not _carrying and _near_pickup:
		reset_bowl()
		_carrying = true
		_assign_target()
		AudioManager.play_sfx("wooden_fish_tap")

func _check_proximity() -> void:
	_near_pickup = _player.position.distance_to(PICKUP_POS) < E_INTERACT_R
	_near_table = _carrying and _target_idx >= 0 and _player.position.distance_to(TABLES[_target_idx]) < E_INTERACT_R

func _move_player(delta: float) -> void:
	var dir3 := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): dir3.z -= 1.0
	if Input.is_key_pressed(KEY_S): dir3.z += 1.0
	if Input.is_key_pressed(KEY_A): dir3.x -= 1.0
	if Input.is_key_pressed(KEY_D): dir3.x += 1.0
	dir3 = dir3.normalized()
	# 依相機朝向轉成世界方向(僅水平面)
	var yaw := _player.rotation.y
	var world_dir := Vector3(
		dir3.x * cos(yaw) + dir3.z * sin(yaw),
		0.0,
		dir3.z * cos(yaw) - dir3.x * sin(yaw)
	)
	var steady := Input.is_key_pressed(KEY_SHIFT)
	var top := MAX_SPEED * (STEADY_SPEED_MULT if steady else 1.0)
	var prev := _vel3
	_vel3 = _vel3.move_toward(world_dir * top, ACCEL * delta)
	_accel_mag = (_vel3 - prev).length() / maxf(delta, 0.0001)
	var nxt := _player.position + _vel3 * delta
	var hit := false
	if nxt.x < -HALF_W + PLAYER_R or nxt.x > HALF_W - PLAYER_R or nxt.z < -HALF_D + PLAYER_R or nxt.z > HALF_D - PLAYER_R:
		hit = true
	for t in TABLES:
		if Vector2(nxt.x, nxt.z).distance_to(Vector2(t.x, t.z)) < 0.9 + PLAYER_R:
			hit = true
			break
	# 吧台(長條檯面)當一道牆：z 落在吧台縱深內、且在吧台寬度範圍內就擋下。
	if nxt.z < COUNTER_Z + 0.75 and nxt.z > COUNTER_Z - 0.75 and absf(nxt.x) < HALF_W - 0.6:
		hit = true
	if hit:
		if _bump_cd <= 0.0 and _carrying:
			bump()
			shake(10.0, 0.2)
			_bump_cd = 0.3
			_flash_toast("晃到了！")
		_vel3 *= -0.2
	else:
		_player.position = nxt
	# 只有端著碗才會晃：3D 移動加速度 + 滑鼠修正量，換算回 2D 版同量級的 accel_mag
	# 餵給沿用不改的 step_slosh()（純邏輯測試以此量級的數字寫死期望值）。
	if _carrying:
		var mouse_contrib := absf(_mouse_dx) * MOUSE_TO_SLOSH
		var move_contrib := _accel_mag * MOVE_ACCEL_TO_SLOSH
		step_slosh(delta, move_contrib + mouse_contrib, false, steady)
		if _bowl != null:
			_bowl.rotation.z = deg_to_rad(clampf(soup_slosh, -SLOSH_MAX, SLOSH_MAX) * 0.6)
	_mouse_dx = 0.0

## 托盤傾斜：滑鼠左右修正量，鬆手回中；純視覺+回饋 step_slosh 的輸入源之一。
func _update_tilt(delta: float) -> void:
	_tilt += _mouse_dx * MOUSE_SENS * -1.0
	_tilt = clampf(_tilt, -TILT_MAX, TILT_MAX)
	_tilt = move_toward(_tilt, 0.0, TILT_RETURN * TILT_MAX * delta)
	if _tray != null:
		_tray.rotation.z = deg_to_rad(_tilt)

## 客人是坐著等餐的靜態擺設(不走動，符合壽司店客滿感/美術參考圖)；
## 只做 idle 呼吸(身體 y 微起伏)+偶爾點頭(頭 x 旋轉)，不佔碰撞判定(桌子本身已擋玩家)。
func _update_customers(delta: float) -> void:
	for n in _npcs:
		var d: Dictionary = n
		var fig: Node3D = d.node
		if fig == null or not is_instance_valid(fig):
			continue
		d.t += delta
		var body: Node3D = d.get("body")
		var head: Node3D = d.get("head")
		if body != null:
			body.position.y = d.base_y + sin(d.t * d.breathe_speed) * 0.02
		if head != null:
			head.rotation.x = sin(d.t * d.nod_speed + d.phase) * 0.05

## 師傅站在吧台後，持續輕微擺動手臂(捏壽司的重複動作)，不走動。
func _update_chef(delta: float) -> void:
	if _chef == null or not is_instance_valid(_chef):
		return
	_chef_t += delta
	var arm: Node3D = _chef.get_meta("arm", null)
	if arm != null:
		arm.rotation.x = -0.3 + sin(_chef_t * 2.2) * 0.22

func _end_game() -> void:
	_running = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_summary()

## 重開一局：歸零全局結算與計時，重新指派目標桌，玩家歸位出餐口。
func restart() -> void:
	income = 0
	delivered_count = 0
	failed_count = 0
	total_spill = 0.0
	total_collision = 0
	total_bonus = 0
	low_streak = 0
	_finished = false
	_vel3 = Vector3.ZERO
	_tilt = 0.0
	_pitch = 0.0
	_mouse_look_dx = 0.0
	_mouse_look_dy = 0.0
	if _player != null:
		_player.position = PICKUP_POS
		_player.rotation.y = PI
	if _cam != null:
		_cam.rotation.x = 0.0
	_start_game()

# ════ 視覺：3D 場景（壽司店，照美術概念圖 minigame_sushi_shop_background_concept.png／
# _topdown_map_concept.png 的配置與配色：檜木吧台+展示櫃在北牆、暖簾+門柱燈在南側入口、
# 5 桌散佈於吧台前方、暖色吊燈+紅色布幔點綴。幾何一律 primitive+stylized shader，無 toon/描邊）════

const PLASTER_SHADER := preload("res://assets/shaders/stylized/plaster.gdshader")
const WOOD_DARK := Color(0.22, 0.14, 0.09)     # 檜木深色(吧台/桌腳/樑柱)
const WOOD_WARM := Color(0.42, 0.27, 0.15)     # 檜木暖色(桌面/吧台面)
const VERMILION := Color(0.62, 0.14, 0.10)     # 暖簾/布幔朱紅
const PAPER_WARM := Color(0.88, 0.82, 0.68)    # 暖簾/招牌紙色
const LANTERN_GLOW := Color(1.0, 0.82, 0.45)   # 燈籠暖光

func _build_env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.03, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.35, 0.29)
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_hdr_threshold = 1.3
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.8
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)

func _build_room() -> void:
	# 地板：石板地(cobblestone shader)，比純木地板更貼近參考圖濕潤石磚質感
	var ground := MeshInstance3D.new()
	var gb := BoxMesh.new()
	gb.size = Vector3(HALF_W * 2, 0.2, HALF_D * 2)
	ground.mesh = gb
	ground.position = Vector3(0, -0.1, 0)
	ground.material_override = _cobble_mat(Color(0.30, 0.27, 0.24))
	_world.add_child(ground)
	# 四牆：暖木色，側牆掛卷軸布幔妝點
	var wall_col := Color(0.38, 0.26, 0.17)
	var specs: Array = [
		[Vector3(0, WALL_H * 0.5, -HALF_D), Vector3(HALF_W * 2, WALL_H, 0.3)],
		[Vector3(0, WALL_H * 0.5, HALF_D), Vector3(HALF_W * 2, WALL_H, 0.3)],
		[Vector3(-HALF_W, WALL_H * 0.5, 0), Vector3(0.3, WALL_H, HALF_D * 2)],
		[Vector3(HALF_W, WALL_H * 0.5, 0), Vector3(0.3, WALL_H, HALF_D * 2)],
	]
	for sp in specs:
		_box(sp[0], sp[1], wall_col)
	# 天花板 + 外露樑柱(檜木深色，強化和風木造感)
	_box(Vector3(0, WALL_H + 0.1, 0), Vector3(HALF_W * 2, 0.2, HALF_D * 2), Color(0.16, 0.11, 0.08))
	for bx in [-HALF_W + 1.5, -HALF_W * 0.5, 0.0, HALF_W * 0.5, HALF_W - 1.5]:
		_box(Vector3(bx, WALL_H - 0.05, 0), Vector3(0.22, 0.16, HALF_D * 2 - 0.4), WOOD_DARK)

	_build_counter()
	_build_entrance()
	_build_side_decor()

	# 燈光：吧台上方暖光重點打亮展示櫃；桌區補光刻意調弱＋縮小範圍(桌上已有小燈籠)，
	# 避免十幾盞燈籠疊加把整個木牆過曝成一片黃。
	_omni(Vector3(0, WALL_H - 0.3, COUNTER_Z + 0.8), LANTERN_GLOW, 1.8, 5.0)

## 檜木壽司吧台：長條檯面＋玻璃展示櫃(半透明藍白)＋吧台後書架(碗盤堆疊)＋
## 吊燈陣＋暖簾布條(垂掛招牌)，出餐口就是吧台東端的窗口。師傅站在吧台後。
func _build_counter() -> void:
	var counter_len := HALF_W * 2 - 1.2
	# 吧台檯面(暖木)+ 檯面下方裙板(深木)
	_box(Vector3(0, 0.9, COUNTER_Z), Vector3(counter_len, 0.08, 0.85), WOOD_WARM)
	_box(Vector3(0, 0.45, COUNTER_Z), Vector3(counter_len, 0.85, 0.7), WOOD_DARK)
	# 玻璃展示櫃(壽司陳列，半透明白藍)
	var glass := MeshInstance3D.new()
	var gbm := BoxMesh.new()
	gbm.size = Vector3(counter_len * 0.55, 0.35, 0.55)
	glass.mesh = gbm
	glass.position = Vector3(0.6, 1.15, COUNTER_Z)
	glass.material_override = _glass_mat()
	_world.add_child(glass)
	# 展示櫃內的壽司(小色塊代表握壽司，白飯+粉紅魚料)
	for i in 6:
		var sx := -1.1 + i * 0.42
		_box(Vector3(sx, 1.02, COUNTER_Z), Vector3(0.16, 0.09, 0.20), Color(0.92, 0.90, 0.85))
		_box(Vector3(sx, 1.07, COUNTER_Z), Vector3(0.15, 0.03, 0.18), Color(0.85, 0.42, 0.38))
	# 吧台後書架：碗盤堆疊(圓柱疊層代表碗)
	for sx in [-4.6, -3.4, 3.0, 4.4]:
		_box(Vector3(sx, 1.5, COUNTER_Z - 0.7), Vector3(0.9, 1.2, 0.3), Color(0.20, 0.13, 0.09))
		for i in 3:
			_cylinder(Vector3(sx - 0.25 + i * 0.25, 1.75, COUNTER_Z - 0.68), 0.10, 0.16, Color(0.80, 0.78, 0.72))
	# 吧台高腳凳
	for s in COUNTER_SEATS:
		_cylinder(s + Vector3(0, 0.42, 0.35), 0.05, 0.42, WOOD_DARK)
		_cylinder(s + Vector3(0, 0.64, 0.35), 0.20, 0.05, WOOD_WARM)
	# 暖簾布條(白底垂布，掛在吧台上方，仿參考圖布條招牌)
	for bx in range(-2, 3):
		var strip := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.5, 0.7, 0.02)
		strip.mesh = sm
		strip.position = Vector3(float(bx) * 1.1, 2.55, COUNTER_Z - 1.0)
		strip.material_override = _flat_mat(PAPER_WARM)
		_world.add_child(strip)
	# 吊燈陣(吧台正上方三盞，仿參考圖紙燈籠)
	for lx in [-1.6, 0.6, 2.8]:
		_hang_lantern(Vector3(lx, WALL_H - 0.2, COUNTER_Z + 0.6))
	# 出餐口招牌(掛在吧台東端上方，面向南方/玩家方向)
	_sign_text("出餐口", PICKUP_POS + Vector3(0, 1.9, -0.3), 0.0, Color(1.4, 1.1, 0.5))
	_omni(PICKUP_POS + Vector3(0, 1.6, -0.4), Color(1.0, 0.85, 0.55), 1.8, 5.0)
	# 師傅站位：矮台階墊高，讓師傅的身體從吧台上緣清楚露出(單靠身高會被吧台擋住大半)
	_box(CHEF_POS + Vector3(0, 0.2, 0), Vector3(1.2, 0.4, 0.6), WOOD_DARK)

## 入口：南牆雙門柱燈籠柱＋紅色暖簾，仿參考俯視圖鳥居式入口。
func _build_entrance() -> void:
	var gate_z := HALF_D - 0.3
	for gx in [-1.6, 1.6]:
		_box(Vector3(gx, 1.6, gate_z), Vector3(0.3, 3.2, 0.3), WOOD_DARK)
		_hang_lantern(Vector3(gx, 2.6, gate_z - 0.35))
	# 暖簾(紅布，兩片中間留縫仿真實暖簾)
	for side in [-1, 1]:
		var noren := MeshInstance3D.new()
		var nm := BoxMesh.new()
		nm.size = Vector3(1.3, 1.3, 0.03)
		noren.mesh = nm
		noren.position = Vector3(float(side) * 0.85, 2.0, gate_z - 0.05)
		noren.material_override = _flat_mat(VERMILION)
		_world.add_child(noren)
	# 石燈籠(入口外側裝飾，圓柱疊層)
	for sx in [-2.8, 2.8]:
		_cylinder(Vector3(sx, 0.3, gate_z + 0.3), 0.18, 0.6, Color(0.35, 0.34, 0.32))
		_cylinder(Vector3(sx, 0.75, gate_z + 0.3), 0.22, 0.12, Color(0.30, 0.29, 0.27))
		_omni(Vector3(sx, 0.9, gate_z + 0.3), LANTERN_GLOW, 0.8, 2.4)

## 側牆裝飾：卷軸布幔＋酒瓶架＋花瓶(菜單板的替代，強化「豐富」感)。
## 布幔色刻意調暗一階(比 PAPER_WARM 暗)，避免掛在牆上被鄰近吊燈打到過曝成純色色塊。
func _build_side_decor() -> void:
	var scroll_col := Color(0.62, 0.56, 0.44)
	for wx in [-HALF_W + 0.2, HALF_W - 0.2]:
		for sz in [-4.0, -1.5, 1.0, 3.5]:
			_box(Vector3(wx, 2.3, sz), Vector3(0.05, 0.9, 0.42), scroll_col)
		_hang_lantern(Vector3(wx * 0.94, 2.4, -3.0))
		_hang_lantern(Vector3(wx * 0.94, 2.4, 2.0))
		# 酒瓶架(小圓柱陣列，代表清酒瓶)
		for i in 4:
			_cylinder(Vector3(wx * 0.9, 0.5, 5.0 + i * 0.35), 0.07, 0.42, Color(0.15, 0.32, 0.20))
	# 花瓶+枝條(角落裝飾)
	_cylinder(Vector3(HALF_W - 0.8, 0.35, -HALF_D + 1.0), 0.18, 0.5, Color(0.30, 0.42, 0.48))

## 紙燈籠(圓柱+暖光點光源)，各處懸掛裝飾共用。energy/range 刻意調小，
## 場景燈籠數量多(吧台+入口+側牆+每桌)，單燈太亮疊加會把牆面過曝成色塊。
func _hang_lantern(pos: Vector3) -> void:
	_cylinder(pos, 0.16, 0.32, Color(0.85, 0.72, 0.45))
	_omni(pos, LANTERN_GLOW, 0.7, 2.2)

func _build_tables() -> void:
	for t in TABLES:
		_cylinder(t + Vector3(0, 0.4, 0), 0.55, 0.06, WOOD_WARM)
		_cylinder(t + Vector3(0, 0.2, 0), 0.08, 0.4, WOOD_DARK)
		# 桌上小燈籠(仿參考圖每桌一盞小燭燈，範圍小、只亮自己這桌)
		_omni(t + Vector3(0, 0.55, 0), LANTERN_GLOW, 0.45, 1.3)
		for i in 2:
			var ang := TAU * float(i) / 2.0 + 0.6
			_cylinder(t + Vector3(cos(ang) * 0.8, 0.22, sin(ang) * 0.8), 0.18, 0.44, Color(0.30, 0.09, 0.08))

func _build_pickup() -> void:
	# 出餐口＝吧台東端窗口(吧台幾何已在 _build_counter 建好)，這裡只補廚房窗簾遮擋視覺
	_box(PICKUP_POS + Vector3(0, 1.3, -0.55), Vector3(1.4, 0.5, 0.08), Color(0.55, 0.10, 0.09))

## 顧客＋師傅：全部 procedural primitive people(膠囊身+球頭+色差衣著)，非圖片/GLB。
func _build_npcs() -> void:
	var palette := [
		Color(0.55, 0.20, 0.18), Color(0.22, 0.38, 0.42), Color(0.45, 0.40, 0.20),
		Color(0.30, 0.28, 0.50), Color(0.50, 0.32, 0.15), Color(0.25, 0.45, 0.30), Color(0.48, 0.24, 0.40),
	]
	for i in CUSTOMER_SEATS.size():
		var seat := CUSTOMER_SEATS[i]
		var face_yaw := 0.0 if seat.z < COUNTER_Z + 1.5 else PI  # 吧台客面向吧台(北)，桌客面向桌心(南)
		var fig := _make_person(seat + Vector3(0, 0.46, 0), palette[i % palette.size()], face_yaw, true)
		fig.name = "Customer%d" % i
		_npcs.append({
			"node": fig, "body": fig.get_node("Body"), "head": fig.get_node("Head"),
			"t": randf() * TAU, "phase": randf() * TAU,
			"breathe_speed": randf_range(1.1, 1.6), "nod_speed": randf_range(0.5, 0.9),
			"base_y": fig.get_node("Body").position.y,
		})
	_chef = _make_person(CHEF_POS + Vector3(0, 0.4, 0), Color(0.85, 0.85, 0.82), 0.0, false)
	_chef.name = "Chef"
	var chef_arm := _chef.get_node_or_null("ArmR")
	if chef_arm != null:
		_chef.set_meta("arm", chef_arm)

## 程式幾何人物：膠囊身體+球頭+兩隻手臂(圓柱)，色差衣著(身體色可自訂，頭統一膚色)。
## seated=true 時身高降低+身體縮短做出「坐姿」視覺(配合椅凳高度)，false 為站姿(師傅)。
func _make_person(pos: Vector3, cloth_col: Color, face_yaw: float, seated: bool) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = face_yaw
	_world.add_child(root)
	var body_h := 0.62 if seated else 1.15
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.20
	cap.height = body_h
	body.mesh = cap
	body.name = "BodyMesh"
	var body_holder := Node3D.new()
	body_holder.name = "Body"
	body_holder.position = Vector3(0, body_h * 0.5, 0)
	body_holder.add_child(body)
	body.material_override = _flat_mat(cloth_col)
	root.add_child(body_holder)
	var head := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.14
	sph.height = 0.28
	head.mesh = sph
	head.material_override = _flat_mat(Color(0.87, 0.72, 0.58))
	var head_holder := Node3D.new()
	head_holder.name = "Head"
	head_holder.position = Vector3(0, body_h + 0.12, 0)
	head_holder.add_child(head)
	root.add_child(head_holder)
	# 兩隻手臂(細圓柱)，師傅右手臂另存節點供 _update_chef 擺動
	for side in [-1, 1]:
		var arm := MeshInstance3D.new()
		var acyl := CylinderMesh.new()
		acyl.top_radius = 0.055
		acyl.bottom_radius = 0.045
		acyl.height = body_h * 0.85
		arm.mesh = acyl
		arm.material_override = _flat_mat(cloth_col.lightened(0.08))
		var arm_holder := Node3D.new()
		arm_holder.name = "ArmR" if side > 0 else "ArmL"
		arm_holder.position = Vector3(0.24 * side, body_h * 0.55, 0.05)
		arm_holder.rotation.x = -0.15
		arm_holder.add_child(arm)
		root.add_child(arm_holder)
	return root

func _build_player() -> void:
	_player = Node3D.new()
	_player.name = "Player"
	_player.position = PICKUP_POS
	_player.rotation.y = PI
	_player.add_to_group("player")
	_world.add_child(_player)
	_cam = Camera3D.new()
	_cam.position = Vector3(0, 1.55, 0)
	_cam.fov = 75.0
	_cam.near = 0.05
	_player.add_child(_cam)
	_cam.current = true
	# 手持托盤+湯碗（畫面下緣，掛在相機下方前方，FPS 手持物常見比例：小、貼近下緣、
	# 不擋視野中央）。托盤是平躺圓盤，貼著相機平視幾乎看成一條邊緣線，繞 X 軸微仰
	# (讓托盤面朝向鏡頭)才看得出「端著」的樣子；半徑/距離刻意調小避免頂到鏡頭。
	_tray = Node3D.new()
	_tray.position = Vector3(0.0, -0.62, -0.75)
	_tray.rotation.x = deg_to_rad(55.0)
	_cam.add_child(_tray)
	var tray_mesh := MeshInstance3D.new()
	var tcyl := CylinderMesh.new()
	tcyl.top_radius = 0.16
	tcyl.bottom_radius = 0.16
	tcyl.height = 0.012
	tray_mesh.mesh = tcyl
	tray_mesh.material_override = _metal_mat(Color(0.55, 0.55, 0.53))
	_tray.add_child(tray_mesh)
	_bowl = Node3D.new()
	_bowl.position = Vector3(0, 0.03, 0)
	_tray.add_child(_bowl)
	var bowl_mesh := MeshInstance3D.new()
	var bcyl := CylinderMesh.new()
	bcyl.top_radius = 0.085
	bcyl.bottom_radius = 0.06
	bcyl.height = 0.06
	bowl_mesh.mesh = bcyl
	bowl_mesh.material_override = _flat_mat(Color(0.85, 0.80, 0.70))
	_bowl.add_child(bowl_mesh)
	var soup_mesh := MeshInstance3D.new()
	var scyl := CylinderMesh.new()
	scyl.top_radius = 0.07
	scyl.bottom_radius = 0.07
	scyl.height = 0.01
	soup_mesh.mesh = scyl
	soup_mesh.position = Vector3(0, 0.028, 0)
	soup_mesh.material_override = _emissive_mat(Color(0.55, 0.32, 0.10), 0.3)
	_bowl.add_child(soup_mesh)
	# 目標箭頭（金色，飄在目標桌上方，跟隨頭朝向自動看向玩家）
	_target_arrow = Sprite3D.new()
	_target_arrow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_target_arrow.pixel_size = 0.01
	_target_arrow.modulate = Color(1.0, 0.85, 0.2)
	_target_arrow.texture = _make_arrow_texture()
	_world.add_child(_target_arrow)

func _make_arrow_texture() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(8, 40):
		var half := int((y - 8) * 0.5)
		for x in range(32 - half, 32 + half):
			img.set_pixel(x, y, Color(1, 0.85, 0.2, 1))
	for y in range(36, 56):
		for x in range(24, 40):
			img.set_pixel(x, y, Color(1, 0.85, 0.2, 1))
	return ImageTexture.create_from_image(img)

func _sign_text(text: String, pos: Vector3, yaw_deg: float, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = 0.006
	l.modulate = col
	l.outline_size = 8
	l.position = pos
	l.rotation_degrees.y = yaw_deg
	_world.add_child(l)

func _flat_mat(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PLASTER_SHADER
	m.set_shader_parameter("albedo", color)
	return m

const COBBLE_SHADER := preload("res://assets/shaders/stylized/cobblestone.gdshader")

func _cobble_mat(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = COBBLE_SHADER
	m.set_shader_parameter("albedo", color)
	return m

func _glass_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.85, 0.90, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic = 0.1
	m.roughness = 0.05
	return m

func _metal_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.4
	m.roughness = 0.55
	return m

func _emissive_mat(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m

func _box(pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _flat_mat(color)
	_world.add_child(mi)
	return mi

func _cylinder(pos: Vector3, radius: float, height: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.position = pos
	mi.material_override = _flat_mat(color)
	_world.add_child(mi)

func _omni(pos: Vector3, col: Color, energy: float, rng_: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng_
	_world.add_child(l)

## SceneRouter 存位慣例（本小遊戲無戰鬥，仍提供以防未來擴充）。
func get_player_position() -> Vector3:
	return _player.position if _player != null else Vector3.ZERO

# ════ HUD（CanvasLayer，2D UI 疊在 3D 畫面上）════

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
	_prompt = _label(Vector2(700, 900), 34, Color(1.0, 0.95, 0.8))
	_prompt.visible = false
	# 佈局工具 v2（P4）：HUD 文字塊登記（父節點 _hud 是 Control，非 Container，
	# is_free()==true）。時間/收入/狀態/提示各自可獨立定位；連段文字次要不重複標。
	LayoutStore.register(_hud_time, "minigame/soupcarry/hud_time")
	LayoutStore.register(_hud_income, "minigame/soupcarry/hud_income")
	LayoutStore.register(_hud_state, "minigame/soupcarry/hud_state")
	LayoutStore.register(_prompt, "minigame/soupcarry/prompt_label")
	# 平衡計(晃動 meter)：亮邊框墊底＋近不透明深底，避免疊在暖棕牆面上融掉。
	var mframe := ColorRect.new()
	mframe.position = Vector2(1496, 36); mframe.size = Vector2(348, 44)
	mframe.color = Color(0.95, 0.9, 0.75, 0.9)
	_hud.add_child(mframe)
	# 佈局工具 v2（P4）：平衡計整塊登記代表框（mbg/_meter_fill 疊在同位置，
	# 隨此框視覺同步，不重複登記）。父節點 _hud 是 Control，非 Container，
	# is_free()==true。
	LayoutStore.register(mframe, "minigame/soupcarry/balance_meter")
	var mbg := ColorRect.new()
	mbg.position = Vector2(1500, 40); mbg.size = Vector2(340, 36)
	mbg.color = Color(0.06, 0.05, 0.04, 0.92)
	_hud.add_child(mbg)
	_meter_fill = ColorRect.new()
	_meter_fill.position = Vector2(1504, 44); _meter_fill.size = Vector2(0, 28)
	_hud.add_child(_meter_fill)
	var mlabel := _label(Vector2(1500, 84), 22, Color(0.8, 0.8, 0.78))
	mlabel.text = "湯晃動(平衡計)"
	# 開場規則提示（照現有小遊戲慣例，短暫顯示後淡出）
	var rule := _label(Vector2(420, 460), 32, Color(1.0, 0.95, 0.85))
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule.custom_minimum_size = Vector2(1080, 0)
	rule.text = "WASD 移動／滑鼠修正托盤平衡／Shift 穩步\n出餐口取碗→送到金箭頭指的桌子→按 E 上菜\n75 秒內看你能送幾桌！"
	rule.position = Vector2(420, 420)
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(rule, "modulate:a", 0.0, 0.8)
	tw.tween_callback(rule.queue_free)

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
	if _carrying and _target_idx >= 0:
		_hud_state.text = "送往第 %d 桌　湯量 %d%%" % [_target_idx + 1, int(soup_amount)]
		if _target_arrow != null:
			_target_arrow.visible = true
			_target_arrow.position = TABLES[_target_idx] + Vector3(0, 1.6 + 0.15 * sin(Time.get_ticks_msec() * 0.004), 0)
	else:
		_hud_state.text = "回出餐口拿下一碗"
		if _target_arrow != null:
			_target_arrow.visible = false
	_hud_streak.text = ("連續完美 ×%d" % low_streak) if low_streak > 0 else ""
	if _prompt != null:
		if _carrying and _near_table:
			_prompt.text = "〔E〕上菜"
			_prompt.visible = true
		elif not _carrying and _near_pickup:
			_prompt.text = "〔E〕取碗"
			_prompt.visible = true
		else:
			_prompt.visible = false
	var frac := clampf(absf(soup_slosh) / SLOSH_MAX, 0.0, 1.0)
	_meter_fill.size.x = 332.0 * frac
	_meter_fill.color = Color(0.4, 0.85, 0.4) if frac < 0.5 else (Color(0.95, 0.8, 0.3) if frac < 0.8 else Color(0.95, 0.35, 0.3))

func _flash_toast(text: String) -> void:
	if _toast == null:
		_toast = _label(Vector2(660, 500), 56, Color(1.0, 0.9, 0.3))
		_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast.custom_minimum_size = Vector2(600, 0)
	_toast.text = text
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 0.0, 0.9)

func _show_summary() -> void:
	var avg_spill := total_spill / float(maxi(delivered_count, 1))
	var r := build_result()
	AudioManager.play_sfx("merit_chime")
	show_result_panel("端湯", rating_text(), [
		{"label": "送達", "value": "%d 碗" % (delivered_count - failed_count)},
		{"label": "作廢", "value": "%d 碗" % failed_count},
		{"label": "平均灑出", "value": "%d%%" % int(avg_spill)},
		{"label": "碰撞扣款", "value": "%d" % total_collision},
		{"label": "bonus", "value": "+%d" % total_bonus},
		{"label": "淨收入", "value": "%d" % income},
	], r)
