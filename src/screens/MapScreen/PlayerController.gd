extends CharacterBody3D

const SPEED:   float = 5.0
const GRAVITY: float = -20.0

@onready var anim_tree: AnimationTree = get_node_or_null("AnimationTree")
@onready var model: Node3D            = $MeshRoot

var _cam_basis: Basis = Basis.IDENTITY

func _ready() -> void:
	# 預設背對相機（第三人稱慣例）；移動時 atan2 會接管朝向。
	model.rotation.y = PI

func _physics_process(delta: float) -> void:
	_refresh_cam_basis()
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	var input := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)
	var dir := (_cam_basis * Vector3(input.x, 0.0, input.y)).normalized()
	if dir.length() > 0.1:
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
		model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), 0.2)
		_set_blend(1.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)
		_set_blend(0.0)
	move_and_slide()

func _refresh_cam_basis() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		_cam_basis = Basis(Vector3.UP, cam.global_rotation.y)

func _set_blend(v: float) -> void:
	if anim_tree:
		anim_tree.set("parameters/blend/blend_amount", v)
