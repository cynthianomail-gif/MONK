# 《和尚逆天》Monk Go Rogue
## Claude Code 技術實作企劃書 v4.0 — 女神異聞錄5 風格重構版

> **版本說明：** v4.0 全面放棄 3D 即時動作方向，改採「2D 俯視地圖選點探索 ＋ 純回合制戰鬥演出」架構，對齊女神異聞錄5 的核心設計語言。視覺主色調改為霓虹混搭（台北夜市感）。

---

## 🤖 給 Claude Code 的總體指示（必讀）

你是本專案的**首席 2D 遊戲架構師**。執行前確認：

1. **引擎與語言：** Godot 4.3+，全專案 **GDScript**，禁用 C#。
2. **渲染管線：** 改用 **Compatibility**（2D 為主，效能佔用低）。
3. **核心設計原則：** 本遊戲的爽感來自 **UI 動態 + 演出節奏**，不是物理碰撞。所有視覺衝擊透過 `Tween`、`AnimationPlayer`、`Shader` 實現。
4. **命名規則：** 場景節點 PascalCase，腳本變數 snake_case，常數 SCREAMING_SNAKE。
5. **模組化：** 超過 150 行的腳本必須拆為 Component，透過 `signal` 通訊。

---

## 一、專案基本資訊

| 項目 | 規格 |
|------|------|
| 遊戲名稱 | 《和尚逆天》Monk Go Rogue |
| 引擎 | Godot 4.3+，Compatibility 渲染器 |
| 遊戲類型 | 2D 都市探索 RPG ＋ 演出型回合制戰鬥 |
| 視覺風格 | 霓虹混搭（台北夜市感）＋ 水墨潑墨 UI |
| 探索方式 | 2D 手繪台北地圖選點（P5 澀谷地圖風格）|
| 戰鬥方式 | 純回合制（技能選單 ＋ 全螢幕演出）|
| 目標平台 | Windows PC、網頁（HTML5 export）|
| 影像生成 | Higgsfield MCP Skills（角色立繪 + 過場）|
| 存檔格式 | JSON（`user://save.json`）|

---

## 二、整體遊戲流程

```
標題畫面
    ↓
【台北地圖】── 選點探索
    ├── 地點互動（對話、購物、破戒）
    ├── 遭遇敵人 ──→ 【戰鬥畫面】── 勝利/逃跑 ──→ 回地圖
    ├── 小遊戲觸發 ──→ 【小遊戲畫面】──→ 回地圖
    └── 劇情節點 ──→ 【過場演出】──→ 回地圖
    ↓（全部地區通關）
【BOSS 戰】──→ 結局演出
```

**時間系統（簡化版）：**
每次行動（前往地點、戰鬥、對話）消耗 1 個「時段」。
一天分為：上午 → 下午 → 傍晚 → 深夜（共 4 段）。
深夜結束自動存檔，業障值不歸零但功德值小幅回復。

---

## 三、專案資料夾結構

```
res://
├── src/
│   ├── autoloads/
│   │   ├── GameManager.gd        # 玩家數值、時間、旗標
│   │   ├── SaveManager.gd        # JSON 存讀檔
│   │   ├── AudioManager.gd       # BGM / SFX 管理
│   │   ├── SceneRouter.gd        # 場景切換（含轉場動畫）
│   │   ├── DialogueManager.gd    # 對話樹解析
│   │   └── EventBus.gd           # 全域信號總線
│   │
│   ├── screens/
│   │   ├── TitleScreen/
│   │   ├── MapScreen/            # 台北地圖選點主畫面
│   │   ├── BattleScreen/         # 回合制戰鬥畫面
│   │   ├── DialogueScreen/       # 對話演出畫面
│   │   ├── MinigameScreen/       # 小遊戲容器
│   │   └── ResultScreen/         # 戰鬥/小遊戲結果
│   │
│   ├── battle/
│   │   ├── BattleManager.gd      # 回合狀態機
│   │   ├── BattleUI.gd           # 技能選單 + 演出
│   │   ├── Combatant.gd          # 戰鬥實體基底（玩家/敵人共用）
│   │   ├── SkillExecutor.gd      # 技能效果解析執行
│   │   ├── AllOutAttack.gd       # 總攻擊演出邏輯
│   │   └── StatusEffects.gd      # 狀態異常（混亂、灼燒、減速）
│   │
│   ├── systems/
│   │   ├── KarmaSystem.gd        # 業障/功德值管理
│   │   ├── BreakVowSystem.gd     # 三大破戒
│   │   ├── TimeSystem.gd         # 時段管理
│   │   ├── AchievementSystem.gd  # 十二因緣成就
│   │   └── QuestManager.gd       # 任務狀態機
│   │
│   └── ui/
│       ├── NeonFrame.gd          # 霓虹邊框動態組件
│       ├── InkSplashLabel.gd     # 水墨噴濺文字
│       ├── StatBar.gd            # 通用血量/蓄力槽
│       ├── SkillMenu.gd          # P5 風格斜切選單
│       └── TransitionEffect.gd   # 全螢幕轉場特效
│
├── assets/
│   ├── characters/               # Higgsfield 生成立繪（.png）
│   │   ├── wujie/                # 無戒三職業立繪（表情變體）
│   │   ├── enemies/              # 敵人立繪
│   │   ├── cherry/               # Cherry 立繪
│   │   └── boss/                 # 阿瑞斯立繪
│   │
│   ├── backgrounds/              # Higgsfield 生成場景背景
│   │   ├── map/                  # 台北各地點縮略圖
│   │   ├── battle/               # 戰鬥背景（西門町夜、林森北路、廟）
│   │   └── dialogue/             # 對話場景背景
│   │
│   ├── ui/
│   │   ├── neon_frames/          # 霓虹邊框素材
│   │   ├── ink_textures/         # 水墨貼圖
│   │   └── icons/                # 技能圖示、職業圖示
│   │
│   ├── audio/
│   │   ├── bgm/                  # 主題曲、戰鬥曲、地圖曲
│   │   └── sfx/                  # 技能音效、UI 音效
│   │
│   ├── fonts/
│   │   └── NotoSansTC-Bold.ttf
│   │
│   └── higgsfield_outputs/       # Higgsfield 生成資產
│       ├── portraits/            # 角色立繪原始輸出
│       ├── backgrounds/          # 背景圖原始輸出
│       └── cutscenes/            # 過場影片
│
└── data/
    ├── skills.json               # 技能資料庫
    ├── enemies.json              # 敵人資料庫
    ├── dialogue/
    │   ├── main_story.json
    │   └── cherry.json
    ├── map_locations.json        # 地圖地點資料
    ├── achievements.json
    └── higgsfield_prompts/
        ├── portraits.json
        ├── backgrounds.json
        └── cutscenes.json
```

