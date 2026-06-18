# 《和尚逆天》Monk Go Rogue
## Claude Code 技術實作企劃書 v5.0 — 完整版

> **v5.0 架構：** 3D 自由探索（Meshy AI + Mixamo）＋ 2D 演出回合制戰鬥（P5 風格）＋ Dialogic 2 對話系統 ＋ PNG 幀序列過場

---

## 🤖 給 Claude Code 的總體指示

1. **引擎：** Godot 4.3+，GDScript，Forward+ 渲染器
2. **命名：** 節點 PascalCase，變數 snake_case，常數 SCREAMING_SNAKE
3. **模組化：** 超過 150 行必須拆 Component，用 signal 通訊
4. **核心原則：** 探索=3D 沉浸，戰鬥=獨立 2D 場景；對話=2D 立繪演出但**疊在 3D 探索場景上**（P5 風，3D 活在背景，非獨立場景）。探索↔戰鬥場景完全隔離。

---

## 一、專案基本資訊

| 項目 | 規格 |
|------|------|
| 遊戲名稱 | 《和尚逆天》Monk Go Rogue |
| 引擎 | Godot 4.3+，Forward+ |
| 類型 | 3D 都市探索 ＋ 2D 回合制 RPG |
| 探索 | CharacterBody3D 自由行走，Area3D 地點觸發 |
| 戰鬥 | 2D 回合制，技能選單＋全螢幕演出 |
| 平台 | Windows PC（主）、HTML5（輕量）|
| 3D 場景 | Meshy AI（Text-to-3D，.glb）|
| 角色骨架 | Mixamo（Walk / Idle / Interact）|
| 2D 立繪 | Higgsfield AI（戰鬥/對話用）|
| 過場 | PNG 幀序列 + AnimationPlayer |
| 對話 | Dialogic 2 插件 |
| 存檔 | JSON（user://save.json）|

---

## 二、整體遊戲流程

### 設計哲學：人中之龍式開放探索

玩家在台北自由行動，**主線、支線、探索三條線完全獨立**，互不阻擋：

| 線路 | 推進方式 | 說明 |
|------|---------|------|
| **主線** | 玩家主動前往劇情地點 | 不去就不推進，隨時可回頭 |
| **支線** | 在對應地點與 NPC 互動觸發 | 全程可用，部分需前置旗標 |
| **自由探索** | 隨意行走、戰鬥、化緣 | 無任何限制 |

- 沒有「今天才能做這件事」的設計
- 技能解鎖綁定**玩家行為**（打了幾場、完成了哪條支線），不綁天數
- 時間流逝只影響**氛圍**（BGM 切換、部分 NPC 夜間才出現），不鎖內容

```
標題畫面
    ↓
【台北 3D 探索地圖】← 隨時可回
    ├── 走入 Area3D → 互動選單
    │     ├── 對話（Dialogic 2）
    │     ├── 購物 / 破戒
    │     ├── NPC 支線任務（隨時觸發）
    │     └── 遭遇敵人 → 【2D 戰鬥】→ 回地圖
    ├── 隨機遭遇（走路觸發）
    └── 劇情節點 → 【PNG 過場】→ 回地圖
    ↓（主線旗標全數達成後解鎖）
【Boss 戰（2D）】→ 結局過場 → 結局畫面
```

**時間系統（僅影響氛圍）：** 上午→下午→傍晚→深夜（4 段）。每次行動消耗 1 段。深夜結束自動存檔。部分 NPC 與地點僅在特定時段出現，但**不鎖主線進度**。

---

## 三、資料夾結構

```
res://
├── addons/dialogic/
├── src/
│   ├── autoloads/
│   │   ├── GameManager.gd
│   │   ├── SaveManager.gd
│   │   ├── AudioManager.gd
│   │   ├── SceneRouter.gd
│   │   └── EventBus.gd
│   ├── screens/
│   │   ├── TitleScreen/
│   │   ├── MapScreen/
│   │   │   ├── MapScreen.tscn        # Node3D
│   │   │   ├── MapScreen.gd
│   │   │   ├── PlayerController.gd
│   │   │   ├── CameraRig.gd
│   │   │   └── LocationTrigger.gd
│   │   ├── BattleScreen/
│   │   │   ├── BattleScreen.tscn
│   │   │   ├── BattleManager.gd
│   │   │   ├── BattleUI.gd
│   │   │   ├── Combatant.gd
│   │   │   ├── SkillExecutor.gd
│   │   │   ├── StatusEffects.gd
│   │   │   └── AllOutAttack.gd
│   │   ├── CutsceneScreen/
│   │   └── ResultScreen/
│   ├── systems/
│   │   ├── KarmaSystem.gd
│   │   ├── BreakVowSystem.gd
│   │   ├── TimeSystem.gd
│   │   ├── QuestManager.gd
│   │   └── AchievementSystem.gd
│   └── ui/
│       ├── SkillMenu.gd
│       ├── StatBar.gd
│       ├── InkSplashLabel.gd
│       ├── NeonFrame.gd
│       ├── ConfirmDialog.tscn
│       └── TransitionEffect.gd
├── assets/
│   ├── 3d/
│   │   ├── environments/            # Meshy .glb 場景
│   │   ├── characters/              # Meshy + Mixamo 角色
│   │   └── props/
│   ├── 2d/
│   │   ├── portraits/               # Higgsfield 立繪
│   │   │   ├── wujie/               # 無戒（各職業×3 表情）
│   │   │   ├── cherry/
│   │   │   ├── npcs/                # 支線 NPC 立繪
│   │   │   ├── enemies/
│   │   │   └── boss/
│   │   └── backgrounds/             # 2D 戰鬥背景
│   ├── cutscenes/                   # PNG 幀序列
│   │   ├── break_food/
│   │   ├── break_lust/
│   │   ├── break_greed/
│   │   ├── heat_tathagata/
│   │   ├── heat_diamond/
│   │   ├── heat_thousand/
│   │   └── ares_phase2/
│   ├── ui/
│   │   ├── neon_frames/
│   │   ├── ink_textures/
│   │   └── icons/
│   ├── audio/
│   │   ├── bgm/
│   │   └── sfx/
│   └── fonts/
│       └── NotoSansTC-Bold.ttf
├── dialogue/                        # Dialogic 2 .dtl 檔
│   ├── cherry_first_meeting.dtl
│   ├── cherry_main.dtl
│   ├── quest_ah_ming.dtl
│   ├── quest_rei.dtl
│   ├── quest_zheng_ma.dtl
│   ├── quest_jie.dtl
│   ├── quest_ah_zhong.dtl
│   ├── quest_david.dtl
│   ├── quest_cherry_debt.dtl
│   ├── quest_cai_ma.dtl
│   ├── quest_grandma.dtl
│   └── quest_lao_wang.dtl
└── data/
    ├── skills.json
    ├── enemies.json
    ├── boss.json
    ├── map_locations.json
    ├── quests.json
    ├── achievements.json
    └── meshy_prompts/
        ├── environments.json
        └── characters.json
```

---

## 四、Autoload 系統

### GameManager.gd

```gdscript
extends Node

signal stat_changed(key: String, value: Variant)
signal time_advanced(new_period: int)
signal job_changed(new_job: String)

const MAX_MERIT: int = 100
const MAX_KARMA: int = 100
const MAX_HP:    int = 500
const TIME_PERIODS = ["上午", "下午", "傍晚", "深夜"]

var player: Dictionary = {
    "name": "無戒",
    "max_hp": MAX_HP, "current_hp": MAX_HP,
    "merit": 0, "karma": 0, "gold": 1000,
    "job": "ascetic",
    "skills_unlocked": ["basic_punch", "wooden_fish"],
    "day": 1, "period": 0,
    "flags": {},
    "completed_quests": [],
    "active_quests": {},
    "last_position": {"x": 0.0, "y": 0.0, "z": 0.0}
}

func advance_time(steps: int = 1) -> void:
    player.period += steps
    if player.period >= TIME_PERIODS.size():
        player.period = 0
        player.day += 1
        add_merit(5)
        EventBus.new_day_started.emit(player.day)
    time_advanced.emit(player.period)

func add_merit(v: int) -> void:
    player.merit = clampi(player.merit + v, 0, MAX_MERIT)
    stat_changed.emit("merit", player.merit)
    if player.merit >= MAX_MERIT: EventBus.merit_maxed.emit()

func add_karma(v: int) -> void:
    player.karma = clampi(player.karma + v, 0, MAX_KARMA)
    stat_changed.emit("karma", player.karma)
    if player.karma >= MAX_KARMA: EventBus.karma_maxed.emit()

func take_damage(v: int) -> void:
    player.current_hp = clampi(player.current_hp - v, 0, player.max_hp)
    stat_changed.emit("current_hp", player.current_hp)
    if player.current_hp <= 0: EventBus.player_died.emit()

func heal(v: int) -> void:
    player.current_hp = clampi(player.current_hp + v, 0, player.max_hp)
    stat_changed.emit("current_hp", player.current_hp)

func spend_gold(v: int) -> bool:
    if player.gold < v: return false
    player.gold -= v
    stat_changed.emit("gold", player.gold)
    return true

func switch_job(job: String) -> void:
    if job not in ["ascetic", "chanter", "beggar"]: return
    player.job = job
    job_changed.emit(job)

func set_flag(key: String, val: Variant) -> void:
    player.flags[key] = val

func get_flag(key: String, default: Variant = false) -> Variant:
    return player.flags.get(key, default)
```

### EventBus.gd

```gdscript
extends Node
signal new_day_started(day: int)
signal location_entered(id: String)
signal location_exited()
signal random_encounter_triggered(district: String)
signal battle_started(enemy_data: Dictionary)
signal battle_ended(result: String)
signal skill_executed(skill_id: String, caster: String, targets: Array)
signal all_out_attack_triggered()
signal heat_action_triggered(job: String)
signal merit_maxed()
signal karma_maxed()
signal player_died()
signal combo_count_changed(count: int)
signal vow_broken(vow_type: String)
signal cherry_affection_changed(val: int)
signal quest_updated(id: String, status: String)
signal dialogue_started(id: String)
signal dialogue_ended()
```

---

## 五、3D 探索地圖

### MapScreen.gd

```gdscript
extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer        = $HUD
@onready var prompt: Control         = $HUD/InteractionPrompt

var _locations: Dictionary = {}
var _current_loc: String   = ""
var _in_trigger: bool      = false

func _ready() -> void:
    _locations = _load_json("res://data/map_locations.json")
    _build_triggers()
    _update_hud()
    GameManager.time_advanced.connect(_on_time_advanced)
    var p: Dictionary = GameManager.player.last_position
    player.global_position = Vector3(p.x, p.y, p.z)

func _build_triggers() -> void:
    for id in _locations:
        var loc: Dictionary = _locations[id]
        if loc.has("unlock_flag") and not GameManager.get_flag(loc.unlock_flag):
            continue
        var t := preload("res://src/screens/MapScreen/LocationTrigger.tscn").instantiate()
        t.setup(id, loc)
        t.player_entered.connect(_on_entered.bind(id))
        t.player_exited.connect(_on_exited)
        add_child(t)

func _input(event: InputEvent) -> void:
    if _in_trigger and event.is_action_just_pressed("interact"):
        _open_menu(_current_loc)

func _open_menu(id: String) -> void:
    hud.show_action_menu(_locations[id], func(a): perform_action(a))

func perform_action(action: String) -> void:
    hud.hide_action_menu()
    GameManager.advance_time(1)
    match action:
        "random_encounter": SceneRouter.go_to_battle(_pick_enemy(_locations[_current_loc].district))
        "cherry_dialogue":  Dialogic.start("cherry_first_meeting")
        "food_break_trigger": BreakVowSystem.try_trigger("food")
        "greed_break_trigger": BreakVowSystem.try_trigger("greed")
        "lust_break_trigger":  BreakVowSystem.try_trigger("lust")
        "beggar_minigame":  SceneRouter.go_to_minigame("beggar_challenge")
        "save":             SaveManager.save_game(); hud.show_toast("存檔完成")
        "job_switch":       hud.open_job_menu()
        _:
            if action.begins_with("quest_"):
                QuestManager.trigger_action(action, _current_loc)

func get_player_position() -> Vector3:
    return player.global_position

func _on_time_advanced(_p: int) -> void:
    _update_hud()
    for t in get_tree().get_nodes_in_group("location_trigger"):
        t.visible = GameManager.player.period in _locations[t.location_id].available_periods

func _update_hud() -> void:
    hud.set_time(GameManager.player.day, GameManager.TIME_PERIODS[GameManager.player.period])
```

