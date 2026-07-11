extends Node3D
## 鍵盤式自由視角（Q/E 轉 yaw）＋spring-arm 防穿牆。
## 沿革：2026-07-02 原僅「右鍵按住拖曳」轉 yaw；2026-07-05 改為 FPS 式滑鼠捕捉視角。
## 2026-07-10（D-1 鍵位定案）：轉視角備援鍵原為 A/D，與 ui_left/ui_right（Godot 內建
## WASD 移動）鍵位重疊，改用 Q/E。
## 2026-07-11（使用者實機回饋拍板）：**整個拿掉滑鼠視角**（含 FPS 捕捉式與右鍵拖曳）。
## 根因推定＝編輯器內嵌視窗下 MOUSE_MODE_CAPTURED 的位移事件時好時壞，不可靠到無法
## 修好；使用者拍板探索地圖只留鍵盤轉視角（Q/E），滑鼠游標永遠可見、不再被捕捉。
## 舊版 use_accumulated_input(false)／MOUSE_MODE_CAPTURED／pitch offset／視窗焦點
## 追蹤全部隨滑鼠視角一併移除；SoupCarry.gd（端湯 3D 小遊戲，滑鼠視角是玩法核心，
## 本次不動）原本間接依賴這裡設的 use_accumulated_input(false)（全域 Input 設定，
## 不隨場景釋放，探索地圖先跑過一次就會沿用到後面進的小遊戲），拿掉後已改在
## SoupCarry.gd 自己的 _ready() 補設，避免它的滑鼠視角隨這次改動被間接弱化。
## 同批加上：對話進行中（Dialogic.current_timeline != null）鍵盤轉視角也鎖住
## （原本只有滑鼠視角會被 _blocking_ui_present() 擋，Q/E 鍵盤旋轉不受影響，是本次
## 一併修正的缺口）。

@export var target_path: NodePath
@export var camera_offset: Vector3 = Vector3(0.0, 11.0, 9.0)
@export var camera_pitch_deg: float = -12.0
@export var follow_speed: float = 0.08

const KEY_ROT_SPEED := 2.2       # Q/E 旋轉速度 (rad/s)
const YAW_SMOOTH := 0.14         # 旋轉平滑係數
const CAM_BLOCK_MASK := 2        # 建築 cam blocker 碰撞層（層2＝只擋相機不擋角色）
const CAM_MIN_FRAC := 0.30       # 相機最近可縮到 offset 的比例

@onready var camera: Camera3D = $Camera3D
var _target: Node3D = null
var _yaw: float = 0.0             # 目標 yaw；rotation.y 平滑追上

func _ready() -> void:
	camera.position = camera_offset
	camera.rotation_degrees.x = camera_pitch_deg
	# 探索地圖不再捕捉滑鼠——保險起見明確釋放一次，避免上一個場景（例如某次意外
	# 沒清乾淨的舊狀態）殘留 CAPTURED 讓游標卡住看不見。
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_register_rotate_actions()
	_acquire_target()

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
	# 對話／選單／商店等 UI 擋著時，Q/E 鍵盤轉視角也一併鎖住（跟玩家移動鎖住的
	# 判準共用 _blocking_ui_present()，避免對話中鏡頭還轉來轉去）。
	if not _blocking_ui_present():
		_yaw += (Input.get_action_strength("cam_left") - Input.get_action_strength("cam_right")) * KEY_ROT_SPEED * delta
	rotation.y = lerp_angle(rotation.y, _yaw, YAW_SMOOTH)
	camera.rotation_degrees.x = camera_pitch_deg
	_resolve_cam_collision()

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

## 是否有 UI／狀態擋著，該鎖住探索輸入（Q/E 轉視角、以及 PlayerController 的移動判準
## 也沿用同一套邏輯）。判準沿用 MapScreen._interact()/_on_enemy_caught() 的既有慣例
## （paused／Dialogic／MenuShell／ShopScreen／action_menu）。
## ⚠MenuShell/ShopScreen 是 MapScreen 的子節點（不是場景樹 current_scene 本身：
## UndergroundParlor 直切成 current_scene、CameraRig 才會是它的孫節點），故用
## _find_host_root() 從自己往上找最近的「有意義宿主」，不要用 get_tree().current_scene——
## 後者在巢狀/測試場景（rig 不是掛在 root 正下方）會找錯層級，MenuShell 開關偵測不到。
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

## 執行期註冊 cam_left(Q) / cam_right(E)，避免動 project.godot 的 InputEvent 序列化格式。
## 2026-07-10：原為 A/D，改 Q/E 以避開 ui_left/ui_right（WASD 移動）鍵位重疊（D-1）。
func _register_rotate_actions() -> void:
	for pair in [["cam_left", KEY_Q], ["cam_right", KEY_E]]:
		var action: String = pair[0]
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = pair[1]
		InputMap.action_add_event(action, ev)