---

## 四、Autoload 全局系統

### 4.1 GameManager.gd

```gdscript
extends Node

# ══ 信號 ══════════════════════════════════
signal stat_changed(key: String, value: Variant)
signal time_advanced(new_period: int)
signal job_changed(new_job: String)

# ══ 常數 ══════════════════════════════════
const MAX_MERIT: int  = 100
const MAX_KARMA: int  = 100
const MAX_HP: int     = 500
const TIME_PERIODS    = ["上午", "下午", "傍晚", "深夜"]

# ══ 玩家資料 ═══════════════════════════════
var player: Dictionary = {
    "name": "無戒",
    "max_hp": MAX_HP,
    "current_hp": MAX_HP,
    "merit": 0,
    "karma": 0,
    "gold": 1000,
    "job": "ascetic",         # ascetic | chanter | beggar
    "skills_unlocked": ["basic_punch", "basic_kick"],
    "day": 1,
    "period": 0,              # 0=上午 1=下午 2=傍晚 3=深夜
    "flags": {},
    "completed_quests": []
}

# ══ 時段推進 ════════════════════════════════
func advance_time(steps: int = 1) -> void:
    player.period += steps
    if player.period >= TIME_PERIODS.size():
        player.period = 0
        player.day += 1
        _on_new_day()
    time_advanced.emit(player.period)

func _on_new_day() -> void:
    # 深夜結束：功德微回復、觸發日常事件
    add_merit(5)
    EventBus.new_day_started.emit(player.day)

# ══ 數值修改 ════════════════════════════════
func add_merit(amount: int) -> void:
    player.merit = clampi(player.merit + amount, 0, MAX_MERIT)
    stat_changed.emit("merit", player.merit)
    if player.merit >= MAX_MERIT:
        EventBus.merit_maxed.emit()

func add_karma(amount: int) -> void:
    player.karma = clampi(player.karma + amount, 0, MAX_KARMA)
    stat_changed.emit("karma", player.karma)
    if player.karma >= MAX_KARMA:
        EventBus.karma_maxed.emit()

func take_damage(amount: int) -> void:
    player.current_hp = clampi(player.current_hp - amount, 0, player.max_hp)
    stat_changed.emit("current_hp", player.current_hp)
    if player.current_hp <= 0:
        EventBus.player_died.emit()

func heal(amount: int) -> void:
    player.current_hp = clampi(player.current_hp + amount, 0, player.max_hp)
    stat_changed.emit("current_hp", player.current_hp)

func spend_gold(amount: int) -> bool:
    if player.gold < amount:
        return false
    player.gold -= amount
    stat_changed.emit("gold", player.gold)
    return true

func switch_job(new_job: String) -> void:
    if new_job not in ["ascetic", "chanter", "beggar"]:
        return
    player.job = new_job
    job_changed.emit(new_job)

# ══ 旗標 ════════════════════════════════════
func set_flag(key: String, val: Variant) -> void:
    player.flags[key] = val

func get_flag(key: String, default: Variant = false) -> Variant:
    return player.flags.get(key, default)
```

---

### 4.2 EventBus.gd

```gdscript
extends Node

# 時間
signal new_day_started(day: int)

# 戰鬥
signal battle_started(enemy_data: Dictionary)
signal battle_ended(result: String)    # "win" | "lose" | "escape"
signal skill_executed(skill_id: String, caster: String, targets: Array)
signal all_out_attack_triggered()
signal heat_action_triggered(job: String)

# 數值
signal merit_maxed()
signal karma_maxed()
signal player_died()
signal combo_count_changed(count: int)

# 劇情
signal vow_broken(vow_type: String)
signal cherry_affection_changed(val: int)
signal quest_updated(id: String, status: String)

# UI
signal dialogue_started(dialogue_id: String)
signal dialogue_ended()
signal map_location_selected(location_id: String)
```

---

### 4.3 SceneRouter.gd（含 P5 風格轉場）

```gdscript
extends Node

# 轉場類型
enum Transition { SLASH_RED, INK_SPLASH, NEON_FLASH, FADE_BLACK }

var _current_transition: Transition = Transition.SLASH_RED

func go_to_battle(enemy_id: String) -> void:
    await _play_transition(Transition.SLASH_RED)
    get_tree().change_scene_to_file("res://src/screens/BattleScreen/BattleScreen.tscn")
    await get_tree().process_frame
    get_tree().get_first_node_in_group("battle_manager").setup(enemy_id)

func go_to_map() -> void:
    await _play_transition(Transition.INK_SPLASH)
    get_tree().change_scene_to_file("res://src/screens/MapScreen/MapScreen.tscn")

func go_to_dialogue(dialogue_id: String) -> void:
    await _play_transition(Transition.FADE_BLACK)
    get_tree().change_scene_to_file("res://src/screens/DialogueScreen/DialogueScreen.tscn")
    await get_tree().process_frame
    DialogueManager.start(dialogue_id)

func _play_transition(type: Transition) -> void:
    var overlay := preload("res://src/ui/TransitionEffect.tscn").instantiate()
    get_tree().root.add_child(overlay)
    overlay.play(type)
    await overlay.finished
    overlay.queue_free()
```

---

## 五、台北地圖畫面（MapScreen）

### 5.1 設計概念

P5 的澀谷地圖是本畫面的直接參考：
- 全螢幕手繪風格台北鳥瞰插圖（Higgsfield 生成）
- 各地點以**霓虹發光圓點**標示，可點選
- 點選後展開**地點卡片**（地點名稱、可用行動、當前 NPC）
- 右上角顯示「第 X 天 / 傍晚」時段資訊
- 背景音樂依時段切換（上午輕快、深夜低沉）

### 5.2 地點資料（map_locations.json）