### PlayerController.gd

```gdscript
extends CharacterBody3D

const SPEED:   float = 5.0
const GRAVITY: float = -20.0

@onready var anim_tree: AnimationTree = $AnimationTree
@onready var model: Node3D            = $MeshRoot

var _cam_basis: Basis = Basis.IDENTITY

func _physics_process(delta: float) -> void:
    if not is_on_floor(): velocity.y += GRAVITY * delta
    var input := Vector2(
        Input.get_axis("ui_left",  "ui_right"),
        Input.get_axis("ui_up",    "ui_down")
    )
    var dir := (_cam_basis * Vector3(input.x, 0.0, input.y)).normalized()
    if dir.length() > 0.1:
        velocity.x = dir.x * SPEED
        velocity.z = dir.z * SPEED
        model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), 0.2)
        anim_tree.set("parameters/blend/blend_amount", 1.0)
    else:
        velocity.x = move_toward(velocity.x, 0.0, SPEED)
        velocity.z = move_toward(velocity.z, 0.0, SPEED)
        anim_tree.set("parameters/blend/blend_amount", 0.0)
    move_and_slide()
```

### Toon Shader（套用所有 Meshy 模型）

```gdshader
shader_type spatial;
render_mode unshaded;

uniform sampler2D albedo_texture : source_color;
uniform int toon_steps = 3;
uniform float outline_width = 0.03;

void fragment() {
    vec4 tex   = texture(albedo_texture, UV);
    float light = dot(NORMAL, normalize(vec3(0.5, 1.0, 0.3)));
    float toon  = floor(light * float(toon_steps)) / float(toon_steps);
    ALBEDO = tex.rgb * max(toon, 0.3);
}

void vertex() {
    vec3 n_clip = normalize(MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
    VERTEX += n_clip * outline_width;
}
```

### 地點資料（map_locations.json）

```json
{
  "ximen_mrt": {
    "name": "捷運西門站 6 號出口", "district": "ximen",
    "position_3d": {"x": 12.0, "y": 0.0, "z": -8.0}, "trigger_radius": 2.5,
    "actions": ["beggar_minigame", "random_encounter", "quest_ah_ming", "quest_rei"],
    "available_periods": [1, 2, 3], "bgm": "ximen_night",
    "scene_file": "res://assets/3d/environments/ximen_mrt.glb"
  },
  "wannian_mall": {
    "name": "萬年商業大樓", "district": "ximen",
    "position_3d": {"x": 8.0, "y": 0.0, "z": -5.0}, "trigger_radius": 3.0,
    "actions": ["shop", "greed_break_trigger", "quest_zheng_ma", "quest_jie"],
    "available_periods": [0, 1, 2], "bgm": "ximen_day",
    "scene_file": "res://assets/3d/environments/wannian_mall.glb"
  },
  "zen_bbq": {
    "name": "禪味燒肉", "district": "wanhua_old",
    "position_3d": {"x": -15.0, "y": 0.0, "z": 10.0}, "trigger_radius": 2.0,
    "actions": ["food_break_trigger", "rest", "quest_ah_zhong", "quest_david"],
    "available_periods": [2, 3], "bgm": "wanhua_night",
    "scene_file": "res://assets/3d/environments/zen_bbq.glb"
  },
  "zuijin_club": {
    "name": "紫醉金迷公關俱樂部", "district": "linsen",
    "position_3d": {"x": 25.0, "y": 0.0, "z": -18.0}, "trigger_radius": 2.5,
    "actions": ["cherry_dialogue", "lust_break_trigger", "quest_cherry_debt", "quest_cai_ma"],
    "available_periods": [3], "unlock_flag": "linsen_unlocked",
    "bgm": "linsen_night",
    "scene_file": "res://assets/3d/environments/zuijin_club.glb"
  },
  "old_temple": {
    "name": "破舊古廟", "district": "wanhua_old",
    "position_3d": {"x": -18.0, "y": 0.0, "z": 8.0}, "trigger_radius": 3.0,
    "actions": ["save", "job_switch", "rest", "skill_learn", "quest_grandma", "quest_lao_wang"],
    "available_periods": [0, 1, 2, 3], "bgm": "temple_ambient",
    "scene_file": "res://assets/3d/environments/old_temple.glb"
  }
}
```

---

## 六、NPC 支線任務系統

### QuestManager.gd

```gdscript
extends Node

var _quests: Dictionary = {}

func _ready() -> void:
    _quests = _load_json("res://data/quests.json")

func trigger_action(action: String, location: String) -> void:
    var quest_id: String = action.replace("quest_", "")
    var q: Dictionary    = _quests.get(quest_id, {})
    if q.is_empty(): return
    var stage: int = GameManager.player.active_quests.get(quest_id, 0)
    if stage >= q.stages.size(): return
    Dialogic.start(q.stages[stage].dialogue)
    Dialogic.timeline_ended.connect(
        func(): _advance_quest(quest_id, stage, q),
        CONNECT_ONE_SHOT
    )

func _advance_quest(id: String, stage: int, q: Dictionary) -> void:
    var s: Dictionary = q.stages[stage]
    # 發放獎勵
    if s.has("merit"):  GameManager.add_merit(s.merit)
    if s.has("karma"):  GameManager.add_karma(s.karma)
    if s.has("gold"):   GameManager.player.gold += s.gold
    if s.has("flag"):   GameManager.set_flag(s.flag, true)
    if s.has("unlock_skill"):
        GameManager.player.skills_unlocked.append(s.unlock_skill)
    # 推進階段
    var next_stage: int = stage + 1
    if next_stage >= q.stages.size():
        GameManager.player.completed_quests.append(id)
        GameManager.player.active_quests.erase(id)
        EventBus.quest_updated.emit(id, "completed")
    else:
        GameManager.player.active_quests[id] = next_stage
        EventBus.quest_updated.emit(id, "advanced")
```

### 支線任務資料（quests.json）

```json
{
  "ah_ming": {
    "name": "街頭藝人的最後一場",
    "location": "ximen_mrt",
    "npc": "街頭藝人阿明",
    "available_periods": [1, 2],
    "stages": [
      {
        "dialogue": "quest_ah_ming_s1",
        "desc": "阿明被警衛驅趕，請你幫他吸引人群",
        "trigger_minigame": "busking_crowd",
        "merit": 15
      },
      {
        "dialogue": "quest_ah_ming_s2",
        "desc": "阿明逃過一劫，感謝無戒",
        "merit": 10,
        "unlock_skill": "brahma_resonance",
        "flag": "ah_ming_saved"
      }
    ],
    "cross_effect": "ah_ming 完成後，古廟新增臨時存檔點"
  },

  "rei": {
    "name": "迷路的外國人",
    "location": "ximen_mrt",
    "npc": "日本背包客澪",
    "available_periods": [0, 1, 2],
    "stages": [
      {
        "dialogue": "quest_rei_choice",
        "desc": "澪搭錯出口，三選一：帶去龍山寺/化緣/推薦林森北路",
        "branches": {
          "guide":    {"merit": 25, "gold": 150, "flag": "rei_guided"},
          "beg":      {"karma": 10, "gold": 300, "flag": "rei_begged"},
          "linsen":   {"karma": 20, "flag": "rei_linsen", "unlock_flag": "linsen_unlocked"}
        }
      }
    ],
    "cross_effect": "rei 後續在其他地點以不同狀態出現，影響第二幕劇情"
  },

  "zheng_ma": {
    "name": "鄭媽的念珠債",
    "location": "wannian_mall",
    "npc": "三樓佛具店老闆娘鄭媽",
    "available_periods": [0, 1, 2],
    "stages": [
      {
        "dialogue": "quest_zheng_ma_s1",
        "desc": "討債人威脅鄭媽關店，三選一：業障恐嚇/借錢/帶去古廟",
        "branches": {
          "intimidate": {"karma": 20, "merit": 10, "flag": "zheng_ma_saved_karma"},
          "lend_gold":  {"gold": -2000, "merit": 30, "flag": "zheng_ma_saved_gold"},
          "temple":     {"merit": 20, "flag": "zheng_ma_temple"}
        }
      },
      {
        "dialogue": "quest_zheng_ma_s2",
        "desc": "鄭媽感謝，開放特殊商品",
        "flag": "zheng_ma_shop_unlocked",
        "merit": 10
      }
    ],
    "cross_effect": "解鎖鄭媽商店特殊道具（護身符、業障結晶）"
  },

  "jie": {
    "name": "電玩少年的挑戰書",
    "location": "wannian_mall",
    "npc": "五樓電玩城少年小傑",
    "available_periods": [0, 1, 2],
    "stages": [
      {
        "dialogue": "quest_jie_challenge",
        "desc": "小傑挑戰木魚節奏戰，賭 500 金幣",
        "trigger_minigame": "wooden_fish_rhythm",
        "win":  {"gold": 500, "unlock_skill": "wooden_fish_fury", "flag": "jie_defeated"},
        "lose": {"gold": -500}
      }
    ],
    "cross_effect": "小傑父親出現於第二幕，陳阿嬤支線前置條件"
  },

  "ah_zhong": {
    "name": "師傅阿忠的最後一鍋",
    "location": "zen_bbq",
    "npc": "老廚師阿忠師傅",
    "available_periods": [2, 3],
    "stages": [
      {
        "dialogue": "quest_ah_zhong_s1",
        "desc": "阿忠說需要三樣食材，分別在不同地點",
        "flag": "ah_zhong_started"
      },
      {
        "dialogue": "quest_ah_zhong_s2",
        "desc": "取得龍山寺藥材（古廟互動獲得）",
        "require_flag": "got_herb",
        "location_required": "old_temple"
      },
      {
        "dialogue": "quest_ah_zhong_s3",
        "desc": "取得西門特製食材（西門 MRT 小販）",
        "require_flag": "got_ingredient",
        "location_required": "ximen_mrt"
      },
      {
        "dialogue": "quest_ah_zhong_final",
        "desc": "阿忠完成最後一道料理，揭露師父的過去",
        "merit": 40,
        "flag": "master_past_revealed",
        "hp_max_up": 100
      }
    ],
    "cross_effect": "解鎖無戒師父的背景故事，影響結局演出"
  },

  "david": {
    "name": "失業工程師的第三杯",
    "location": "zen_bbq",
    "npc": "失業工程師大衛",
    "available_periods": [3],
    "stages": [
      {
        "dialogue": "quest_david_choice",
        "desc": "大衛喝悶酒，三選一：認真傾聽/勸打坐/化緣",
        "branches": {
          "listen": {"merit": 20, "flag": "david_listened"},
          "meditate": {"merit": 10, "flag": "david_meditate"},
          "beg": {"karma": 15, "gold": 200, "flag": "david_begged"}
        }
      }
    ],
    "cross_effect": "david 後續在西門出現，listen 路線解鎖被動技「哀兵必勝」"
  },

  "cherry_debt": {
    "name": "Cherry 的債（主支線）",
    "location": "zuijin_club",
    "npc": "Cherry",
    "available_periods": [3],
    "require_flag": "cherry_met",
    "stages": [
      {
        "dialogue": "quest_cherry_debt_s1",
        "desc": "Cherry 欠老鴇 5 萬，告知無戒"
      },
      {
        "dialogue": "quest_cherry_debt_choice",
        "desc": "三選一：借錢/談判（需業障≥60）/幫她逃跑（觸發色戒）",
        "branches": {
          "lend":      {"gold": -5000, "merit": 30, "flag": "cherry_debt_lend"},
          "negotiate": {"require_karma": 60, "karma": -30, "flag": "cherry_debt_negotiated"},
          "escape":    {"trigger_vow": "lust", "flag": "cherry_escape"}
        }
      },
      {
        "dialogue": "quest_cherry_debt_final",
        "desc": "依選擇播放不同結果",
        "flag": "cherry_debt_resolved"
      }
    ],
    "cross_effect": "Cherry 解鎖為戰鬥後援（破色戒後），影響 Cherry 個人結局"
  },

  "cai_ma": {
    "name": "媽媽桑的神秘委託",
    "location": "zuijin_club",
    "npc": "老鴇蔡媽",
    "available_periods": [3],
    "require_flag": "linsen_unlocked",
    "stages": [
      {
        "dialogue": "quest_cai_ma_s1",
        "desc": "蔡媽委託送包裹到古廟，不能打開"
      },
      {
        "dialogue": "quest_cai_ma_choice",
        "desc": "到達古廟後：照做/偷看",
        "location_required": "old_temple",
        "branches": {
          "deliver":  {"merit": 30, "flag": "cai_ma_trusted"},
          "peek_good": {"merit": 20, "flag": "cai_ma_peeked_good"},
          "peek_bad":  {"karma": 40, "flag": "cai_ma_peeked_bad"}
        }
      }
    ],
    "cross_effect": "影響第二幕蔡媽立場（敵/友），peek_bad 路線觸發警察遭遇戰"
  },

  "grandma": {
    "name": "陳阿嬤找孫子",
    "location": "old_temple",
    "npc": "老香客陳阿嬤",
    "available_periods": [0, 1, 2, 3],
    "require_completed": "jie",
    "stages": [
      {
        "dialogue": "quest_grandma_s1",
        "desc": "阿嬤說孫子小傑三天沒回家"
      },
      {
        "dialogue": "quest_grandma_s2",
        "desc": "去萬年找到小傑，勸他回家",
        "location_required": "wannian_mall",
        "require_flag": "jie_defeated"
      },
      {
        "dialogue": "quest_grandma_final",
        "desc": "小傑與阿嬤和好，父親出場",
        "merit": 50,
        "flag": "true_ending_flag_1"
      }
    ],
    "cross_effect": "解鎖真結局旗標之一，小傑父親開啟第二幕副線"
  },

  "lao_wang": {
    "name": "流浪漢老王的過去",
    "location": "old_temple",
    "npc": "廟前流浪漢老王",
    "available_periods": [0, 1, 2, 3],
    "stages": [
      {
        "dialogue": "quest_lao_wang_s1",
        "desc": "老王自稱前董事長，被合夥人背叛"
      },
      {
        "dialogue": "quest_lao_wang_s2",
        "desc": "帶老王去萬年找人（對質）",
        "location_required": "wannian_mall"
      },
      {
        "dialogue": "quest_lao_wang_choice",
        "desc": "最終選擇：復仇 or 放下",
        "branches": {
          "revenge":    {"gold": 800, "karma": 30, "flag": "lao_wang_revenge"},
          "let_go":     {"merit": 60, "flag": "lao_wang_forgave", "true_ending_flag": true}
        }
      }
    ],
    "cross_effect": "let_go 路線影響尾章結局走向，revenge 路線觸發額外 Boss 小副本"
  }
}
```

