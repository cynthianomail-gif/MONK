extends AnimationTree
## 掛在 Player/AnimationTree 上：_ready 從模型的 AnimationPlayer 取走路 clip、
## 並程式生成一段「雙臂下垂合於身前」的待機 clip（rig 沒附 idle），
## 組成 idle↔walk 混合樹，暴露 parameters/blend/blend_amount 給 PlayerController。

@export var model_path: NodePath          # 指向 MeshRoot 下的 GLB 實例（可空，會 fallback 搜父節點）
const ARM_DEG := 90.0                       # 上臂繞 LOCAL RIGHT 軸下垂角度（IdleSignTest 測得 down90 最自然）
const ARM_AXIS := Vector3.RIGHT             # 雙臂同號繞此軸即自然垂於體側（非 BACK）
const WALK_KEYS := ["walk", "walking", "move", "run", "running"]

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
	var walk_anim := ap.get_animation(walk_name)
	if walk_anim:
		walk_anim.loop_mode = Animation.LOOP_LINEAR
	var idle_name := _make_idle(ap, skel)
	var bt := AnimationNodeBlendTree.new()
	var ni := AnimationNodeAnimation.new(); ni.animation = idle_name
	var nw := AnimationNodeAnimation.new(); nw.animation = walk_name
	var b := AnimationNodeBlend2.new()
	bt.add_node("idle", ni, Vector2(-260, 0))
	bt.add_node("walk", nw, Vector2(-260, 160))
	bt.add_node("blend", b, Vector2(0, 80))
	bt.connect_node("blend", 0, "idle")
	bt.connect_node("blend", 1, "walk")
	bt.connect_node("output", 0, "blend")
	anim_player = get_path_to(ap)
	tree_root = bt
	active = true

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