```json
{
  "ximen_mrt": {
    "name": "捷運西門站 6 號出口",
    "district": "ximen",
    "position": {"x": 320, "y": 410},
    "actions": ["beggar_minigame", "random_encounter"],
    "available_periods": [1, 2, 3],
    "bgm": "ximen_night",
    "background": "bg_ximen_mrt.png",
    "description": "人潮最密集的出口。化緣勝地，也是扒手重災區。"
  },
  "wannian_mall": {
    "name": "萬年商業大樓",
    "district": "ximen",
    "position": {"x": 290, "y": 380},
    "actions": ["shop", "greed_break_trigger"],
    "available_periods": [0, 1, 2],
    "shop_id": "wannian_shop",
    "description": "五層樓的精品殿堂。純金勞力士念珠在三樓等著你。"
  },
  "zen_bbq": {
    "name": "禪味燒肉",
    "district": "wanhua_old",
    "position": {"x": 180, "y": 510},
    "actions": ["food_break_trigger", "rest"],
    "available_periods": [2, 3],
    "description": "深夜飄出的牛油香。三千金幣換一場破戒的美味。"
  },
  "zuijin_club": {
    "name": "紫醉金迷公關俱樂部",
    "district": "linsen",
    "position": {"x": 520, "y": 280},
    "actions": ["cherry_dialogue", "lust_break_trigger"],
    "available_periods": [3],
    "unlock_flag": "linsen_unlocked",
    "description": "林森北路地下室。Cherry 在這裡等你。"
  },
  "old_temple": {
    "name": "破舊古廟",
    "district": "wanhua_old",
    "position": {"x": 160, "y": 490},
    "actions": ["save", "job_switch", "rest", "skill_learn"],
    "available_periods": [0, 1, 2, 3],
    "description": "無戒的大本營。廟裡很破，但心很定。"
  }
}
```

### 5.3 MapScreen.gd（核心邏輯）

```gdscript
extends Node2D

@onready var location_dots: Node2D = $LocationDots
@onready var location_card: Control = $LocationCard
@onready var time_label: Label = $TimePanel/TimeLabel
@onready var day_label: Label = $TimePanel/DayLabel

var locations_data: Dictionary = {}
var _selected_location: String = ""

func _ready() -> void:
    locations_data = _load_locations()
    _build_location_dots()
    _update_time_display()
    GameManager.time_advanced.connect(_on_time_advanced)

func _build_location_dots() -> void:
    for id in locations_data:
        var loc: Dictionary = locations_data[id]
        # 檢查是否需要旗標解鎖
        if loc.has("unlock_flag") and not GameManager.get_flag(loc.unlock_flag):
            continue
        # 檢查當前時段是否開放
        if GameManager.player.period not in loc.available_periods:
            continue
        var dot := preload("res://src/screens/MapScreen/LocationDot.tscn").instantiate()
        dot.setup(id, loc)
        dot.position = Vector2(loc.position.x, loc.position.y)
        dot.pressed.connect(_on_location_selected.bind(id))
        location_dots.add_child(dot)

func _on_location_selected(location_id: String) -> void:
    _selected_location = location_id
    var loc := locations_data[location_id]
    location_card.show_location(loc)

func perform_action(action_id: String) -> void:
    location_card.hide()
    GameManager.advance_time(1)
    match action_id:
        "random_encounter":
            var enemy := _pick_random_enemy(locations_data[_selected_location].district)
            SceneRouter.go_to_battle(enemy)
        "cherry_dialogue":
            SceneRouter.go_to_dialogue("cherry_main")
        "food_break_trigger":
            BreakVowSystem.try_trigger("food")
        "greed_break_trigger":
            BreakVowSystem.try_trigger("greed")
        "beggar_minigame":
            SceneRouter.go_to_minigame("beggar_challenge")
        "save":
            SaveManager.save_game()
            _show_save_toast()
        "job_switch":
            _open_job_menu()

func _update_time_display() -> void:
    day_label.text = "第 %d 天" % GameManager.player.day
    time_label.text = GameManager.TIME_PERIODS[GameManager.player.period]

func _on_time_advanced(_period: int) -> void:
    _update_time_display()
    _rebuild_dots()   # 依新時段重建可用地點

func _rebuild_dots() -> void:
    for child in location_dots.get_children():
        child.queue_free()
    _build_location_dots()
```

---

## 六、回合制戰鬥系統

### 6.1 設計概念（P5 戰鬥語言翻譯）

| P5 元素 | 《和尚逆天》對應 |
|---------|----------------|
| 怪物弱點（槍/火/冰）| 敵人弱點（業障技/功德技/道具技）|
| Baton Pass | 連續超渡（擊中弱點換下一個技能免費出）|
| All-Out Attack | **超渡大陣**（全場業障/功德滿時觸發）|
| Hold Up | **恐嚇化緣**（打倒全場後強制索金）|
| Showtime | **如來神掌 / 金剛薩埵大陣**（各職業限定）|

### 6.2 BattleManager.gd（回合狀態機）

