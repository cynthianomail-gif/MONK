extends Node
## headless 測試：選單系統地基（SkillUnlockManager 資料驅動重構 + 三職修為）。
## 跑法：Godot --headless res://test/TestMenuSystem.tscn
## 之後會補上 MenuShell/SkillsPage/StatusPage 場景煙霧測試。

var ok: bool = true

func _ready() -> void:
	await get_tree().process_frame
	_test_unlock_states()
	_test_job_mastery()
	_test_check_unlocks()
	_test_learn_skill()
	await _test_learn_badge()
	_test_audio_buses()
	await _test_settings_manager()
	await _smoke_scenes()
	await _test_pending_arrival()
	await _test_travel_app()
	await _test_job_app()
	print("MENU_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		ok = false
		print("FAIL: ", msg)

func _test_unlock_states() -> void:
	var sum := SkillUnlockManager
	# initial：開局已學
	var s := sum.get_unlock_state("basic_punch")
	_check(s.kind == "initial" and s.learned and s.condition_met, "basic_punch initial learned")
	# heat：恆 condition_met、不可學、不入池
	var h := sum.get_unlock_state("tathagata_palm")
	_check(h.kind == "heat" and h.condition_met and not h.learnable, "tathagata_palm heat not learnable")
	# story：羅漢拳未授予時 condition 不成立、不可學、未學
	GameManager.player.skills_unlocked.erase("arhat_strike")
	var st := sum.get_unlock_state("arhat_strike")
	_check(st.kind == "story" and not st.condition_met and not st.learnable and not st.learned,
		"arhat_strike story locked before grant")
	# behavior：5 招改綁之一（ascetic_temper：weakness_hit_count >= 10）
	GameManager.player.skills_unlocked.erase("ascetic_temper")
	GameManager.set_flag("weakness_hit_count", 5)
	var b := sum.get_unlock_state("ascetic_temper")
	_check(b.kind == "behavior" and b.target == 10 and b.current == 5
		and not b.condition_met and not b.learnable,
		"ascetic_temper 5/10 not met (got %d/%d met=%s)" % [b.current, b.target, b.condition_met])
	GameManager.set_flag("weakness_hit_count", 10)
	var b2 := sum.get_unlock_state("ascetic_temper")
	_check(b2.condition_met and b2.learnable and not b2.learned, "ascetic_temper met→learnable at 10")
	# 5 招改綁的 kind 正確
	_check(sum.get_unlock_state("sound_wave").kind == "quest", "sound_wave now quest")
	_check(sum.get_unlock_state("lions_roar").kind == "quest", "lions_roar now quest")
	var bb := sum.get_unlock_state("broken_bowl_beg")
	_check(bb.kind == "behavior" and bb.target == 6, "broken_bowl_beg behavior target 6")
	var sh := sum.get_unlock_state("self_harm")
	_check(sh.kind == "behavior" and sh.target == 5, "self_harm behavior target 5")
	# flag（vajra_glare：ah_ming_saved）
	GameManager.player.skills_unlocked.erase("vajra_glare")
	GameManager.player.flags.erase("ah_ming_saved")
	_check(not sum.get_unlock_state("vajra_glare").learnable, "vajra_glare not learnable w/o flag")
	GameManager.set_flag("ah_ming_saved", true)
	_check(sum.get_unlock_state("vajra_glare").learnable, "vajra_glare learnable w/ flag")
	# quest（great_compassion_shield：完成 zheng_ma）
	GameManager.player.skills_unlocked.erase("great_compassion_shield")
	_check(not sum.get_unlock_state("great_compassion_shield").learnable, "compassion not learnable w/o quest")
	if "zheng_ma" not in GameManager.player.completed_quests:
		GameManager.player.completed_quests.append("zheng_ma")
	_check(sum.get_unlock_state("great_compassion_shield").learnable, "compassion learnable w/ quest")

func _test_job_mastery() -> void:
	var m := SkillUnlockManager.get_job_mastery()
	_check(m.ascetic.total == 6, "ascetic learnable total=6 (got %d)" % m.ascetic.total)
	_check(m.chanter.total == 6, "chanter learnable total=6 (got %d)" % m.chanter.total)
	_check(m.beggar.total == 6, "beggar learnable total=6 (got %d)" % m.beggar.total)
	_check(SkillUnlockManager.get_heat_skill_ids().size() == 3, "3 heat skills")

func _test_check_unlocks() -> void:
	var sum := SkillUnlockManager
	# initial 會被自動學（erase 後 check_unlocks 補回）
	GameManager.player.skills_unlocked.erase("basic_punch")
	sum.check_unlocks(false)
	_check("basic_punch" in GameManager.player.skills_unlocked, "initial basic_punch auto-learned")
	# heat 不自動學
	_check("tathagata_palm" not in GameManager.player.skills_unlocked, "heat not auto-learned")
	# behavior 條件達成後 check_unlocks 不自動學，只標可學
	GameManager.player.skills_unlocked.erase("rolling_taunt")
	GameManager.set_flag("karma_skill_count", 10)
	sum.check_unlocks(false)
	_check("rolling_taunt" not in GameManager.player.skills_unlocked,
		"rolling_taunt NOT auto-learned (learnable only)")
	_check(sum.get_unlock_state("rolling_taunt").learnable, "rolling_taunt is learnable")
	# 習得後才入池
	_check(sum.learn_skill("rolling_taunt"), "learn rolling_taunt")
	_check("rolling_taunt" in GameManager.player.skills_unlocked, "rolling_taunt learned after learn_skill")

func _test_learn_skill() -> void:
	var sum := SkillUnlockManager
	# 準備：underdog（flag:david_listened）未學、條件未達
	GameManager.player.skills_unlocked.erase("underdog")
	GameManager.player.flags.erase("david_listened")
	# 條件未達 → 不可學、learn_skill 失敗
	_check(not sum.learn_skill("underdog"), "learn_skill fails when condition unmet")
	_check("underdog" not in GameManager.player.skills_unlocked, "underdog not learned when unmet")
	# 條件達成 → learnable，但尚未 learned
	GameManager.set_flag("david_listened", true)
	var st := sum.get_unlock_state("underdog")
	_check(st.learnable and not st.learned, "underdog learnable but not learned after condition")
	_check("underdog" in sum.learnable_skills(), "underdog in learnable_skills()")
	# 習得 → 成功、進池、不再可學
	_check(sum.learn_skill("underdog"), "learn_skill succeeds when learnable")
	var st2 := sum.get_unlock_state("underdog")
	_check(st2.learned and not st2.learnable, "underdog learned, no longer learnable")
	# 重複習得 → 失敗
	_check(not sum.learn_skill("underdog"), "learn_skill fails when already learned")
	# grant_skill 防呆：不存在的招不授予
	_check(not sum.grant_skill("brahma_resonance"), "grant_skill rejects non-existent skill")
	_check("brahma_resonance" not in GameManager.player.skills_unlocked, "junk skill not in pool")
	# grant_skill 授予真招（story）：羅漢拳直給
	GameManager.player.skills_unlocked.erase("arhat_strike")
	_check(sum.grant_skill("arhat_strike"), "grant_skill grants arhat_strike")
	_check("arhat_strike" in GameManager.player.skills_unlocked, "arhat_strike granted into pool")

func _test_learn_badge() -> void:
	# 經書/技能 紅點：有可學的招時亮、學完（透過 EventBus.skill_unlocked）自動滅
	GameManager.player.skills_unlocked.erase("alms_wave")
	if "grandma" not in GameManager.player.completed_quests:
		GameManager.player.completed_quests.append("grandma")
	_check(SkillUnlockManager.learnable_skills().size() > 0, "have learnable for badge")
	var shell = load("res://src/ui/menu/MenuShell.tscn").instantiate()
	shell.set("pause_game", false)
	get_tree().root.add_child(shell)
	await get_tree().process_frame
	shell._show_device("book")
	await get_tree().process_frame
	_check(shell.find_child("LearnBadge", true, false) != null, "經書/技能 顯示紅點 (learnable)")
	# 學完全部可學 → 不手動刷新，靠 skill_unlocked 訊號自動清紅點
	for sid in SkillUnlockManager.learnable_skills().duplicate():
		SkillUnlockManager.learn_skill(sid)
	await get_tree().process_frame
	_check(shell.find_child("LearnBadge", true, false) == null, "學完後紅點自動消失")
	shell.queue_free()
	await get_tree().process_frame

func _test_audio_buses() -> void:
	# 三條 bus 都存在（Master 內建 + 執行期建 BGM/SFX）
	_check(AudioServer.get_bus_index("BGM") != -1, "BGM bus exists")
	_check(AudioServer.get_bus_index("SFX") != -1, "SFX bus exists")
	# linear setter/getter 往返
	AudioManager.set_bus_volume_linear("BGM", 0.5)
	var v: float = AudioManager.get_bus_volume_linear("BGM")
	_check(absf(v - 0.5) < 0.02, "BGM bus volume ~0.5 (got %f)" % v)
	# 0 → 靜音、不報錯
	AudioManager.set_bus_volume_linear("SFX", 0.0)
	_check(AudioManager.get_bus_volume_linear("SFX") < 0.01, "SFX muted at 0")
	# missing bus → returns 1.0 (documented contract)
	_check(AudioManager.get_bus_volume_linear("NonExistentBus") == 1.0, "missing bus returns 1.0")
	# 還原
	AudioManager.set_bus_volume_linear("BGM", 1.0)
	AudioManager.set_bus_volume_linear("SFX", 1.0)

func _test_settings_manager() -> void:
	# set→get 往返
	SettingsManager.set_setting("bgm_vol", 0.3)
	_check(absf(float(SettingsManager.get_setting("bgm_vol")) - 0.3) < 0.001, "settings bgm_vol roundtrip")
	# set 後即時套到 bus
	_check(absf(AudioManager.get_bus_volume_linear("BGM") - 0.3) < 0.02, "settings applied to BGM bus")
	# 文字速度反轉：UI 2.0x（更快）→ Dialogic delay 0.5
	SettingsManager.set_setting("text_speed", 2.0)
	if Dialogic.has_subsystem("Settings"):
		_check(absf(float(Dialogic.Settings.text_speed) - 0.5) < 0.001, "text_speed inverted to 0.5")
	# 持久化：寫檔後另一個實例載入應一致
	var sm2 = load("res://src/autoloads/SettingsManager.gd").new()
	get_tree().root.add_child(sm2)
	await get_tree().process_frame
	_check(absf(float(sm2.get_setting("bgm_vol")) - 0.3) < 0.001, "settings persisted across instance")
	sm2.queue_free()
	# 還原
	SettingsManager.set_setting("bgm_vol", 1.0)
	SettingsManager.set_setting("text_speed", 1.0)

func _smoke_scenes() -> void:
	# MenuShell（不暫停遊戲，避免卡住測試）
	var shell_ps: PackedScene = load("res://src/ui/menu/MenuShell.tscn")
	if shell_ps == null:
		_check(false, "load MenuShell.tscn");
	else:
		var shell = shell_ps.instantiate()
		shell.set("pause_game", false)
		get_tree().root.add_child(shell)
		for i in 4:
			await get_tree().process_frame
		_check(is_instance_valid(shell), "MenuShell alive")
		# 手機應有 5 頁：任務/情報/移動/打工/設定
		_check(shell.has_method("_show_device"), "MenuShell has _show_device")
		if shell.has_method("_show_device"):
			shell._show_device("phone")
			await get_tree().process_frame
			_check("phone" in shell._devices, "phone device exists in _devices")
			var phone_pages: Array = shell._devices["phone"]["pages"]
			_check(phone_pages.size() == 5, "phone has 5 pages (got %d)" % phone_pages.size())
			var titles := []
			for p in phone_pages:
				titles.append(p.title)
			_check("移動" in titles and "打工" in titles and "設定" in titles,
				"phone tabs include 移動/打工/設定")
			# 逐頁開啟不崩
			for i in phone_pages.size():
				shell._show_page(i)
				await get_tree().process_frame
			shell._show_device("book")
			await get_tree().process_frame
		shell.queue_free()
		await get_tree().process_frame
	# 兩個經書頁直接 instantiate
	for path in ["res://src/ui/menu/pages/SkillsPage.gd",
			"res://src/ui/menu/pages/StatusPage.gd"]:
		var gs = load(path)
		if gs == null:
			_check(false, "load %s" % path); continue
		var page = gs.new()
		get_tree().root.add_child(page)
		for i in 3:
			await get_tree().process_frame
		_check(is_instance_valid(page), "page alive %s" % path)
		page.queue_free()
		await get_tree().process_frame

	# SkillsPage 習得流程煙霧：可學招按「習得」後變已學
	var sp = load("res://src/ui/menu/pages/SkillsPage.gd").new()
	get_tree().root.add_child(sp)
	await get_tree().process_frame
	GameManager.player.skills_unlocked.erase("alms_wave")
	if "grandma" not in GameManager.player.completed_quests:
		GameManager.player.completed_quests.append("grandma")
	_check(SkillUnlockManager.get_unlock_state("alms_wave").learnable, "alms_wave learnable for page test")
	_check(sp.has_method("_on_learn"), "SkillsPage has _on_learn")
	if sp.has_method("_on_learn"):
		sp._on_learn("alms_wave")
		await get_tree().process_frame
		_check("alms_wave" in GameManager.player.skills_unlocked, "SkillsPage _on_learn learns skill")
	sp.queue_free()
	await get_tree().process_frame

	# 新手機 app smoke（含設定頁 + 移動頁 + 打工頁）
	for path in ["res://src/ui/menu/pages/SettingsApp.gd",
			"res://src/ui/menu/pages/TravelApp.gd",
			"res://src/ui/menu/pages/JobApp.gd"]:
		var gs2 = load(path)
		if gs2 == null:
			_check(false, "load %s" % path); continue
		var page2 = gs2.new()
		get_tree().root.add_child(page2)
		for i in 3:
			await get_tree().process_frame
		_check(is_instance_valid(page2), "phone app alive %s" % path)
		page2.queue_free()
		await get_tree().process_frame

func _test_pending_arrival() -> void:
	# GameManager 有可寫的暫存欄位，預設空
	GameManager.pending_arrival = {}
	_check(GameManager.pending_arrival.is_empty(), "pending_arrival starts empty")
	GameManager.pending_arrival = {"area": "ximen", "x": 0.66}
	_check(float(GameManager.pending_arrival.get("x", -1.0)) == 0.66, "pending_arrival writable")
	GameManager.pending_arrival = {}
	# DistrictScene.setup 接受 spawn_x_frac 參數（簽章存在即可，煙霧）
	var ds = load("res://src/screens/MapScreen/DistrictScene.tscn").instantiate()
	get_tree().root.add_child(ds)
	await get_tree().process_frame
	_check(ds.has_method("setup"), "DistrictScene has setup")
	ds.queue_free()
	await get_tree().process_frame

func _test_travel_app() -> void:
	var app = load("res://src/ui/menu/pages/TravelApp.gd").new()
	get_tree().root.add_child(app)
	await get_tree().process_frame
	# 捷運扣款＋耗時（_pay_mrt 只處理付費/推時，不換場）
	GameManager.player.gold = 100
	var p0: int = GameManager.player.period
	var ok_mrt: bool = app._pay_mrt("shrine")
	_check(ok_mrt and GameManager.player.gold == 95, "MRT charges 5 gold (got %d)" % GameManager.player.gold)
	_check(GameManager.player.period == (p0 + 1) % 4, "MRT advances 1 period")
	# 計程車扣款＋設 pending_arrival、不耗時
	GameManager.player.gold = 100
	GameManager.pending_arrival = {}
	var p1: int = GameManager.player.period
	var ok_taxi: bool = app._pay_taxi("old_temple")
	_check(ok_taxi and GameManager.player.gold == 70, "taxi charges 30 gold (got %d)" % GameManager.player.gold)
	_check(GameManager.player.period == p1, "taxi no time cost")
	_check(String(GameManager.pending_arrival.get("area", "")) == "shrine", "taxi sets pending area")
	# 錢不夠：不扣款、不動作
	GameManager.player.gold = 2
	GameManager.pending_arrival = {}
	_check(not app._pay_taxi("old_temple"), "taxi fails when broke")
	_check(GameManager.player.gold == 2, "broke: gold unchanged")
	_check(GameManager.pending_arrival.is_empty(), "broke: no pending")
	app.queue_free()
	GameManager.player.gold = 1000
	await get_tree().process_frame

func _test_job_app() -> void:
	var app = load("res://src/ui/menu/pages/JobApp.gd").new()
	get_tree().root.add_child(app)
	await get_tree().process_frame
	# 打工板列兩工
	_check(app.JOBS.size() == 2, "job board has 2 jobs")
	var ids := []
	for j in app.JOBS:
		ids.append(j.id)
	_check("soup_carry" in ids and "beggar_challenge" in ids, "jobs = soup_carry + beggar_challenge")
	# 開工耗 1 時段（_start_job_time 只推時，不換場）
	var p0: int = GameManager.player.period
	app._start_job_time()
	_check(GameManager.player.period == (p0 + 1) % 4, "job advances 1 period")
	app.queue_free()
	await get_tree().process_frame
