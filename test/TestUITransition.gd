extends Node
## headless 煙霧測試：LoadingScreen 與 TransitionEffect。
## 跑法：Godot --headless res://test/TestUITransition.tscn
## 驗證：LoadingScreen 能建立並經 fade_out 自我釋放；4 種轉場各自 play→emit finished。

func _ready() -> void:
	await get_tree().process_frame
	var ok := true

	# --- LoadingScreen ---
	var ls_scene: PackedScene = load("res://src/ui/LoadingScreen.tscn")
	if ls_scene == null:
		print("FAIL: 無法載入 LoadingScreen.tscn"); ok = false
	else:
		var ls: Node = ls_scene.instantiate()
		get_tree().root.add_child(ls)
		await get_tree().create_timer(0.6).timeout  # 跑佛語循環 + 至少一次木魚
		if not ls.has_method("fade_out"):
			print("FAIL: LoadingScreen 缺 fade_out()"); ok = false
		else:
			ls.fade_out(0.1)
			await get_tree().create_timer(0.35).timeout
			if is_instance_valid(ls):
				print("FAIL: LoadingScreen fade_out 後未釋放"); ok = false

	# --- TransitionEffect x4 ---
	var fx_scene: PackedScene = load("res://src/ui/TransitionEffect.tscn")
	if fx_scene == null:
		print("FAIL: 無法載入 TransitionEffect.tscn"); ok = false
	else:
		for t in [
			SceneRouter.Transition.SLASH_RED,
			SceneRouter.Transition.INK_SPLASH,
			SceneRouter.Transition.NEON_FLASH,
			SceneRouter.Transition.FADE_BLACK,
		]:
			var fx: Node = fx_scene.instantiate()
			get_tree().root.add_child(fx)
			var fired := {"v": false}
			fx.finished.connect(func() -> void: fired["v"] = true)
			fx.play(t)
			await fx.finished
			if not fired["v"]:
				print("FAIL: 轉場 %d 未發出 finished" % t); ok = false
			fx.queue_free()
			await get_tree().process_frame

	print("UI_TRANSITION_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)
