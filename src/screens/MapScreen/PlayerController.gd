extends CharacterBody3D

const WALK_SPEED: float = 5.0
const RUN_SPEED:  float = 8.5
const GRAVITY:    float = -20.0

@onready var anim_tree: AnimationTree = get_node_or_null("AnimationTree")
@onready var model: Node3D            = $MeshRoot

var _cam_basis: Basis = Basis.IDENTITY

func _ready() -> void:
	_register_sprint_action()
	_register_wasd_axes()
	# 預設背對相機（第三人稱慣例）；移動時 atan2 會接管朝向。
	model.rotation.y = PI

func _physics_process(delta: float) -> void:
	_refresh_cam_basis()
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	# 2026-07-11 使用者實機回饋：Dialogic 對話開著時玩家角色還能被 WASD 走動（對話
	# 不像 MenuShell/ShopScreen 那樣會 get_tree().paused=true，PlayerController 原本
	# 完全沒檢查對話狀態）。對話中鎖死水平輸入，但仍讓既有速度衰減到 0＋照常
	# move_and_slide()（維持重力貼地，不是整個函式 return，避免對話開始那瞬間卡在
	# 半空或穿地板）。
	if Dialogic.current_timeline != null:
		velocity.x = move_toward(velocity.x, 0.0, WALK_SPEED)
		velocity.z = move_toward(velocity.z, 0.0, WALK_SPEED)
		_set_blend(0.0)
		move_and_slide()
		return
	var input := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)
	var dir := (_cam_basis * Vector3(input.x, 0.0, input.y)).normalized()
	var sprinting := Input.is_action_pressed("sprint")
	if dir.length() > 0.1:
		var speed := RUN_SPEED if sprinting else WALK_SPEED
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), 0.2)
		_set_blend(1.0 if sprinting else 0.5)     # 跑 / 走
	else:
		velocity.x = move_toward(velocity.x, 0.0, WALK_SPEED)
		velocity.z = move_toward(velocity.z, 0.0, WALK_SPEED)
		_set_blend(0.0)                            # 待機
	move_and_slide()

func _refresh_cam_basis() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		_cam_basis = Basis(Vector3.UP, cam.global_rotation.y)

## BlendSpace1D 直接當 tree_root → 參數路徑＝parameters/blend_position（非巢狀）。
func _set_blend(v: float) -> void:
	if anim_tree:
		anim_tree.set("parameters/blend_position", v)

## 執行期註冊「sprint」(左 Shift)，避免動 project.godot 的 InputEvent 序列化格式。
func _register_sprint_action() -> void:
	if InputMap.has_action("sprint"):
		return
	InputMap.add_action("sprint")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_SHIFT
	InputMap.action_add_event("sprint", ev)

## 2026-07-10 review 退回修正（F5）：ui_left/ui_right/ui_up/ui_down 是 Godot 內建 action，預設只
## 綁方向鍵（不含 WASD，已實測 InputMap.action_get_events 證實）。HelpApp/MapHUD 卻一直寫著
## 「W/A/S/D 移動」，玩家照著按完全沒反應。內建 action 一樣不動 project.godot（同 sprint 的既有
## 模式），執行期補上 WASD 事件即可；InputMap 執行期註冊不落地存檔，MapScreen 每次進場都會重跑
## 這個 _ready()，用 action_get_events 判斷是否已加過，避免同一 session 反覆進出地圖疊加重複事件。
func _register_wasd_axes() -> void:
	_ensure_key_event("ui_left", KEY_A)
	_ensure_key_event("ui_right", KEY_D)
	_ensure_key_event("ui_up", KEY_W)
	_ensure_key_event("ui_down", KEY_S)

func _ensure_key_event(action: StringName, physical_key: Key) -> void:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and ev.physical_keycode == physical_key:
			return
	var ev := InputEventKey.new()
	ev.physical_keycode = physical_key
	InputMap.action_add_event(action, ev)
