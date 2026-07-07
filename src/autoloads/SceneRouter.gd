extends Node

enum Transition { SLASH_RED, INK_SPLASH, NEON_FLASH, FADE_BLACK }

## 小遊戲結束、獎勵已套用、即將返回地圖時發出。
## 監聽端（如 QuestManager）可據此推進支線。
signal minigame_finished(minigame_id: String, result: Dictionary)

const TITLE_SCENE:    String = "res://src/screens/TitleScreen/TitleScreen.tscn"
const MAP_SCENE:      String = "res://src/screens/MapScreen/MapScreen.tscn"
const BATTLE_SCENE:   String = "res://src/screens/BattleScreen/BattleScreen.tscn"
const CUTSCENE_SCENE: String = "res://src/screens/CutsceneScreen/CutsceneScreen.tscn"
const STORY_CUTSCENE_SCENE: String = "res://src/screens/CutsceneScreen/StoryCutscene.tscn"
const LOADING_SCENE:  String = "res://src/ui/LoadingScreen.tscn"
const TRANSITION_FX:  String = "res://src/ui/TransitionEffect.tscn"

var _loading_screen: CanvasLayer = null
var _minigame_context: Dictionary = {}
var _active_minigame: String = ""

func go_to_title() -> void:
	await _change_scene(TITLE_SCENE, Transition.FADE_BLACK)

func go_to_map() -> void:
	await _change_scene(MAP_SCENE, Transition.INK_SPLASH)

## 通用換場：返回任意指定場景（戰後回原 3D 探索場景等用）。
func go_to_scene(path: String) -> void:
	await _change_scene(path, Transition.INK_SPLASH)

func go_to_battle(enemy_id: String) -> void:
	_store_player_position()
	await _change_scene(BATTLE_SCENE, Transition.SLASH_RED)
	# change_scene_to_file 是延遲換場，換場後第一幀群組可能還查不到（同 play_cutscene 的等待迴圈）。
	var bm := get_tree().get_first_node_in_group("battle_manager")
	var tries := 0
	while bm == null and tries < 10:
		await get_tree().process_frame
		bm = get_tree().get_first_node_in_group("battle_manager")
		tries += 1
	if bm and bm.has_method("setup"):
		bm.setup(enemy_id)
	else:
		push_error("SceneRouter: 換場後找不到 battle_manager，戰鬥未初始化（enemy_id=%s）" % enemy_id)

## 全螢幕過場：切到 CutsceneScreen 場景、播完後依 next_scene 轉場
## （next_scene == "map" 回地圖；其他非空字串視為下一段過場 id 串接）。
func play_cutscene(cutscene_id: String, next_scene: String = "map") -> void:
	if not ResourceLoader.exists(CUTSCENE_SCENE):
		push_warning("SceneRouter: CutsceneScreen 尚未實作，略過過場 %s" % cutscene_id)
		if next_scene == "map":
			go_to_map()
		return
	await _change_scene(CUTSCENE_SCENE, Transition.FADE_BLACK)
	var cs := get_tree().current_scene
	var tries := 0
	while (cs == null or not cs.has_method("play")) and tries < 10:
		await get_tree().process_frame
		cs = get_tree().current_scene
		tries += 1
	if cs and cs.has_method("play"):
		cs.play(cutscene_id)
		await cs.finished
	if next_scene == "map":
		go_to_map()
	elif next_scene != "":
		play_cutscene(next_scene)

## 劇情過場（分鏡＋字幕，StoryCutscene）：全螢幕播放主線敘事過場，
## 播完依 next 轉場（"map" 回地圖）。供開場與神祇登場使用。
func play_story_cutscene(cutscene_id: String, next_scene: String = "map") -> void:
	if not ResourceLoader.exists(STORY_CUTSCENE_SCENE):
		push_warning("SceneRouter: StoryCutscene 尚未實作，略過 %s" % cutscene_id)
		if next_scene == "map":
			go_to_map()
		return
	await _change_scene(STORY_CUTSCENE_SCENE, Transition.FADE_BLACK)
	var cs := get_tree().current_scene
	var tries := 0
	while (cs == null or not cs.has_method("play")) and tries < 10:
		await get_tree().process_frame
		cs = get_tree().current_scene
		tries += 1
	if cs and cs.has_method("play"):
		cs.play(cutscene_id)
		await cs.finished
	if next_scene == "map":
		go_to_map()
	elif next_scene != "":
		play_story_cutscene(next_scene)