```gdscript
extends Node
class_name BattleManager

enum BattleState {
    PLAYER_TURN,
    ENEMY_TURN,
    SKILL_ANIMATION,
    ALL_OUT_ATTACK,
    HOLD_UP,
    BATTLE_END
}

signal state_changed(new_state: BattleState)
signal turn_started(is_player: bool)
signal enemy_weakpoint_hit(enemy_id: String)

var state: BattleState = BattleState.PLAYER_TURN
var player_combatant: Combatant
var enemy_combatants: Array[Combatant] = []
var _consecutive_hits: int = 0   # 連續擊中弱點計數（Baton Pass 機制）

func setup(enemy_id: String) -> void:
    var enemy_data: Dictionary = _load_enemy(enemy_id)
    player_combatant = _create_player_combatant()
    enemy_combatants = _create_enemy_group(enemy_data)
    _start_battle()

func _start_battle() -> void:
    AudioManager.switch_bgm("battle_theme")
    await BattleUI.play_encounter_intro()
    _change_state(BattleState.PLAYER_TURN)

# ── 玩家選擇技能後呼叫
func player_use_skill(skill_id: String, target_idx: int) -> void:
    if state != BattleState.PLAYER_TURN:
        return
    _change_state(BattleState.SKILL_ANIMATION)
    var result := await SkillExecutor.execute(skill_id, player_combatant,
                                               enemy_combatants[target_idx])
    _process_skill_result(result)

func _process_skill_result(result: Dictionary) -> void:
    # 擊中弱點
    if result.get("hit_weakness"):
        _consecutive_hits += 1
        enemy_weakpoint_hit.emit(result.target_id)
        EventBus.combo_count_changed.emit(_consecutive_hits)
        # 全場都被弱點擊倒 → 觸發超渡大陣
        if _all_enemies_downed():
            await _trigger_all_out_attack()
            return
        # 否則：玩家可繼續行動（Baton Pass）
        _change_state(BattleState.PLAYER_TURN)
        return
    # 普通擊中：回合結束，輪到敵人
    _consecutive_hits = 0
    _check_battle_end()
    if state != BattleState.BATTLE_END:
        await _enemy_turn()

func _enemy_turn() -> void:
    _change_state(BattleState.ENEMY_TURN)
    for enemy in enemy_combatants:
        if enemy.is_alive():
            await SkillExecutor.execute_enemy_action(enemy, player_combatant)
            await get_tree().create_timer(0.5).timeout
    _check_battle_end()
    if state != BattleState.BATTLE_END:
        _consecutive_hits = 0
        _change_state(BattleState.PLAYER_TURN)

func _trigger_all_out_attack() -> void:
    _change_state(BattleState.ALL_OUT_ATTACK)
    await AllOutAttack.play()
    # 超渡大陣造成全場傷害
    for enemy in enemy_combatants:
        enemy.take_damage(9999)
    await get_tree().create_timer(1.0).timeout
    _check_battle_end()

func _all_enemies_downed() -> bool:
    return enemy_combatants.all(func(e): return e.is_downed or not e.is_alive())

func _check_battle_end() -> void:
    var all_dead := enemy_combatants.all(func(e): return not e.is_alive())
    if all_dead:
        _change_state(BattleState.BATTLE_END)
        _on_victory()
    elif not player_combatant.is_alive():
        _change_state(BattleState.BATTLE_END)
        _on_defeat()

func _on_victory() -> void:
    # Hold Up 判定（全場倒地時可以強制化緣）
    await BattleUI.play_victory_fanfare()
    var gold_reward: int = _calculate_gold_reward()
    GameManager.player.gold += gold_reward
    GameManager.add_merit(15)
    EventBus.battle_ended.emit("win")
    await get_tree().create_timer(1.5).timeout
    SceneRouter.go_to_map()

func _on_defeat() -> void:
    await BattleUI.play_defeat_sequence()
    EventBus.battle_ended.emit("lose")

func _change_state(new_state: BattleState) -> void:
    state = new_state
    state_changed.emit(new_state)
```

---

### 6.3 技能資料庫（skills.json）

```json
{
  "basic_punch": {
    "name": "鐵拳",
    "job": "any",
    "cost": {"karma": 0, "merit": 0, "hp": 0},
    "damage_type": "physical",
    "power": 80,
    "target": "single",
    "weakness_type": null,
    "description": "基本近身攻擊。",
    "animation": "anim_punch"
  },
  "arhat_strike": {
    "name": "羅漢伏虎",
    "job": "ascetic",
    "cost": {"karma": 20},
    "damage_type": "karma",
    "power": 180,
    "target": "single",
    "weakness_type": "karma",
    "special": "knockdown",
    "description": "業障化為鐵拳，擊飛正面敵人。擊中弱點可繼續行動。",
    "animation": "anim_arhat"
  },
  "sound_wave": {
    "name": "梵音氣功",
    "job": "chanter",
    "cost": {"merit": 15},
    "damage_type": "merit",
    "power": 120,
    "target": "all",
    "weakness_type": "merit",
    "description": "敲擊木魚釋放音波，打擊全場敵人。",
    "animation": "anim_soundwave"
  },
  "great_compassion_shield": {
    "name": "大悲咒護罩",
    "job": "chanter",
    "cost": {"merit": 30},
    "damage_type": "support",
    "effect": "barrier",
    "barrier_value": 200,
    "target": "self",
    "description": "佛光護盾，抵擋下一次攻擊的全部傷害。",
    "animation": "anim_shield"
  },
  "lions_roar": {
    "name": "獅子吼",
    "job": "beggar",
    "cost": {"karma": 25},
    "damage_type": "karma",
    "power": 90,
    "target": "all",
    "special": "chaos",
    "chaos_duration": 2,
    "description": "扇形吼聲令全場敵人進入混亂，互相毆打 2 回合。",
    "animation": "anim_roar"
  },
  "tathagata_palm": {
    "name": "如來神掌",
    "job": "ascetic",
    "cost": {"karma": 100},
    "damage_type": "karma",
    "power": 9999,
    "target": "single",
    "is_heat_action": true,
    "description": "【業障滿值限定】躍至空中，單掌從天而降。",
    "animation": "anim_heat_tathagata"
  },
  "diamond_sutra_formation": {
    "name": "金剛薩埵超渡大陣",
    "job": "chanter",
    "cost": {"merit": 100},
    "damage_type": "merit",
    "power": 500,
    "target": "all",
    "ignore_defense": true,
    "is_heat_action": true,
    "description": "【功德滿值限定】梵文金光鎖定全場，無視防禦的淨化傷害。",
    "animation": "anim_heat_diamond"
  }
}
```

---

### 6.4 BattleUI.gd（P5 風格技能選單演出）

