extends Node
## 對話立繪依職業切換：GameManager._apply_wujie_job_portraits()（掛在 Dialogic.timeline_started）
## 依 player.job 把 Wujie.dch 的 4 表情 image 覆寫成該職 bust。
var ok := true

func _check(c: bool, m: String) -> void:
	if not c: ok = false; print("FAIL: ", m)

func _img(mood: String) -> String:
	return str_to_var(load("res://dialogue/Wujie.dch").portraits[mood]["export_overrides"]["image"])

func _ready() -> void:
	await get_tree().process_frame
	# 8 張新 bust 都在
	for job in ["chanter", "beggar"]:
		for m in ["calm", "angry", "happy", "surprised"]:
			_check(ResourceLoader.exists("res://assets/2d/portraits/wujie/bust/wujie_%s_%s.png" % [job, m]),
				"bust 存在 %s_%s" % [job, m])
	# 依職切換：每種職業 apply 後 4 表情都應指向該職
	for job in ["chanter", "beggar", "ascetic"]:
		GameManager.player["job"] = job
		GameManager._apply_wujie_job_portraits()
		for m in ["calm", "angry", "happy", "surprised"]:
			_check(_img(m).contains("wujie_%s_%s" % [job, m]),
				"%s %s 立繪 (got %s)" % [job, m, _img(m)])
	print("JOB_PORTRAIT_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)
