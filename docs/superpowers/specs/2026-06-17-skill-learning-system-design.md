# 了塵為師：技能「可學 → 習得」學習系統 設計 spec

日期：2026-06-17
關聯：[[project-skill-learning-system]]、[[project-build-status]]、[[project-monk-game]]、[[project-phone-apps]]（經書 app）。
既有 spec：`2026-06-14-menu-system-design.md`（經書技能頁＝唯讀展示）、`2026-06-15-ch1-ares-expansion-design.md`（ch1 九 stage、`c1_armory_gate` 修練門檻）。

## 願景與範圍

把技能解鎖從「條件達成就無聲自動會」改成「**幫了人/練到位 → 回經書跟了塵習得才真正會**」，兌現使用者願景「學習都要跟修練者學」。同時修掉 `c1_armory_gate`（需 5 技能）的**雙重假門檻**，讓修練門檻真正有意義。

**核心狀態拆分**：把舊的「unlocked」一個布林拆成三段——
- **condition_met（條件達成）**：幫了阿忠、打夠 6 場…條件成立。
- **learnable（可學）**：condition_met 且尚未學，且屬「須習得」類。
- **learned（已學）**：進 `player.skills_unlocked`，**戰鬥能用、計入 gate**。

中間「跟了塵學」這一步在**經書·技能頁**發生：可學的招顯示「習得」鈕，點下去才 `learned`。

**範圍邊界（拍板）：**
- 例外三類**不走習得**：`initial`（拳/木魚，開局已會）、`story`（羅漢拳，c1_intel 了塵當場親授，劇情教學時刻）、`heat`（如來神掌等三處決技，滿值發動、不入池）。
- **其餘全部**（quest/flag/behavior 解鎖的招）一律走「條件達成→可學→經書習得」。**行為招（打場數/弱點數達標）也要習得**（使用者 2026-06-17 拍板，貫徹一致）。
- **完全不動任何 .dtl**：羅漢拳沿用既有 `[signal arg="skill:arhat_strike"]` 直接授予＝「當場學會」，正是 `story` 要的效果。避開「改 dtl 要關 Godot」的陷阱。
- **習得免費**（DEMO 不收 gold/merit；條件本身就是門檻）。
- 只做系統＋ch1 驗證，不擴 ch2–12。
- 不做存檔遷移：既有舊存檔（舊版 7 招 initial 全灌）保留其 `skills_unlocked` 不動；修正只對**新遊戲**生效（DEMO 存檔可丟棄，開發測試用 new game）。

## 現況（已探查確認）

### 雙重假門檻
`c1_armory_gate` 走 `MainQuestManager.gate_passed({type:"skills", min:5})` ＝ `player.skills_unlocked.size() >= 5`。但兩條路徑讓它從第一幀就過：

1. **7 招誤標 `initial`**：`SkillUnlockManager.UNLOCK_TABLE` 把 `basic_punch / arhat_strike / wooden_fish / sound_wave / broken_bowl_beg / lions_roar / self_harm` 全標 `initial`。`_ready()` 的 `check_unlocks()` 一次把 7 招灌進 `skills_unlocked`（其中 `basic_punch/wooden_fish` 本來就在種子內）。開局實際＝**7 招**，gate(5) 永遠過。
2. **支線送「鬼招」**：`quests.json` 的 `ah_ming` s2 送 `unlock_skill: "brahma_resonance"`、`jie` win 送 `unlock_skill: "wooden_fish_fury"`——這兩個 id **`skills.json` 根本沒有**。`QuestManager._advance_quest`（line 67-68）與 `SceneRouter`（line 143-147）照樣 `skills_unlocked.append()`。戰鬥用不到（`BattleManager` 以 `get_skill()` 過濾掉），**但照樣 +1 灌進 gate 計數**。

