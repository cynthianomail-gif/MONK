# 第一章阿瑞斯 · 劇情擴充設計（精實切片 8 stage）

> 2026-06-15。把 ch1 從「開場→一段對話→打雜兵→打 Boss」（4 stage）擴成人中之龍式節奏。
> 承 [`2026-06-14-main-story-design.md`](2026-06-14-main-story-design.md)、[`2026-06-15-main-entry-design.md`](2026-06-15-main-entry-design.md)。
> 12 章模板：本章流程之後 ch2–12 照抄。

## 目標節奏
探聽 12 神情報 → 慢慢結識修練者 → 突襲阿瑞斯軍火庫（雜兵）→ 最後決戰阿瑞斯。

## 九個 stage（`ch01_ares.stages`）— 2026-06-15 二次加料（12 神 CG＋串支線＋修練門檻）
| # | id | 類型 | 內容 | 狀態 |
|---|----|------|------|------|
| 1 | c1_demolition | 過場 | opening_temple_falls；set `relic_stolen` | 現成 |
| 2 | c1_aftermath | 對話 | `main_ch1_aftermath` 初遇了塵＋**逐一介紹 12 主神（CG 切圖）**；一次填滿 12 情報 | 新 |
| 3 | c1_intel | 對話 | `main_ch1_intel` 聚焦阿瑞斯＋**串支線(阿忠/老王/鄭媽)＋選擇(解支線/繼續)**＋傳羅漢拳 | 新 |
| 4 | c1_armory_gate | 門檻 | **修練門檻**：解鎖技能 ≥5 才放行；未達播 not_ready 中止，達標播 gate_ready | 新 |
| 5 | c1_confront | 對話 | `main_ares_lead` 了塵領路直闖保全總部 | 現成 |
| 6 | c1_armory_breach | 對話＋戰鬥 | `main_ch1_armory_breach`(短) + battle `pantheon_guard`（第一波） | 新 |
| 7 | c1_armory_deep | 戰鬥 | battle `pantheon_guard`（第二波）；set `ares_encountered` | 新 |
| 8 | c1_ares_intro | 過場 | ares_intro 阿瑞斯登場 | 現成 |
| 9 | c1_ares | Boss | boss `ares` → `ares_purified` | 現成 |

- complete_flag/rewards/require_flag 不變（`ares_purified`）。下游 ch2 閘門與成就不受影響。
- **MainQuestManager 加 `gate`：** `_run_stage` 開頭處理 `gate` 鍵 → `gate_passed(gate)`（type=skills → `skills_unlocked.size() >= min`）；未過播 `fail_dialogue` 並 return false（中止本章、保留 stage 進度）→ 玩家回地圖歷練/解支線，之後任務 app「繼續主線」自 gate stage 重新檢查；過了播 `pass_dialogue` 再續。其餘 cutscene/dialogue/battle/boss/set_flag 鍵照舊。

## 12 神 CG 介紹（stage 2）
- 了塵逐一引介 12 主神，每位用 `[background arg="res://assets/2d/gods/<god>.jpg" fade="0.4"]` 切到該神立繪當 CG，配一句簡介＋`[signal arg="flag:intel_<god>"]`，介紹完 `[background arg=""]` 收回露出地圖。
- 開場給每神**第 1 塊碎片**（`intel_<god>`）＝全 12 神在圖鑑現身，但進度條只 1/N；其餘碎片靠支線/各章補齊（見下「神祇情報圖鑑」）。

## 串支線＋玩家選擇（stage 3）
- 了塵點名 3 個現成支線 NPC 當「知情/需援手」線索：阿忠師傅（zen_bbq，與無戒師父有舊）、老王（old_temple，前商場人見過萬神殿手段）、鄭媽（wannian_mall，被阿瑞斯爪牙討債）。
- 2 選分支：「先去走訪幫他們」(set `ch1_help_side`) ／「先繼續追舍利」。皆續往 gate；實際是否放行由修練門檻決定（純劇情選擇＋門檻雙管）。支線照常在地圖各點觸發，本選擇只做敘事指路，不內聯啟動。

## 修練門檻（stage 4）
- metric＝**解鎖技能數**（使用者選定）。`gate.min=5`（初始 2＋了塵羅漢拳=3，需再練/解支線拿 2 招；數值寫在 main_quests.json 易調）。
- 達標 → `main_ch1_gate_ready`（了塵領路進軍火庫）；未達 → `main_ch1_not_ready`（叫你回紅塵道場歷練）。

