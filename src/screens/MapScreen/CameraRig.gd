extends Node3D
## FPS 式滑鼠自由視角＋spring-arm 防穿牆。
## 沿革：2026-07-02 原僅「右鍵按住拖曳」轉 yaw——實測「不能用」的根因是滑鼠游標
## 全程停在 MOUSE_MODE_VISIBLE（沒人設過 Input.mouse_mode），拖曳靈敏度雖然沒問題，
## 但體驗上更像「按著按鈕才勉強轉一點」，完全不是使用者期待的 FPS 直覺（滑鼠一動
## 就轉）。2026-07-05 改為：探索中滑鼠 MOUSE_MODE_CAPTURED、X 軸直轉 yaw、Y 軸轉
## pitch(clamp 防翻天)；任何 UI 開啟（手機選單/對話/商店/小遊戲/結算/傳送）自動
## 釋放滑鼠、關閉後恢復；Esc 手動切換。A/D 鍵轉視角與右鍵拖曳（備援輸入裝置時）皆保留。

@export var target_path: NodePath
@export var camera_offset: Vector3 = Vector3(0.0, 11.0, 9.0)
@export var camera_pitch_deg: float = -12.0
@export var follow_speed: float = 0.08

const KEY_ROT_SPEED := 2.2       # A/D 旋轉速度 (rad/s)
const MOUSE_ROT_SENS := 0.008    # 滑鼠 yaw 靈敏度 (rad/px)——捕捉模式與右鍵拖曳共用
const MOUSE_PITCH_SENS := 0.006  # 滑鼠 pitch 靈敏度 (rad/px)
const PITCH_MIN_DEG := -35.0     # pitch clamp：不讓相機翻到地板下
const PITCH_MAX_DEG := 15.0      # pitch clamp：不讓相機翻到天花板上
const YAW_SMOOTH := 0.14         # 旋轉平滑係數
const CAM_BLOCK_MASK := 2        # 建築 cam blocker 碰撞層（層2＝只擋相機不擋角色）
const CAM_MIN_FRAC := 0.30       # 相機最近可縮到 offset 的比例

@onready var camera: Camera3D = $Camera3D
var _target: Node3D = null
var _yaw: float = 0.0             # 目標 yaw；rotation.y 平滑追上
var _pitch_offset_deg: float = 0.0  # 疊加在 camera_pitch_deg 上的滑鼠 pitch（clamp 過）
var _mouse_look_enabled: bool = true   # Esc 手動開關
## 邏輯捕捉狀態（獨立於 Input.mouse_mode 讀回值）——headless 測試環境沒有真實
## 視窗，OS 層的 Input.mouse_mode 寫入會被靜默忽略、讀回恆為 VISIBLE，若拿它當
## 判斷依據，headless 測試永遠驗不到「捕捉時滑鼠移動即轉視角」這件事。改成自己
## 記錄「上一次要求的捕捉意圖」，GPU 真機與 headless 測試都能一致依此判斷。
var _captured: bool = false
## 視窗焦點狀態——headless 測試沒有焦點通知，預設 true 讓既有測試路徑不變。
## 失焦時它是 _mouse_look_active() 的一票否決：沒有它，_physics_process 每 tick 的
## _refresh_mouse_capture() 會在失焦後下一個 tick 就把游標搶回 CAPTURED，
## 「失焦釋放游標」形同虛設。
var _window_focused: bool = true

func _ready() -> void:
	camera.position = camera_offset
	camera.rotation_degrees.x = camera_pitch_deg
	# 不要累積滑鼠移動事件——累積模式下每個 physics tick 只送一個「合併」的
	# InputEventMouseMotion，若引擎/宿主（例如編輯器內嵌遊戲視窗）在合併時
	# 把位移歸零或漏送，FPS 視角就會「滑鼠一直動卻不轉」。關掉累積讓每筆
	# OS 位移各自成一個事件，捕捉模式下的自由視角最穩。
	Input.set_use_accumulated_input(false)
	_register_rotate_actions()
	_register_toggle_look_action()
	_acquire_target()
	_refresh_mouse_capture()

