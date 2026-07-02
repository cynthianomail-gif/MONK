extends Node3D

@export var target_path: NodePath
@export var camera_offset: Vector3 = Vector3(0.0, 11.0, 9.0)
@export var camera_pitch_deg: float = -12.0
@export var follow_speed: float = 0.08

const KEY_ROT_SPEED := 2.2       # A/D 旋轉速度 (rad/s)
const MOUSE_ROT_SENS := 0.008    # 右鍵拖曳靈敏度 (rad/px)
const YAW_SMOOTH := 0.14         # 旋轉平滑係數
const CAM_BLOCK_MASK := 2        # 建築 cam blocker 碰撞層（層2＝只擋相機不擋角色）
const CAM_MIN_FRAC := 0.30       # 相機最近可縮到 offset 的比例

@onready var camera: Camera3D = $Camera3D
var _target: Node3D = null
var _yaw: float = 0.0            # 目標 yaw；rotation.y 平滑追上

func _ready() -> void:
	camera.position = camera_offset
	camera.rotation_degrees.x = camera_pitch_deg
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
	_yaw += (Input.get_action_strength("cam_left") - Input.get_action_strength("cam_right")) * KEY_ROT_SPEED * delta
	rotation.y = lerp_angle(rotation.y, _yaw, YAW_SMOOTH)
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

## 右鍵按住拖曳旋轉視角（玩家移動吃相機 yaw，會自動跟著轉）。
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_yaw -= (event as InputEventMouseMotion).relative.x * MOUSE_ROT_SENS

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
