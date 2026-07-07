extends SceneTree

## Headless generator for Dialogic .dch character resources.
## Reproduces DialogicCharacterFormatSaver's on-disk format
## (var_to_str(inst_to_dict(character))) WITHOUT depending on the editor
## plugin registering the ResourceFormatSaver. Run with:
##   godot --headless --script res://test/GenDch.gd

const CHAR_SCRIPT := "res://addons/dialogic/Resources/character.gd"
const OUT_DIR := "res://dialogue/"


func _portrait(image_path: String) -> Dictionary:
	# image override is stored as var_to_str(path) -> a quoted string,
	# matching the Character Editor (character_editor.gd:346).
	return {
		"scene": "",
		"export_overrides": {"image": var_to_str(image_path)},
		"scale": 1.0,
		"offset": Vector2(),
		"mirror": false,
	}


func _make(display_name: String, color: Color, description: String,
		default_portrait: String, portraits: Dictionary) -> Object:
	var char_script: GDScript = load(CHAR_SCRIPT)
	var c: Object = char_script.new()
	c.display_name = display_name
	c.nicknames = []
	c.color = color
	c.description = description
	c.scale = 1.0
	c.offset = Vector2()
	c.mirror = false
	c.default_portrait = default_portrait
	c.portraits = portraits
	c.custom_info = {}
	return c


func _save(c: Object, file_name: String) -> void:
	var path := OUT_DIR + file_name
	var f := FileAccess.open(path, FileAccess.WRITE)
	if not f:
		push_error("[GenDch] cannot open %s err=%d" % [path, FileAccess.get_open_error()])
		return
	f.store_string(var_to_str(inst_to_dict(c)))
	f.close()
	print("[GenDch] wrote ", path)