### 解鎖機制
- `SkillUnlockManager.get_unlock_state(skill_id)` 回 `{unlocked, kind, label, current, target}`，`unlocked` 把「條件達成」與「已學」混為一談（line 72-74：已在 `skills_unlocked` 則恆 `unlocked`）。
- `check_unlocks()` 掃全表，條件達成（非 heat）就 `append` 進 `skills_unlocked` 並發 `EventBus.skill_unlocked`（→ `MapHUD` toast「新技能解鎖：X」）。被以下處呼叫：`GameManager`（merit/karma/hp 變動、`skill:` signal）、`QuestManager`（支線推進）、`SceneRouter`（小遊戲獎勵）、`BreakVowSystem`（破戒）、`BattleManager`/`SkillExecutor`（戰後 kill_count/weakness_hit_count/karma_skill_count）。
- 羅漢拳：`main_ch1_intel.dtl:23` 的 `[signal arg="skill:arhat_strike"]` → `GameManager._on_dialogic_signal`「skill」分支（line 54-57）直接 `append` ＋ `check_unlocks()`。但 arhat 又標 `initial`，故其實開局就被灌（signal 變 no-op）。
- 行為旗標確認**已被累加**（保底可達，絕不 softlock）：`kill_count` 在 `BattleManager.gd:260`（戰勝 += 擊殺數）、`weakness_hit_count` 在 `SkillExecutor.gd:92-93`（命中弱點/Down +1）、`karma_skill_count` 在 `SkillExecutor.gd:230-231`。

### 經書技能頁（`SkillsPage.gd`）
唯讀展示：三職分組、`🔒未解鎖 / ✓已解鎖 / behavior 進度條`，真相源＝`get_unlock_state()`（讀 `st.unlocked / st.kind / st.current / st.target / st.label`）。無「習得」互動。

### 既有測試
- `TestMenuSystem.gd`：`_test_unlock_states`（讀 `.unlocked`）、`_test_check_unlocks`（斷言 behavior 條件達成後 `check_unlocks` 會學會 `rolling_taunt`）、`_test_job_mastery`（每職 6 招非 heat）、`_smoke_scenes`（instantiate `SkillsPage`）。
- `TestCh1Expansion.gd`：`_test_gate_logic`（3<5 擋、5>=5 放行）、`_test_new_dialogues`（`main_ch1_intel` signal 數 >=2）。

## 架構：狀態模型重整 + 習得入口

### 1. `get_unlock_state()` 拆三態（`SkillUnlockManager.gd`）

回傳改為 `{learned, learnable, condition_met, kind, label, current, target}`：

| kind | condition_met | learnable | 備註 |
|---|---|---|---|
| `initial` | 恆 true | false | 開局自動學（種子＋`check_unlocks` 確保） |
| `story` | ＝learned（劇情授予才算達成） | false | 不入經書習得；由 `skill:` signal 直給 |
| `heat` | 恆 true | false | 不入池；滿值發動 |
| `flag` | `get_flag(flag)` | condition_met && !learned | 須習得 |
| `quest` | `quest in completed_quests` | condition_met && !learned | 須習得 |
| `behavior` | `get_flag(flag,0) >= target` | condition_met && !learned | 須習得；回報 current/target |

`learned = skill_id in player.skills_unlocked`。`learnable = condition_met and not learned and kind in [flag, quest, behavior]`。

**過渡相容鍵**：保留 `unlocked = condition_met or learned`（＝舊語意）一鍵，純供「尚未改寫的舊 `check_unlocks` 與舊 `SkillsPage`」在重構期間繼續運作；待 `SkillsPage` 改寫完成（最後一個消費者消失）即移除，並以 grep 確認無殘留消費者。

### 2. 新表項（`UNLOCK_TABLE`，5 改）＋新 `story` 類

```gdscript
"arhat_strike":    {"kind": "story"},                                      # 舊 initial
"sound_wave":      {"kind": "quest", "quest": "ah_zhong"},                  # 舊 initial
"lions_roar":      {"kind": "quest", "quest": "lao_wang"},                  # 舊 initial
"broken_bowl_beg": {"kind": "behavior", "flag": "kill_count", "target": 6}, # 舊 initial（保底）
"self_harm":       {"kind": "behavior", "flag": "weakness_hit_count", "target": 5}, # 舊 initial（保底）
```

其餘維持：`basic_punch / wooden_fish`＝initial；`great_compassion_shield`(quest:zheng_ma)、`alms_wave`(quest:grandma)、`vajra_glare`(flag:ah_ming_saved)、`underdog`(flag:david_listened)、`iron_shirt/requiem/karma_rebound`(flag)、`ascetic_temper/sacrifice_strike/sutra_seal/rolling_taunt`(behavior)、三 heat。

### 3. 新方法（`SkillUnlockManager.gd`）

```gdscript
## 玩家在經書點「習得」：驗證可學 → 進 skills_unlocked。回傳是否成功。
func learn_skill(skill_id: String) -> bool

## 目前可學（condition_met 且未學、屬須習得類）的招清單。
func learnable_skills() -> Array

## 劇情/系統直接授予（如了塵傳羅漢拳、未來劇情招）：進池 + 報「已學」toast。
## 防呆：skills.json 不存在的招不授予（擋鬼招灌 gate）。
func grant_skill(skill_id: String) -> bool
```