---

## 七、完整回合制戰鬥系統

### 7.1 BattleManager.gd

```gdscript
extends Node
class_name BattleManager

enum State { PLAYER_TURN, ENEMY_TURN, SKILL_ANIM, ALL_OUT, HOLD_UP, END }

const ALL_OUT_DMG: int = 9999

signal state_changed(s: State)
signal enemy_weakpoint_hit(id: String)

var state: State = State.PLAYER_TURN
var player_combatant: Combatant
var enemy_combatants: Array[Combatant] = []
var _hits: int = 0

func setup(enemy_id: String) -> void:
    var data: Dictionary = _load_json("res://data/enemies.json")[enemy_id]
    player_combatant = _make_player()
    enemy_combatants = _make_enemies(data)
    AudioManager.switch_bgm("battle_theme")
    await BattleUI.play_encounter_intro()
    _set_state(State.PLAYER_TURN)

func player_use_skill(skill_id: String, target_idx: int) -> void:
    if state != State.PLAYER_TURN: return
    _set_state(State.SKILL_ANIM)
    var result := await SkillExecutor.execute(skill_id, player_combatant, enemy_combatants[target_idx])
    _process_result(result)

func _process_result(r: Dictionary) -> void:
    if r.get("hit_weakness"):
        _hits += 1
        enemy_weakpoint_hit.emit(r.target_id)
        EventBus.combo_count_changed.emit(_hits)
        if _all_downed():
            await _all_out_attack()
            return
        _set_state(State.PLAYER_TURN)
        return
    _hits = 0
    _check_end()
    if state != State.END:
        await _enemy_turn()

func _enemy_turn() -> void:
    _set_state(State.ENEMY_TURN)
    for e in enemy_combatants:
        if e.is_alive():
            await SkillExecutor.execute_enemy_action(e, player_combatant)
            await get_tree().create_timer(0.5).timeout
    _check_end()
    if state != State.END:
        _hits = 0
        _set_state(State.PLAYER_TURN)

func _all_out_attack() -> void:
    _set_state(State.ALL_OUT)
    await AllOutAttack.play()
    for e in enemy_combatants: e.take_damage(ALL_OUT_DMG)
    await get_tree().create_timer(1.0).timeout
    _hold_up()

func _hold_up() -> void:
    _set_state(State.HOLD_UP)
    var choice: String = await BattleUI.show_hold_up_menu()
    match choice:
        "gold":  GameManager.player.gold += _enemy_level() * 50
        "info":  GameManager.set_flag("knows_weakness_" + _current_enemy_type(), true)
        "item":  if randf() > 0.5: _give_random_item()
    _check_end()

func _check_end() -> void:
    if enemy_combatants.all(func(e): return not e.is_alive()):
        _set_state(State.END); _victory()
    elif not player_combatant.is_alive():
        _set_state(State.END); _defeat()

func _victory() -> void:
    await BattleUI.play_victory_fanfare()
    GameManager.player.gold += _calculate_gold()
    GameManager.add_merit(15)
    EventBus.battle_ended.emit("win")
    await get_tree().create_timer(1.5).timeout
    SceneRouter.go_to_map()

func _defeat() -> void:
    await BattleUI.play_defeat_sequence()
    EventBus.battle_ended.emit("lose")

func _all_downed() -> bool:
    return enemy_combatants.all(func(e): return e.is_downed or not e.is_alive())

func _set_state(s: State) -> void:
    state = s; state_changed.emit(s)
```

### 7.2 SkillExecutor.gd（傷害公式）

```gdscript
extends Node

var _skills: Dictionary = {}
var _status: StatusEffects

func _ready() -> void:
    _skills  = _load_json("res://data/skills.json")
    _status  = $StatusEffects

# 傷害公式：
# base = skill.power × (atk / 100)
# weakness_mult: 弱點屬性 ×2.0，一般 ×1.0，抗性 ×0.5
# crit: 10% 機率 ×1.5
# 最終 = base × weakness_mult × crit_mult × buff_mult

func execute(skill_id: String, caster: Combatant, target: Combatant) -> Dictionary:
    var sk: Dictionary = _skills[skill_id]
    var result: Dictionary = {"target_id": target.id, "hit_weakness": false}

    # 消耗資源
    if not _pay_cost(sk, caster):
        return {"error": "cost_failed"}

    # 傷害計算
    if sk.get("damage_type", "") != "support":
        var base: float    = sk.power * (caster.attack / 100.0)
        var w_mult: float  = _weakness_mult(sk.damage_type, target)
        var crit: float    = 1.5 if randf() < 0.1 else 1.0
        var buff: float    = _buff_mult(caster)
        var final_dmg: int = int(base * w_mult * crit * buff)

        if sk.get("ignore_defense"):
            target.take_damage(final_dmg)
        else:
            var reduced: int = max(final_dmg - target.defense, 1)
            target.take_damage(reduced)

        result["damage"]       = final_dmg
        result["hit_weakness"] = w_mult >= 2.0
        result["is_crit"]      = crit > 1.0

        await BattleUI.play_skill_animation(skill_id, result.hit_weakness)

        if result.hit_weakness and not target.is_downed:
            target.set_down(true)

    # 狀態異常
    if sk.has("special"):
        _status.apply(sk.special, target, sk.get("duration", 2))

    # 支援技
    if sk.damage_type == "support":
        await _apply_support(sk, caster)

    return result

func _weakness_mult(dtype: String, target: Combatant) -> float:
    if dtype in target.weaknesses:   return 2.0
    if dtype in target.resistances:  return 0.5
    return 1.0

func _buff_mult(c: Combatant) -> float:
    var m: float = 1.0
    if c.has_buff("ascetic_temper"): m *= 1.6
    if c.has_buff("weaken"):         m *= 0.5
    if GameManager.get_flag("buff_berserker_days") > 0: m *= 1.5
    return m

func _pay_cost(sk: Dictionary, caster: Combatant) -> bool:
    var cost: Dictionary = sk.get("cost", {})
    if cost.get("karma", 0)  > GameManager.player.karma:  return false
    if cost.get("merit", 0)  > GameManager.player.merit:  return false
    if cost.get("hp", 0) > 0:
        var hp_cost: int = int(caster.max_hp * cost.hp)
        if caster.current_hp <= hp_cost: return false
        caster.take_damage(hp_cost)
    GameManager.add_karma(-cost.get("karma", 0))
    GameManager.add_merit(-cost.get("merit", 0))
    return true

func execute_enemy_action(enemy: Combatant, target: Combatant) -> void:
    var ai: String         = enemy.ai_pattern
    var skill_id: String   = _pick_enemy_skill(enemy, target, ai)
    var sk: Dictionary     = _skills.get(skill_id, {})
    if sk.is_empty(): return
    var base: float = sk.get("power", 50) * (enemy.attack / 100.0)
    var final_dmg: int = max(int(base) - target.defense, 1)
    target.take_damage(final_dmg)
    if sk.has("special"):
        _status.apply(sk.special, target, sk.get("duration", 2))
    await BattleUI.play_enemy_attack_anim(enemy.id, skill_id)

func _pick_enemy_skill(e: Combatant, target: Combatant, ai: String) -> String:
    var hp_ratio: float = float(e.current_hp) / float(e.max_hp)
    match ai:
        "aggressive":
            if hp_ratio < 0.3 and e.skills.size() > 2: return e.skills[2]
            return e.skills[randi() % 2]
        "defensive":
            if hp_ratio > 0.5: return e.skills[1]
            return e.skills[0]
        "random":
            return e.skills[randi() % e.skills.size()]
        "boss_phase1":
            return _boss_phase1_ai(e)
        "boss_phase2":
            return _boss_phase2_ai(e)
    return e.skills[0]
```

### 7.3 StatusEffects.gd