## 戰鬥內過場：把 CutsceneScreen 疊加在目前場景（如戰鬥）之上播放，
## 播完移除並返回，呼叫端可 await 後繼續原本的流程（戰鬥狀態不受影響）。
func play_battle_cutscene(cutscene_id: String) -> void:
	if not ResourceLoader.exists(CUTSCENE_SCENE):
		push_warning("SceneRouter: CutsceneScreen 尚未實作，略過戰鬥過場 %s" % cutscene_id)
		return
	var root := get_tree().current_scene
	if root == null:
		return
	# 戰鬥 UI（BattleUI）是 CanvasLayer（layer 1），過場是普通 Control（layer 0）會被它蓋住，
	# 所以用高 layer 的 CanvasLayer 包住過場，確保疊在戰鬥畫面「最上層」可見。
	var overlay := CanvasLayer.new()
	overlay.layer = 128
	root.add_child(overlay)
	# 全螢幕黑色遮罩做淡入淡出：進場前「淡入全黑→黑幕下換成過場→淡出顯示過場」，
	# 播完「淡入全黑→移除過場→淡出回到戰鬥」，藏住戰鬥↔過場的硬切。
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(cover)
	const FADE := 0.3
	# 1) 戰鬥 → 淡入全黑
	await _fade_cover(cover, 1.0, FADE)
	# 2) 黑幕下放入過場並開始播放（遮罩維持在最上層）
	var cs: Node = load(CUTSCENE_SCENE).instantiate()
	overlay.add_child(cs)
	overlay.move_child(cover, overlay.get_child_count() - 1)
	if cs.has_method("play"):
		cs.play(cutscene_id)
	# 3) 淡出黑幕 → 顯示過場
	await _fade_cover(cover, 0.0, FADE)
	# 4) 等過場播完（可被玩家跳過）
	if cs.has_signal("finished"):
		await cs.finished
	# 5) 過場 → 淡入全黑
	await _fade_cover(cover, 1.0, FADE)
	# 6) 移除過場、淡出黑幕 → 回到戰鬥
	cs.queue_free()
	await _fade_cover(cover, 0.0, FADE)
	overlay.queue_free()


## 全螢幕遮罩淡入/淡出到指定 alpha（給 play_battle_cutscene 的進出轉場用）。
func _fade_cover(rect: ColorRect, alpha: float, dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(rect, "color:a", alpha, dur)
	await tw.finished

## 小遊戲過場短片（規格 2026-07-04 minigame-overhaul-design.md §4）：
## CanvasLayer(128) 疊加逐幀播放（CutsceneScreen 格式：frame_%04d.png 12fps + audio.ogg，
## 沿用 play_battle_cutscene 的淡入淡出轉場）。
## 素材目錄 res://assets/cutscenes/<clip_id>/ 不存在時立即回傳 null，不擋流程
## （沿用鳥居缺檔的優雅跳過模式）。
## 播完（或按任意鍵/滑鼠跳過，跳過也會先跳到最後一幀）停在最後一幀，
## 回傳疊加用的 CanvasLayer，交給呼叫端決定何時用 dismiss_minigame_cutscene 移除
## （開場：淡出後直接進入遊戲；結尾：結算面板出現前先移除，見 MinigameBase.show_result_panel）。
## instant_cover=true（開場片用）：overlay 立刻不透明蓋住（不從遊戲畫面淡入）＝杜絕閃現，
## 且 overlay 標 PROCESS_MODE_ALWAYS，讓小遊戲場景被凍結（go_to_minigame DISABLED）時短片照播。
## 預設 false 供結尾片沿用舊行為（從遊戲畫面淡到黑再顯示過場）。
func play_minigame_cutscene(clip_id: String, instant_cover: bool = false) -> CanvasLayer:
	var dir: String = "res://assets/cutscenes/%s/" % clip_id
	if not ResourceLoader.exists(dir + "frame_0001.png"):
		return null
	if not ResourceLoader.exists(CUTSCENE_SCENE):
		return null
	var root := get_tree().current_scene
	if root == null:
		return null
	var overlay := CanvasLayer.new()
	overlay.layer = 128
	if instant_cover:
		overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(overlay)
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 1.0 if instant_cover else 0.0)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(cover)
	const FADE := 0.3
	if not instant_cover:
		await _fade_cover(cover, 1.0, FADE)
	var cs: Node = load(CUTSCENE_SCENE).instantiate()
	overlay.add_child(cs)
	overlay.move_child(cover, overlay.get_child_count() - 1)
	# 先用 connect（而非等淡出結束才 await cs.finished）記下播放完成旗標：
	# 玩家有可能在淡出轉場的 0.3s 窗口內就按鍵/點滑鼠跳過，若等到淡出結束才建立
	# await 訂閱，中間這段時間發出的 finished 訊號會因為還沒人在聽而遺失，
	# 導致下面的等待永遠等不到（已在 TestMinigameCutscene 實測到這個競態）。
	var cs_done := {"v": false}
	if cs.has_signal("finished"):
		cs.finished.connect(func() -> void: cs_done.v = true, CONNECT_ONE_SHOT)
	if cs.has_method("play"):
		cs.play(clip_id, true)   # skip_to_last=true：小遊戲過場跳過也停在最後一幀
	await _fade_cover(cover, 0.0, FADE)
	while not cs_done.v:
		await get_tree().process_frame
	return overlay   # 仍在樹上，停在最後一幀；由呼叫端決定何時 dismiss

