# 《和尚逆天》專案狀態總表

> **🎯 範圍：DEMO 版＝只做第一章（阿瑞斯）（2026-06-15 定案）。** ch2–12 暫不實作；所有規劃以「ch1 完整可玩 demo」為目標。
> 常駐進度文件 — 切帳號/換 session 先讀這份。最後更新 **2026-06-18**。
> 企畫書＝[`monk_go_rogue_GDD_v5.md`](monk_go_rogue_GDD_v5.md)；主線設計＝[`docs/superpowers/specs/2026-06-14-main-story-design.md`](docs/superpowers/specs/2026-06-14-main-story-design.md)。

---

## 一、一頁速覽

- **系統/程式**：核心幾乎全做完（autoload／2D 戰鬥／地圖程式／過場播放／轉場讀取／存檔／對話橋接／選單地基＋經書）。
- **支線內容**：9 條支線＋Cherry 初遇＋3 段破戒獨白＝26 個對話檔，全做完並驗證。
- **2D 美術**：英雄/敵人/NPC 立繪、5 戰鬥背景、12 神設定集 splash（今日完成）、28 音檔、7+1 段過場幀。
- **探索地圖**：**2026-06-16 改為 2D 楓谷式**（取代 3D），系統＋美術皆完成並引擎驗證；街景二版＝平面立面＋2 倍長（詳見記憶 `project-2d-map`、spec `2026-06-16-2d-exploration-map-design.md`）。
- **三大缺口**：① ~~3D 探索 0 內容~~ → **已轉 2D 並完成**（3D 街景退役保留）② **主線 12 神戰役只有資料骨架、內容 0 實作**（但 DEMO 只做 ch1，已擴成完整切片）③ **GDD 文件過時**（沒主線章、Boss 結局資料有 bug）。

---

## 二、已完成（細節見記憶 project-build-status）