### 4. `check_unlocks(announce := true)` 改邏輯

- `initial`：確保進 `skills_unlocked`（自動學）。
- `story` / `heat`：跳過（不自動學、不標可學）。
- `flag` / `quest` / `behavior`：condition_met 且未學 → **只標「可學」**（不進池）；若是「本輪新變可學」（以 runtime `_announced_learnable` 去重）且 `announce`，發 `EventBus.skill_learnable`（→ toast「可學新招：X（去經書習得）」）。
- `_ready()` 改呼叫 `check_unlocks(false)`：建立 initial 學會 + 把當下已達成者標記為「已通知」（避免載入舊進度時洗一排 toast）。

### 5. 統一入口（防鬼招繞過了塵）

- `GameManager._on_dialogic_signal`「skill」分支 → 改呼叫 `SkillUnlockManager.grant_skill(val)`（含 skills.json 存在性防呆）。
- `QuestManager._advance_quest` 與 `SceneRouter` 的 `unlock_skill` → 同樣改走 `grant_skill()`（存在性防呆，擋鬼招；真支線招本就靠表的 quest/flag 類走習得）。
- `quests.json`：移除 `ah_ming` s2 的 `unlock_skill: brahma_resonance`、`jie` win 的 `unlock_skill: wooden_fish_fury`（真獎勵＝`flag: ah_ming_saved`/`jie_defeated` 仍在，分別經表解 `vajra_glare`/推進 grandma 前置，無損）。

### 6. 經書技能頁加「習得」（`SkillsPage.gd`）

- 列項狀態四級：`【處決】`(heat)／`✓ 已學`(learned)／`✦ 可學`(learnable，冷亮藍)／`🔒`(未達)；behavior 未達顯示 `(current/target)`。
- 詳情面板：learnable → 顯「✦ 可習得」＋「習得」鈕；點鈕 → `learn_skill()` → 即時刷新該列與詳情（鈕變「✓ 已學會」）。learned → 「✓ 已學會」＋習得方式。未達 → 「🔒 未達」＋條件＋behavior 進度條。heat → 「滿值處決技」。
- 以 `_rows` 字典存各列 Button、`_style_row(id)` 重繪單列，避免整頁 rebuild 閃爍。

### 7. EventBus / HUD

- 新增 `signal skill_learnable(skill_name: String)`。
- `MapHUD._ready` 加 `EventBus.skill_learnable.connect(func(n): show_toast("可學新招：%s（去經書習得）" % n))`；既有 `skill_unlocked` toast（「新技能解鎖：%s」）保留給真正習得/劇情授予。
- 已知邊界：戰鬥中（無 `MapHUD`）達成的可學只在經書呈現 `✦`，當下無 toast；回地圖完成支線等則照常 toast。DEMO 可接受。

## ch1 門檻流（驗證目標）

開局 `[basic_punch, wooden_fish]`＝**2 已學** → c1_intel 了塵親授羅漢拳（`skill:` signal → grant_skill）＝**3 已學** → gate 需 5，差 2。湊法（任一達 2 招習得即可）：
- 保底純刷：打 6 場（kill_count≥6 → 破碗乞討可學）＋ 弱點 5 次（weakness_hit_count≥5 → 苦肉計可學）→ 進經書各點習得 → 5。
- 或解支線：阿忠（梵音氣功）、老王（獅子吼）、鄭媽（大悲咒護罩）任二 → 可學 → 習得。

**絕不 softlock**：行為旗標純戰鬥即可累加（已確認），故不依賴任何支線也能湊 5。

## 測試（擴充既有 headless，不新建場景）

`test/TestMenuSystem.gd`（`MENU_TEST`）：
- `_test_unlock_states` 改寫成新模型：initial→learned；heat→condition_met、!learnable；behavior（ascetic_temper 5/10 未達→10 達成 learnable、未 learned）；flag（vajra_glare）；quest（great_compassion_shield）；**story（arhat 未授予時 !learnable !learned）**；驗 5 改項 kind 正確（broken_bowl_beg=behavior target6 等）。
- 新增 `_test_learn_skill`：條件達成 → learnable && !learned；`learn_skill()` → true、learned；再 `learn_skill()` → false（已學）；未達 → `learn_skill()` false。
- `_test_check_unlocks` 改寫：initial 自動學（erase 後 check 回來）；heat 不自動學；**behavior 條件達成後 `check_unlocks` 不自動學、改為 learnable**，`learn_skill` 後才入池。
- `_test_job_mastery` 不變（每職 6 非 heat）。
- `_smoke_scenes` 既有（instantiate SkillsPage/StatusPage）回歸不崩。