## 淡出並移除 play_minigame_cutscene 回傳的 overlay。overlay 為 null（缺檔跳過）時安全不做事。
func dismiss_minigame_cutscene(overlay: CanvasLayer) -> void:
	if overlay == null or not is_instance_valid(overlay):
		return
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(cover)
	await _fade_cover(cover, 1.0, 0.3)
	overlay.queue_free()

## 啟動小遊戲。context 可帶情境（如支線 win/lose 獎勵 dict），
## 結束時由 finish_minigame 依 result.win 套用。
## 載入場景後、遊戲開始前播 minigame_<id>_intro（缺檔優雅跳過，不擋流程）；
## 「再玩一次」重玩時不會再走這條路徑，所以開場片天然只播一次。
func go_to_minigame(minigame_id: String, context: Dictionary = {}) -> void:
	var path: String = "res://src/screens/Minigames/%s.tscn" % minigame_id.to_pascal_case()
	if not ResourceLoader.exists(path):
		push_warning("SceneRouter: 小遊戲 %s 尚未實作" % minigame_id)
		_minigame_context = {}
		_active_minigame = ""
		return
	_minigame_context = context
	_active_minigame = minigame_id
	await _change_scene(path, Transition.NEON_FLASH)
	# change_scene_to_file 是延遲換場：換場後這一幀 current_scene 仍可能是 null
	# （同 play_cutscene/play_story_cutscene/go_to_battle 的等待迴圈）。play_minigame_cutscene
	# 需要 current_scene 當開場 overlay 的掛載點，null 會讓它直接回傳 null＝整段 intro 被跳過，
	# 這正是「所有小遊戲都看不到開場動畫」的成因（2026-07-07 實測 cur=<null>）。先等場景落定再播。
	# 換場結束到開場片接手前，先用一層不透明黑幕蓋住畫面（layer 127＝壓在讀取畫面 128
	# 之下、小遊戲畫面 0 之上），杜絕小遊戲畫面「閃現一下」（2026-07-07 使用者回報）。
	var guard := CanvasLayer.new()
	guard.layer = 127
	var guard_rect := ColorRect.new()
	guard_rect.color = Color(0, 0, 0, 1)
	guard_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	guard_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guard.add_child(guard_rect)
	get_tree().root.add_child(guard)
	while get_tree().current_scene == null:
		await get_tree().process_frame
	# 開場片要「整段播完才開始玩」，不能疊在已開跑的遊戲上（否則棒球早就投出去、
	# 玩家看完片才發現沒揮到棒——2026-07-07 使用者回報）。把小遊戲場景整個凍結
	# （PROCESS_MODE_DISABLED：連 _process/tween/timer 全停），開場 overlay 自標 ALWAYS 照播。
	# 用「場景層級 DISABLED」而非 get_tree().paused，才不會一起凍到還在淡出的讀取畫面
	# （LoadingScreen 是 root 的子節點、用 tween 淡出，被 paused 凍住會卡在畫面上）。
	var game_scene := get_tree().current_scene
	game_scene.process_mode = Node.PROCESS_MODE_DISABLED
	var overlay := await play_minigame_cutscene("minigame_%s_intro" % minigame_id, true)
	guard.queue_free()   # 開場 overlay（或缺檔時的凍結遊戲）已接手畫面，撤黑幕
	await dismiss_minigame_cutscene(overlay)
	# 開場片播完、淡出結束，才解凍讓小遊戲真正開始（第一球/第一手從這一刻才動）。
	if is_instance_valid(game_scene):
		game_scene.process_mode = Node.PROCESS_MODE_INHERIT