```gdscript
extends CanvasLayer

# ══ 節點引用 ══════════════════════════════
@onready var skill_menu: Control       = $SkillMenu
@onready var enemy_sprites: HBoxContainer = $EnemyArea/EnemySprites
@onready var player_portrait: TextureRect = $PlayerArea/Portrait
@onready var status_bar: Control       = $StatusBar
@onready var combo_label: Label        = $ComboDisplay/Label
@onready var anim_player: AnimationPlayer = $AnimationPlayer

# ══ P5 風格技能選單 ══════════════════════
func show_skill_menu(available_skills: Array) -> String:
    # 斜切選單從左側飛入
    skill_menu.visible = true
    var tween := create_tween()
    tween.tween_property(skill_menu, "position:x", 0.0, 0.2)\
         .from(-300.0)\
         .set_ease(Tween.EASE_OUT)\
         .set_trans(Tween.TRANS_BACK)
    # 填充技能按鈕
    _populate_skill_buttons(available_skills)
    # 等待玩家選擇（透過 signal）
    var selected: String = await SkillMenu.skill_selected
    skill_menu.visible = false
    return selected

func _populate_skill_buttons(skills: Array) -> void:
    for child in skill_menu.get_children():
        child.queue_free()
    for skill_id in skills:
        var btn := preload("res://src/ui/SkillButton.tscn").instantiate()
        btn.setup(skill_id)
        btn.pressed.connect(func(): SkillMenu.skill_selected.emit(skill_id))
        skill_menu.add_child(btn)

# ══ 技能演出 ══════════════════════════════
func play_skill_animation(skill_id: String, hit_weakness: bool) -> void:
    # 全螢幕技能名稱砸入
    anim_player.play("skill_name_splash")
    await anim_player.animation_finished
    # 依技能播放對應動畫
    anim_player.play(SkillData.get(skill_id).animation)
    await anim_player.animation_finished
    # 命中弱點特效
    if hit_weakness:
        anim_player.play("weakness_burst")
        AudioManager.play_sfx("weakness_hit")
        await anim_player.animation_finished

# ══ 超渡大陣（All-Out Attack）演出 ════════
func play_all_out_attack_intro() -> void:
    # 畫面切換為剪影風格（P5 All-Out Attack 演出）
    anim_player.play("all_out_intro")
    AudioManager.switch_bgm("all_out_theme")
    await anim_player.animation_finished

# ══ 遭遇演出 ══════════════════════════════
func play_encounter_intro() -> void:
    anim_player.play("encounter_slash")    # 紅色斜切劃入
    AudioManager.play_sfx("encounter_sting")
    await anim_player.animation_finished

# ══ Combo 計數顯示 ═══════════════════════
func _ready() -> void:
    EventBus.combo_count_changed.connect(_on_combo_changed)

func _on_combo_changed(count: int) -> void:
    if count <= 1:
        combo_label.visible = false
        return
    combo_label.visible = true
    combo_label.text = "連擊 ×%d" % count
    var tween := create_tween()
    tween.tween_property(combo_label, "scale", Vector2(1.3, 1.3), 0.1)
    tween.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.1)
```

---

## 七、視覺風格系統（霓虹混搭 UI）

### 7.1 色彩語言

| 用途 | 色碼 | 說明 |
|------|------|------|
| 業障主色 | `#FF2D2D` | 深紅熾熱 |
| 業障輔色 | `#FF6B00` | 橘焰 |
| 功德主色 | `#FFD700` | 純金 |
| 功德輔色 | `#FFFACD` | 淡金光 |
| 霓虹綠（檳榔攤）| `#39FF14` | 高彩度 |
| 霓虹粉（酒吧）| `#FF69B4` | 粉紅霓虹 |
| 霓虹藍（捷運）| `#00BFFF` | 深天藍 |
| UI 底色 | `#0A0A0A` | 近黑（不是純黑）|
| 文字主色 | `#F5F5F0` | 暖白 |
| 水墨黑 | `#1A0A00` | 深褐黑（水墨感）|

### 7.2 UI 特徵設計

**技能選單（SkillMenu.gd）：**
```
┌──────────────────┐
│ ▶ 鐵拳           │  ← 選中項目：背景霓虹色填滿，文字反白
│   羅漢伏虎  ○20  │  ← 未選：透明背景，左側紅色豎線
│   梵音氣功  ◇15  │
│   如來神掌  ████ │  ← 滿值限定：金色邊框閃爍
└──────────────────┘
整體向右斜切 8°（P5 招牌斜排版）
```

**傷害數字（InkSplashLabel.gd）：**
```gdscript
extends Label

func splash(damage: int, damage_type: String, is_critical: bool) -> void:
    text = str(damage)
    # 依傷害類型設定顏色
    match damage_type:
        "karma":   add_theme_color_override("font_color", Color("#FF2D2D"))
        "merit":   add_theme_color_override("font_color", Color("#FFD700"))
        "physical":add_theme_color_override("font_color", Color("#F5F5F0"))
    # 暴擊放大
    var base_scale := Vector2(1.5, 1.5) if is_critical else Vector2(1.0, 1.0)
    scale = base_scale * 1.5
    var tween := create_tween()
    tween.tween_property(self, "scale", base_scale, 0.15)\
         .set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(self, "position:y", position.y - 60.0, 0.6)
    tween.tween_property(self, "modulate:a", 0.0, 0.3)
    await tween.finished
    queue_free()
```

**轉場特效（TransitionEffect.gd）：**
```gdscript
extends CanvasLayer

signal finished

func play(type: SceneRouter.Transition) -> void:
    match type:
        SceneRouter.Transition.SLASH_RED:
            # 紅色對角斜切劃過全螢幕
            $AnimationPlayer.play("slash_red")
        SceneRouter.Transition.INK_SPLASH:
            # 水墨從中央噴灑擴散至全螢幕
            $AnimationPlayer.play("ink_splash")
        SceneRouter.Transition.NEON_FLASH:
            # 霓虹色閃爍三次後淡出
            $AnimationPlayer.play("neon_flash")
        SceneRouter.Transition.FADE_BLACK:
            $AnimationPlayer.play("fade_black")
    await $AnimationPlayer.animation_finished
    finished.emit()
```

---

## 八、三大破戒系統

### 8.1 BreakVowSystem.gd