func _exit_tree() -> void:
	# 場景被 change_scene_to_file 整個換掉時，mouse_mode 是全域狀態，不隨場景樹釋放——
	# 沒有這行，切去戰鬥/小遊戲/過場後滑鼠會繼續卡在 captured。
	_set_mouse_captured(false)

## 視窗重新取得焦點時（Alt-Tab 回來、或編輯器內嵌遊戲視窗被點回來）重新套用
## 捕捉意圖——OS 在失焦時會自行把 mouse_mode 放回 VISIBLE，若不在回焦時補回
## CAPTURED，玩家切出去再切回來滑鼠視角就死掉。失焦時明確釋放，避免游標被鎖在
## 別的視窗上。
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_window_focused = true
		if is_inside_tree():
			_refresh_mouse_capture()
	elif what == NOTIFICATION_WM_MOUSE_ENTER:
		if is_inside_tree():
			_refresh_mouse_capture()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_window_focused = false
		_set_mouse_captured(false)

## 解析 target；成功時直接貼齊（避免相機從原點慢慢飄過去）。
## target_path 的 NodePath export 在某些載入時序會掉值，故以 "player" group 為備援。
func _acquire_target() -> void:
	_target = get_node_or_null(target_path)
	if _target == null:
		_target = get_tree().get_first_node_in_group("player")
	if _target:
		global_position = _target.global_position

func _physics_process(delta: float) -> void:
	# target 可能在 _ready 當下尚未就位（NodePath/spawn 時序），未取得就每幀補抓。
	if _target == null:
		_acquire_target()
		return
	global_position = global_position.lerp(_target.global_position, follow_speed)
	_yaw += (Input.get_action_strength("cam_left") - Input.get_action_strength("cam_right")) * KEY_ROT_SPEED * delta
	rotation.y = lerp_angle(rotation.y, _yaw, YAW_SMOOTH)
	camera.rotation_degrees.x = camera_pitch_deg + _pitch_offset_deg
	_resolve_cam_collision()
	_refresh_mouse_capture()

## Spring-arm：玩家→相機理想位置打射線（只打層2 cam blocker），被建築擋住就沿臂縮短。
func _resolve_cam_collision() -> void:
	var from := global_position + Vector3.UP * 1.5
	var to := to_global(camera_offset)
	var frac := 1.0
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, to, CAM_BLOCK_MASK))
	if not hit.is_empty():
		frac = clampf((hit.position - from).length() / (to - from).length() - 0.16, CAM_MIN_FRAC, 1.0)
	camera.position = camera.position.lerp(camera_offset * frac, 0.25)

## Esc 手動開關留在 _unhandled_input（維持原本「UI 先吃、rig 後收」的順序，
## 不搶 MenuShell 的 Esc）。
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_mouse_look"):
		# 只在真正探索中（無 UI 擋著）才切手動開關——否則玩家用 Esc 關手機選單時
		# 會順便把 _mouse_look_enabled 切掉，選單關閉後視角反而卡死不會轉。
		# _mouse_look_active() 已把「開關本身是否開著」也算進去，這裡改用
		# _blocking_ui_present() 只看 UI，不看開關，才不會自己卡自己。
		if not _blocking_ui_present():
			_mouse_look_enabled = not _mouse_look_enabled
			_refresh_mouse_capture()

## 滑鼠移動：捕捉模式下（FPS 式，不用按鍵）或右鍵按住拖曳（未捕捉時的備援），
## 直接轉 yaw／pitch。UI 擋著或手動關閉時 _mouse_look_active() 會擋掉。
## ⚠改在 _input 而非 _unhandled_input：捕捉模式下 HUD 等 Control 節點會先把
## InputEventMouseMotion 吃掉，事件到不了 _unhandled_input，視角就不轉——這正是
## 真機「只能按右鍵才能轉」的成因（右鍵拖曳走另一條 OS 事件較不受影響）。_input
## 先於 GUI 收事件，攔不掉；且這裡不呼叫 set_input_as_handled，UI 照常運作。
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseMotion):
		return
	if not _mouse_look_active():
		return
	if not _captured and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		return
	var rel := (event as InputEventMouseMotion).relative
	_yaw -= rel.x * MOUSE_ROT_SENS
	_pitch_offset_deg = clampf(
		_pitch_offset_deg - rel.y * MOUSE_PITCH_SENS * 57.2958,
		PITCH_MIN_DEG, PITCH_MAX_DEG)

