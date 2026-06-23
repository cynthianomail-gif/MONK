extends Node3D
## 探索世界站立 NPC：載 Meshy GLB → 修透明材質+消光 → 程式呼吸搖擺(免綁骨)。
## 保留 Meshy 貼圖(源自 okami 立繪、本身水墨味)，靠場景螢幕空間描邊給墨邊。
## ponytail: 不套 ink_toon 平塗(會把 6 NPC 變同色灰、認不出)；要與主角平塗一致再改 _matte→toon。

const NPC_DIR := "res://assets/3d/characters/npcs/"

var _t := 0.0
var _model: Node3D = null

## model_name = GLB 檔名(無副檔)，如 "liaochen"；缺檔則優雅略過(待 Meshy 生成)。
func setup(model_name: String) -> void:
	var path := NPC_DIR + model_name + ".glb"
	if not ResourceLoader.exists(path):
		push_warning("NpcFigure: 模型不存在 %s(先略過)" % path)
		return
	_model = (load(path) as PackedScene).instantiate()
	add_child(_model)
	_fix_materials(_model)

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
	_model.position.y = sin(_t * 1.6) * 0.02