```gdscript
extends Node

# 狀態列表：chaos / burn / stun / seal / slow / fear / poison / weaken
#           taunt / down / golden_body / brahma_resonance

var _active: Dictionary = {}  # target_id → [{type, duration}]

func apply(status_type: String, target: Combatant, duration: int) -> void:
    if not _active.has(target.id):
        _active[target.id] = []
    # Boss 免疫恐懼
    if status_type == "fear" and target.is_boss: return
    _active[target.id].append({"type": status_type, "duration": duration})
    BattleUI.show_status_icon(target.id, status_type)

func process_turn_start(combatant: Combatant) -> bool:
    # 回傳 false 表示跳過行動
    var effects: Array = _active.get(combatant.id, [])
    for eff in effects:
        match eff.type:
            "stun":   eff.duration -= 1; return false
            "fear":   if randf() < 0.5: return false
            "slow":   eff.duration -= 1; return false
            "chaos":  combatant.chaos_target = _random_combatant()
    return true

func process_turn_end(combatant: Combatant) -> void:
    var effects: Array = _active.get(combatant.id, [])
    for eff in effects.duplicate():
        match eff.type:
            "burn":   combatant.take_damage(15)
            "poison":
                var stacks: int = effects.filter(func(e): return e.type == "poison").size()
                combatant.take_damage(10 * stacks)
        eff.duration -= 1
        if eff.duration <= 0: effects.erase(eff)

func clear_negative(combatant: Combatant) -> void:
    var neg: Array = ["chaos","burn","stun","seal","slow","fear","poison","weaken","taunt"]
    _active[combatant.id] = _active.get(combatant.id, []).filter(
        func(e): return e.type not in neg
    )

func has_status(combatant: Combatant, status: String) -> bool:
    return _active.get(combatant.id, []).any(func(e): return e.type == status)
```

### 7.4 完整技能資料庫（skills.json）

```json
{
  "basic_punch": {
    "name": "鐵拳", "job": "ascetic",
    "cost": {}, "damage_type": "physical", "power": 80, "target": "single",
    "description": "基本近身攻擊。", "animation": "anim_punch"
  },
  "arhat_strike": {
    "name": "羅漢伏虎", "job": "ascetic",
    "cost": {"karma": 20}, "damage_type": "karma", "power": 180, "target": "single",
    "special": "knockdown",
    "unlock_condition": "初始解鎖",
    "description": "業障凝聚成鐵拳。命中弱點觸發 Down，可繼續行動。",
    "animation": "anim_arhat"
  },
  "vajra_glare": {
    "name": "金剛怒目", "job": "ascetic",
    "cost": {"karma": 15}, "damage_type": "support", "target": "single",
    "special": "fear", "duration": 2,
    "unlock_condition": "完成支線「街頭藝人阿明」",
    "description": "附加恐懼（2回合，50%跳過行動）。對 Boss 無效。",
    "animation": "anim_glare"
  },
  "ascetic_temper": {
    "name": "苦行淬煉", "job": "ascetic",
    "cost": {"hp": 0.15}, "damage_type": "support", "target": "self",
    "special": "self_buff_atk", "buff_value": 0.6, "duration": 2,
    "side_effect": {"karma": 10},
    "unlock_condition": "達成成就「行」（弱點連擊累積 10 次）",
    "description": "ATK+60% 持續 2 回合，獲得業障 10。",
    "animation": "anim_temper"
  },
  "iron_shirt": {
    "name": "鐵布衫", "job": "ascetic",
    "cost": {"karma": 25}, "damage_type": "support", "target": "self",
    "special": "reflect_shield", "shield_value": 0.8, "reflect_value": 0.5,
    "unlock_condition": "首次完成任意破戒後自動解鎖",
    "description": "本回合受到傷害減 80%，反彈 50% 給攻擊者。",
    "animation": "anim_iron_shirt"
  },
  "sacrifice_strike": {
    "name": "捨身一擊", "job": "ascetic",
    "cost": {"hp": 0.3}, "damage_type": "physical", "power": 300, "target": "single",
    "special": "self_weaken", "duration": 1,
    "unlock_condition": "累計擊倒 20 名敵人",
    "description": "消耗大量 HP，攻擊後自身虛弱一回合。",
    "animation": "anim_sacrifice"
  },
  "tathagata_palm": {
    "name": "如來神掌", "job": "ascetic",
    "cost": {"karma": 100}, "damage_type": "karma", "power": 9999, "target": "single",
    "ignore_defense": true, "is_heat_action": true,
    "description": "【業障滿值】從天而降，傷害無視防禦。業障歸零。",
    "animation": "anim_heat_tathagata",
    "cutscene": "heat_tathagata"
  },

  "wooden_fish": {
    "name": "木魚敲擊", "job": "chanter",
    "cost": {}, "damage_type": "physical", "power": 60, "target": "single",
    "side_effect": {"merit": 3},
    "unlock_condition": "初始解鎖",
    "description": "基本攻擊，附加功德 +3。", "animation": "anim_woodenfish"
  },
  "sound_wave": {
    "name": "梵音氣功", "job": "chanter",
    "cost": {"merit": 15}, "damage_type": "merit", "power": 120, "target": "all",
    "special": "knockdown",
    "unlock_condition": "初始解鎖",
    "description": "命中功德弱點觸發 Down。", "animation": "anim_soundwave"
  },
  "great_compassion_shield": {
    "name": "大悲咒護罩", "job": "chanter",
    "cost": {"merit": 30}, "damage_type": "support", "target": "self",
    "special": "golden_body", "shield_value": 200, "duration": 3,
    "unlock_condition": "完成支線「鄭媽的念珠債」",
    "description": "護盾抵擋下次傷害（上限200），持續3回合。",
    "animation": "anim_shield"
  },
  "requiem": {
    "name": "超渡法事", "job": "chanter",
    "cost": {"merit": 20}, "damage_type": "support", "target": "self",
    "special": "heal_and_cleanse", "heal_value": 100,
    "unlock_condition": "首次在戰鬥中 HP 降至 20% 以下（瀕死觸發頓悟）",
    "description": "回復 HP100 並清除全部負面狀態。",
    "animation": "anim_requiem"
  },
  "karma_rebound": {
    "name": "業火反噬", "job": "chanter",
    "cost": {"merit": 25}, "damage_type": "merit",
    "power_formula": "enemy_karma * 1.5", "target": "single",
    "unlock_condition": "業障值首次達到滿值（100）",
    "description": "傷害 = 目標業障值 × 1.5，對業障高敵人特效。",
    "animation": "anim_rebound"
  },
  "sutra_seal": {
    "name": "誦經結界", "job": "chanter",
    "cost": {"merit": 35}, "damage_type": "support", "target": "all_enemies",
    "special": "seal", "duration": 1,
    "unlock_condition": "Cherry 好感度達到 50",
    "description": "全體封印 1 回合，無法使用技能。",
    "animation": "anim_seal"
  },
  "diamond_sutra": {
    "name": "金剛薩埵超渡大陣", "job": "chanter",
    "cost": {"merit": 100}, "damage_type": "merit", "power": 500, "target": "all",
    "ignore_defense": true, "is_heat_action": true,
    "description": "【功德滿值】全體無視防禦，功德歸零。",
    "animation": "anim_heat_diamond",
    "cutscene": "heat_diamond"
  },

  "broken_bowl_beg": {
    "name": "破碗乞討", "job": "beggar",
    "cost": {}, "damage_type": "physical", "power": 40, "target": "single",
    "special": "steal_gold", "steal_min": 50, "steal_max": 100,
    "unlock_condition": "初始解鎖",
    "description": "攻擊同時奪取 50~100 金幣。", "animation": "anim_beg"
  },
  "lions_roar": {
    "name": "獅子吼", "job": "beggar",
    "cost": {"karma": 25}, "damage_type": "karma", "power": 90, "target": "all",
    "special": "chaos", "duration": 2,
    "unlock_condition": "初始解鎖",
    "description": "全體傷害，附加混亂 2 回合。", "animation": "anim_roar"
  },
  "self_harm": {
    "name": "苦肉計", "job": "beggar",
    "cost": {"hp": 0.2}, "damage_type": "support", "target": "self",
    "special": "gain_karma", "karma_gain": 35,
    "unlock_condition": "初始解鎖",
    "description": "自傷換業障 +35。", "animation": "anim_selfharm"
  },
  "underdog": {
    "name": "哀兵必勝", "job": "beggar",
    "cost": {}, "damage_type": "passive", "target": "self",
    "passive": {"hp_threshold": 0.3, "atk_bonus": 0.8, "evade_bonus": 0.3},
    "unlock_condition": "完成支線「失業工程師大衛」（選擇認真傾聽）",
    "description": "【被動】HP<30% 時 ATK+80%，閃避+30%。",
    "animation": null
  },
  "rolling_taunt": {
    "name": "滿地打滾", "job": "beggar",
    "cost": {"karma": 10}, "damage_type": "support", "target": "all_enemies",
    "special": "taunt_and_evade", "evade_bonus": 0.5, "duration": 1,
    "unlock_condition": "使用業障技能累計 10 次",
    "description": "全體嘲諷，自身閃避+50%，持續 1 回合。",
    "animation": "anim_rolling"
  },
  "alms_wave": {
    "name": "化緣大法", "job": "beggar",
    "cost": {"merit": 20}, "damage_type": "merit", "power": 150, "target": "all",
    "special": "mass_steal_gold", "steal_ratio": 0.3,
    "unlock_condition": "完成支線「陳阿嬤找孫子」",
    "description": "全體傷害，奪取所有敵人 30% 金幣。",
    "animation": "anim_alms_wave"
  },
  "thousand_hands": {
    "name": "千手化緣大法", "job": "beggar",
    "cost": {"karma": 80, "gold_required": 3000},
    "damage_type": "karma", "power": 400, "hits": 3, "target": "random",
    "special": "multi_steal", "steal_per_hit": 500,
    "is_heat_action": true,
    "description": "【業障≥80+持有3000金】三連擊，每擊奪金500，上限1500。",
    "animation": "anim_heat_thousand",
    "cutscene": "heat_thousand"
  }
}
```

### 7.5 完整敵人資料庫（enemies.json）