```gdscript
extends Node

const VOWS: Dictionary = {
    "food": {
        "name": "飲食戒",
        "location_id": "zen_bbq",
        "gold_cost": 3000,
        "karma_gain": 50,
        "description": "吃下那碗極品和牛。業障滾燙，但真的太香了。",
        "effect": "berserker",          # 戰鬥中物理傷害 +50%，持續 3 天
        "crowd_reaction": "oil_shame",
        "flag": "broke_food_vow"
    },
    "lust": {
        "name": "色戒",
        "location_id": "zuijin_club",
        "gold_cost": 5000,
        "karma_gain": 30,
        "description": "Cherry 靠近時，你沒有起身離開。",
        "effect": "cherry_combat_ally",  # Cherry 解鎖為戰鬥後援
        "flag": "broke_lust_vow"
    },
    "greed": {
        "name": "貪戒",
        "location_id": "wannian_mall",
        "gold_cost": 8000,
        "karma_gain": 40,
        "description": "純金勞力士念珠戴上的瞬間，你感覺自己是台北之王。",
        "effect": "gold_multiplier",     # 戰鬥金幣獎勵 ×2，但地圖遭遇扒手機率 +40%
        "flag": "broke_greed_vow"
    }
}

func try_trigger(vow_type: String) -> void:
    var vow: Dictionary = VOWS.get(vow_type, {})
    if vow.is_empty():
        return
    if GameManager.get_flag(vow.flag):
        # 已破戒：提示語改為「業已鑄成」
        DialogueManager.show_quick_line("業已鑄成……再吃一次也無妨。")
        return
    # 顯示破戒確認對話
    DialogueManager.show_confirm(
        vow.description,
        "破戒（-%d 金）" % vow.gold_cost,
        "克制離開",
        func(): _execute_break(vow_type, vow),
        func(): DialogueManager.show_quick_line("南無阿彌陀佛……")
    )

func _execute_break(vow_type: String, vow: Dictionary) -> void:
    if not GameManager.spend_gold(vow.gold_cost):
        DialogueManager.show_quick_line("……金幣不夠。業障暫時饒過你了。")
        return
    GameManager.add_karma(vow.karma_gain)
    GameManager.set_flag(vow.flag, true)
    # 播放破戒過場（Higgsfield 生成的影片）
    SceneRouter.play_cutscene("cutscene_break_" + vow_type)
    EventBus.vow_broken.emit(vow_type)
    _apply_effect(vow_type, vow.effect)

func _apply_effect(vow_type: String, effect_id: String) -> void:
    match effect_id:
        "berserker":
            GameManager.set_flag("buff_berserker_days", 3)
        "cherry_combat_ally":
            GameManager.set_flag("cherry_unlocked", true)
        "gold_multiplier":
            GameManager.set_flag("gold_multiplier_active", true)
            GameManager.set_flag("pickpocket_rate_up", true)
```

---

## 九、對話系統（DialogueScreen）

### 9.1 設計概念

P5 的對話演出核心：**左側角色立繪 + 右側文字框 + 說話者名牌**。
本遊戲加入：台北在地語氣（台灣繁體，偶爾夾雜台語）、立繪表情切換、選項觸發分歧。

### 9.2 dialogue_main_story.json（節錄）

```json
{
  "cherry_first_meeting": {
    "background": "bg_zuijin_club.png",
    "bgm": "cherry_theme",
    "lines": [
      {
        "speaker": "Cherry",
        "portrait": "cherry_neutral.png",
        "text": "師父，你是第一次來吧？",
        "sfx": "glass_clink"
      },
      {
        "speaker": "無戒",
        "portrait": "wujie_surprised.png",
        "text": "……阿彌陀佛。我只是路過。"
      },
      {
        "speaker": "Cherry",
        "portrait": "cherry_smile.png",
        "text": "路過的和尚不會在門口站三分鐘。",
        "trigger_affection": 5
      },
      {
        "type": "choice",
        "prompt": "你要怎麼回答？",
        "options": [
          {
            "text": "「我在……觀察眾生苦。」",
            "next": "cherry_response_a",
            "karma_change": -5,
            "merit_change": 10
          },
          {
            "text": "「……你怎麼知道？」",
            "next": "cherry_response_b",
            "affection_change": 10
          }
        ]
      }
    ]
  }
}
```

### 9.3 DialogueManager.gd（核心）

```gdscript
extends Node

signal line_displayed(line: Dictionary)
signal choice_requested(options: Array)
signal dialogue_completed()

var _current_dialogue: Array = []
var _current_index: int = 0

func start(dialogue_id: String) -> void:
    var data := _load_dialogue(dialogue_id)
    _current_dialogue = data.lines
    _current_index = 0
    EventBus.dialogue_started.emit(dialogue_id)
    _display_next()

func advance() -> void:
    _current_index += 1
    if _current_index >= _current_dialogue.size():
        _finish()
        return
    _display_next()

func _display_next() -> void:
    var line: Dictionary = _current_dialogue[_current_index]
    if line.get("type") == "choice":
        choice_requested.emit(line.options)
        return
    # 套用旗標觸發
    if line.has("trigger_affection"):
        EventBus.cherry_affection_changed.emit(
            GameManager.get_flag("cherry_affection", 0) + line.trigger_affection
        )
    if line.has("karma_change"):
        GameManager.add_karma(line.karma_change)
    if line.has("merit_change"):
        GameManager.add_merit(line.merit_change)
    line_displayed.emit(line)

func choose(option_index: int, options: Array) -> void:
    var opt: Dictionary = options[option_index]
    if opt.has("affection_change"):
        var cur: int = GameManager.get_flag("cherry_affection", 0)
        GameManager.set_flag("cherry_affection", cur + opt.affection_change)
    if opt.has("karma_change"):
        GameManager.add_karma(opt.karma_change)
    if opt.has("merit_change"):
        GameManager.add_merit(opt.merit_change)
    start(opt.next)

func show_confirm(message: String, yes_text: String, no_text: String,
                  on_yes: Callable, on_no: Callable) -> void:
    # 顯示二選一確認框，呼叫對應 Callable
    pass

func _finish() -> void:
    _current_dialogue = []
    _current_index = 0
    EventBus.dialogue_ended.emit()
    dialogue_completed.emit()
```

---

## 十、小遊戲（P5 風格重製版）

### 10.1 捷運化緣（BeggarChallenge）

**視角：** 2D 側視固定鏡頭，路人從右側走入畫面。

```gdscript
# BeggarChallenge.gd
extends Node2D

var score: int = 0
var time_left: float = 60.0
var _spawn_timer: float = 0.0
const SPAWN_INTERVAL: float = 1.2

const CITIZEN_TYPES: Dictionary = {
    "office_worker": {"reward": 50,  "weight": 0.4, "speed": 180.0},
    "tourist":       {"reward": 100, "weight": 0.3, "speed": 120.0},
    "rich_lady":     {"reward": 500, "weight": 0.1, "speed": 100.0},
    "drunk_man":     {"reward": 10,  "weight": 0.2, "speed": 220.0}
}

func _process(delta: float) -> void:
    time_left -= delta
    if time_left <= 0.0:
        _end_minigame()
        return
    _spawn_timer += delta
    if _spawn_timer >= SPAWN_INTERVAL:
        _spawn_timer = 0.0
        _spawn_citizen()

func _on_citizen_in_range(citizen: Node2D) -> void:
    if Input.is_action_just_pressed("interact"):
        var reward: int = CITIZEN_TYPES[citizen.citizen_type].reward
        # 行動支付加成
        if GameManager.get_flag("has_qr_code"):
            reward = int(reward * 3.0)
        score += reward
        citizen.play_donate_anim()
        _show_popup("+%d" % reward, citizen.position)
```