`test/TestCh1Expansion.gd`（`CH1_EXPANSION_TEST`）：
- `_test_gate_logic` 保留（gate 計 size 不變）。
- 新增 `_test_skill_learning`：模擬新遊戲（skills_unlocked=[basic_punch,wooden_fish]）→ grant_skill(arhat)=3；arhat 為 story（!learnable）；保底（set kill_count=6、weakness_hit_count=5 → broken_bowl_beg/self_harm learnable、check_unlocks 不自動學）→ learn 兩招 → 5 → `gate_passed({type:skills,min:5})` true；`grant_skill("brahma_resonance")`=false 且不入池（鬼招防呆）；驗「純刷可達 5、無 softlock」。
- `_test_new_dialogues` 不變（dtl 零改，`main_ch1_intel` signal 數 >=2 仍成立）。

每次改動後跑 `--editor --quit` 確認無 parse / JSON error。

## 風險／邊界

- **過渡相容鍵 `unlocked`**：重構期間舊 `check_unlocks`/舊 `SkillsPage` 靠它運作；最後一步移除並 grep 確認（消費者僅 SkillsPage＋已改寫的測試）。
- **戰鬥中可學無 toast**：見 §7，DEMO 接受；未來可在地圖入口或經書 app icon 加「有可學」紅點。
- **舊存檔不遷移**：見 §範圍邊界，DEMO 測試用 new game。
- **`grant_skill` 與「都跟了塵學」哲學**：`unlock_skill`/`skill:` 為「劇情直給」通道（如 arhat），含存在性防呆；真支線招的正規路徑仍是表的 quest/flag 類走習得。鬼招欄位已從 quests.json 移除。

## 檔案清單

**修改：**
- `src/systems/SkillUnlockManager.gd` — `get_unlock_state` 拆三態（+過渡 `unlocked`）、新 `story` 類、5 表改、`learn_skill`/`learnable_skills`/`grant_skill`、`check_unlocks(announce)` 改邏輯、`_announced_learnable` 成員、`_notify_learnable`。
- `src/autoloads/EventBus.gd` — 新 `signal skill_learnable`。
- `src/autoloads/GameManager.gd` — `skill:` 分支改走 `grant_skill`。
- `src/systems/QuestManager.gd` — `unlock_skill` 改走 `grant_skill`。
- `src/autoloads/SceneRouter.gd` — `unlock_skill` 改走 `grant_skill`。
- `data/quests.json` — 移除 2 個鬼招 `unlock_skill` 欄位。
- `data/skills.json` — 5 招 `unlock_condition` 文案同步（sound_wave/lions_roar/broken_bowl_beg/self_harm/arhat_strike）。
- `src/ui/menu/pages/SkillsPage.gd` — `✦可學` 狀態 + 「習得」鈕 + `_rows`/`_style_row`/`_on_learn`；改用新鍵；移除對 `unlocked` 的依賴。
- `src/screens/MapScreen/MapHUD.gd` — 接 `skill_learnable` toast。
- `test/TestMenuSystem.gd` — `_test_unlock_states`/`_test_check_unlocks` 改寫 + 新 `_test_learn_skill`。
- `test/TestCh1Expansion.gd` — 新 `_test_skill_learning`。

**不動：**
- 所有 `.dtl`（尤其 `main_ch1_intel.dtl` 的 `skill:arhat_strike`）。
- `data/main_quests.json`（gate min=5、stage 結構不變）。
- `BattleManager`/`SkillExecutor`（旗標累加邏輯不變）、`StatusPage`（用 `get_job_mastery`，不讀 `get_unlock_state`）。

## 備註

專案不在 git 下，略過「commit 設計文件」步驟（與既有流程一致）。實作完成後依 [[feedback-sync-docs-memory]] 同步 `project_build_status` 與 `project_skill_learning_system` 記憶、並把 GDD v5 §八·五 舊 lambda 解鎖表標註為已被資料驅動 `UNLOCK_TABLE` 取代（避免文件誤導）。