```json
{
  "street_punk": {
    "name": "西門混混", "district": "ximen",
    "max_hp": 150, "attack": 25, "defense": 10, "level": 2,
    "weaknesses": ["merit"], "resistances": ["physical"],
    "ai_pattern": "aggressive",
    "skills": ["punk_punch", "provoke", "call_backup"],
    "skill_defs": {
      "punk_punch": {"name":"街頭亂拳","power":30,"damage_type":"physical","target":"single"},
      "provoke":    {"name":"尋釁滋事","damage_type":"support","special":"taunt_self_def","def_bonus":0.3,"duration":1,"condition":"hp_below_50"},
      "call_backup":{"name":"叫兄弟來","damage_type":"support","special":"summon","summon_id":"street_punk","max_once":true,"condition":"hp_below_30"}
    },
    "gold_reward": 80, "portrait": "enemy_punk.png",
    "description": "西門晃蕩的小混混。"
  },

  "corrupt_vendor": {
    "name": "黑心攤販", "district": "ximen",
    "max_hp": 200, "attack": 20, "defense": 25, "level": 3,
    "weaknesses": ["karma"], "resistances": ["merit"],
    "ai_pattern": "defensive",
    "skills": ["overcharge", "smoke_screen", "fake_goods"],
    "skill_defs": {
      "overcharge":  {"name":"坑殺定價","power":20,"damage_type":"physical","target":"single","special":"steal_gold","steal":100},
      "smoke_screen":{"name":"煙霧彈","damage_type":"support","special":"self_evade","evade":0.6,"duration":1},
      "fake_goods":  {"name":"假貨進攻","power":35,"damage_type":"physical","target":"single","special":"poison","duration":3,"condition":"hp_below_50"}
    },
    "gold_reward": 150, "portrait": "enemy_vendor.png",
    "description": "賣假貨的攤販。"
  },

  "night_ghost": {
    "name": "深夜孤魂", "district": "wanhua_old",
    "max_hp": 120, "attack": 40, "defense": 0, "level": 4,
    "weaknesses": ["merit"], "resistances": ["physical"],
    "ai_pattern": "random",
    "skills": ["haunt", "spirit_claw", "drain_merit"],
    "skill_defs": {
      "haunt":      {"name":"陰魂附體","damage_type":"support","special":"fear","duration":2,"side_effect":{"self_atk":20}},
      "spirit_claw":{"name":"奪命抓","power":50,"damage_type":"karma","target":"single","ignore_defense":true},
      "drain_merit":{"name":"吸取功德","damage_type":"support","special":"drain_merit","drain":20,"heal_self":30}
    },
    "gold_reward": 100, "portrait": "enemy_ghost.png",
    "description": "萬華古廟附近的亡魂。深夜限定。",
    "time_restriction": [3]
  },

  "drunk_guard": {
    "name": "醉漢保鑣", "district": "linsen",
    "max_hp": 180, "attack": 35, "defense": 15, "level": 5,
    "weaknesses": ["karma"], "resistances": [],
    "ai_pattern": "aggressive",
    "skills": ["bottle_smash", "double_hit", "bodyguard"],
    "skill_defs": {
      "bottle_smash":{"name":"酒瓶砸頭","power":45,"damage_type":"physical","target":"single","special":"stun","stun_chance":0.2},
      "double_hit":  {"name":"雙人夾擊","power":30,"damage_type":"physical","target":"single","hits":2,"condition":"partner_alive"},
      "bodyguard":   {"name":"護主","damage_type":"support","special":"cover_ally","cover_ratio":0.5,"condition":"ally_hp_lowest"}
    },
    "spawn_pair": true,
    "gold_reward": 200, "portrait": "enemy_guard.png",
    "description": "林森北路的保鑣，成對出現。"
  },

  "temple_ghost": {
    "name": "廟宇惡鬼", "district": "wanhua_old",
    "max_hp": 350, "attack": 30, "defense": 30, "level": 6,
    "weaknesses": ["merit"], "resistances": ["karma", "physical"],
    "ai_pattern": "defensive",
    "skills": ["curse_seal", "ghost_fire", "dark_regen", "karma_burst"],
    "skill_defs": {
      "curse_seal": {"name":"詛咒封印","damage_type":"support","special":"seal","duration":2,"target":"player"},
      "ghost_fire": {"name":"鬼火燃燒","power":60,"damage_type":"karma","target":"single","special":"burn","duration":3},
      "dark_regen": {"name":"黑霧再生","damage_type":"support","special":"self_heal","heal":80,"condition":"hp_below_40","per_turn":true},
      "karma_burst":{"name":"業障爆發","damage_type":"karma","power_formula":"player_karma * 1.5","target":"single","condition":"player_karma_above_50"}
    },
    "gold_reward": 400, "portrait": "enemy_temple_ghost.png",
    "description": "萬華古廟鎮守惡鬼，菁英敵人。"
  },

  "ares": {
    "name": "阿瑞斯", "subtitle": "台北戰神",
    "max_hp": 2000, "attack": 80, "defense": 40, "level": 20,
    "weaknesses": [], "resistances": ["karma", "merit", "physical"],
    "is_boss": true,
    "phases": [
      {
        "phase": 1, "hp_threshold": 1.0,
        "ai_pattern": "boss_phase1",
        "skills": ["war_strike", "intimidate", "rage_charge"],
        "skill_defs": {
          "war_strike":  {"name":"戰神怒斬","power":90,"damage_type":"physical","target":"single"},
          "intimidate":  {"name":"威壓","damage_type":"support","special":"weaken","duration":2,"target":"player"},
          "rage_charge": {"name":"神怒蓄力","damage_type":"support","special":"charge_next","warn_text":"戰神怒火蓄積……","cycle":3}
        }
      },
      {
        "phase": 2, "hp_threshold": 0.5,
        "transition_cutscene": "ares_phase2_intro",
        "ai_pattern": "boss_phase2",
        "skills": ["war_strike", "area_crush", "divine_judgment", "divine_rage"],
        "skill_defs": {
          "area_crush":      {"name":"天地壓制","power":120,"damage_type":"physical","target":"all","special":"slow","duration":1},
          "divine_judgment": {"name":"神裁","power":200,"damage_type":"physical","target":"single","ignore_defense":true,"condition":"hp_below_30_per_turn"},
          "divine_rage":     {"name":"戰神怒火","power":150,"damage_type":"physical","target":"single","guaranteed_down":true,"condition":"after_charge"}
        }
      }
    ],
    "gold_reward": 5000,
    "defeat_cutscene": "ares_defeated",
    "portrait": "boss_ares.png",
    "battle_bg": "bg_battle_ximen_rain.png",
    "bgm": "boss_theme",
    "description": "台北戰神降臨西門天橋。深夜大雨。"
  }
}
```

### 7.6 BattleUI.gd（修正版）

```gdscript
extends CanvasLayer

@onready var skill_menu: Control          = $SkillMenu
@onready var enemy_area: HBoxContainer    = $EnemyArea/EnemySprites
@onready var player_portrait: TextureRect = $PlayerArea/Portrait
@onready var status_bar: Control          = $StatusBar
@onready var combo_label: Label           = $ComboDisplay/Label
@onready var anim_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
    EventBus.combo_count_changed.connect(_on_combo)
    skill_menu.visible = false

# ⚠️ 使用實例信號，非靜態類別
func show_skill_menu(skills: Array) -> String:
    skill_menu.visible = true
    var tw := create_tween()
    tw.tween_property(skill_menu, "position:x", 0.0, 0.2).from(-300.0)\
      .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
    _populate_buttons(skills)
    var selected: String = await skill_menu.skill_selected
    skill_menu.visible = false
    return selected

func _populate_buttons(skills: Array) -> void:
    for c in skill_menu.get_children(): c.queue_free()
    for id in skills:
        var btn := preload("res://src/ui/SkillButton.tscn").instantiate()
        btn.setup(id)
        btn.pressed.connect(
            func(): skill_menu.skill_selected.emit(id),
            CONNECT_ONE_SHOT
        )
        skill_menu.add_child(btn)

func show_hold_up_menu() -> String:
    return await $HoldUpMenu.choice_selected

func play_skill_animation(skill_id: String, hit_weakness: bool) -> void:
    anim_player.play("skill_name_splash")
    await anim_player.animation_finished
    anim_player.play(SkillData.get(skill_id, {}).get("animation", "anim_punch"))
    await anim_player.animation_finished
    if hit_weakness:
        anim_player.play("weakness_burst")
        AudioManager.play_sfx("weakness_hit")
        await anim_player.animation_finished

func play_encounter_intro() -> void:
    anim_player.play("encounter_slash")
    AudioManager.play_sfx("encounter_sting")
    await anim_player.animation_finished

func _on_combo(count: int) -> void:
    combo_label.visible = count > 1
    if count > 1:
        combo_label.text = "連擊 ×%d" % count
        var tw := create_tween()
        tw.tween_property(combo_label, "scale", Vector2(1.3,1.3), 0.1)
        tw.tween_property(combo_label, "scale", Vector2(1.0,1.0), 0.1)
```

---

## 八、美術完整規劃

### 8.1 整體美術方向

| 層次 | 技術 | 風格 |
|------|------|------|
| 3D 探索場景 | Meshy AI → Godot Forward+ | 卡通渲染（Toon Shader），台北霓虹夜市 |
| 3D 角色 | Meshy + Mixamo + Blender | 低多邊形，同套 Toon Shader |
| 2D 戰鬥/對話立繪 | Higgsfield AI | 視覺小說風，手繪感，乾淨 Lineart |
| 2D 戰鬥背景 | Higgsfield AI | 動漫背景風，大景深 |
| UI/選單 | Godot CanvasLayer + Shader | 霓虹斜切，水墨噴濺，P5 風 |
| 過場演出 | Higgsfield 影片 → ffmpeg 拆幀 | PNG 幀序列，每秒 12 幀 |

---

### 8.1.1 美術定案 — 2D 立繪風格與 UI 色系（2026-06-13 鎖定）

> 本節為**最終定案**，凌駕 8.1 表格中較早的籠統描述。所有 2D 立繪、UI、key art 一律依此標準。

**主角無戒定裝基準：** `assets/2d/portraits/wujie/_LOCKED_base_reference.png`（= 苦行僧·平靜 `wujie_ascetic_calm.png`）。
此圖為**臉型／風格的唯一基準**，往後所有表情版、職業版、其他角色都以它對齊（臉部維持此基準，不可漂移）。

**2D 立繪風格公式（Higgsfield `soul_2`，2:3）：**

- 半寫實風格化遊戲立繪、**強烈立體感與體積**、厚塗 painterly 光影、有深度（**不要純平塗 cel、不要粗黑邊**）。
- 臉：硬派成熟、有氣場、自然暖膚色；抬頭紋／皺紋保留(角色本來的滄桑感是特色)。
- 服裝：洗舊的**灰色袈裟**＋米白內襟，自然色，**人物本身不上紅光**。
- 構圖：上半身、抱臂、P5 風格俐落氣場。
- 背景：**乾淨的暗 charcoal 近黑**，柔和漸層即可，**不放紅色心魔剪影、不放紅墨噴**（已於 2026-06-13 取消紅心魔母題）。背景保持單純，凸顯人物。
- canonical 反向約束：character not tinted red、background clean no red figure、dimensional not flat。

**UI 主色系：暗金 × 黑 + 業障動態變色。**

| 狀態 | UI 主色 | 語意 |
|------|---------|------|
| 基準（平時） | **暗金／琉璃金**（gold-on-near-black） | 佛教識別色；對應功德＝金光、金錢＝金 |
| 功德高 | 偏明亮**金光**、神聖感增強 | 正向修行 |
| 業障高 | 漸變到**墮落色（暗紅／毒紫）** | 魔性侵蝕（UI 層面，立繪背景不放紅心魔） |

- 金配近黑 = 取得與 P5「紅配黑」同級的高對比衝擊，但不撞 P5、更貼佛教調性。
- 紅色僅作 **accent / 業障側**，不作 UI 基準主色；人物身上不鋪紅。
- 水墨噴濺、霓虹斜切等 P5 風 UI 質感保留，主色改套暗金。

**一致性產線備註：** 為維持「同一張臉」，後續表情／職業版**應以基準圖作為參考圖**（img2img／角色參考）生成，而非純文字重抽；必要時可考慮訓練專屬 Soul。

---

### 8.2 3D 場景美術規格（Meshy AI）

**生成設定標準：**

| 參數 | 設定值 |
|------|--------|
| 模式 | Text-to-3D → Preview → Refine |
| Art Style | `cartoon` |
| Topology | `quad`（Godot 友好） |
| 輸出格式 | `.glb` |
| 比例標準 | 場景高度基準：無戒角色高 1.8m |

**場景 Prompt 資料庫（meshy_prompts/environments.json）：**

```json
{
  "ximen_mrt": {
    "prompt": "Taipei MRT exit 6 Ximending at night, underground station entrance, metallic railings, neon signs Chinese characters, wet pavement reflecting colorful lights, convenience store nearby, low poly 3D game environment, stylized cartoon",
    "art_style": "cartoon", "topology": "quad",
    "godot_scale": 1.0,
    "output": "assets/3d/environments/ximen_mrt.glb",
    "toon_shader": true
  },
  "wannian_mall": {
    "prompt": "5-story commercial building Ximending Taipei retro shopping mall exterior night, glowing shop signs electronics toy stores neon lights escalator glass, low poly 3D cartoon stylized game asset",
    "art_style": "cartoon", "topology": "quad",
    "godot_scale": 1.2,
    "output": "assets/3d/environments/wannian_mall.glb"
  },
  "zen_bbq": {
    "prompt": "small Japanese BBQ restaurant old Taipei district late night, hanging red lanterns smoke grill wooden sign narrow alley warm orange glow, low poly 3D cartoon",
    "art_style": "cartoon", "topology": "quad",
    "godot_scale": 0.9,
    "output": "assets/3d/environments/zen_bbq.glb"
  },
  "zuijin_club": {
    "prompt": "underground nightclub entrance Linsen North Road Taipei, neon purple pink signs velvet rope dark staircase bouncer silhouette seductive, low poly 3D cartoon stylized",
    "art_style": "cartoon", "topology": "quad",
    "godot_scale": 1.0,
    "output": "assets/3d/environments/zuijin_club.glb"
  },
  "old_temple": {
    "prompt": "small dilapidated Buddhist temple Wanhua Taipei, cracked stone walls incense smoke red lanterns worn wooden gate urban background, low poly 3D cartoon atmospheric",
    "art_style": "cartoon", "topology": "quad",
    "godot_scale": 1.0,
    "output": "assets/3d/environments/old_temple.glb"
  }
}
```