### 10.2 端湯上塔（SoupCarry）—— 純 2D 版

```gdscript
# SoupCarry2D.gd — 改為 2D 橫版，碗的傾斜以 2D Sprite 旋轉表現
extends Node2D

var bowl_tilt: float = 0.0       # -MAX_TILT ~ +MAX_TILT
var spillage: float = 0.0
var floor_index: int = 1         # 當前層數（1~10）
const MAX_TILT: float = 25.0

@onready var bowl_sprite: Sprite2D = $BowlSprite
@onready var spill_particles: CPUParticles2D = $SpillParticles

func _input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        bowl_tilt += event.relative.x * 0.15

func _process(delta: float) -> void:
    # 各層干擾事件
    var wind := _get_floor_wind(floor_index) * delta
    bowl_tilt += wind
    # 超出上限 → 溢出
    if absf(bowl_tilt) > MAX_TILT:
        spillage += (absf(bowl_tilt) - MAX_TILT) * delta * 8.0
        spill_particles.emitting = true
    else:
        spill_particles.emitting = false
    # 自然回正阻尼
    bowl_tilt = lerpf(bowl_tilt, 0.0, 2.5 * delta)
    # 更新碗的旋轉
    bowl_sprite.rotation_degrees = bowl_tilt
    if spillage >= 100.0:
        _game_over()

func _get_floor_wind(floor: int) -> float:
    # 7樓以上加強風
    if floor >= 7:
        return sin(Time.get_ticks_msec() * 0.002) * 12.0
    return sin(Time.get_ticks_msec() * 0.001) * 3.0
```

---

## 十一、Higgsfield 整合（v4 更新版）

### 11.1 安裝與設定

```bash
# 在專案根目錄執行
npx skills add higgsfield-ai/skills
higgsfield auth login
```

### 11.2 本專案 Higgsfield 使用重點

v4 改為 **2D 立繪驅動遊戲**，對 Higgsfield 的依賴度反而更高：

| 資產類型 | 數量 | Higgsfield 模式 |
|---------|------|----------------|
| 角色立繪（含表情變體）| ~20 張 | Text-to-Image (Soul) |
| 戰鬥背景 | 5 張 | Text-to-Image (Nano Banana) |
| 地圖各地點縮略圖 | 8 張 | Text-to-Image (Nano Banana) |
| 破戒過場動畫 | 3 段 | Text-to-Video (Seedance，各 4–6 秒) |
| 熱血處決演出 | 2 段 | Text-to-Video (Seedance，各 6 秒) |

### 11.3 Prompt 資料庫（portraits.json 節錄）

```json
{
  "wujie_neutral": {
    "prompt": "2D visual novel portrait, Taiwanese Buddhist monk in his 30s, shaved head, worn grey kasaya robe, calm neutral expression, standing pose, upper body shot, modern Taipei neon city background visible through window, hand-drawn illustration style, clean lineart, flat color with cel shading, character sheet quality",
    "negative": "3D render, photorealistic, cartoon chibi, western monk, weapons, robes too clean",
    "model": "soul",
    "aspect_ratio": "2:3",
    "output_path": "assets/higgsfield_outputs/portraits/wujie_neutral.png"
  },
  "wujie_angry": {
    "prompt": "2D visual novel portrait, same Buddhist monk, intense furious expression, eyebrows furrowed, slight forward lean, veins faintly visible on forehead, otherwise same style as wujie_neutral",
    "negative": "3D render, photorealistic, smiling, peaceful",
    "model": "soul",
    "aspect_ratio": "2:3",
    "output_path": "assets/higgsfield_outputs/portraits/wujie_angry.png"
  },
  "cherry_smile": {
    "prompt": "2D visual novel portrait, Taiwanese hostess woman in her late 20s, elegant black evening dress, warm genuine smile, slightly tired eyes that carry a story, neon-lit bar interior softly visible behind her, hand-drawn illustration style, cel shading, upper body shot",
    "negative": "3D render, explicit, revealing clothing, childlike",
    "model": "soul",
    "aspect_ratio": "2:3",
    "output_path": "assets/higgsfield_outputs/portraits/cherry_smile.png"
  },
  "bg_battle_ximen": {
    "prompt": "2D game background, Ximending Taipei street at midnight, raining lightly, wet neon-lit pavement, betel nut shop green glow, convenience store in distance, empty street ready for a fight, anime-style background art, highly detailed, atmospheric perspective",
    "negative": "characters, people, photorealistic, daytime",
    "model": "nano_banana",
    "aspect_ratio": "16:9",
    "output_path": "assets/higgsfield_outputs/backgrounds/bg_battle_ximen.png"
  }
}
```

### 11.4 Claude Code 執行流程

```
1. 讀取 portraits.json
2. 逐筆確認 output_path 是否已存在（跳過已生成）
3. 執行：/higgsfield:generate --prompt "..." --model soul --aspect 2:3
4. 下載至 output_path
5. 對過場影片：ffmpeg 轉換 .mp4 → .ogv
6. 在 Godot 重新匯入資源（提示開發者按 F5 重整）
```

---

## 十二、成就系統（十二因緣鏈）

```gdscript
# achievements.json（對應 AchievementSystem.gd）
{
  "ignorance":    {"name": "無明", "desc": "完成第一場戰鬥"},
  "formation":    {"name": "行",   "desc": "累積連擊（弱點）10 次"},
  "consciousness":{"name": "識",   "desc": "Cherry 好感度達 100"},
  "name_form":    {"name": "名色", "desc": "三大破戒全數完成"},
  "six_bases":    {"name": "六入", "desc": "探索全部台北地點"},
  "contact":      {"name": "觸",   "desc": "使用全部三種職業的熱血處決"},
  "sensation":    {"name": "受",   "desc": "單場戰鬥金幣收入破 2000"},
  "craving":      {"name": "愛",   "desc": "在化緣小遊戲單次超過 5000 元"},
  "clinging":     {"name": "取",   "desc": "業障與功德同時滿值"},
  "becoming":     {"name": "有",   "desc": "擊倒 50 名敵人"},
  "birth":        {"name": "生",   "desc": "通關主線第二幕"},
  "aging_death":  {"name": "老死", "desc": "達成所有結局"}
}
```