func _init() -> void:
	# ⚠⚠ 警告（2026-07-06）：下方既有 12 角色（Cherry~Liaochen）的 display_name/description/
	# 表情 portraits 是本檔建立當時的舊資料，已與 dialogue/*.dch 的實際內容脫節
	# （例：Cherry 現為「櫻」、Liaochen 現有 stern/smile/surprised 表情，本檔都沒有）。
	# 若整檔重跑，這 12 個 .dch 會被舊資料覆蓋＝退版。**要新增角色時，只保留你要新增的
	# _make/_save，把既有 12 個註解掉再跑**；或先待 GenDch 既有區塊同步為現況（另有任務）。
	# 下方 6 個新配角（Guard~Kenta_Father）是 2026-07-06 旁白改對話時新增，資料為現況。
	var cherry := _make(
		"Cherry",
		Color(0.85, 0.32, 0.46, 1),
		"林森北路的酒店女公關，近三十，眼底有倦也有故事。",
		"neutral",
		{
			"neutral": _portrait("res://assets/2d/portraits/cherry/bust/cherry_neutral.png"),
			"smile": _portrait("res://assets/2d/portraits/cherry/bust/cherry_smile.png"),
			"sorrow": _portrait("res://assets/2d/portraits/cherry/bust/cherry_sorrow.png"),
			"angry": _portrait("res://assets/2d/portraits/cherry/bust/cherry_angry.png"),
		}
	)
	_save(cherry, "Cherry.dch")

	var wujie := _make(
		"無戒",
		Color(0.83, 0.8, 0.74, 1),
		"萬華破廟的和尚，本作主角。",
		"calm",
		{
			"calm": _portrait("res://assets/2d/portraits/wujie/bust/wujie_ascetic_calm.png"),
			"angry": _portrait("res://assets/2d/portraits/wujie/bust/wujie_ascetic_angry.png"),
			"happy": _portrait("res://assets/2d/portraits/wujie/bust/wujie_ascetic_happy.png"),
			"surprised": _portrait("res://assets/2d/portraits/wujie/bust/wujie_ascetic_surprised.png"),
		}
	)
	_save(wujie, "Wujie.dch")

	# ── 支線 NPC（單一立繪，portrait 名統一為 "default"）──
	# 來源：assets/2d/portraits/npcs/npc_<id>.png
	var npcs := {
		"AhMing":   ["阿明", "西門町街頭藝人，賣唱維生，被警衛驅趕。", Color(0.45, 0.62, 0.78, 1), "ah_ming"],
		"Rei":      ["澪", "日本來的女背包客，迷路又語言不通。", Color(0.78, 0.66, 0.80, 1), "rei"],
		"ZhengMa":  ["鄭媽", "萬年大樓三樓佛具店老闆娘，被討債人威脅。", Color(0.72, 0.58, 0.40, 1), "zheng_ma"],
		"Jie":      ["小傑", "萬年五樓電玩城少年，叛逆、離家出走。", Color(0.40, 0.70, 0.65, 1), "jie"],
		"AhZhong":  ["阿忠師傅", "禪燒烤的老廚師，與無戒師父有舊。", Color(0.66, 0.50, 0.42, 1), "ah_zhong"],
		"David":    ["大衛", "失業的中年工程師，在燒烤攤喝悶酒。", Color(0.50, 0.55, 0.62, 1), "david"],
		"CaiMa":    ["蔡媽", "醉金閣的老鴇媽媽桑，手腕老練、立場難測。", Color(0.80, 0.45, 0.55, 1), "cai_ma"],
		"Grandma":  ["陳阿嬤", "古廟前的老香客，掛念離家的孫子。", Color(0.74, 0.72, 0.62, 1), "grandma"],
		"LaoWang":  ["老王", "廟前流浪漢，自稱被合夥人背叛的前董事長。", Color(0.55, 0.52, 0.48, 1), "lao_wang"],
	}
	for fname in npcs:
		var info: Array = npcs[fname]
		var img := "res://assets/2d/portraits/npcs/bust/npc_%s.png" % info[3]
		var c := _make(info[0], info[2], info[1], "default", {"default": _portrait(img)})
		_save(c, fname + ".dch")

	# ── 主線角色：了塵（引路修練者）──
	# 立繪：soul_2 生概念 → nano_banana_pro 雙圖(+無戒基準)統一厚塗畫風＋斷左臂改空袖 →
	# higgsfield remove_background 去背 → OpenCV 臉部偵測裁胸像（2026-06-15）。
	var liaochen := _make(
		"了塵",
		Color(0.46, 0.52, 0.5, 1),
		"斷一臂的還俗苦行僧。十年前曾組織反抗、敗於萬神殿而隱姓埋名，藏身新梵市舊城雨巷茶攤。懂諸神底細，因他敗過。",
		"default",
		{"default": _portrait("res://assets/2d/portraits/npcs/bust/npc_liaochen.png")}
	)
	_save(liaochen, "Liaochen.dch")

	# ── 旁白改寫升級：原本無立繪的配角，升級為正式 Dialogic 說話者（2026-07-06）──
	# 無名路人（警衛/安保隊長/討債的）＝使用者拍板統一用通用黑影剪影立繪（2026-07-06）。
	const ANON := "res://assets/2d/portraits/npcs/bust/npc_anon_silhouette.png"
	var guard := _make(
		"警衛",
		Color(0.35, 0.38, 0.42, 1),
		"萬神殿保全集團總部門口的警衛，攔阻無戒。",
		"default",
		{"default": _portrait(ANON)}
	)
	_save(guard, "Guard.dch")

	var security_chief := _make(
		"安保隊長",
		Color(0.30, 0.32, 0.36, 1),
		"城西軍火庫的重武裝安保隊長，阿瑞斯的爪牙。",
		"default",
		{"default": _portrait(ANON)}
	)
	_save(security_chief, "SecurityChief.dch")

	var debt_collector := _make(
		"討債的",
		Color(0.45, 0.30, 0.28, 1),
		"萬年大樓佛具店門口的地下錢莊打手。",
		"default",
		{"default": _portrait(ANON)}
	)
	_save(debt_collector, "DebtCollector.dch")

	var hayashida := _make(
		"林田",
		Color(0.42, 0.40, 0.34, 1),
		"源造(老王)昔日合夥人，二十年前偽造文書鵲巢鳩占，如今經營「林田投資」。",
		"default",
		{"default": _portrait("res://assets/2d/portraits/npcs/bust/npc_hayashida.png")}
	)
	_save(hayashida, "Hayashida.dch")

	var lao_zhang := _make(
		"老張",
		Color(0.50, 0.44, 0.36, 1),
		"櫻木町賣了半世紀醬料的老攤主，與大村師傅有段陳年往事。",
		"default",
		{"default": _portrait("res://assets/2d/portraits/npcs/bust/npc_lao_zhang.png")}
	)
	_save(lao_zhang, "LaoZhang.dch")

	var kenta_father := _make(
		"健太父",
		Color(0.40, 0.46, 0.50, 1),
		"健太的父親，離家在外地工作多年，終於回來與健太、婆婆團聚。",
		"default",
		{"default": _portrait("res://assets/2d/portraits/npcs/bust/npc_kenta_father.png")}
	)
	_save(kenta_father, "Kenta_Father.dch")

	print("[GenDch] DONE")
	quit()
