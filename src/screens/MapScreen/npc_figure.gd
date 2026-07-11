extends Node3D
## 探索世界站立 NPC：載 Meshy GLB → 修透明材質+消光 → 程式呼吸搖擺(免綁骨)。
## 保留 Meshy 貼圖(源自 okami 立繪)；場景已去水墨(無描邊/toon)，角色靠貼圖本身立體感。

const NPC_DIR := "res://assets/3d/characters/npcs/"

var _t := 0.0
var _model: Node3D = null
var _ground_y := 0.0   # 貼地校正後的基準 y（_process 呼吸位移疊加在這個基準上，不是疊加在 0 上）

## model_name = GLB 檔名(無副檔)，如 "liaochen"；缺檔則優雅略過(待 Meshy 生成)。
func setup(model_name: String) -> void:
	var path := NPC_DIR + model_name + ".glb"
	if not ResourceLoader.exists(path):
		push_warning("NpcFigure: 模型不存在 %s(先略過)" % path)
		return
	_model = (load(path) as PackedScene).instantiate()
	add_child(_model)
	_fix_materials(_model)
	_snap_to_ground(_model)

## 2026-07-10 QC 修正（沉地）：Meshy image-to-3d 匯出的原點不保證在腳底——實測 12 隻探索
## NPC 裡有 6 隻原點落在模型垂直中心（bottom≈-0.95，約自身身高一半），用地圖慣例
## position.y=0(=地面頂面)擺放時會沉入地板一半。量測 AABB（相對 model 自身局部座標系，
## 不吃 LocationTrigger 世界座標——用 model.global_transform 反矩陣把每個 MeshInstance3D
## 的全域 AABB 拉回 model 局部空間，這樣不論觸發點擺在哪個高度都算得出正確的「模型自己
## 的腳底相對模型原點的偏移」，不會像直接用全域 y 那樣意外把腳底焊死在世界 y=0）。
## 算出偏移後把 _ground_y 設成貼地基準，_process() 的呼吸位移疊加其上（原本直接寫
## _model.position.y=sin(...) 會整幀蓋掉貼地校正，這裡改成疊加）。
## AABB 已在 0 的模型（原點本來就在腳底）偏移量為 0，不受影響。
## 同一手法沿用 ShrineStreet._build_shrine_hall() 既有的 AABB 正規化慣例。
func _snap_to_ground(model: Node3D) -> void:
	var aabb := _local_aabb(model)
	if aabb.size.y <= 0.0:
		return   # 無 MeshInstance3D(例如純骨架或載入失敗)，沒有幾何可對齊
	_ground_y = -aabb.position.y
	model.position.y = _ground_y

## 回傳 node 底下所有 MeshInstance3D 合併後的 AABB，座標系＝node 自身的局部空間
## （不受 node 在場景樹中的世界位置影響）。
func _local_aabb(node: Node3D) -> AABB:
	var ref_inv := node.global_transform.affine_inverse()
	var aabb := AABB()
	var first := true
	var stack: Array = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var rel := ref_inv * mi.global_transform
			var a := rel * mi.get_aabb()
			aabb = a if first else aabb.merge(a)
			first = false
		for c in n.get_children():
			stack.append(c)
	return aabb

## 修 Meshy base-color alpha→整模型透明 雷；消光成 matte ink。保留貼圖(albedo_texture)。
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

func _process(delta: float) -> void:
	if _model == null:
		return
	_t += delta
	_model.rotation.z = sin(_t * 1.2) * 0.012
	_model.position.y = _ground_y + sin(_t * 1.6) * 0.02