**Godot 匯入設定：**
- Import → MeshInstance3D → 勾選 `Generate Lightmap UV2`
- 材質全部替換為 `Toon ShaderMaterial`
- 碰撞：`Generate Collision` → `Trimesh Static Body`

---

### 8.3 3D 角色美術規格（Meshy + Mixamo）

**角色 Prompt 資料庫（meshy_prompts/characters.json）：**

```json
{
  "wujie_base": {
    "prompt": "Taiwanese Buddhist monk male 30s shaved head worn grey kasaya robe calm T-pose full body rigging ready, low poly cartoon style clean topology quad mesh",
    "art_style": "cartoon", "topology": "quad",
    "output": "assets/3d/characters/wujie_base.glb",
    "next_step": "mixamo"
  }
}
```

**Mixamo 綁骨架完整流程：**

```
Step 1: 上傳 wujie_base.glb 至 mixamo.com
Step 2: Auto Rigger → Male skeleton → 標記下巴/手腕/膝蓋
Step 3: 下載以下動作（Format: FBX for Unity, Skin: With Skin）：
  - "Idle"              → 存為 idle.fbx
  - "Walking"           → 存為 walk.fbx
  - "Interact"          → 搜尋 "Picking Up" → 存為 interact.fbx
  - "Victory"           → 搜尋 "Cheering" → 存為 victory.fbx（勝利演出用）

Step 4: Blender 合軌
  - 開新檔案，File → Import FBX → 匯入 idle.fbx（含骨架）
  - 選骨架 → 進入 NLA Editor
  - 重複 Import → 僅選 Animation（不含骨架）匯入其他 .fbx
  - 每個動作推入 NLA Track，命名：idle / walk / interact / victory
  - File → Export → glTF 2.0（.glb）→ 勾選 Animation

Step 5: Godot 匯入
  - 拖入 assets/3d/characters/wujie.glb
  - Import 頁籤 → Animation → 確認 4 個 Clip 存在
  - 設定 AnimationTree：
      BlendSpace1D：blend_amount 0.0=Idle, 1.0=Walk
      OneShot Node：interact, victory
```

**角色 Scale 標準：**
- 無戒高度：`1.8` Godot units
- Meshy 匯出後若比例錯誤：Blender 中 Object → Apply Scale

---

### 8.4 2D 立繪規格（Higgsfield AI）

**立繪清單（共 26 張）：**

| 角色 | 表情 | 職業/狀態 | 數量 |
|------|------|-----------|------|
| 無戒 | 平靜/憤怒/驚訝 | 苦行僧 | 3 |
| 無戒 | 平靜/憤怒/驚訝 | 念經僧 | 3 |
| 無戒 | 平靜/憤怒/驚訝 | 化緣僧 | 3 |
| Cherry | 微笑/哀愁/憤怒 | — | 3 |
| 阿明 | 感謝/緊張 | — | 2 |
| 澪 | 困惑/感謝 | — | 2 |
| 阿忠師傅 | 平靜/感慨 | — | 2 |
| 老王 | 落魄/堅定 | — | 2 |
| 阿瑞斯（Boss）| 傲慢/憤怒/第二階段 | — | 3 |
| 敵人立繪 | — | 5 種敵人各 1 | 5 |

**Higgsfield Prompt 模板（portraits.json）：**

```json
{
  "wujie_ascetic_neutral": {
    "prompt": "2D visual novel portrait, Taiwanese Buddhist monk 30s shaved head worn grey kasaya robe, calm neutral expression, upper body, modern Taipei neon city background through window, hand-drawn illustration cel shading clean lineart, character sheet quality",
    "negative": "3D render photorealistic cartoon chibi western monk weapons pristine robes",
    "model": "soul", "aspect_ratio": "2:3",
    "output": "assets/2d/portraits/wujie/ascetic_neutral.png"
  },
  "wujie_ascetic_angry": {
    "prompt": "2D visual novel portrait, same Buddhist monk as wujie_ascetic_neutral, intense furious expression eyebrows furrowed forward lean veins on forehead, same style",
    "negative": "3D render photorealistic smiling peaceful",
    "model": "soul", "aspect_ratio": "2:3",
    "output": "assets/2d/portraits/wujie/ascetic_angry.png"
  },
  "cherry_smile": {
    "prompt": "2D visual novel portrait, Taiwanese hostess woman late 20s elegant black evening dress, warm genuine smile slightly tired eyes story behind them, neon-lit bar interior behind, hand-drawn cel shading upper body",
    "negative": "3D render explicit revealing childlike",
    "model": "soul", "aspect_ratio": "2:3",
    "output": "assets/2d/portraits/cherry/smile.png"
  },
  "boss_ares_phase1": {
    "prompt": "2D visual novel portrait, Greek war god Ares reimagined as Taipei gangster boss, muscular imposing in modern black suit, arrogant smirk, glowing red eyes, neon rain behind, hand-drawn dramatic style",
    "negative": "3D render cartoon cute",
    "model": "soul", "aspect_ratio": "2:3",
    "output": "assets/2d/portraits/boss/ares_phase1.png"
  }
}
```

**一致性維護原則：**
- 每個角色首先生成「標準立繪」（neutral），存為 Anchor
- 其他表情 Prompt 必須加入 `same style as [anchor_name]`
- 若臉部不一致：Negative 加入 `different face, different artstyle`

**Godot 匯入設定：**
- Import → 關閉 `Detect 3D`，關閉 `Mipmaps`
- Compress → `Lossless`（保持立繪清晰度）

---

### 8.5 2D 戰鬥背景規格

```json
{
  "bg_battle_ximen": {
    "prompt": "2D game battle background, Ximending Taipei street midnight raining, wet neon-lit pavement betel nut shop green glow convenience store distance, empty street anime-style background art highly detailed atmospheric perspective",
    "model": "nano_banana", "aspect_ratio": "16:9",
    "output": "assets/2d/backgrounds/bg_battle_ximen.png"
  },
  "bg_battle_wanhua": {
    "prompt": "2D game battle background, Wanhua old district Taipei alley night, old brick walls red lanterns incense smoke dim light, atmospheric anime background",
    "model": "nano_banana", "aspect_ratio": "16:9",
    "output": "assets/2d/backgrounds/bg_battle_wanhua.png"
  },
  "bg_battle_linsen": {
    "prompt": "2D game battle background, Linsen North Road Taipei underground club interior, purple neon bar stools bottles glowing, anime style",
    "model": "nano_banana", "aspect_ratio": "16:9",
    "output": "assets/2d/backgrounds/bg_battle_linsen.png"
  },
  "bg_battle_temple": {
    "prompt": "2D game battle background, interior dilapidated Buddhist temple Taipei night, incense smoke flickering candles cracked Buddha statue eerie, anime atmospheric",
    "model": "nano_banana", "aspect_ratio": "16:9",
    "output": "assets/2d/backgrounds/bg_battle_temple.png"
  },
  "bg_battle_boss": {
    "prompt": "2D game battle background, Ximending elevated bridge overpass Taipei midnight heavy rain, neon signs reflected on wet road, dramatic anime background final boss atmosphere",
    "model": "nano_banana", "aspect_ratio": "16:9",
    "output": "assets/2d/backgrounds/bg_battle_boss.png"
  }
}
```

---

### 8.6 過場演出製作流程（PNG 幀序列）

**過場清單（7 段）：**

| 過場 ID | 觸發點 | 長度 | 描述 |
|---------|--------|------|------|
| `break_food` | 破飲食戒 | 4s | 無戒吃下和牛，業障從眼中噴出 |
| `break_lust` | 破色戒 | 5s | Cherry 靠近，無戒沒有起身 |
| `break_greed` | 破貪戒 | 4s | 戴上金念珠，霓虹光照全身 |
| `heat_tathagata` | 如來神掌 | 6s | 躍至空中，掌影從天而降 |
| `heat_diamond` | 金剛薩埵大陣 | 6s | 梵文金光鎖場，淨化光束 |
| `heat_thousand` | 千手化緣大法 | 5s | 千手幻影，金幣漫天飛舞 |
| `ares_phase2` | Boss 第二階段 | 6s | 阿瑞斯神域降臨，天空裂開 |

**製作流程：**

```bash
# Step 1: Higgsfield 生成影片（Seedance 模式）
# Prompt 範例（break_food）：
# "Buddhist monk breaks food vow, takes bite of premium wagyu beef,
#  dark karma energy bursts from his eyes in red flames,
#  neon Taipei restaurant background, dramatic anime style, 4 seconds"

# Step 2: ffmpeg 拆幀（每秒 12 幀）
ffmpeg -i break_food.mp4 -vf fps=12 assets/cutscenes/break_food/frame_%04d.png

# Step 3: Godot AnimationPlayer 設定
# - Track: CutsceneScreen/FrameSprite → texture
# - 每格 0.0833 秒（= 1/12）
# - 在關鍵幀插入 AudioManager.play_sfx() 觸發音效

# Step 4: 音效對齊
# frame_0001~0012：靜音（醞釀）
# frame_0013：play_sfx("impact_heavy")
# frame_0036：play_sfx("karma_surge")
```

**CutsceneScreen.gd：**

```gdscript
extends Node2D

@onready var frame_sprite: Sprite2D       = $FrameSprite
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var _next: String = ""

func play(cutscene_id: String, next_scene: String = "map") -> void:
    _next = next_scene
    anim_player.play(cutscene_id)
    await anim_player.animation_finished
    _finish()

func _finish() -> void:
    if _next == "map": SceneRouter.go_to_map()
    elif _next != "": SceneRouter.play_cutscene(_next)
```

---

### 8.7 UI 美術設計系統

**色彩系統：**

```gdscript
# 在 NeonFrame.gd 等 UI 元件中統一引用
const COLOR = {
    "karma_main":   Color("#FF2D2D"),
    "karma_sub":    Color("#FF6B00"),
    "merit_main":   Color("#FFD700"),
    "merit_sub":    Color("#FFFACD"),
    "neon_green":   Color("#39FF14"),
    "neon_pink":    Color("#FF69B4"),
    "neon_blue":    Color("#00BFFF"),
    "ui_bg":        Color("#0A0A0A"),
    "text_main":    Color("#F5F5F0"),
    "ink_black":    Color("#1A0A00")
}
```

**字體規格：**
- 主字體：`NotoSansTC-Bold.ttf`，繁體中文支援
- 標題大小：28px，技能名：16px，說明文：12px，Badge：10px
- 英文 Fallback：`Oswald` 或 `Bebas Neue`（粗體工業風）

**技能選單視覺規格：**
```
整體向右傾斜 8°（skew_x = -8）
選中項目：
  - 背景：業障主色 #FF2D2D 填滿
  - 文字：白色反白
  - 左側紅色豎線 4px
未選中：
  - 背景：透明 / 10% 白
  - 左側豎線：灰色 2px
熱血處決條目：
  - 邊框：金色 #FFD700，閃爍動畫（sin 波）
  - 文字：金色
```

**傷害數字（InkSplashLabel.gd）：**

```gdscript
extends Label

func splash(damage: int, dtype: String, is_crit: bool) -> void:
    text = str(damage)
    match dtype:
        "karma":    add_theme_color_override("font_color", Color("#FF2D2D"))
        "merit":    add_theme_color_override("font_color", Color("#FFD700"))
        "physical": add_theme_color_override("font_color", Color("#F5F5F0"))
    var base: Vector2 = Vector2(1.5, 1.5) if is_crit else Vector2(1.0, 1.0)
    scale = base * 1.5
    var tw := create_tween()
    tw.tween_property(self, "scale", base, 0.15).set_ease(Tween.EASE_OUT)
    tw.parallel().tween_property(self, "position:y", position.y - 60.0, 0.6)
    tw.tween_property(self, "modulate:a", 0.0, 0.3)
    await tw.finished
    queue_free()
```

