extends AnimationTree
## 掛在 Player/AnimationTree 上：從模型 AnimationPlayer 取走路 clip、程式生成待機 clip，
## 並（若有）從相鄰 GLB 併入跑步 clip，組成 idle→walk→run 的 BlendSpace1D。
## PlayerController 設 parameters/move/blend_position：0=待機 0.5=走 1.0=跑。
## 跑步 GLB 缺檔時優雅退成 idle↔walk（run 點沿用 walk clip），不擋既有流程。

@export var model_path: NodePath          # 指向 MeshRoot 下的 GLB 實例（可空，會 fallback 搜父節點）
const RUN_GLB := "res://assets/3d/characters/wujie/wujie_run.glb"
const ARM_DEG := 90.0                       # 上臂繞 LOCAL RIGHT 軸下垂角度（IdleSignTest 測得 down90 最自然）
const ARM_AXIS := Vector3.RIGHT             # 雙臂同號繞此軸即自然垂於體側（非 BACK）
const WALK_KEYS := ["walk", "walking", "move"]
const RUN_KEYS := ["run", "running", "sprint", "jog"]

func _ready() -> void:
	# 延一幀，確保 GLB 子樹完全進場（synchronous _ready 解析不到）。
	await get_tree().process_frame
	# 直接從父節點(Player)整棵子樹找，不依賴 model_path export（相對路徑易失效）。
	var model: Node = get_node_or_null(model_path)
	if model == null:
		model = get_parent()
	var ap := _find_ap(model)
	var skel := _find_skel(model)
	if ap == null or skel == null:
		push_warning("PlayerAnimTree: 缺 AnimationPlayer/Skeleton，動畫停用 (model=%s)" % str(model))
		return
	_make_opaque(model)
	var walk_name := _pick(ap.get_animation_list(), WALK_KEYS)
	if walk_name == "":
		push_warning("PlayerAnimTree: 找不到走路動畫，clips=%s" % str(ap.get_animation_list()))
		return
	# Meshy 的 walk clip 匯入是 loop=NONE → 播一輪(~1s)就定格＝「腳不會動」。強制循環。
	_force_loop(ap.get_animation(walk_name))
	var idle_name := _make_idle(ap, skel)
	var run_name := _merge_run(ap)          # 有跑步 GLB 就併入並回傳名；否則回 walk_name

	# BlendSpace1D：idle(0)→walk(0.5)→run(1.0)，單一 blend_position 控制。
	var bs := AnimationNodeBlendSpace1D.new()
	bs.min_space = 0.0
	bs.max_space = 1.0
	var ni := AnimationNodeAnimation.new(); ni.animation = idle_name
	var nw := AnimationNodeAnimation.new(); nw.animation = walk_name
	var nr := AnimationNodeAnimation.new(); nr.animation = run_name
	bs.add_blend_point(ni, 0.0)
	bs.add_blend_point(nw, 0.5)
	bs.add_blend_point(nr, 1.0)
	anim_player = get_path_to(ap)
	tree_root = bs
	active = true

## 從相鄰 wujie_run.glb 取跑步 clip 併入主 AnimationPlayer（同 rig→骨名一致→可跨 GLB 播）。
## 回傳併入後的 clip 名；缺檔/找不到則回空串前的 fallback＝walk（由呼叫端處理）。
func _merge_run(ap: AnimationPlayer) -> String:
	# 若主 ap 本身已含跑步 clip（同一 GLB 內），直接用。
	var existing := _pick(ap.get_animation_list(), RUN_KEYS)
	if existing != "":
		_force_loop(ap.get_animation(existing))
		return existing
	if not ResourceLoader.exists(RUN_GLB):
		# 無跑步資產：run 點沿用 walk（PlayerController 設 1.0 時就是快走）。
		return _pick(ap.get_animation_list(), WALK_KEYS)
	var inst := (load(RUN_GLB) as PackedScene).instantiate()
	var run_ap := _find_ap(inst)
	var result := ""
	if run_ap:
		var rn := _pick(run_ap.get_animation_list(), RUN_KEYS)
		if rn == "":
			rn = _pick(run_ap.get_animation_list(), WALK_KEYS)
		if rn != "":
			var run_anim: Animation = run_ap.get_animation(rn).duplicate()
			_force_loop(run_anim)
			if not ap.has_animation_library(""):
				ap.add_animation_library("", AnimationLibrary.new())
			ap.get_animation_library("").add_animation("run_merged", run_anim)
			result = "run_merged"
	inst.free()
	return result if result != "" else _pick(ap.get_animation_list(), WALK_KEYS)

func _force_loop(anim: Animation) -> void:
	if anim:
		anim.loop_mode = Animation.LOOP_LINEAR

## 生成待機：對 LeftArm/RightArm 各下垂 ARM_DEG（合手於身前），其餘骨用 rest＝直立站姿。
func _make_idle(ap: AnimationPlayer, skel: Skeleton3D) -> String:
	var anim := Animation.new()
	anim.length = 1.0
	anim.loop_mode = Animation.LOOP_LINEAR
	var base := ap.get_node(ap.root_node)
	var skel_path := String(base.get_path_to(skel))
	var q := Quaternion(ARM_AXIS, deg_to_rad(ARM_DEG))
	for bone in ["LeftArm", "RightArm"]:
		if skel.find_bone(bone) < 0:
			continue
		var tr := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(tr, "%s:%s" % [skel_path, bone])
		anim.rotation_track_insert_key(tr, 0.0, q)
	if not ap.has_animation_library(""):
		ap.add_animation_library("", AnimationLibrary.new())
	ap.get_animation_library("").add_animation("idle_gen", anim)
	return "idle_gen"

## Meshy 匯出材質常帶 alpha<1／TRANSPARENCY_ALPHA，會整隻透明/破圖；強制不透明（道具踩過的雷）。
func _make_opaque(n: Node) -> void:
	for c in _all(n):
		if c is MeshInstance3D and (c as MeshInstance3D).mesh:
			var mi := c as MeshInstance3D
			for s in mi.mesh.get_surface_count():
				var m = mi.mesh.surface_get_material(s)
				if m is BaseMaterial3D:
					m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
					var col: Color = m.albedo_color; col.a = 1.0; m.albedo_color = col

func _all(n: Node, acc: Array = []) -> Array:
	acc.append(n)
	for c in n.get_children():
		_all(c, acc)
	return acc

func _find_ap(n: Node) -> AnimationPlayer:
	if n == null: return null
	if n is AnimationPlayer: return n
	for c in n.get_children():
		var r := _find_ap(c)
		if r: return r
	return null

func _find_skel(n: Node) -> Skeleton3D:
	if n == null: return null
	if n is Skeleton3D: return n
	for c in n.get_children():
		var r := _find_skel(c)
		if r: return r
	return null

func _pick(clips: Array, keys: Array) -> String:
	for k in keys:
		for c in clips:
			if String(c).to_lower().contains(k):
				return String(c)
	return ""