## 是否該啟用滑鼠視角：手動開關開著、且沒有任何會擋掉探索輸入的 UI 蓋在上面。
## 判準沿用 MapScreen._interact()/_on_enemy_caught() 的既有慣例（paused／Dialogic／
## MenuShell／ShopScreen／action_menu），另加「本節點是否還在場景樹裡」防呆。
## ⚠MenuShell/ShopScreen 是 MapScreen 的子節點（不是場景樹 current_scene 本身：
## UndergroundParlor 直切成 current_scene、CameraRig 才會是它的孫節點），故用
## _find_host_root() 從自己往上找最近的「有意義宿主」，不要用 get_tree().current_scene——
## 後者在巢狀/測試場景（rig 不是掛在 root 正下方）會找錯層級，MenuShell 開關偵測不到。
func _mouse_look_active() -> bool:
	if not _mouse_look_enabled:
		return false
	if not _window_focused:
		return false
	return not _blocking_ui_present()

## 純粹只看「有沒有 UI 擋著」，不看 _mouse_look_enabled 手動開關——供 _unhandled_input
## 判斷「現在能不能切開關」用，跟 _mouse_look_active() 分開才不會互相卡住。
func _blocking_ui_present() -> bool:
	if not is_inside_tree():
		return true
	if get_tree().paused:
		return true
	if Dialogic.current_timeline != null:
		return true
	var root := _find_host_root()
	if root != null:
		if root.get_node_or_null("MenuShell") != null:
			return true
		if root.get_node_or_null("ShopScreen") != null:
			return true
		var hud := root.get_node_or_null("HUD")
		if hud != null and "action_menu" in hud and is_instance_valid(hud.action_menu) and hud.action_menu.visible:
			return true
	return false

## 往上找 CameraRig 所屬的「宿主」節點：MapScreen（神社街/軍火庫走這條，
## MenuShell/ShopScreen 掛在 MapScreen 底下）或場景樹的 current_scene（地下遊藝場
## 獨立切場景時走這條，也是安全預設）。用「父節點名稱是否叫 MapScreen」判斷，
## 避免直接假設固定階層深度（CameraRig 是環境 tscn 的直接子節點，環境又是
## MapScreen/World 的子節點，層數會因巢狀方式而變，用名稱找比數階層穩）。
func _find_host_root() -> Node:
	var n: Node = self
	while n != null:
		if n.name == "MapScreen":
			return n
		n = n.get_parent()
	return get_tree().current_scene

## 依 _mouse_look_active() 的結果同步 Input.mouse_mode；狀態不變就不重複寫入。
func _refresh_mouse_capture() -> void:
	_set_mouse_captured(_mouse_look_active())

## Input.mouse_mode 在 headless（無真實視窗）下設定是安全的 no-op（同 SoupCarry.gd
## 既有慣例，未加防護也一路 ALL PASS，寫入不會拋錯，只是讀回值不會變）——這裡
## 故意不擋 headless；真正的邏輯狀態記在 _captured，OS 呼叫只是「盡量同步」。
func _set_mouse_captured(want_captured: bool) -> void:
	_captured = want_captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if want_captured else Input.MOUSE_MODE_VISIBLE

## 執行期註冊 cam_left(A) / cam_right(D)，避免動 project.godot 的 InputEvent 序列化格式。
func _register_rotate_actions() -> void:
	for pair in [["cam_left", KEY_A], ["cam_right", KEY_D]]:
		var action: String = pair[0]
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = pair[1]
		InputMap.action_add_event(action, ev)

## 執行期註冊 toggle_mouse_look(Esc)——與 cancel 共用鍵位沒關係，這裡收到事件
## 只切滑鼠視角開關，不 consume 事件，MenuShell 等其餘 Esc 監聽照常收到。
func _register_toggle_look_action() -> void:
	if InputMap.has_action("toggle_mouse_look"):
		return
	InputMap.add_action("toggle_mouse_look")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ESCAPE
	InputMap.action_add_event("toggle_mouse_look", ev)
