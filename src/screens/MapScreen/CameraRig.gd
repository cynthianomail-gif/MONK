extends Node3D

@export var target_path: NodePath
@export var camera_offset: Vector3 = Vector3(0.0, 11.0, 9.0)
@export var follow_speed: float = 0.08

@onready var camera: Camera3D = $Camera3D
@onready var _target: Node3D = get_node_or_null(target_path)

func _ready() -> void:
	camera.position = camera_offset
	camera.rotation_degrees.x = -50.0
	if _target:
		global_position = _target.global_position

func _physics_process(_delta: float) -> void:
	if _target:
		global_position = global_position.lerp(_target.global_position, follow_speed)
