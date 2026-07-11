extends Node

const ARMORY_SCENE := preload("res://src/screens/MapScreen/environments/ArmoryDistrict.tscn")
const PARLOR_SCENE := preload("res://src/screens/MapScreen/environments/UndergroundParlor.tscn")
const SOUP_SCENE := preload("res://src/screens/Minigames/SoupCarry.tscn")
const SHRINE_SCENE := preload("res://src/screens/MapScreen/environments/ShrineStreet.tscn")

var ok := true

func _ready() -> void:
	await _test_shrine()
	await _test_armory()
	await _test_parlor()
	await _test_soup()
	print("ENVIRONMENT_POLISH_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

func _test_shrine() -> void:
	var scene := SHRINE_SCENE.instantiate()
	add_child(scene)
	await _settle()
	var architecture := scene.get_node_or_null("ShrineArchitecture")
	_check(architecture != null, "shrine has ShrineArchitecture root")
	if architecture != null:
		_check(_has_children(architecture, ["SideStreetEndcap", "ShrineForecourt", "ToriiDetails", "BackdropDepth", "TownDetails"]), "shrine architecture modules exist")
		_check(_count_type(architecture, "MeshInstance3D") >= 42, "shrine architecture has at least 42 meshes")
	var shops := get_tree().get_nodes_in_group("shrine_shop")
	_check(shops.size() >= 8, "shrine keeps a full shop-lined hub")
	var archetypes := {}
	for shop in shops:
		if scene.is_ancestor_of(shop):
			archetypes[int(shop.get_meta("archetype", -1))] = true
	_check(archetypes.size() >= 3, "shrine exposes three shop archetypes")
	var cobble := _find_shader_material(scene, "cobblestone.gdshader")
	_check(cobble != null, "shrine has cobblestone material")
	if cobble != null:
		_check(float(cobble.get_shader_parameter("stone_size")) <= 0.42, "shrine cobbles are street-scale")
		var bump_value = cobble.get_shader_parameter("bump")
		_check(typeof(bump_value) == TYPE_FLOAT and bump_value <= 0.35, "shrine cobbles have restrained bump")
	var world_env := _find_world_environment(scene)
	_check(world_env != null, "shrine has WorldEnvironment")
	if world_env != null:
		_check(world_env.environment.ambient_light_energy >= 0.54, "shrine morning shadow split is softened")
	var paper_lanterns := _group_descendants(scene, "shrine_paper_lantern")
	_check(paper_lanterns.size() >= 4, "shrine uses multiple paper lantern bodies")
	for lantern in paper_lanterns:
		_check(lantern is MeshInstance3D and (lantern as MeshInstance3D).mesh is CylinderMesh, "shrine lantern body is cylindrical")
	var canopies := _group_descendants(scene, "shrine_sakura_canopy")
	_check(canopies.size() >= 12, "shrine has layered sakura canopy clusters")
	for canopy in canopies:
		_check((canopy as Node3D).scale.y <= 0.70, "sakura clusters avoid perfect spheres")
	var backdrop_trees := _group_descendants(scene, "shrine_backdrop_tree")
	_check(backdrop_trees.size() >= 12, "shrine has a full backdrop tree line")
	for tree in backdrop_trees:
		var tree_mesh := (tree as MeshInstance3D).mesh as CylinderMesh
		_check(tree_mesh != null and tree_mesh.top_radius >= 0.12 and tree_mesh.height <= 17.0, "backdrop trees avoid needle spikes")
	await _remove_scene(scene)

func _check(condition: bool, message: String) -> void:
	if not condition:
		ok = false
		print("FAIL: ", message)

func _test_armory() -> void:
	var scene := ARMORY_SCENE.instantiate()
	add_child(scene)
	await _settle()
	var architecture := scene.get_node_or_null("ArmoryArchitecture")
	_check(architecture != null, "armory has ArmoryArchitecture root")
	if architecture != null:
		_check(_has_children(architecture, ["Gantries", "PipeRuns", "StorageTanks", "FacadeFrames"]), "armory architecture modules exist")
		_check(_count_type(architecture, "MeshInstance3D") >= 24, "armory architecture has at least 24 meshes")
		var cool_fill := architecture.get_node_or_null("ArmoryCoolFill") as OmniLight3D
		_check(cool_fill != null and cool_fill.light_color.b > cool_fill.light_color.r, "armory has cool fill against forge light")
	var cobble := _find_shader_material(scene, "cobblestone.gdshader")
	_check(cobble != null, "armory has cobblestone material")
	if cobble != null:
		_check(float(cobble.get_shader_parameter("stone_size")) <= 0.5, "armory cobbles are street-scale")
		_check(float(cobble.get_shader_parameter("bump")) <= 0.35, "armory cobbles do not overpower the architecture")
	await _remove_scene(scene)

func _test_parlor() -> void:
	var scene := PARLOR_SCENE.instantiate()
	add_child(scene)
	await _settle()
	var architecture := scene.get_node_or_null("ParlorArchitecture")
	_check(architecture != null, "parlor has ParlorArchitecture root")
	if architecture != null:
		_check(_has_children(architecture, ["StationAlcoves", "CeilingTrusses", "Partitions", "WallPanels"]), "parlor architecture modules exist")
		_check(_count_type(architecture, "MeshInstance3D") >= 24, "parlor architecture has at least 24 meshes")
		var trusses := architecture.get_node_or_null("CeilingTrusses")
		_check(trusses != null and _lowest_mesh_point(trusses) >= 4.0, "parlor trusses stay above the play view")
	var world_env := _find_world_environment(scene)
	_check(world_env != null, "parlor has WorldEnvironment")
	if world_env != null:
		_check(world_env.environment.adjustment_saturation <= 1.0, "parlor saturation is restrained")
		_check(world_env.environment.glow_intensity <= 0.6, "parlor bloom is restrained")
	await _remove_scene(scene)

func _test_soup() -> void:
	var scene := SOUP_SCENE.instantiate()
	scene.auto_start = false
	add_child(scene)
	await _settle()
	var architecture := scene.get_node_or_null("World3D/SoupArchitecture")
	_check(architecture != null, "soup has SoupArchitecture root")
	if architecture != null:
		_check(_has_children(architecture, ["WoodFloor", "WallFrames", "KitchenShelves", "MenuBoards"]), "soup architecture modules exist")
		_check(_count_type(architecture, "MeshInstance3D") >= 36, "soup architecture has at least 36 meshes")
	var world_env := _find_world_environment(scene)
	_check(world_env != null, "soup has WorldEnvironment")
	if world_env != null:
		_check(world_env.environment.ambient_light_energy >= 0.85, "soup ambient light is readable")
	var intro_rules := scene.find_child("IntroRules", true, false) as Label
	_check(intro_rules != null, "soup intro rules have a stable visual node")
	if intro_rules != null:
		_check(intro_rules.position.y <= 240.0, "soup intro rules stay above the horizon")
		_check(intro_rules.get_theme_font_size("font_size") <= 28, "soup intro rules use compact type")
	await _remove_scene(scene)

func _settle() -> void:
	for i in 4:
		await get_tree().process_frame

func _remove_scene(scene: Node) -> void:
	scene.queue_free()
	await get_tree().process_frame

func _has_children(root: Node, names: Array[String]) -> bool:
	for child_name in names:
		if root.get_node_or_null(child_name) == null:
			return false
	return true

func _group_descendants(root: Node, group_name: StringName) -> Array:
	var result: Array = []
	for node in get_tree().get_nodes_in_group(group_name):
		if root.is_ancestor_of(node):
			result.append(node)
	return result

func _count_type(root: Node, class_name_to_count: String) -> int:
	var count := 1 if root.is_class(class_name_to_count) else 0
	for child in root.get_children():
		count += _count_type(child, class_name_to_count)
	return count

func _find_world_environment(root: Node) -> WorldEnvironment:
	if root is WorldEnvironment:
		return root as WorldEnvironment
	for child in root.get_children():
		var found := _find_world_environment(child)
		if found != null:
			return found
	return null

func _find_shader_material(root: Node, shader_suffix: String) -> ShaderMaterial:
	if root is MeshInstance3D:
		var material := (root as MeshInstance3D).material_override
		if material is ShaderMaterial:
			var shader := (material as ShaderMaterial).shader
			if shader != null and shader.resource_path.ends_with(shader_suffix):
				return material as ShaderMaterial
	for child in root.get_children():
		var found := _find_shader_material(child, shader_suffix)
		if found != null:
			return found
	return null

func _lowest_mesh_point(root: Node) -> float:
	var lowest := INF
	if root is MeshInstance3D:
		var mesh_instance := root as MeshInstance3D
		lowest = minf(lowest, (mesh_instance.transform * mesh_instance.get_aabb()).position.y)
	for child in root.get_children():
		lowest = minf(lowest, _lowest_mesh_point(child))
	return lowest
