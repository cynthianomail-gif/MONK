extends Area3D

signal player_entered
signal player_exited

const NPC_FIGURE := preload("res://src/screens/MapScreen/npc_figure.gd")

var location_id: String = ""
var loc_data: Dictionary = {}

func setup(id: String, data: Dictionary) -> void:
	location_id = id
	loc_data = data
	var p: Dictionary = data.get("position_3d", {"x": 0.0, "y": 0.0, "z": 0.0})
	position = Vector3(p.x, p.y, p.z)
	add_to_group("location_trigger")
	var shape := SphereShape3D.new()
	var radius: float = data.get("trigger_radius", 2.5)
	shape.radius = radius
	get_node("CollisionShape3D").shape = shape
	get_node("NameLabel").text = data.get("name", id)
	# 地面金環標記隨觸發半徑縮放（環 mesh 原生外徑 1.72≈半徑 2.5 的視覺佔比）
	var ring_scale := clampf(radius / 2.5, 0.5, 1.4)
	get_node("Marker").scale = Vector3(ring_scale, 1.0, ring_scale)
	if data.has("npc_model") and String(data.get("npc_model", "")) != "":
		var fig: Node3D = NPC_FIGURE.new()
		fig.name = "NpcFigure"
		add_child(fig)
		fig.setup(String(data.npc_model))
		fig.rotation.y = deg_to_rad(float(data.get("npc_facing_deg", 180.0)))

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_start_marker_pulse()

## 金環緩慢呼吸脈動（透明度+微縮放），比舊版綠色實心圓盤低調且更「可互動」。
func _start_marker_pulse() -> void:
	var marker := get_node_or_null("Marker") as MeshInstance3D
	if marker == null:
		return
	var base := marker.scale
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(marker, "scale", base * 1.08, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(marker, "scale", base, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_entered.emit()

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_exited.emit()