## 目前這局小遊戲是否帶 quest context 啟動（供小遊戲自身區分「支線場」vs「常駐休閒場」
## 的內建獎勵，如三僧木魚：支線 win merit=3、休閒重玩 win merit=1）。
func has_minigame_quest_context() -> bool:
	return not _minigame_context.is_empty()

## 由 MinigameBase.finish() 呼叫：套用獎勵、回報結果、返回地圖
## （或 context.return_scene 指定的原 3D 場景）。
func finish_minigame(result: Dictionary) -> void:
	var ctx := _minigame_context
	var id: String = result.get("id", _active_minigame)
	_minigame_context = {}
	_active_minigame = ""
	# ① intrinsic 獎勵
	if int(result.get("gold", 0)) != 0:
		GameManager.add_gold(int(result.gold))
	if int(result.get("merit", 0)) != 0:
		GameManager.add_merit(int(result.merit))
	if int(result.get("karma", 0)) != 0:
		GameManager.add_karma(int(result.karma))
	# ② 支線 win/lose 獎勵（quests.json 的 win/lose dict）
	var branch: Dictionary = ctx.get("quest_win", {}) if result.get("win", false) else ctx.get("quest_lose", {})
	_apply_quest_reward(branch)
	# ③ 回報並返回。context 可帶 return_scene 指定回原 3D 場景
	#（如地下遊藝場房間），沒帶或場景不存在則照舊回城市地圖。
	minigame_finished.emit(id, result)
	var return_scene := String(ctx.get("return_scene", ""))
	if return_scene != "" and ResourceLoader.exists(return_scene):
		go_to_scene(return_scene)
	else:
		go_to_map()

## 套用 quests.json 風格的獎勵 dict（gold/merit/karma/flag/unlock_skill/hp_max_up）。
func _apply_quest_reward(reward: Dictionary) -> void:
	if reward.is_empty():
		return
	if reward.has("gold"):
		GameManager.add_gold(int(reward.gold))
	if reward.has("merit"):
		GameManager.add_merit(int(reward.merit))
	if reward.has("karma"):
		GameManager.add_karma(int(reward.karma))
	if reward.has("flag"):
		GameManager.set_flag(reward.flag, true)
	if reward.has("hp_max_up"):
		GameManager.player.max_hp += int(reward.hp_max_up)
	if reward.has("unlock_skill"):
		SkillUnlockManager.grant_skill(reward.unlock_skill)

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
	# 防呆：正常流程 _hide_loading 會把 _loading_screen 清為 null，此處應為 null。
	# 但萬一兩次換場並發（前一個讀取畫面還沒 hide 就被新的一次覆寫參照），舊 CanvasLayer
	# 會失去參照變孤兒、永不隱藏＝卡讀取。開新的之前先移除殘留，確保同時只有一個。
	if _loading_screen != null and is_instance_valid(_loading_screen):
		_loading_screen.queue_free()
	_loading_screen = load(LOADING_SCENE).instantiate() as CanvasLayer
	get_tree().root.add_child(_loading_screen)

func _hide_loading() -> void:
	if _loading_screen == null:
		return
	var ls := _loading_screen
	_loading_screen = null
	# CanvasLayer 沒有 modulate 屬性，淡出交給場景自身的 fade_out()。
	if ls.has_method("fade_out"):
		ls.fade_out(0.3)
	else:
		ls.queue_free()