- **Autoloads**：GameManager / EventBus / SaveManager / JsonLoader / SceneRouter / AudioManager / QuestManager / BreakVowSystem / SkillUnlockManager / Dialogic。
- **2D 戰鬥**：BattleManager / SkillExecutor / StatusEffects / Combatant / BattleUI（弱點連擊→Down→總攻擊→Hold-up；Boss 兩階段）。skills/enemies/boss.json 資料齊（**但 boss.json 只有阿瑞斯**）。
- **2D 探索地圖（2026-06-16 完成並引擎驗證）**：MapScreen 改建為 2D Control 協調者＋三層（DistrictScene 捲動街景／LocationInterior 內景／CityMap 選區），沿用所有後端與 MapHUD。美術 9 張全到位：3 街景（**二版＝平面立面＋2 倍長 6036×1344**，`tools/stitch_street.py` 拼接）＋城市地圖＋5 內景；無戒由 3D 模型渲成 2D sprite。驗證 `test/TestMapData2D`＋`test/CaptureMapAll`。詳見記憶 `project-2d-map`／`project-mapscreen-areas`。舊 3D 街景（`XimenStreet.gd` 等）退役保留。
- **過場**：CutsceneScreen 逐幀播放器（**2026-06-18 加 per-cutscene `audio.ogg` 支援**：過場資料夾若有 `audio.ogg` 就用獨立 `CutsceneAudio` player 同步播放、skip/結束會停音，與幀號 SFX_CUES 互斥；**並修戰鬥內疊播被 BattleUI(CanvasLayer) 蓋住的 bug＝`play_battle_cutscene` 改用 layer 128 CanvasLayer 包過場；並加進出淡入淡出轉場（黑遮罩四段 fade，藏戰鬥↔過場硬切）**，實機 demo `test/PlayAresPhase2.tscn`），破戒×3／處決×3／ares_phase2／opening_temple_falls 已拆幀。**ares_phase2 二階變身過場 2026-06-18 再做＝黑西裝→熔岩戰神，於「軍火熔鑄爐」戰場「受擊→蓄釀→爆發」變身、帶原生音效、含「單鏡頭推進＋仰角英雄收尾」運鏡**（magnific seedance-pro-2.0；運鏡靠頭尾 keyframe 用「不同景別」＝起手 establishing 黑西裝較小／收尾仰角戰神放大頂天＋`cameraMotion:pushIn`＋prompt 指揮；ffmpeg 12fps 61 幀＋抽 `audio.ogg`；⚠暴力字眼會觸發 Seedance 審核，要改中性講法）。舊版備份(`_art_review/`)：固定機位 forge 版 `ares_phase2_forge_static.mp4`、暗底無聲版 `ares_phase2_darkbg.mp4`、最早「一開場就爆發」版 `ares_phase2_OLD_burst.mp4`。headless `test/TestCutscene.tscn` ALL PASS。
- **轉場/讀取**：TransitionEffect（4 種）＋ LoadingScreen（佛語循環）。
- **對話**：26 個 `.dtl`（9 支線 22 timeline＋3 破戒＋Cherry）＋11 個 `.dch`；P5 風版面、輸入修正、胸像化。全驗證。
- **小遊戲**：化緣 beggar／端湯 soup_carry／木魚 wooden_fish（3 個）。
- **選單**：手機×經書雙殼；經書「技能頁／狀態頁」做實；SkillUnlockManager 資料驅動重構。
- **手機 app 補完（2026-06-17 完成並驗證 ALL PASS）＝選單階段 2**：手機 5 頁籤 任務/情報/**移動/打工/設定**。①**移動 `TravelApp`**（🚇捷運 5 金+耗1時段到區中心／🚕計程車 30 金+即時直達已解鎖地點、落在地點門口）取代免費 `FastTravelApp`（已刪）；付費邏輯抽成 `_pay_mrt`/`_pay_taxi`(回 bool 可測)。②**105 打工 `JobApp`**（端湯/化緣→耗1時段→`go_to_minigame`）。③**設定 `SettingsApp`**（主/BGM/SFX 音量+全螢幕+文字速度，即時套用+寫檔）。支撐系統：**AudioManager 執行期建 BGM/SFX 音量 bus**（`set/get_bus_volume_linear`）＋**`SettingsManager` autoload**（`user://settings.cfg` 持久化、開機 apply_all、text_speed 取倒數套 Dialogic）＋GameManager `pending_arrival` 計程車落點暫存。驗證 `test/TestMenuSystem.tscn` 全綠、TestMainEntry/TestDemoScope 回歸 ALL PASS。spec＝`docs/superpowers/specs/2026-06-16-phone-apps-design.md`、plan＝`docs/superpowers/plans/2026-06-16-phone-apps.md`。詳見記憶 `project-phone-apps`。**仍待：實機 GPU 視窗抽驗三頁觀感；JobApp 路由的 soup_carry/beggar_challenge 小遊戲場景與付費移動的實機手感。**
- **主線進入點（2026-06-15 完成並驗證 ALL PASS）**：手機「任務」app（`QuestsApp.gd`＝主線進度＋「繼續主線」按鈕正式入口＋十二因緣成就圖鑑＋進行中支線）；`AchievementSystem`（autoload，成就純從 complete_flag 推導、`GameManager.flag_changed` 觸發解鎖彈窗、MapScreen 補播 `pending_toasts`）。開場自動起 ch1 早已接好（TitleScreen「開始修行」）。spec：`docs/superpowers/specs/2026-06-15-main-entry-design.md`。
- **DEMO 收尾＋小遊戲觸發修正（2026-06-15 完成並驗證 ALL PASS）**：`main_quests.json` 加 `_demo.last_chapter=ch01_ares`；`MainQuestManager` 加 `demo_last_chapter()/is_demo_complete()`，`continue_story` 在 demo 完成時改播 `demo_end.dtl` 收尾（不掉進空的 ch2）；任務 app 顯示「試玩版結束」。阿明小遊戲觸發 `busking_crowd`→`wooden_fish_rhythm`。驗證 `test/TestDemoScope.tscn`。
- **第 1 章劇情擴充（2026-06-15 完成並驗證 ALL PASS，二版加料）**：ch1 從 4 stage 擴成人中之龍式 **9 stage**（開場→雨夜茶攤遇了塵＋**12 神 CG 逐一介紹**→聚焦阿瑞斯＋**串支線＋玩家選擇(解支線/繼續)**＋傳羅漢拳→**修練門檻(解鎖技能≥5才帶你打)**→了塵領路直闖總部→軍火庫兩波雜兵→戰神現身→決戰）。新角色**了塵**（斷臂還俗修練者，引路＋情報＋傳羅漢拳，**正式立繪 2026-06-15 已生** `npcs/bust/npc_liaochen.png`）；**神祇情報圖鑑** `GodIntel`（autoload，純從 intel_<god> 旗標推導，ch1 一次填滿 12 條）＋手機「情報」分頁 `IntelApp.gd`（鎖住顯示 ？？？）；**MainQuestManager 加 `gate` 門檻機制**（未達中止回地圖、任務 app 繼續主線會重檢）；5 新對話。spec：`docs/superpowers/specs/2026-06-15-ch1-ares-expansion-design.md`。
- **技能習得系統「了塵為師」（2026-06-17 完成並驗證 ALL PASS）**：解鎖拆三態 `condition_met → learnable → learned`——幫人/練到位只變「可學」，玩家進經書·技能頁點「習得」才真正入招池（戰鬥能用、計入 gate）。例外：`initial`(拳/木魚開局已會)、`story`(羅漢拳 c1_intel 了塵當場親授，沿用 `[signal skill:arhat_strike]` 直給)、`heat`(滿值處決不入池)；其餘 quest/flag/behavior（**含行為招**）一律走習得。修掉 `c1_armory_gate` 雙重假門檻：① 7 招誤標 `initial` 開局全灌 → 改 arhat→story、sound_wave→quest:ah_zhong、lions_roar→quest:lao_wang、broken_bowl_beg→behavior:kill_count≥6、self_harm→behavior:weakness_hit_count≥5；② quests.json 送的鬼招 `brahma_resonance`/`wooden_fish_fury`（skills.json 沒有）灌 gate → 經 `grant_skill` 存在性防呆擋下並移除死欄位。ch1 gate 流：開局 2 → 了塵授羅漢拳 3 → 保底純刷(打 6 場/弱點 5 次)或解支線湊 5 → gate 開，**絕不 softlock**。新 `learn_skill`/`learnable_skills`/`grant_skill`、`check_unlocks(announce)` 只自動學 initial、`EventBus.skill_learnable` toast、**MenuShell 經書裝置鈕＋技能頁籤紅點**（有可學的招就亮、習得即時清，補戰鬥中無 toast 的缺口）。**完全不動 .dtl**。spec＝`docs/superpowers/specs/2026-06-17-skill-learning-system-design.md`、plan＝`docs/superpowers/plans/2026-06-17-skill-learning-system.md`。驗證 TestMenuSystem／TestCh1Expansion ALL PASS。**仍待：實機 GPU 抽驗習得體驗。**
- **商店系統「鄭媽佛具店」（2026-06-17 完成並驗證 ALL PASS）**：賺金幣 → 鄭媽店買消耗道具 → 戰鬥中用 的循環，給金幣新去處＋讓戰鬥更耐打。5 元件：① `data/items.json` 單一真相源（金瘡藥150/heal200、業障結晶250/karma+40、護身符350/shield250×3回合，kind∈heal/karma/merit/shield/cleanse）；② 背包 `GameManager.player.inventory:{id:count}` ＋ `add_item`/`item_count`/`consume_item`（隨 SaveManager 整包存、`_ensure_inventory` 防舊存檔缺鍵、JSON float→int 夾正）；③ `src/ui/menu/ShopScreen.gd`（CanvasLayer 暗金 overlay 仿 MenuShell，左清單右詳情+購買鈕，只買不賣，金幣不足鈕 disabled）；④ 戰鬥 `BattleUI` 技能選單頂端「🎒 道具」鈕→道具子選單→`BattleManager.player_use_item`→`_apply_item_effect`（複用 `Combatant.heal`/`add_buff("golden_body")`、`GameManager.add_karma/add_merit`、`StatusEffects.clear_negative`）；自我施放、消耗一回合、空背包鈕 disabled；⑤ `MapScreen` shop 動作開店＋`zheng_ma_shop_unlocked` gate（未解→toast「鄭媽的店還沒開」，含防重複開店守門）。開店沿用 perform_action「每動作推進一時段」慣例。TDD 6 task，spec＝`docs/superpowers/specs/2026-06-17-shop-items-design.md`、plan＝`docs/superpowers/plans/2026-06-17-shop-items-system.md`、驗證 `test/TestShop.tscn` ALL PASS＋TestMenuSystem/TestCh1Expansion 回歸 ALL PASS＋parse clean。詳見記憶 `project-shop-system`。**仍待：實機 GPU 抽驗購買+戰鬥道具手感。**
- **對話 UI P5 化「立繪出框」（2026-06-17 完成並 headless 驗證 ALL PASS）＝缺口 #8**：把對話呈現從「立繪內嵌框內」改成 **Persona 5 式 VN 版面**——立繪是螢幕**左下角獨立大胸像**（壓在場景上、不在框內），文字框是**斜切（StyleBoxFlat.skew）＋金邊（border）＋金色霓虹光暈（shadow）**，名字另成**斜切金色名牌**。**全程不寫 shader、不動 Dialogic addon、零 `.dtl` 改動**——立繪靠新 `speaker_bust_layer`（`SPEAKER` 模式立繪容器，自動跟「當前說話者」、免 join 事件）。3 新檔＝`src/ui/dialogue_style/speaker_bust_layer.tscn`＋`.gd`、`monk_textbox_panel.tres`（斜切/金邊/光暈/近黑底）、`monk_nametag_panel.tres`（斜切金底）；改寫 `monk_dialogue_style.tres`：第 12 層 `Layer_SpeakerPortraitTextbox`→內建 `Layer_VN_Textbox`（純文字框＋**獨立名牌 panel**，全靠 overrides）、新增第 17 層立繪（排在文字框後＝畫在框上）、填一組 overrides（box_panel/name_label_box_panel 指向自製 StyleBox、兩個 self_modulate 設**白**＝顏色烤進 StyleBox 不被乘色染色、文字奶白、名牌近黑字）。**這翻掉了當初「胸像內嵌框」的決定（記憶 `project-build-status`）＝依使用者 P5 參考圖有意識改方向**。立繪去背 RGBA 沿用（無戒 850×884）。spec＝`docs/superpowers/specs/2026-06-17-p5-dialogue-vn-layout-design.md`、驗證 `test/TestDialogueStyle.tscn` ALL PASS（24 檢查）＋`--editor --quit` import clean。詳見記憶 `project-dialogue-vn-style`。**GPU 已實機調定（2026-06-17，用 `test/PreviewDialogueStyle.tscn` 反覆微調）：立繪 `origin_offset=(320,-20)`/`anchor_top=0.38`、文字 `content_margin_left=295`、名牌 `name_label_box_offset=(295,0)`（切齊內文）；斜切 0.12／光暈 10／近黑底觀感 OK。**選項鈕 P5 化（2 新 StyleBox `monk_choice_normal/hover.tres`＝斜切暗金底＋hover 金邊霓虹、文字奶白→亮金，套 vn_choice 層 overrides；位置維持置中），headless 驗證 ALL PASS。**
- **戰鬥畫面美術串接（2026-06-17 完成並 headless 驗證 ALL PASS）**：把「生了卻沒顯示」的戰鬥美術全接上——① 背景資料驅動（`boss.json` `battle_bg` 優先，否則 `enemies.json` `district`→`bg_battle_<區>`，**新生 `bg_battle_pantheon.png`＝軍火庫**；取代純色 ColorRect）；② 敵人/Boss 立繪進 `EnemyPanel`（暗金霓虹 StyleBox 框、死亡轉灰）；③ **阿瑞斯 4 立繪動態切換**（base 平時／mocking_laugh 出招暫態 0.8s／pained 受擊暫態 0.6s／phase2 進二階段持久）；④ 玩家立繪依職業 `wujie_<job>_calm`、HP<30% 換 `_angry`。純路徑/StyleBox 邏輯集中於新 `src/screens/BattleScreen/battle_art.gd`（`resolve_battle_bg`/`resolve_portrait_path`/`player_portrait_path`/`neon_frame`）。spec＝`docs/superpowers/specs/2026-06-17-battle-screen-art-design.md`、plan＝`docs/superpowers/plans/2026-06-17-battle-screen-art.md`、驗證 `test/TestBattleArt.tscn` ALL PASS＋TestMainQuest/TestMenuSystem/TestCh1Expansion 回歸 ALL PASS＋parse clean。**仍待：實機 GPU 抽驗背景/立繪/霓虹框觀感＋阿瑞斯表情切換時機。**
- **戰鬥「站立對峙」立繪＋程式呼吸（2026-06-17 完成、4 測試 ALL PASS＋GPU 截圖驗證）＝取代上一條的「框內立繪」呈現**：改 Persona 5 式站立對峙——敵我都是**去背戰姿透明立繪**站在共用背景上、**程式呼吸**微動（腳踩地 sine 上下浮＋胸口縮放＋輕搖、各圖隨機相位不同步）。**無戒改背面視角**（面向敵人、玩家看背），每職 2 態：`wujie_<job>.png`（戰姿）＋`wujie_<job>_hurt.png`（HP<30% 換踉蹌護腹受傷姿，背面無臉故換姿不換臉）。**9 張立繪**＝無戒 3 職×2 態＋`pantheon_guard`＋阿瑞斯 base/phase2，全存 `…/portraits/{wujie,enemies,boss}/cut/*.png`（RGBA 1696×2528）。生圖 higgsfield `nano_banana_pro`（吃鎖定基底參考）＋magnific `imagen-nano-banana-2`（hurt 3 張，higgsfield 額度耗盡）＋magnific `images_remove_background` 去背。程式：新 `breathing_figure.gd`(BreathingFigure)、`EnemyPanel` 重構成站立單位（figure＋浮動暗金霓虹名牌/HP＋點立繪選敵）、`BattleScreen.tscn` 上方敵人站列＋前景大 `PlayerFigure`、`battle_art` 加 `resolve_figure_path`/`player_figure_path(job,state)`、`BattleManager` Boss 表情/階段走 `_boss_fig`→cut。spec＝`docs/superpowers/specs/2026-06-17-battle-standing-figures-design.md`、plan＝`docs/superpowers/plans/2026-06-17-battle-standing-figures.md`。**雷：新 class_name 要先 `--editor --quit` 掃描註冊；GDScript lambda 按值捕捉值型別 local（測 signal 用陣列）；CaptureBattle phase2 須自行 resolve_figure_path。微調(2026-06-17，GPU 截圖反覆對齊)：血條/名牌移到敵人**頭上**(plate move_child(0)+vbox sep28)、敵人站列下移放大貼地(EnemyArea offset_top100/bottom945、一般敵 figure 300×440、**Boss figure 265×455＋腳底 lift70 往後站**)、9 張 cut 圖 tight-crop 到 alpha bbox(腳底對齊底邊)＝保全/Ares/無戒都腳踩地、Boss 夠壓迫；chanter 受傷圖修掉多手重生；阿瑞斯立繪重生(修頭身比例＋phase2 改 3/4 側身)；阿瑞斯戰鬥背景改 **`bg_battle_ares_forge.png`(軍火熔鑄爐，暖色配火焰戰神、無擋腳欄杆)** 取代街景/頂樓。**呼吸 bug 修**：原每幀寫 position.y 與容器版面打架＋抬腳離地→改只用 scale(腳底 pivot)＋輕搖、不碰 position。仍待：呼吸節奏實機手感。**
- **資產**：12 BGM＋16 SFX；英雄立繪 2x；**8 戰鬥背景（+pantheon 軍火庫、+ares_forge 軍火熔鑄爐；ares_rooftop 頂樓備用）**；敵人/NPC 立繪（戰鬥畫面已接顯示）；**12 神設定集 `assets/2d/gods/`**；**戰鬥站立去背立繪 9 張（無戒 3 職×2 態＋guard＋ares base/phase2）**。

---

## 三、計畫 vs 實作落差（盤點重點）

### 🔴 嚴重（擋遊戲成形）

1. ~~**3D 探索＝最大未完成塊。**~~ → ✅ **解除（2026-06-16 探索改 2D 楓谷式，3D 街景退役保留）。** 原 approach A（程式化盒體＋AI 貼圖）因「假房子」迭代 ~8 版仍不滿意、與使用者 2D 美術強項不合，改走 2D：城市地圖→平面長街→內景，系統＋美術全完成並驗證（見上「二、已完成」）。3D 檔案（`XimenStreet.gd`＋`assets/3d/`）留著供故事地標日後用 Meshy 單物件。詳見記憶 `project-2d-map`／`project-3d-environment`（後者已標退役）。

2. **主線 12 神戰役只有資料骨架（ch1 已擴成完整劇情切片）。** `main_quests.json`＋成就已對齊「12 章一神」；**ch1 阿瑞斯 2026-06-15 已擴成 8 stage 人中之龍式流程（探聽情報→結識了塵→軍火庫雜兵→決戰），含神祇情報圖鑑系統＝12 章劇情模板**。ch2–12 內容幾乎全 NEW：
   - Boss 戰鬥資料：**只有 ch1 阿瑞斯**；缺 11 個（hermes/poseidon/demeter/hephaestus/aphrodite/apollo/dionysus/artemis/athena/hera/zeus）含數值＋場地機制。
   - 迷宮場景 ×12（沿用 3D 探索場景＋觸發）。
   - 過場 ×14（opening_temple_falls 已做；缺 12 個 `<god>_intro`＋ending_true）。
   - 主線對話 ×12（`main_<god>_lead` 等）。
   - 一般敵兵 `pantheon_guard`（enemies.json 待補）。
   - ✅ 今日完成：12 神**立繪/設定集**（是 portrait，不等於 Boss 戰鬥資料）。

### 🟠 文件/資料不一致（需更新或修）

3. **GDD v5 過時：** 無「主線/12 神」專章；§11 只有阿瑞斯當「最終 Boss → ending_true」；§12 成就條件是舊行為型（已被 achievements.json 通章解鎖版取代）。
4. ~~**資料 bug：** `boss.json` 的 `ares.unlock_ending`~~ → ✅ **已修（2026-06-14）**，移除該行（之後給 zeus）。
5. ~~**城市名：** 對話/資料仍寫「台北」~~ → ✅ **遊戲內已軟化（2026-06-16）**：`boss.json` 副標、`BreakVowSystem.gd`、`vow_break_greed.dtl`、`quest_rei_choice.dtl` 4 處台北→新梵市（區名/地標西門/林森北路/龍山寺及「台灣」國名保留）。**GDD v5 文件內仍寫台北＝隨整份 GDD 重寫一起處理。** 開場立誓用詞拍板＝「孽障」（呼應超渡主線，不改）。

### 🟡 功能缺口（不擋骨架）

6. ~~**小遊戲觸發對不上：** 阿明 s1→`busking_crowd`（沒做）／`soup_carry` 無觸發點~~ → ✅ **全部已接（截至 2026-06-17）**：阿明＝`wooden_fish_rhythm`（小傑挑戰亦是）；`soup_carry`＝手機「105 打工·端湯」（`JobApp`）；`beggar_challenge`＝打工·托缽＋地圖「化緣」動作。三小遊戲皆有觸發點，`busking_crowd` 已棄用。TestDemoScope 驗證所有 trigger_minigame 都指向存在的小遊戲。
7. ~~**選單階段 2/3：** 手機「任務」app＝主線 UI 入口、AchievementSystem、成就圖鑑頁~~ → ✅ **已完成（2026-06-15）**。~~手機其餘 app（移動/打工/設定）待實作~~ → ✅ **已實作並驗證 ALL PASS（2026-06-17）**：移動（🚇捷運 5 金+耗1時段／🚕計程車 30 金+即時直達落點）、105 打工（端湯/化緣→小遊戲）、設定（主/BGM/SFX 音量+全螢幕+文字速度）＋AudioManager 執行期音量 bus＋SettingsManager autoload（`user://settings.cfg` 持久化）。手機改 5 頁籤；免費 FastTravelApp 已刪、由付費 TravelApp 取代。詳見「二、已完成」與記憶 `project-phone-apps`。**仍待：實機 GPU 抽驗三頁觀感。**
8. ~~**對話 UI 美化：** P5 斜切邊框/霓虹未做。~~ → ✅ **已實作＋headless 驗證＋GPU 實機調定（2026-06-17）**：改 **VN 版面**——立繪移出框（左下大胸像，SPEAKER 模式自動跟說話者、**零 .dtl 改**）＋斜切金色霓虹文字框＋斜切金名牌。GPU 調定立繪/文字/名牌落點。**選項鈕也一併 P5 化（斜切暗金底＋hover 金色霓虹光暈、文字奶白→亮金，位置維持置中）。** 詳見「二、已完成」與 spec `2026-06-17-p5-dialogue-vn-layout-design.md`。
9. **次要：** 支線 cross_effect 的「第二幕」對應到 12 章哪章未定；多結局（業障/功德/Cherry 個人）暫緩，先單一真結局。
10. ~~**🟢 商店系統（spec 已核可、待實作）**~~ → ✅ **已實作並驗證 ALL PASS（2026-06-17）**：鄭媽佛具店道具＋背包＋戰鬥「道具」指令。詳見「二、已完成」與記憶 `project-shop-system`。**仍待：實機 GPU 抽驗購買+戰鬥道具手感。**
11. ~~**skill_learn 地圖動作（古廟）：** 死按鈕「此功能尚未實作」，因經書 `M` 已可隨時習得而冗餘~~ → ✅ **已移除（2026-06-17）**：自 `old_temple` actions 拿掉 `skill_learn`＋刪 `MapScreen.gd` 死 case＋刪 `MapHUD.gd` 的「參悟技能」label。習得統一走經書 M·技能頁。驗證：JSON 有效＋`--editor --quit` 無 parse error＋`TestMapData2D` PASS。

---

## 四、已拍板的決策（2026-06-14）

- **A. 3D 方向：** ~~暫緩~~ → **作廢（2026-06-16 探索改 2D 楓谷式）。** 探索不再走 3D；3D 僅保留給故事地標（破廟/茶攤）日後用 Meshy 單物件嵌入的可能性。
- **B. 主線下一步：** **先讓第 1 章完整跑通**（垂直切片，證明主線管線），再決定批量化。
- **C. 小遊戲觸發：** 未定（次要，不擋主線）。候選：阿明改接已做的小遊戲／補 busking_crowd／端湯找觸發點。
- **D. 文件：** ares bug ✅ 已修；GDD 全面改寫成 12 章版＝之後再說（先靠本文件＋main-story spec 當真相源）。
- **清圖：** ✅ 刪 `_style_samples` 比稿廢稿（−133MB）；保留 `_backup_1k`／`_nobg`。

---

## 五、第 1 章「跑通」建置清單（2026-06-14 完成並 headless 驗證 ALL PASS）

> 目標：開場過場 → 赴保全總部對話 → 被驅趕開打雜兵 → 阿瑞斯現身 → Boss 戰 → `ares_purified`。證明整條主線管線可動，之後 ch2–12 照抄。

- [x] **MainQuestManager**（`src/systems/MainQuestManager.gd`，已註冊 autoload）— 通用 12 章引擎：讀 `main_quests.json`，`current_chapter_id()` 依 complete_flag/require_flag 線性閘門；`continue_story()` 協程逐 stage `await`（cutscene→`play_story_cutscene`、dialogue→`Dialogic.timeline_ended`、battle/boss→`go_to_battle`+`EventBus.battle_ended`）；通章設 complete_flag＋發 rewards＋重置 stage 指標。戰敗保留 stage 進度可續推。
- [x] **入口** — 古廟（old_temple）加 `main_quest` 動作 → `MainQuestManager.continue_story()`（map_locations.json＋MapScreen.gd）。⚠ 仍待：手機「任務」app（正式入口）、開場後自動起 ch1。
- [x] **`pantheon_guard` 敵兵**（enemies.json，成對／召援，portrait 暫用 enemy_guard.png）。
- [x] **`main_ares_lead` 對話**（`dialogue/main_ares_lead.dtl`，無戒＋旁白，已註冊 dtl_directory）。
- [x] **`ares_intro` 劇情過場**（cutscenes.json，正式美術 `cutscenes/ch1_ares/ares_reveal.jpg`＝magnific Nano Banana 以 `gods/ares.jpg` 為角色參考 image-to-image 生成；zoom_in＋字幕）。
- [x] `opening_temple_falls` 過場／`ares` boss（已修 unlock_ending）。
- [x] **headless 驗證** `test/TestMainQuest.tscn`：ALL PASS（資料完整性＋章節閘門＋通章獎勵推進）；全專案 `--editor --quit` 編譯無 parse error。

**仍待（ch1 收尾＋擴張）：**
- 真 GPU 視窗跑一次完整 ch1（驗證協程串接的場景轉換/1.3s 結算時序在實機正確）。**含本次新增的手機任務 app「繼續主線」按鈕＋成就彈窗在實機的觀感。**
- ~~手機「任務」app（正式主線入口）＋ 開場後自動起 ch1 ＋ AchievementSystem~~ → ✅ **已完成（2026-06-15）**。
- ~~`main_ares_lead`/`ares_intro` 的正式美術~~ → ✅ **已完成（2026-06-17）**：`ares_intro`＝`ch1_ares/ares_reveal.jpg`（A1 阿瑞斯現身）；`main_ares_lead` 開頭加 `[background]`＝`ch1_ares/hq_exterior.jpg`（B2 總部入口，已洗去招牌亂碼字「cean」），結尾 `arg=""` 清空。皆 magnific Nano Banana 16:9 2k；headless `test/TestAresArt.tscn` ALL PASS。⚠ 敵兵 portrait 仍借 `enemy_guard.png`（另案）。
- **ch2–12 套同管線**（各需 boss 戰鬥資料＋迷宮＋god_intro 過場＋主線對話＋敵兵）。
- god_intro 過場/lineup（延續美術）；3D 依決策 A 擱置。

---

## 六、重要踩坑/規則（詳見記憶檔）

- 美術產線、畫風統一法、12 神模板 → 記憶 `project-art-direction`、`project-twelve-gods-design`。
- 對話/Dialogic 格式、`.dtl` 編輯器陷阱、建置細節 → 記憶 `project-build-status`。
- 立繪一律先鎖無戒基底當畫風錨點再生。改 `.dtl` 前一定先關 Godot。