---

## 十三、開發步驟（給 Claude Code 的藍圖）

### Step 1：基礎架構
- [ ] 建立資料夾結構（依第三章）
- [ ] 設定 `project.godot`（Compatibility 渲染器，1920×1080，2D 像素抗鋸齒關閉）
- [ ] 建立全部 Autoload（GameManager、SaveManager、AudioManager、SceneRouter、DialogueManager、EventBus）
- [ ] 建立 MapScreen 佔位符（純色背景 + 一個可點擊的 Button）
- **驗收：** 點擊按鈕觸發 `SceneRouter.go_to_battle("test_enemy")`，Console 無錯誤

### Step 2：回合制戰鬥核心
- [ ] 實作 `BattleManager.gd`（狀態機）
- [ ] 實作 `Combatant.gd`（血量、技能列表、弱點屬性）
- [ ] 實作 `SkillExecutor.gd`（讀取 skills.json，計算傷害）
- [ ] 實作 `AllOutAttack.gd`（超渡大陣演出框架）
- [ ] 建立最簡 BattleUI（技能按鈕清單，可點擊出招）
- **驗收：** 可與佔位符敵人完整打一場回合制戰鬥並獲勝，回到地圖

### Step 3：UI 動態與風格
- [ ] 實作 `TransitionEffect.gd`（至少：SLASH_RED 與 FADE_BLACK）
- [ ] 實作斜切技能選單（SkillMenu，帶 Tween 飛入動畫）
- [ ] 實作 `InkSplashLabel.gd` 傷害飄字（三色：紅/金/白）
- [ ] 實作 `StatBar.gd`（血量槽＋業障槽＋功德槽，帶緩衝條 Tween）
- **驗收：** 戰鬥畫面有完整霓虹風格 UI，傷害數字有動態

### Step 4：Higgsfield 資產批次生產
- [ ] 安裝 Higgsfield Skills，登入帳號
- [ ] 依 `portraits.json` 生成：無戒 3 表情 ×3 職業 = 9 張；Cherry 3 表情 = 3 張
- [ ] 依 `backgrounds.json` 生成戰鬥背景 5 張＋地圖縮略圖 8 張
- [ ] 執行 `higgsfield_import.sh` 匯入資源
- **驗收：** `assets/higgsfield_outputs/` 內圖片完整，Godot 可正常顯示

### Step 5：地圖畫面與時間系統
- [ ] 實作 `TimeSystem.gd`（時段推進、新的一天觸發）
- [ ] 實作 `MapScreen.gd`（讀取 `map_locations.json`，動態建立地點按鈕）
- [ ] 實作地點卡片（LocationCard.tscn，顯示地點描述與可用行動）
- [ ] 套用 Higgsfield 生成的台北地圖插圖為背景
- **驗收：** 地圖可點選各地點，消耗時段，深夜自動存檔

### Step 6：對話系統與破戒
- [ ] 實作 `DialogueManager.gd`（讀取 JSON，逐行顯示，處理選項）
- [ ] 實作 `DialogueScreen.tscn`（立繪 + 文字框 + 名牌）
- [ ] 套用 Higgsfield 立繪至對話畫面
- [ ] 實作 `BreakVowSystem.gd`（三大破戒確認流程）
- [ ] 串接 Higgsfield 過場影片（破戒演出）
- **驗收：** Cherry 對話可完整走一輪，選項觸發不同後果；食戒破戒流程完整

### Step 7：小遊戲
- [ ] 實作化緣小遊戲（BeggarChallenge，含路人生成＋計時）
- [ ] 實作端湯小遊戲（SoupCarry2D，含阻尼物理）
- [ ] 實作木魚節奏戰（WoodenFishRhythm，含 Combo 計數）
- **驗收：** 三個小遊戲可獨立完整遊玩

### Step 8：整合與成就
- [ ] 串接 `SaveManager.gd`
- [ ] 實作 `AchievementSystem.gd`（十二因緣）
- [ ] 連結所有場景轉場（地圖→戰鬥→地圖→對話→地圖）
- [ ] 音效與 BGM 全部到位（至少：地圖曲、戰鬥曲、Cherry 主題、破戒演出）
- **驗收：** 可從標題完整玩到第一幕結尾，無 crash

---

## 十四、輸入對照表

| 動作 | 鍵盤 | Gamepad |
|------|------|---------|
| `ui_accept` | Enter / Space | A |
| `ui_cancel` | Esc / Backspace | B |
| `ui_up/down/left/right` | 方向鍵 | 左搖桿 / 方向鍵 |
| `interact` | E | A |
| `skill_1~5` | 1~5（戰鬥選單快捷）| 無（純選單操作）|
| `job_switch` | Tab（開啟職業選單）| Y |
| `pause` | Esc | Start |

> 注意：v4 為 2D 選單驅動遊戲，大多數操作透過滑鼠點擊或方向鍵選單完成，無需複雜的即時輸入映射。

---

## 十五、常見問題排除

| 問題 | 原因 | 解法 |
|------|------|------|
| 技能選單 Tween 動畫卡頓 | 每次都重新 instantiate 選單節點 | 改為常駐節點，用 `visible` 切換 |
| 業障槽顏色不對 | `add_theme_color_override` 在 Tween 中被覆蓋 | 改用 ShaderMaterial 控制顏色 |
| Higgsfield 立繪有白邊 | PNG 匯入設定未開啟 Alpha 通道 | Godot Import → 確認 `Detect 3D` 關閉，`Mipmaps` 關閉 |
| 對話選項信號重複觸發 | 按鈕 `pressed` 信號沒有 disconnect | 使用 `connect(..., CONNECT_ONE_SHOT)` |
| 過場影片無法播放 | .ogv 需要 VideoStreamTheora plugin | 確認 Godot 內建 `theora` 已啟用（Export → Features）|
| 存檔後讀檔地點不對 | `map_location_selected` 狀態沒存進 JSON | 在 `player.flags` 加入 `last_location_id` 欄位 |
| 時段推進後地點未更新 | `_rebuild_dots()` 沒連接 `time_advanced` 信號 | 在 MapScreen._ready() 補上 `GameManager.time_advanced.connect(_rebuild_dots)` |

---

*文件版本：v4.0（P5 風格重構）｜ 維護者：Chuu ｜ 最後更新：2026-06*
