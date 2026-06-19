extends Node3D
## HD-2D 西門街原型：可走場景（方向鍵移動）。
## 重用 Hd2dStreet（世界）＋Hd2dPlayer（厚塗 billboard 主角）＋CameraRig（固定 3/4 俯角跟隨）。
## 跑法：Godot res://test/Hd2dProto.tscn（要 GPU 視窗才看得到 glow/DOF）。

const Hd2dStreet := preload("res://src/screens/MapScreen/environments/Hd2dStreet.gd")
const Hd2dPlayer := preload("res://src/screens/MapScreen/Hd2dPlayer.gd")
const CameraRig := preload("res://src/screens/MapScreen/CameraRig.gd")

func _ready() -> void:
	var street := Hd2dStreet.new()
	street.name = "Hd2dStreet"
	add_child(street)

	# 主角＝焦點主體（站在移軸景深清晰帶內）
	var player := Hd2dPlayer.new()
	player.name = "Player"
	player.position = Vector3(0.0, 1.0, 0.0)
	add_child(player)

	var rig := CameraRig.new()
	rig.name = "CameraRig"
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.current = true
	cam.fov = 48.0
	rig.add_child(cam)
	# 固定 3/4 俯角；offset 先設好再 add_child，讓 CameraRig._ready 套用。
	# 拉近＝主角更大、街谷更壓迫，但維持高俯角箱庭感。
	rig.set("camera_offset", Vector3(0.0, 7.5, 6.0))
	rig.set("camera_pitch_deg", -33.0)
	add_child(rig)

	var hud := CanvasLayer.new()
	var lbl := Label.new()
	lbl.text = "HD-2D 西門街原型　·　方向鍵移動"
	lbl.position = Vector2(28, 24)
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	hud.add_child(lbl)
	add_child(hud)
