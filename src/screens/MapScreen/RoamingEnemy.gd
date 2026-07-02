extends Node3D
## 人中之龍式路上漫遊敵人：在巡邏區內閒晃，玩家靠近就追，
## 追到（進入 catch 半徑）→ emit caught_player → MapScreen 起遭遇戰（SLASH_RED 轉場）。
## 敵人模型＝Meshy image-to-3d（靜態未綁骨），靠位移＋程式呼吸/擺動呈現「活著」。
## 追擊速度刻意 < 玩家走路速，玩家可甩開（跑步更容易）＝人中之龍那種「可閃避的雜魚」。

signal caught_player(enemy_id: String)

const ENEMY_DIR := "res://assets/3d/characters/enemies/"
const WANDER_SPEED := 1.6
const CHASE_SPEED  := 3.4
const AGGRO_RADIUS := 5.0     # 進入此半徑開始追（沿街多隻→不設太大，避免整條街一起圍）
const DEAGGRO_RADIUS := 9.0   # 拉開此距離放棄追、回巡邏
const CATCH_RADIUS := 1.3     # 追到＝觸發戰鬥
const TURN_RATE := 8.0        # 朝向插值速度
const SPAWN_GRACE := 2.5      # 生成後暫不索敵（防戰後回場落點在敵群裡被連環抓）

var enemy_id: String = ""
var _model: Node3D = null
var _home: Vector3 = Vector3.ZERO
var _patrol_radius: float = 4.0
var _wander_target: Vector3 = Vector3.ZERO
var _pause_t: float = 0.0
var _t: float = 0.0
var _stride: float = 0.0       # 步伐相位（隨實際位移推進→彈跳與腳程同步）
var _is_ghost: bool = false    # 鬼類＝飄浮滑行（滑的合理）；人形＝步伐彈跳
var _chasing: bool = false
var _done: bool = false        # 已觸發過戰鬥→停手（等場景切換）
var _rng := RandomNumberGenerator.new()

## data: {enemy_id, model, patrol_center{x,z}, patrol_radius}
func setup(data: Dictionary) -> void:
	enemy_id = String(data.get("enemy_id", ""))
	_home = Vector3(
		float(data.get("patrol_center", {}).get("x", 0.0)), 0.0,
		float(data.get("patrol_center", {}).get("z", 0.0)))
	_patrol_radius = float(data.get("patrol_radius", 4.0))
	position = _home
	_rng.randomize()
	_wander_target = _pick_wander_point()
	var model_name := String(data.get("model", enemy_id))
	_is_ghost = model_name.contains("ghost")
	var path := ENEMY_DIR + model_name + ".glb"
	if not ResourceLoader.exists(path):
		push_warning("RoamingEnemy: 模型不存在 %s(先略過)" % path)
		return
	_model = (load(path) as PackedScene).instantiate()
	add_child(_model)
	_fix_materials(_model)

func _physics_process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var to_player := Vector3.ZERO
	var dist := INF
	if player:
		to_player = player.global_position - global_position
		to_player.y = 0.0
		dist = to_player.length()

	# 追擊狀態切換（生成寬限期內不索敵）
	if _chasing:
		if dist > DEAGGRO_RADIUS:
			_chasing = false
			_wander_target = _pick_wander_point()
	elif dist < AGGRO_RADIUS and _t > SPAWN_GRACE:
		_chasing = true

	var target: Vector3
	var speed: float
	if _chasing:
		target = player.global_position
		speed = CHASE_SPEED
		if dist < CATCH_RADIUS:
			_trigger()
			return
	else:
		target = _wander_target
		speed = WANDER_SPEED
		if global_position.distance_to(_wander_target) < 0.4:
			_pause_t -= delta
			if _pause_t <= 0.0:
				_wander_target = _pick_wander_point()
				_pause_t = _rng.randf_range(0.8, 2.2)
			speed = 0.0

	var flat := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	var moving := speed > 0.0 and flat.length() > 0.05
	if moving:
		var dir := flat.normalized()
		global_position += dir * speed * delta
		_face(dir, delta)
		_stride += speed * delta * 5.2   # 相位隨位移推進＝彈跳頻率跟腳程同步(追擊時自然變快)

	_animate(moving, delta)

## 程式化「走路感」（模型無骨骼）：人形＝步伐彈跳＋左右搖擺＋前傾；鬼類＝飄浮滑行。
## 站住時退回慢呼吸。取代原本幾乎看不見的微晃(0.02)。
func _animate(moving: bool, delta: float) -> void:
	if _model == null:
		return
	if _is_ghost:
		# 鬼：離地飄浮＋大幅緩慢起伏＋幽幽側傾，滑行本身就是移動方式
		_model.position.y = 0.25 + sin(_t * 1.6) * 0.10
		_model.rotation.z = sin(_t * 0.9) * 0.05
		_model.rotation.x = lerp(_model.rotation.x, -0.06 if moving else 0.0, 4.0 * delta)
		return
	if moving:
		# 人形步伐：|sin|＝每步著地的頓點；roll 半頻＝左右腳交替重心；披加前傾
		_model.position.y = abs(sin(_stride)) * 0.07
		_model.rotation.z = sin(_stride * 0.5) * 0.07
		_model.rotation.x = lerp(_model.rotation.x, -0.10 if _chasing else -0.05, 6.0 * delta)
	else:
		_model.position.y = lerp(_model.position.y, sin(_t * 2.0) * 0.02, 8.0 * delta)
		_model.rotation.z = lerp(_model.rotation.z, 0.0, 6.0 * delta)
		_model.rotation.x = lerp(_model.rotation.x, 0.0, 6.0 * delta)

func _face(dir: Vector3, delta: float) -> void:
	if _model == null:
		return
	var want := atan2(dir.x, dir.z)
	_model.rotation.y = lerp_angle(_model.rotation.y, want, clamp(TURN_RATE * delta, 0.0, 1.0))

func _trigger() -> void:
	_done = true
	caught_player.emit(enemy_id)

func _pick_wander_point() -> Vector3:
	var a := _rng.randf() * TAU
	var r := _rng.randf() * _patrol_radius
	return _home + Vector3(cos(a) * r, 0.0, sin(a) * r)

## 修 Meshy base-color alpha→整模型透明 雷；消光 matte。保留貼圖。(同 npc_figure)
func _fix_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var n: int = mi.mesh.get_surface_count() if mi.mesh != null else 0
		for i in n:
			var m := mi.get_active_material(i)
			if m is BaseMaterial3D:
				var b := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
				b.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				b.albedo_color.a = 1.0
				b.roughness = 1.0
				b.metallic = 0.0
				b.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
				mi.set_surface_override_material(i, b)
	for c in node.get_children():
		_fix_materials(c)