## 新角色：了塵（Liaochen）
- 設定：斷一臂的還俗苦行僧；十年前曾組織反抗、敗於萬神殿而隱姓埋名，藏身新梵市舊城雨巷茶攤。沉鬱、護著無戒這把新火。懂諸神底細＝因他敗過。
- 定位：情報來源＋引路人＋傳藝者，**劇情登場、不進戰鬥系統**。
- `dialogue/Liaochen.dch`（key `Liaochen`，display_name 了塵，單 portrait `default`）。dtl 用 `Liaochen (default): …`。
- 立繪：**先用佔位**（指向現有圖，標 TODO），對話/資料跑通後再 higgsfield 生正式立繪（那步才花 credits）。
- 傳藝：用現成技能 `arhat_strike`（羅漢拳，技能表已有，不新增數值），在 `main_ch1_intel` 以 `[signal arg="skill:arhat_strike"]` 發給玩家。

## 神祇情報圖鑑（碎片＋蒐集進度條）
- 使用者要求：每神有蒐集進度條；開場簡介只給一塊（進度不滿），其餘要透過其他人補齊。
- `data/god_intel.json`：13 筆（pantheon＋12 神），每筆 `{order, god, domain, pieces[]}`。`pieces` ＝情報碎片，各 `{flag, text}`；`flag` 支援一般旗標（`intel_*`）或 `"quest:<id>"`（完成該支線）。
- `src/systems/GodIntel.gd`（autoload）：碎片純推導（不另存）。API `total / is_discovered(id) / discovered_count() / progress(id)→{got,total} / get_all()`。發現＝第 1 塊已解。
- 碎片配置：**阿瑞斯 4 塊**＝開場 `intel_ares`＋`quest:ah_zhong`／`quest:lao_wang`／`quest:zheng_ma`（ch1 完成 3 條支線即可 4/4，呼應「透過其他人了解」）；**其餘 11 神 2 塊**＝開場 `intel_<god>`＋深入 `intel_<god>_2`（待各自章節解）；pantheon 1 塊。
- `src/ui/menu/pages/IntelApp.gd`：每神顯示進度條（got/total）＋已解碎片原文；未解碎片顯示「？？？（待查訪）」，未發現顯示「？？？」。
- 開場了塵簡介設 `intel_pantheon`＋12×`intel_<god>`（每神第 1 塊）→ 全 12 神「已發現」但進度條只 1/N。
- 注意：`intel_*` 旗標會觸發 `GameManager.flag_changed`，但非成就 unlock_flag，AchievementSystem 不誤觸。

## 軍火庫雜兵
- 第一/二波都用現成 `pantheon_guard`（HP220/atk38/def22，弱點 merit，已有 call_reinforcement＝會召援＝「很多小兵」感）。
- 「越深越硬」：第二波之後可加精英變體（`pantheon_warden`，之後微調）；本切片先兩波同兵種，不新增平衡。

## 新增對話檔（5）
- `main_ch1_aftermath.dtl`：初遇了塵＋12 神 CG 介紹。signals：`flag:intel_pantheon`＋12×`flag:intel_<god>`（共 13）。
- `main_ch1_intel.dtl`：聚焦阿瑞斯＋串支線（阿忠/老王/鄭媽）＋2 選分支＋傳藝。signals：`flag:armory_known`、（分支）`flag:ch1_help_side`、`skill:arhat_strike`。
- `main_ch1_armory_breach.dtl`（短）：闖入軍火庫前對峙，接戰鬥。
- `main_ch1_gate_ready.dtl`：修練達標，了塵領路進軍火庫。
- `main_ch1_not_ready.dtl`：未達標，了塵叫無戒回紅塵歷練。

## 動到的檔案
新增：`data/god_intel.json`、`src/systems/GodIntel.gd`、`src/ui/menu/pages/IntelApp.gd`、`dialogue/main_ch1_{aftermath,intel,armory_breach,gate_ready,not_ready}.dtl`、`dialogue/Liaochen.dch`、`test/TestCh1Expansion.*`。
修改：`data/main_quests.json`（ch1 stages 4→9＋gate）、`src/systems/MainQuestManager.gd`（`gate_passed()`＋_run_stage gate 處理）、`src/ui/menu/MenuShell.gd`（情報分頁）、`project.godot`（GodIntel autoload＋ dch/dtl 註冊）、`test/GenDch.gd`（加了塵）。

## 驗證
- headless `test/TestCh1Expansion.tscn`：
  - main_quests ch01_ares 有 8 stage、id 正確、complete_flag 仍 ares_purified、boss/cutscene/dialogue 鍵齊。
  - 3 個新 .dtl `load().process()` 解析無誤、signal 數符合預期（intel/skill/flag）。
  - GodIntel：total==13(12神+總覽)、清旗標 unlocked0、set `intel_ares`→is_unlocked 真、get_all 鎖住項 teaser 不外洩。
  - IntelApp / MenuShell(phone 三分頁) 場景煙霧。
- 全專案 `--editor --quit` 無 parse error；既有 TestAllDialogue/TestMainQuest 回歸。
- ⚠ 了塵正式立繪、實機 GPU 跑一次 ch1 觀感＝後續手動。

## YAGNI / 不做
- 了塵進戰鬥系統（盟友參戰）；多分支結局；ch2–12；3D 迷宮；新 Boss 數值。
