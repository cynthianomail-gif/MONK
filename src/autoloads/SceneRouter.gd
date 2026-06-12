extends Node

enum Transition { SLASH_RED, INK_SPLASH, NEON_FLASH, FADE_BLACK }

const TITLE_SCENE:    String = "res://src/screens/TitleScreen/TitleScreen.tscn"
const MAP_SCENE:      String = "res://src/screens/MapScreen/MapScreen.tscn"
const BATTLE_SCENE:   String = "res://src/screens/BattleScreen/BattleScreen.tscn"
const CUTSCENE_SCENE: String = "res://src/screens/CutsceneScreen/CutsceneScreen.tscn"
const LOADING_SCENE:  String = "res://src/ui/LoadingScreen.tscn"
const TRANSITION_FX:  String = "res://src/ui/TransitionEffect.tscn"

var _loading_screen: CanvasLayer = null

func go_to_title() -> void:
	await _change_scene(TITLE_SCENE, Transition.FADE_BLACK)

func go_to_map() -> void:
	await _change_scene(MAP_SCENE, Transition.INK_SPLASH)

func go_to_battle(enemy_id: String) -> void:
	_store_player_position()
	await _change_scene(BATTLE_SCENE, Transition.SLASH_RED)
	var bm := get_tree().get_first_node_in_group("battle_manager")
	if bm and bm.has_method("setup"):
		bm.setup(enemy_id)

func play_cutscene(cutscene_id: String, next_scene: String = "map") -> void:
	if not ResourceLoader.exists(CUTSCENE_SCENE):
		push_warning("SceneRouter: CutsceneScreen 尚未實作，略過過場 %s" % cutscene_id)
		if next_scene == "map":
			go_to_map()
		return
	await _change_scene(CUTSCENE_SCENE, Transition.FADE_BLACK)
	var cs := get_tree().current_scene
	if cs and cs.has_method("play"):
		cs.play(cutscene_id, next_scene)

func go_to_minigame(minigame_id: String) -> void:
	var path: String = "res://src/screens/Minigames/%s.tscn" % minigame_id.to_pascal_case()
	if not ResourceLoader.exists(path):
		push_warning("SceneRouter: 小遊戲 %s 尚未實作" % minigame_id)
		return
	await _change_scene(path, Transition.NEON_FLASH)

func _store_player_position() -> void:
	var cur := get_tree().current_scene
	if cur and cur.has_method("get_player_position"):
		var pos: Vector3 = cur.get_player_position()
		GameManager.player.last_position = {"x": pos.x, "y": pos.y, "z": pos.z}

func _change_scene(path: String, transition: Transition) -> void:
	_show_loading()
	await _play_transition(transition)
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	_hide_loading()

func _play_transition(transition: Transition) -> void:
	if not ResourceLoader.exists(TRANSITION_FX):
		await get_tree().process_frame
		return
	var fx: Node = load(TRANSITION_FX).instantiate()
	get_tree().root.add_child(fx)
	fx.play(transition)
	await fx.finished
	fx.queue_free()

func _show_loading() -> void:
	if not ResourceLoader.exists(LOADING_SCENE):
		return
	_loading_screen = load(LOADING_SCENE).instantiate() as CanvasLayer
	get_tree().root.add_child(_loading_screen)

func _hide_loading() -> void:
	if _loading_screen == null:
		return
	var tw := create_tween()
	tw.tween_property(_loading_screen, "modulate:a", 0.0, 0.3)
	tw.tween_callback(_loading_screen.queue_free)
	_loading_screen = null