**HUD（3D 探索地圖）元件清單：**

| 元件 | 位置 | 說明 |
|------|------|------|
| 時間板 | 右上角 | 「第 X 天 / 傍晚」，背景水墨潑灑 |
| 業障槽 | 左下 | 紅色橫條，帶緩衝條（Tween） |
| 功德槽 | 左下 | 金色橫條，帶緩衝條 |
| 金幣顯示 | 左下 | 金幣圖示 + 數字 |
| 互動提示 | 畫面中央下 | 「[E] 進入」，霓虹閃爍 |
| 地點卡片 | 右側滑入 | 地點名稱 + 可用行動清單 |
| Toast 通知 | 上方 | 「存檔完成」等短暫提示 |

**轉場特效（TransitionEffect.gd）：**

```gdscript
extends CanvasLayer
signal finished

func play(type: SceneRouter.Transition) -> void:
    match type:
        SceneRouter.Transition.SLASH_RED:   $Anim.play("slash_red")
        SceneRouter.Transition.INK_SPLASH:  $Anim.play("ink_splash")
        SceneRouter.Transition.NEON_FLASH:  $Anim.play("neon_flash")
        SceneRouter.Transition.FADE_BLACK:  $Anim.play("fade_black")
    await $Anim.animation_finished
    finished.emit()
```

**SLASH_RED 動畫關鍵幀設計：**
```
Frame 0:    ColorRect（#FF2D2D）position.x = -1920, rotation = 8°
Frame 0.1:  position.x = 0（畫面覆蓋）
Frame 0.2:  position.x = 1920（劃出）
同時：      AudioManager.play_sfx("slash_red")
```

---

### 8.7・五、讀取畫面（LoadingScreen）

場景切換期間顯示，覆蓋在所有 CanvasLayer 最上層。

**視覺設計：**
```
┌─────────────────────────────────────────┐
│                                         │
│                                         │
│         阿彌陀佛...                      │  ← 中央，淡入淡出循環
│         （水墨字體，暖白色）              │
│                                         │
│                                         │
│                          🪘             │  ← 右下角木魚，持續敲擊動畫
└─────────────────────────────────────────┘
底色：#0A0A0A（近黑）
```

**木魚動畫規格：**
- `AnimatedSprite2D`，2 幀循環：`rest` → `knock` → `rest`
- 每次敲擊間隔：0.5 秒
- `knock` 幀播放時觸發 SFX `wooden_fish_tap`（輕柔木魚聲，音量 40%）
- 位置：右下角，margin 20px

**中央文字循環佛語：**

```gdscript
const LOADING_PHRASES: Array = [
    "阿彌陀佛...",
    "南無阿彌陀佛...",
    "色即是空，空即是色...",
    "萬般帶不走，唯有業隨身...",
    "放下屠刀，立地成佛...",
    "業障深重...",
    "功德無量...",
    "諸行無常，諸法無我...",
    "菩提本無樹，明鏡亦非台...",
    "人生八苦，生老病死...",
    "善有善報，惡有惡報...",
    "一念天堂，一念地獄...",
]
```

**LoadingScreen.gd：**

```gdscript
extends CanvasLayer

@onready var phrase_label: Label           = $PhraseLabel
@onready var wooden_fish: AnimatedSprite2D = $WoodenFish
@onready var knock_timer: Timer            = $KnockTimer

var _phrase_idx: int = 0

func _ready() -> void:
    layer = 128  # 最上層，蓋過所有 UI
    phrase_label.modulate.a = 0.0
    _show_next_phrase()
    knock_timer.start()

func _show_next_phrase() -> void:
    _phrase_idx = (_phrase_idx + 1) % LoadingScreen.LOADING_PHRASES.size()
    phrase_label.text = LOADING_PHRASES[_phrase_idx]
    var tw := create_tween()
    tw.tween_property(phrase_label, "modulate:a", 1.0, 0.4)
    tw.tween_interval(1.2)
    tw.tween_property(phrase_label, "modulate:a", 0.0, 0.4)
    tw.tween_callback(_show_next_phrase)

func _on_knock_timer_timeout() -> void:
    wooden_fish.play("knock")
    AudioManager.play_sfx("wooden_fish_tap")
    await wooden_fish.animation_finished
    wooden_fish.play("rest")
```

**整合進 SceneRouter（所有切換自動顯示）：**

```gdscript
# SceneRouter.gd 補充
var _loading_screen: CanvasLayer = null

func _show_loading() -> void:
    _loading_screen = preload("res://src/ui/LoadingScreen.tscn").instantiate()
    get_tree().root.add_child(_loading_screen)

func _hide_loading() -> void:
    if _loading_screen:
        var tw := create_tween()
        tw.tween_property(_loading_screen, "modulate:a", 0.0, 0.3)
        tw.tween_callback(_loading_screen.queue_free)
        _loading_screen = null

func go_to_map() -> void:
    _show_loading()                      # 木魚出現
    await _play_transition(Transition.INK_SPLASH)
    get_tree().change_scene_to_file("res://src/screens/MapScreen/MapScreen.tscn")
    await get_tree().process_frame
    _hide_loading()                      # 木魚淡出

func go_to_battle(enemy_id: String) -> void:
    _show_loading()
    await _play_transition(Transition.SLASH_RED)
    get_tree().change_scene_to_file("res://src/screens/BattleScreen/BattleScreen.tscn")
    await get_tree().process_frame
    get_tree().get_first_node_in_group("battle_manager").setup(enemy_id)
    _hide_loading()
```

**SFX 補充：** `wooden_fish_tap` — 輕柔單聲木魚敲擊，建議從 Freesound.org 搜尋 `mokugyo soft`

---

### 8.8 音效與 BGM 規劃

**BGM 清單：**

| ID | 情境 | 風格 | 時長 |
|----|------|------|------|
| `title_theme` | 標題畫面 | 水墨+電音融合，神秘感 | 3min loop |
| `ximen_day` | 西門白天探索 | 輕快台式流行，捷運廣播感 | 2min loop |
| `ximen_night` | 西門深夜探索 | Lofi 節拍，霓虹氛圍 | 2min loop |
| `wanhua_night` | 萬華深夜探索 | 古琴+電子，詭異感 | 2min loop |
| `linsen_night` | 林森北路深夜 | 爵士鋼琴+低音貝斯 | 2min loop |
| `temple_ambient` | 古廟全時段 | 木魚聲+環境音，平靜 | 3min loop |
| `battle_theme` | 一般戰鬥 | 電子鼓+三弦琴 riff，緊張 | 2min loop |
| `all_out_theme` | 超渡大陣演出 | 爆發+梵唱，5秒非loop | 5s |
| `boss_theme` | 阿瑞斯戰鬥 | 管弦+電子，史詩感 | 3min loop |
| `cherry_theme` | Cherry 對話 | 慵懶爵士鋼琴 | 2min loop |
| `victory_jingle` | 戰鬥勝利 | 短促爽快，3秒 | 3s |
| `defeat_sting` | 戰鬥失敗 | 低沉，5秒 | 5s |

**SFX 清單：**

| ID | 觸發點 |
|----|--------|
| `slash_red` | SLASH_RED 轉場 |
| `ink_splash` | INK_SPLASH 轉場 |
| `weakness_hit` | 命中弱點 |
| `encounter_sting` | 遭遇戰開始 |
| `impact_heavy` | 重擊音效 |
| `karma_surge` | 業障技能 |
| `merit_chime` | 功德技能 |
| `gold_collect` | 獲得金幣 |
| `ui_select` | 選單選擇 |
| `ui_cancel` | 取消 |
| `save_done` | 存檔完成 |
| `vow_break` | 破戒瞬間 |
| `heat_buildup` | 熱血處決蓄力 |
| `status_apply` | 狀態異常附加 |
| `combo_up` | 連擊計數上升 |

**AudioManager.gd：**

```gdscript
extends Node

@onready var bgm_player: AudioStreamPlayer = $BGMPlayer
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer

var _bgm_lib: Dictionary = {}
var _sfx_lib: Dictionary = {}

func _ready() -> void:
    _bgm_lib = _load_json("res://data/audio_bgm.json")
    _sfx_lib = _load_json("res://data/audio_sfx.json")

func switch_bgm(id: String, fade_time: float = 0.5) -> void:
    if bgm_player.stream and bgm_player.playing:
        var tw := create_tween()
        tw.tween_property(bgm_player, "volume_db", -60.0, fade_time)
        await tw.finished
    bgm_player.stream = load(_bgm_lib.get(id, ""))
    bgm_player.volume_db = 0.0
    bgm_player.play()

func play_sfx(id: String) -> void:
    sfx_player.stream = load(_sfx_lib.get(id, ""))
    sfx_player.play()
```

