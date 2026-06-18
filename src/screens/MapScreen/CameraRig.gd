extends Node3D

@export var target_path: NodePath
@export var camera_offset: Vector3 = Vector3(0.0, 11.0, 9.0)
@export var camera_pitch_deg: float = -12.0
@export var follow_speed: float = 0.08

@onready var camera: Camera3D = $Camera3D
var _target: Node3D = null

func _ready() -> void:
	camera.position = camera_offset
	camera.rotation_degrees.x = camera_pitch_deg
	_acquire_target()

## 解析 target；成功時直接貼齊（避免相機從原點慢慢飄過去）。
## target_path 的 NodePath export 在某些載入時序會掉值，故以 "player" group 為備援。
func _acquire_target() -> void:
	_target = get_node_or_null(target_path)
	if _target == null:
		_target = get_tree().get_first_node_in_group("player")
	if _target:
		global_position = _target.global_position

func _physics_process(_delta: float) -> void:
	# target 可能在 _ready 當下尚未就位（NodePath/spawn 時序），未取得就每幀補抓。
	if _target == null:
		_acquire_target()
		return
	global_position = global_position.lerp(_target.global_position, follow_speed)
