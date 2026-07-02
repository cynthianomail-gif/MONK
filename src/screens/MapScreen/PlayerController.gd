extends CharacterBody3D

const WALK_SPEED: float = 5.0
const RUN_SPEED:  float = 8.5
const GRAVITY:    float = -20.0

@onready var anim_tree: AnimationTree = get_node_or_null("AnimationTree")
@onready var model: Node3D            = $MeshRoot

var _cam_basis: Basis = Basis.IDENTITY

func _ready() -> void:
	_register_sprint_action()
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
