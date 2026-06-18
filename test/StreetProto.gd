extends Node3D
## 西門霓虹街原型：可走場景。方向鍵移動。
## 跑法：Godot res://test/StreetProto.tscn（要 GPU 視窗才看得到霓虹/霧/雨）。

const XimenStreet := preload("res://src/screens/MapScreen/environments/XimenStreet.gd")
const PlayerController := preload("res://src/screens/MapScreen/PlayerController.gd")
const CameraRig := preload("res://src/screens/MapScreen/CameraRig.gd")

func _ready() -> void:
	# 街景環境
	var street := XimenStreet.new()
	add_child(street)

	# 玩家（膠囊佔位，PlayerController 需要 $MeshRoot）
	var player := CharacterBody3D.new()
	player.name = "Player"
	player.set_script(PlayerController)
	player.add_to_group("player")
	player.position = Vector3(0, 1.2, 0)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	col.shape = cap
	col.position = Vector3(0, 0.9, 0)
	player.add_child(col)
	var mesh_root := Node3D.new()
	mesh_root.name = "MeshRoot"
	player.add_child(mesh_root)
	# 占位人形（暗袈裟身＋頭）；正牌 3D 無戒之後走 Meshy
	var torso := MeshInstance3D.new()
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.27
	torso_mesh.height = 1.15
	var robe := StandardMaterial3D.new()
	robe.albedo_color = Color(0.30, 0.30, 0.36)
	torso_mesh.material = robe
	torso.mesh = torso_mesh
	torso.position = Vector3(0, 0.95, 0)
	mesh_root.add_child(torso)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.17
	head_mesh.height = 0.34
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.82, 0.66, 0.52)
	head_mesh.material = skin
	head.mesh = head_mesh
	head.position = Vector3(0, 1.66, 0)
	mesh_root.add_child(head)
	add_child(player)

	# 相機（壓低角度展示霓虹街谷）
	var rig := Node3D.new()
	rig.name = "CameraRig"
	rig.set_script(CameraRig)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.current = true
	cam.fov = 60.0
	rig.add_child(cam)
	rig.set("target_path", NodePath("../Player"))
	rig.set("camera_offset", Vector3(0, 3.4, 5.2))   # 過肩：更低更近（原 y4.6/z7.2）
	add_child(rig)
	cam.rotation_degrees.x = -12.0                    # 過肩微俯（原 -20）

	# 操作提示
	var hud := CanvasLayer.new()
	var lbl := Label.new()
	lbl.text = "西門霓虹街原型　·　方向鍵移動"
	lbl.position = Vector2(28, 24)
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	hud.add_child(lbl)
	add_child(hud)
