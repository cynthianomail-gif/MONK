# 主線劇情設計 spec —《和尚逆天》跨神系的物理超渡（12 章版）

日期：2026-06-14
來源：使用者主線大綱（2026-06-14）＋ 12 章 12 神定案。資料：[main_quests.json](../../../data/main_quests.json)、[achievements.json](../../../data/achievements.json)。
關聯：[[project-monk-game]]、[[project-build-status]]。

## 一、世界觀
- **類型**：現代都市開放街區探索 ＋ 回合制 RPG。
- **舞台**：「**新梵市**」，被跨國巨頭「**萬神殿集團**」高度掌控的霓虹大都會（＝虛構化台北；既有西門/萬華/林森為其行政區）。
- **反派**：集團高層真面目是降臨現代的希臘神祇，把神力轉化為資本，將人類的慾望與信仰當作企業能源。
- **主角無戒**：隱居破廟的武僧，外表慈眉木訥、戒律掛嘴邊，實則武術深不可測。破廟遭強拆、鎮寺之寶「**舍利塔**」被奪，被迫帶佛法與雙拳踏入紅塵。

## 二、結構：12 章 × 12 神 × 十二因緣
一章一神（希臘十二主神），線性推進，神力由小到大排到宙斯收尾。**每通一章解鎖對應的十二因緣成就**（章 N → 因緣 N），主線進度與成就系統綁定。

| 章 | 神 | 命脈（部門） | 迷宮 location | 因緣成就 | complete_flag |
|---|----|------|------|------|------|
| 1 | 阿瑞斯 Ares | 武力·保全·軍火 | pantheon_security_hq | 無明 ignorance | ares_purified |
| 2 | 荷米斯 Hermes | 物流·快遞·地下情報 | hermes_logistics | 行 formation | hermes_purified |
| 3 | 波賽頓 Poseidon | 海運·港口·走私 | poseidon_cruise | 識 consciousness | poseidon_purified |
| 4 | 狄蜜特 Demeter | 食品·農業·糧食壟斷 | demeter_farm | 名色 name_form | demeter_purified |
| 5 | 赫菲斯托斯 Hephaestus | 建設·重工·軍火（拆廟母公司） | hephaestus_site | 六入 six_bases | hephaestus_purified |
| 6 | 阿芙蘿黛蒂 Aphrodite | 娛樂·夜生活·偶像 | aphrodite_arena | 觸 contact | aphrodite_purified |
| 7 | 阿波羅 Apollo | 媒體·音樂·輿論 | apollo_broadcast | 受 sensation | apollo_purified |
| 8 | 戴歐尼修斯 Dionysus | 酒業·夜店·成癮經濟 | dionysus_club | 愛 craving | dionysus_purified |
| 9 | 阿緹蜜絲 Artemis | 私人軍事·狩獵·賞金 | artemis_lodge | 取 clinging | artemis_purified |
| 10 | 雅典娜 Athena | 科技·數據·監控·AI | athena_datacenter | 有 becoming | athena_purified |
| 11 | 赫拉 Hera | 政商聯姻·權勢核心（二把手） | hera_banquet | 生 birth | hera_purified |
| 12 | 宙斯 Zeus | 電網·能源·權力（CEO，最終） | olympus_tower | 老死 aging_death | ending_true |

舍利塔貫穿：`relic_stolen`（ch1 序）→ `relic_recovered`（ch12 終）。

## 三、資料結構
- `data/main_quests.json`：12 章 entry，線性 `require_flag`＝前一章 `complete_flag`；每章 boss/location/achievement/stages。
- `data/achievements.json`：十二因緣改為「通章解鎖」，每筆帶 `unlock_flag`（章 complete_flag）＋ `chapter`。
- 推進：階段2 手機「任務」app 讀 main_quests 顯示主線進度＋「前往」；旗標走 GameManager.flags。AchievementSystem（待實作）監看 unlock_flag 設定即解鎖因緣。

## 四、與既有資料的對齊決定（已採用）
1. **城市名**：台北 → 新梵市（區名沿用）。對話中寫死「台北」之後軟化。
2. **阿瑞斯**：由舊「最終 Boss」降為**第一章 Boss，且第一章即超渡擊敗**（不逃脫、不回歸）。`boss.json` 現有 `ares.unlock_ending: "ending_true"` 需移除（改由 zeus 持有）。
3. **最終結局**：先做**單一真結局** `ending_true`（ch12 奪回舍利塔）。多結局（業障/功德傾向、Cherry 個人結局）之後再擴。
4. **成就**：十二因緣**改為通章解鎖**，原本的行為條件（完成首戰/弱點連擊/破戒等）由本綁定取代；若日後想保留行為型成就，另立新成就群。
5. **迷宮形式**：12 迷宮**沿用 3D 探索場景＋劇情觸發**（非獨立線性關卡），以省 3D 工。

## 五、待產缺口（NEW，本 spec 只規劃不實作）—— 規模很大
- **Boss 戰鬥資料 ×12**（boss.json）：ares 已存在（需改 unlock_ending）；新增 hermes/poseidon/demeter/hephaestus/aphrodite/apollo/dionysus/artemis/athena/hera/zeus（11 個）。各需 stats＋場地機制＋portrait/battle_bg/bgm。機制草案：
  - 波賽頓 水柱全體水傷＋海妖歌聲魅惑；阿芙蘿黛蒂 狂粉雜兵牆＋媚惑反打；雅典娜 監控預判（先讀玩家技能）；荷米斯 高速多段＋偷金；狄蜜特 藤蔓/毒孢＋回復；赫菲斯托斯 重甲＋砲塔＋機械雜兵；阿波羅 遠程音波＋沉默(輿論)＋預言；戴歐尼修斯 醉狂混亂＋成癮強制行動；阿緹蜜絲 狙擊暴擊＋陷阱＋獵犬；赫拉 召保鏢＋恐懼＋群體強化；宙斯 蓄力全屏雷擊＋兩階段神域。
- **迷宮場景 ×12**（3D 探索場景＋觸發）：pantheon_security_hq / hermes_logistics / poseidon_cruise / demeter_farm / hephaestus_site / aphrodite_arena / apollo_broadcast / dionysus_club / artemis_lodge / athena_datacenter / hera_banquet / olympus_tower。
- **過場 ×14**（PNG 幀序列）：opening_temple_falls、各神 `<god>_intro`（12）、ending_true。既有 7 段全為破戒/處決/ares_phase2。
- **主線對話 ×12**：`main_<god>_lead`（及各 Boss 戰前後台詞）。
- **一般敵兵**：pantheon_guard（enemies.json 待補）。

## 六、剩餘開放問題（次要，不擋資料層）
1. 12 Boss 的數值平衡與場地機制細節（戰鬥設計階段細修）。
2. 迷宮沿用探索場景的具體做法（每迷宮一個 3D 場景，或共用場景換景＋觸發）。
3. 支線 cross_effect（rei/jie/cai_ma 影響「第二幕」）對應到 12 章版的哪一章（之後微調）。
