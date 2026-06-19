extends CharacterBody3D
## HD-2D 主角：CharacterBody3D ＋ Y-billboard Sprite3D。
## 方向鍵相對相機移動，移動時循環 walk 幀、靜止顯示 idle，依水平位移翻面。
## 重用既有厚塗 wujie sprite（256×384），UNSHADED 保畫風。

const SPRITE_DIR := "res://assets/2d/characters/wujie/sprite/"
const SPEED := 5.0
const GRAVITY := -20.0
const PLAYER_HEIGHT := 2.4     # 世界高度（公尺）；pixel_size 由此與貼圖高度反推
const WALK_FPS := 10.0

var _idle: Texture2D
var _walk: Array = []
var _sprite: Sprite3D
var _cam_basis := Basis.IDENTITY
var _anim_t := 0.0

func _ready() -> void:
	add_to_group("player")
	_idle = load(SPRITE_DIR + "idle_0.png") as Texture2D
	for i in 8:
		var t := load(SPRITE_DIR + "walk_%d.png" % i) as Texture2D
		if t: _walk.append(t)

	_sprite = Sprite3D.new()
	_sprite.name = "Sprite3D"
	_sprite.texture = _idle
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y    # 直立、繞 Y 面向相機
	_sprite.shaded = false                                  # 厚塗自帶光影，不吃 3D 燈
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD      # 硬邊去背、免透明排序
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if _idle:
		_sprite.pixel_size = PLAYER_HEIGHT / float(_idle.get_height())
	_sprite.position = Vector3(0, PLAYER_HEIGHT * 0.5, 0)   # 腳在 y=0
	add_child(_sprite)

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = PLAYER_HEIGHT
	col.shape = cap
	col.position = Vector3(0, PLAYER_HEIGHT * 0.5, 0)
	add_child(col)

func _physics_process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		_cam_basis = Basis(Vector3.UP, cam.global_rotation.y)
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	var input := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)
	var dir := _cam_basis * Vector3(input.x, 0.0, input.y)
	dir.y = 0.0
	dir = dir.normalized()
	if dir.length() > 0.1:
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
		if absf(dir.x) > 0.01:
			_sprite.flip_h = dir.x < 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)
	move_and_slide()
	_update_frame(delta)

func _update_frame(delta: float) -> void:
	var moving := Vector2(velocity.x, velocity.z).length() > 0.3
	if moving and not _walk.is_empty():
		_anim_t += delta * WALK_FPS
		_sprite.texture = _walk[int(_anim_t) % _walk.size()]
	else:
		_anim_t = 0.0
		if _idle:
			_sprite.texture = _idle
