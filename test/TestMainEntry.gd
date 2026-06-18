extends Node
## headless 測試：主線進入點（AchievementSystem + 手機任務 app）。
## 跑法：Godot --headless res://test/TestMainEntry.tscn

var ok := true
var _ach_signals: Array = []

const PURIFIED := ["ares_purified", "hermes_purified", "poseidon_purified", "demeter_purified",
	"hephaestus_purified", "aphrodite_purified", "apollo_purified", "dionysus_purified",
	"artemis_purified", "athena_purified", "hera_purified", "ending_true"]

func _ready() -> void:
	await get_tree().process_frame
	_setup_clean_flags()
	_test_totals_and_order()
	_test_unlock_derivation()
	_test_unlock_signal_and_dedup()
	await _smoke_quests_app()
	await _smoke_phone_menu()
	print("MAIN_ENTRY_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		ok = false
		print("FAIL: ", msg)

func _setup_clean_flags() -> void:
	for f in PURIFIED:
		GameManager.player.flags.erase(f)

func _test_totals_and_order() -> void:
	var a := AchievementSystem
	_check(a.total() == 12, "total==12 (got %d)" % a.total())
	_check(a.unlocked_count() == 0, "unlocked_count==0 clean (got %d)" % a.unlocked_count())
	var all := a.get_all()
	_check(all.size() == 12, "get_all size 12 (got %d)" % all.size())
	if all.size() == 12:
		_check(all[0].id == "ignorance" and int(all[0].chapter) == 1, "first=ignorance ch1")
		_check(all[11].id == "aging_death" and int(all[11].chapter) == 12, "last=aging_death ch12")
		var prev := 0
		var ordered := true
		for it in all:
			if int(it.chapter) < prev:
				ordered = false
			prev = int(it.chapter)
		_check(ordered, "get_all ordered by chapter")
		for it in all:
			_check(not it.unlocked, "all locked clean: %s" % it.id)

func _test_unlock_derivation() -> void:
	var a := AchievementSystem
	GameManager.player.flags.erase("hermes_purified")
	_check(not a.is_unlocked("formation"), "formation locked w/o flag")
	GameManager.set_flag("hermes_purified", true)
	_check(a.is_unlocked("formation"), "formation unlock via flag")
	GameManager.player.flags.erase("hermes_purified")  # 復原

func _test_unlock_signal_and_dedup() -> void:
	var a := AchievementSystem
	a.pending_toasts.clear()
	_ach_signals.clear()
	EventBus.achievement_unlocked.connect(_on_ach)
	GameManager.player.flags.erase("ares_purified")
	GameManager.set_flag("ares_purified", true)
	_check(a.is_unlocked("ignorance"), "ignorance unlocked after flag")
	_check(a.unlocked_count() == 1, "unlocked_count==1 (got %d)" % a.unlocked_count())
	_check(_ach_signals == ["ignorance"], "signal fired once w/ ignorance (got %s)" % str(_ach_signals))
	_check("ignorance" in a.pending_toasts, "pending_toasts has ignorance")
	# 去重：再設同值不重發
	GameManager.set_flag("ares_purified", true)
	_check(_ach_signals == ["ignorance"], "no re-emit on same value (got %s)" % str(_ach_signals))
	EventBus.achievement_unlocked.disconnect(_on_ach)

func _on_ach(id: String) -> void:
	_ach_signals.append(id)

func _smoke_quests_app() -> void:
	var gs := load("res://src/ui/menu/pages/QuestsApp.gd")
	_check(gs != null, "load QuestsApp.gd")
	if gs:
		var page = gs.new()
		get_tree().root.add_child(page)
		for i in 3:
			await get_tree().process_frame
		_check(is_instance_valid(page), "QuestsApp alive")
		page.queue_free()
		await get_tree().process_frame

func _smoke_phone_menu() -> void:
	var ps := load("res://src/ui/menu/MenuShell.tscn")
	_check(ps != null, "load MenuShell.tscn")
	if ps:
		var shell = ps.instantiate()
		shell.set("pause_game", false)
		get_tree().root.add_child(shell)
		for i in 4:
			await get_tree().process_frame
		if shell.has_method("_show_device"):
			shell._show_device("phone")
			await get_tree().process_frame
		_check(is_instance_valid(shell), "phone menu alive")
		shell.queue_free()
		await get_tree().process_frame