**推薦免費音源：**
- BGM：[FreeMusicArchive.org](https://freemusicarchive.org)（CC 授權）、Pixabay Music
- SFX：[Freesound.org](https://freesound.org)（CC 授權）
- 木魚聲：搜尋 "wooden fish" / "mokugyo"

---

## 八・五、技能解鎖系統（SkillUnlockManager）

技能完全不依賴天數，全部綁定**玩家行為旗標**。EventBus 每次有重要事件發生時呼叫 `check_unlocks()`。

> **⚠ 已過時（2026-06-17）：** 下方 lambda 版 `UNLOCK_CONDITIONS`/`check_unlocks` 已被 `SkillUnlockManager.UNLOCK_TABLE` 資料驅動取代，且解鎖改為「了塵為師」習得制——條件達成只變「可學」，玩家須進經書·技能頁點「習得」才真正入招池（例外：initial/story 羅漢拳/heat）。`check_unlocks()` 只自動學 initial。詳見 spec `docs/superpowers/specs/2026-06-17-skill-learning-system-design.md`。

```gdscript
extends Node

# 解鎖條件表：skill_id → Callable（回傳 bool）
const UNLOCK_CONDITIONS: Dictionary = {
    # 苦行僧
    "arhat_strike":    func(): return true,  # 初始
    "vajra_glare":     func(): return "ah_ming_saved" in GameManager.player.completed_quests,
    "ascetic_temper":  func(): return GameManager.get_flag("weakness_hit_count", 0) >= 10,
    "iron_shirt":      func(): return GameManager.get_flag("broke_any_vow"),
    "sacrifice_strike":func(): return GameManager.get_flag("kill_count", 0) >= 20,
    # 念經僧
    "wooden_fish":     func(): return true,
    "sound_wave":      func(): return true,
    "great_compassion_shield": func(): return "zheng_ma" in GameManager.player.completed_quests,
    "requiem":         func(): return GameManager.get_flag("near_death_triggered"),
    "karma_rebound":   func(): return GameManager.get_flag("karma_maxed_once"),
    "sutra_seal":      func(): return GameManager.get_flag("cherry_affection", 0) >= 50,
    # 化緣僧
    "broken_bowl_beg": func(): return true,
    "lions_roar":      func(): return true,
    "self_harm":       func(): return true,
    "underdog":        func(): return GameManager.get_flag("david_listened"),
    "rolling_taunt":   func(): return GameManager.get_flag("karma_skill_count", 0) >= 10,
    "alms_wave":       func(): return "grandma" in GameManager.player.completed_quests,
}

func check_unlocks() -> void:
    for skill_id in UNLOCK_CONDITIONS:
        if skill_id in GameManager.player.skills_unlocked: continue
        if UNLOCK_CONDITIONS[skill_id].call():
            GameManager.player.skills_unlocked.append(skill_id)
            _notify_unlock(skill_id)

func _notify_unlock(skill_id: String) -> void:
    # 畫面右下角飄出「新技能解鎖：XXX」提示
    var skills: Dictionary = _load_json("res://data/skills.json")
    var name: String = skills.get(skill_id, {}).get("name", skill_id)
    EventBus.skill_unlocked.emit(name)
```

**觸發時機（在 EventBus 對應信號中呼叫）：**

```gdscript
# GameManager.gd 中加入
func add_karma(v: int) -> void:
    # ... 原有邏輯 ...
    if player.karma >= MAX_KARMA:
        set_flag("karma_maxed_once", true)
    SkillUnlockManager.check_unlocks()

# BattleManager.gd 中
func _process_result(r: Dictionary) -> void:
    if r.get("hit_weakness"):
        var cnt: int = GameManager.get_flag("weakness_hit_count", 0)
        GameManager.set_flag("weakness_hit_count", cnt + 1)
    var kills: int = GameManager.get_flag("kill_count", 0)
    GameManager.set_flag("kill_count", kills + _count_dead_enemies())
    SkillUnlockManager.check_unlocks()

# PlayerController.gd 中（HP 瀕死偵測）
func _physics_process(delta: float) -> void:
    if GameManager.player.current_hp < GameManager.player.max_hp * 0.2:
        GameManager.set_flag("near_death_triggered", true)
        SkillUnlockManager.check_unlocks()
```

---

## 九、對話系統（Dialogic 2）

**安裝：** Godot → AssetLib → 搜尋 Dialogic → 安裝 Dialogic 2

**整合 EventBus：**

```gdscript
# DialogicGameHandler.gd（繼承 Node，加入 MapScreen）
extends Node

func _ready() -> void:
    Dialogic.signal_event.connect(_on_signal)

func _on_signal(arg: String) -> void:
    match arg:
        "karma_up_5":       GameManager.add_karma(5)
        "karma_up_20":      GameManager.add_karma(20)
        "merit_up_10":      GameManager.add_merit(10)
        "merit_up_25":      GameManager.add_merit(25)
        "affection_up_10":
            var cur: int = GameManager.get_flag("cherry_affection", 0)
            GameManager.set_flag("cherry_affection", cur + 10)
        "unlock_linsen":    GameManager.set_flag("linsen_unlocked", true)
        "cherry_met":       GameManager.set_flag("cherry_met", true)
        "break_food_vow":   BreakVowSystem.try_trigger("food")
        "break_lust_vow":   BreakVowSystem.try_trigger("lust")
        "got_herb":         GameManager.set_flag("got_herb", true)
        "got_ingredient":   GameManager.set_flag("got_ingredient", true)
```

---

## 十、三大破戒系統

```gdscript
extends Node

const VOWS: Dictionary = {
    "food":  {"name":"飲食戒","gold_cost":3000,"karma_gain":50,
              "desc":"吃下那碗極品和牛。業障滾燙，但真的太香了。",
              "effect":"berserker","cutscene":"break_food","flag":"broke_food_vow"},
    "lust":  {"name":"色戒","gold_cost":5000,"karma_gain":30,
              "desc":"Cherry 靠近時，你沒有起身離開。",
              "effect":"cherry_combat_ally","cutscene":"break_lust","flag":"broke_lust_vow"},
    "greed": {"name":"貪戒","gold_cost":8000,"karma_gain":40,
              "desc":"純金勞力士念珠戴上，你感覺自己是台北之王。",
              "effect":"gold_multiplier","cutscene":"break_greed","flag":"broke_greed_vow"}
}

func try_trigger(vow_type: String) -> void:
    var vow: Dictionary = VOWS.get(vow_type, {})
    if vow.is_empty(): return
    if GameManager.get_flag(vow.flag):
        Dialogic.start("vow_already_broken"); return
    _show_confirm(vow, vow_type)

func _show_confirm(vow: Dictionary, vow_type: String) -> void:
    var dlg := preload("res://src/ui/ConfirmDialog.tscn").instantiate()
    dlg.setup(vow.desc, "破戒（%d 金）" % vow.gold_cost, "南無阿彌陀佛……離開")
    get_tree().root.add_child(dlg)
    var ok: bool = await dlg.chose
    dlg.queue_free()
    if ok: _execute(vow_type, vow)

func _execute(vow_type: String, vow: Dictionary) -> void:
    if not GameManager.spend_gold(vow.gold_cost):
        Dialogic.start("vow_no_gold"); return
    GameManager.add_karma(vow.karma_gain)
    GameManager.set_flag(vow.flag, true)
    SceneRouter.play_cutscene(vow.cutscene, "map")
    EventBus.vow_broken.emit(vow_type)
    _apply_effect(vow.effect)

func _apply_effect(eff: String) -> void:
    match eff:
        "berserker":         GameManager.set_flag("buff_berserker_days", 3)
        "cherry_combat_ally":GameManager.set_flag("cherry_unlocked", true)
        "gold_multiplier":
            GameManager.set_flag("gold_multiplier_active", true)
            GameManager.set_flag("pickpocket_rate_up", true)
```

---

## 十一、Boss 戰

**boss.json：**

```json
{
  "ares": {
    "name": "阿瑞斯", "subtitle": "台北戰神",
    "max_hp": 2000, "attack": 80, "defense": 40,
    "weaknesses": [], "resistances": ["karma","merit","physical"],
    "portrait": "boss_ares.png",
    "battle_bg": "bg_battle_boss.png", "bgm": "boss_theme",
    "phases": [
      {
        "hp_threshold": 1.0, "ai_pattern": "boss_phase1",
        "skills": ["war_strike","intimidate","rage_charge"]
      },
      {
        "hp_threshold": 0.5,
        "transition_cutscene": "ares_phase2",
        "ai_pattern": "boss_phase2",
        "skills": ["war_strike","area_crush","divine_judgment","divine_rage"]
      }
    ],
    "gold_reward": 5000,
    "defeat_cutscene": "ares_defeated",
    "unlock_ending": "ending_true"
  }
}
```

---

## 十二、成就系統（十二因緣）

```json
{
  "ignorance":    {"name":"無明","desc":"完成第一場戰鬥"},
  "formation":    {"name":"行","desc":"弱點連擊累積 10 次"},
  "consciousness":{"name":"識","desc":"Cherry 好感度達 100"},
  "name_form":    {"name":"名色","desc":"三大破戒全數完成"},
  "six_bases":    {"name":"六入","desc":"探索全部台北地點"},
  "contact":      {"name":"觸","desc":"使用三職業熱血處決各一次"},
  "sensation":    {"name":"受","desc":"單場戰鬥金幣收入破 2000"},
  "craving":      {"name":"愛","desc":"化緣小遊戲單次超過 5000 元"},
  "clinging":     {"name":"取","desc":"業障與功德同時滿值"},
  "becoming":     {"name":"有","desc":"擊倒 50 名敵人"},
  "birth":        {"name":"生","desc":"通關主線第二幕"},
  "aging_death":  {"name":"老死","desc":"達成所有結局"}
}
```

---

## 十三、開發步驟

### Step 1：基礎架構
- [ ] 建立資料夾結構
- [ ] project.godot（Forward+，1920×1080）
- [ ] 安裝 Dialogic 2
- [ ] 全部 Autoload
- [ ] 3D 佔位 MapScreen（灰色地板 + 一個 Area3D）
- **驗收：** Area3D 觸發 go_to_battle，Console 無錯誤

### Step 2：Meshy 資產生成
- [ ] 執行 tools/meshy_generate.py 生成 5 個場景 + 無戒角色
- [ ] Mixamo 綁骨架 → Blender 合軌 → wujie.glb
- [ ] Godot 匯入，套 Toon Shader
- **驗收：** 無戒在場景中行走，動作正常

### Step 3：戰鬥核心
- [ ] BattleManager / Combatant / SkillExecutor / StatusEffects
- [ ] AllOutAttack 框架
- [ ] 最簡 BattleUI（可點擊技能）
- [ ] skills.json + enemies.json 完整資料
- **驗收：** 可打一場完整戰鬥，含弱點連擊與超渡大陣

### Step 4：UI 動態
- [ ] TransitionEffect（SLASH_RED + FADE_BLACK）
- [ ] 斜切技能選單（Tween 飛入）
- [ ] InkSplashLabel 傷害飄字
- [ ] StatBar（血量/業障/功德 + 緩衝條）
- **驗收：** 戰鬥畫面完整霓虹風格

### Step 5：Higgsfield 立繪生成
- [ ] 生成 26 張立繪（依 portraits.json）
- [ ] 戰鬥背景 5 張
- **驗收：** 戰鬥/對話畫面立繪正常顯示

### Step 6：3D 地圖完整實作
- [ ] PlayerController（CharacterBody3D + AnimationTree）
- [ ] CameraRig（固定角度跟隨）
- [ ] LocationTrigger（Area3D + 互動提示）
- [ ] HUD 完整（時段/業障/功德/金幣/互動提示）
- [ ] 套用 Meshy 場景
- **驗收：** 台北地圖自由行走，所有地點可觸發

### Step 7：NPC 支線與對話
- [ ] Dialogic 2 製作 10 條支線對話
- [ ] QuestManager.gd（讀取 quests.json）
- [ ] DialogicGameHandler 串接數值
- [ ] ConfirmDialog.tscn（破戒確認）
- [ ] BreakVowSystem 完整實作
- **驗收：** 全部 10 條支線可觸發，破戒流程含過場

### Step 8：過場動畫
- [ ] Higgsfield 生成 7 段影片
- [ ] ffmpeg 拆幀（fps=12）
- [ ] Godot AnimationPlayer 設定幀序列
- [ ] 音效對齊關鍵幀
- **驗收：** 7 段過場可正常播放

### Step 9：小遊戲
- [ ] 化緣小遊戲（BeggarChallenge）
- [ ] 端湯小遊戲（SoupCarry2D）
- [ ] 木魚節奏戰（WoodenFishRhythm）
- **驗收：** 三個小遊戲可獨立完整遊玩

### Step 10：整合與收尾
- [ ] Boss 戰（BossManager 兩階段）
- [ ] SaveManager（含 3D 位置 + 任務旗標）
- [ ] AchievementSystem（十二因緣）
- [ ] 音效與 BGM 全到位
- **驗收：** 從標題玩到 Boss 結局，無 crash

---

## 十四、輸入對照表

| 動作 | 鍵盤 | Gamepad |
|------|------|---------|
| 移動 | WASD / 方向鍵 | 左搖桿 |
| 互動 | E | A |
| 確認 | Enter / Space | A |
| 取消 | Esc / Backspace | B |
| 技能快捷 | 1~5（戰鬥） | 無 |
| 職業切換 | Tab | Y |
| 暫停 | Esc | Start |

---

## 十五、常見問題排除

| 問題 | 原因 | 解法 |
|------|------|------|
| Meshy .glb 材質錯誤 | Forward+ 與 Compatibility 材質不同 | 確認 Forward+，重新指定 Toon ShaderMaterial |
| Mixamo 骨架比例異常 | FBX 單位問題 | Blender 匯入勾選 Apply Unit，再匯出 .glb |
| Area3D 觸發不靈敏 | CollisionShape radius 太小 | 增大至 2.5~3.0，或改 CylinderShape3D |
| Dialogic 結束後卡住 | 未監聽 timeline_ended | DialogicGameHandler 補上 Dialogic.timeline_ended.connect |
| PNG 幀序列不順 | 幀率未對齊 | 確認 fps=12，每格 0.0833 秒 |
| 技能選單信號重複觸發 | pressed 未用 ONE_SHOT | 見 BattleUI._populate_buttons，加 CONNECT_ONE_SHOT |
| 3D 回地圖位置重置 | last_position 未更新 | SceneRouter.go_to_battle 前確認已存 player.last_position |
| Boss 第二階段未觸發 | _check_phase_transition 未呼叫 | BossManager._process_result 末尾補呼叫 |
| Higgsfield 立繪白邊 | PNG Alpha 通道設定 | Godot Import → 關閉 Detect 3D，關閉 Mipmaps |
| QuestManager 支線不推進 | require_flag 未滿足 | 確認前置旗標已透過 Dialogic Signal Event 寫入 |

---

*文件版本：v5.0 完整版｜維護者：Chuu｜最後更新：2026-06*
