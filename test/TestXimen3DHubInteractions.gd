extends Node

func _ready() -> void:
	var scene := load("res://test/TestXimen3DHub.tscn") as PackedScene
	if scene == null:
		return _fail("TestXimen3DHub scene missing")
	var hub := scene.instantiate()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame

	var hotspots := get_tree().get_nodes_in_group("ximen_hub_hotspot")
	if hotspots.size() != 3:
		return _fail("expected 3 ximen hub hotspots, got %d" % hotspots.size())

	var ids: Array[String] = []
	for h in hotspots:
		if not h.has_meta("hub_action"):
			return _fail("hotspot missing hub_action metadata")
		ids.append(String(h.get_meta("hub_action")))
	ids.sort()
	if ids != ["battle", "exit", "npc"]:
		return _fail("unexpected hotspot actions: %s" % str(ids))

	var hint := hub.get_node_or_null("HUD/Hint") as Label
	if hint == null:
		return _fail("HUD/Hint missing")
	if not hint.text.contains("WASD"):
		return _fail("HUD hint should keep movement instructions")
	var objective := hub.get_node_or_null("HUD/Objective") as Label
	if objective == null:
		return _fail("HUD/Objective missing")
	if not objective.text.contains("Objective:"):
		return _fail("HUD objective should describe the current goal")
	var status := hub.get_node_or_null("HUD/Status") as Label
	if status == null:
		return _fail("HUD/Status missing")
	if not status.text.contains("Ambush"):
		return _fail("HUD status should mention ambush state")
	var street_kit := hub.get_node_or_null("StreetKit") as Node3D
	if street_kit == null:
		return _fail("StreetKit missing")
	if street_kit.get_child_count() < 14:
		return _fail("StreetKit should have at least 14 set dressing props")
	if not hub.has_method("_dialogue_timeline"):
		return _fail("hub should expose dialogue timeline for NPC interaction")
	if hub.call("_dialogue_timeline") != "main_ch1_intel":
		return _fail("NPC interaction should use main_ch1_intel timeline")
	if not hub.has_method("_exit_to_map"):
		return _fail("hub should expose map exit behavior")
	if not hub.has_method("_battle_flag_key"):
		return _fail("hub should expose battle clear flag")
	if hub.call("_battle_flag_key") != "ximen_ambush_cleared":
		return _fail("battle clear flag should be ximen_ambush_cleared")
	if not hub.has_method("_is_hotspot_available"):
		return _fail("hub should expose hotspot availability")
	GameManager.set_flag("ximen_ambush_cleared", false)
	if not bool(hub.call("_is_hotspot_available", "battle")):
		return _fail("battle hotspot should be available before clear flag")
	GameManager.set_flag("ximen_ambush_cleared", true)
	if bool(hub.call("_is_hotspot_available", "battle")):
		return _fail("battle hotspot should hide after clear flag")
	GameManager.set_flag("ximen_ambush_cleared", false)
	if not hub.has_method("_battle_return_scene"):
		return _fail("hub should expose prototype battle return scene")
	if hub.call("_battle_return_scene") != "res://test/TestXimen3DHub.tscn":
		return _fail("prototype battle should return to TestXimen3DHub")
	if not hub.has_method("_prepare_battle_return"):
		return _fail("hub should prepare prototype battle return")
	GameManager.set_flag("battle_return_scene", "")
	GameManager.set_flag("battle_return_restore_last_position", false)
	GameManager.set_flag("battle_clear_flag_on_win", "")
	hub.call("_prepare_battle_return")
	if GameManager.get_flag("battle_return_scene", "") != "res://test/TestXimen3DHub.tscn":
		return _fail("prepare battle return should store return scene")
	if not bool(GameManager.get_flag("battle_return_restore_last_position", false)):
		return _fail("prepare battle return should request position restore")
	if GameManager.get_flag("battle_clear_flag_on_win", "") != "ximen_ambush_cleared":
		return _fail("prepare battle return should store clear flag")
	GameManager.set_flag("battle_return_scene", "")
	GameManager.set_flag("battle_return_restore_last_position", false)
	GameManager.set_flag("battle_clear_flag_on_win", "")
	if not hub.has_method("_restore_last_player_position"):
		return _fail("hub should restore last player position")
	GameManager.player.last_position = {"x": 1.25, "y": 0.08, "z": -2.5}
	hub.call("_restore_last_player_position")
	var player := hub.get_node_or_null("Player") as Node3D
	if player == null:
		return _fail("hub player missing")
	if player.global_position.distance_to(Vector3(1.25, 0.08, -2.5)) > 0.01:
		return _fail("player should restore from GameManager.player.last_position")

	var battle_scene := load("res://src/screens/BattleScreen/BattleScreen.tscn") as PackedScene
	if battle_scene == null:
		return _fail("BattleScreen scene missing")
	var battle := battle_scene.instantiate()
	add_child(battle)
	await get_tree().process_frame
	if not battle.has_method("_apply_battle_victory_hooks"):
		return _fail("BattleManager should expose battle victory hooks")
	GameManager.set_flag("battle_clear_flag_on_win", "ximen_test_clear")
	GameManager.set_flag("ximen_test_clear", false)
	battle.call("_apply_battle_victory_hooks")
	if not bool(GameManager.get_flag("ximen_test_clear", false)):
		return _fail("battle victory hook should set requested clear flag")
	if GameManager.get_flag("battle_clear_flag_on_win", "") != "":
		return _fail("battle victory hook should clear pending flag")
	if not battle.has_method("_return_from_battle"):
		return _fail("BattleManager should expose return-from-battle hook")
	battle.queue_free()

	print("TEST PASS: Ximen 3D hub interactions are present")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("TEST FAIL: %s" % message)
	get_tree().quit(1)
