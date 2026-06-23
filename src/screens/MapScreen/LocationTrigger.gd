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
	shape.radius = data.get("trigger_radius", 2.5)
	get_node("CollisionShape3D").shape = shape
	get_node("NameLabel").text = data.get("name", id)
	if data.has("npc_model") and String(data.get("npc_model", "")) != "":
		var fig: Node3D = NPC_FIGURE.new()
		fig.name = "NpcFigure"
		add_child(fig)
		fig.setup(String(data.npc_model))
		fig.rotation.y = deg_to_rad(float(data.get("npc_facing_deg", 180.0)))

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_entered.emit()

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_exited.emit()
