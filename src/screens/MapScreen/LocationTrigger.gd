extends Area3D

signal player_entered
signal player_exited

const NPC_FIGURE := preload("res://src/screens/MapScreen/npc_figure.gd")

## 主線可推進點的橘色（2026-07-10：跟支線黃/金一眼可分，見 Minimap.gd DOT_QUEST_MAIN 同色系）。
const MAIN_QUEST_ALBEDO := Color(1.0, 0.45, 0.08, 0.8)
const MAIN_QUEST_EMISSION := Color(1.0, 0.42, 0.05, 1.0)

var location_id: String = ""
var loc_data: Dictionary = {}
var _default_mat: StandardMaterial3D = null
var _main_quest_mat: StandardMaterial3D = null

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
	# 地面金環標記隨觸發半徑縮放（環 mesh 原生外徑 1.72≈半徑 2.5 的視覺佔比）
	var ring_scale := clampf(radius / 2.5, 0.5, 1.4)
	get_node("Marker").scale = Vector3(ring_scale, 1.0, ring_scale)
	if data.has("npc_model") and String(data.get("npc_model", "")) != "":
		var fig: Node3D = NPC_FIGURE.new()
		fig.name = "NpcFigure"
		add_child(fig)
		fig.setup(String(data.npc_model))
		fig.rotation.y = deg_to_rad(float(data.get("npc_facing_deg", 180.0)))
	_refresh_marker_color()

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_start_marker_pulse()
	# 主線可推進點會隨進度移動（例如 armory_unlocked 之後鐵叔的 main_quest 動作改變門檻），
	# 用旗標變動來刷新橘/金——主線與支線的可觸發判斷都吃 flags/completed_quests，
	# flag_changed 是涵蓋面最廣的單一訊號（同 AchievementSystem 監聽慣例）。
	if not GameManager.flag_changed.is_connected(_on_flag_changed):
		GameManager.flag_changed.connect(_on_flag_changed)

func _on_flag_changed(_key: String, _val: Variant) -> void:
	_refresh_marker_color()

## 依 loc_data 目前是否有「現在可推進的主線」決定地面環顏色：橘＝主線、金＝原色（含支線／地標）。
## 用 MeshInstance3D.set_surface_override_material（每個實例各自獨立），不直接改 mesh.material——
## TorusMesh 是 .tscn 裡的共用 sub-resource，載入一次、instantiate 多份時所有觸發點共用同一個
## mesh 物件，直接改 mesh.material 會讓「一個點變橘」波及全地圖所有觸發點的地面環顏色。
func _refresh_marker_color() -> void:
	var marker := get_node_or_null("Marker") as MeshInstance3D
	if marker == null or marker.mesh == null:
		return
	if _default_mat == null:
		var existing := marker.get_active_material(0)
		_default_mat = (existing as StandardMaterial3D) if existing is StandardMaterial3D else (marker.mesh.material as StandardMaterial3D)
	var is_main: bool = QuestManager.location_has_main_quest(loc_data)
	if is_main:
		if _main_quest_mat == null:
			_main_quest_mat = (_default_mat.duplicate() if _default_mat != null else StandardMaterial3D.new()) as StandardMaterial3D
			_main_quest_mat.albedo_color = MAIN_QUEST_ALBEDO
			_main_quest_mat.emission = MAIN_QUEST_EMISSION
		marker.set_surface_override_material(0, _main_quest_mat)
	else:
		marker.set_surface_override_material(0, null)   # null＝還原用 mesh 原生材質（金）

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
