# 托缽 + 木魚 小遊戲 okami 化生圖 Handoff → Codex

日期：2026-06-24
用途：把街頭托缽(BeggarChallenge)、木魚節奏(WoodenFishRhythm)兩個小遊戲裡**程式畫的多邊形佔位**換成 okami 水墨美術。背景與小傑立繪**已經是 okami、不用動**。Codex 只要生下表的圖到指定路徑，我再改 code 把它們接進去(比照端湯)。

## 風格(全部)
- **半寫實厚塗水墨**，同現有 cast(`new_ink_shrine_style/characters/game_ready/`)＋ okami 戰鬥背景＋端湯俯視圖。日本和風。
- **透明底 cutout**(PNG，四角 alpha=0)。
- 落點一律 `assets/art_direction/new_ink_shrine_style/minigames/`(和端湯同夾)。

---

## A. 街頭托缽：路人 ×4 + 乞討無戒（**側視 side-view**，面朝左，走路姿）
這遊戲是 2D 側視、路人由右往左走過街，所以要**側面全身、面朝左**(會被程式水平翻面，畫一個方向即可)。

| 檔名(`minigames/` 下) | 是誰 | 內容 | 尺寸 |
|---|---|---|---|
| `beggar_ped_office_worker.png` | 上班族(常見) | 日本上班族西裝、公事包、趕路 | ~512×900 直幅全身 |
| `beggar_ped_tourist.png` | 觀光客 | 背包+相機、悠閒 | ~512×900 |
| `beggar_ped_rich_lady.png` | 貴婦(稀有/高賞) | 華麗和服貴婦、貴氣 | ~512×900 |
| `beggar_ped_drunk_man.png` | 醉漢(低賞) | 微醺踉蹌、酒瓶 | ~512×900 |
| `beggar_wujie_begging.png` | 乞討無戒 | 無戒**側面**托缽(持缽蹲/站)，同 cast 黑袈裟 | ~512×900 |

> 側視＋面朝左＋透明底是重點(跟 cast 的正面立繪不同角度)。走路姿(單一靜態 frame 即可，v1 不做逐幀)。

## B. 木魚節奏：道具
| 檔名 | 是誰 | 內容 | 尺寸 |
|---|---|---|---|
| `woodenfish_instrument.png` | 木魚 | 傳統木魚樂器(俯視或 3/4)，朱漆/木紋、okami | ~512×512 透明 |
| `woodenfish_note.png` | 落下音符 | 落向判定線的音符 icon(木魚槌/念珠/卍 任一，好辨識)、okami | ~256×256 透明 |
| `woodenfish_hit_fx.png`(選配) | 敲擊特效 | 敲中時的墨花/光暈，可省(程式畫也行) | ~256×256 透明 |

## C. 無戒分職正面（兩遊戲的角色立繪，也補之前盤點缺口）
現在用舊 JPG。要 okami 正面(同 cast 風格、透明底)：
| 檔名 | 是誰 | 用在 |
|---|---|---|
| `wujie_chanter_front_game_ready.png` | 誦經僧無戒(正面) | 木魚節奏側邊立繪(對小傑) | ~1024×1536 |
| `wujie_beggar_front_game_ready.png` | 行腳/托缽僧無戒(正面) | 托缽備用立繪 | ~1024×1536 |

> chanter＝誦經(數珠/木魚)、beggar＝行腳托缽(斗笠/缽)，跟 ascetic(苦行)同一人不同打扮。

---

## 接線(我做，非 Codex)
Codex 生好後我會：①讀 `art_direction/.../minigames/` ②改 `BeggarChallenge.gd`(路人/乞討無戒 Sprite 取代多邊形)、`WoodenFishRhythm.gd`(木魚/音符 Sprite 取代多邊形)、monk_portrait 指新 chanter/beggar front ③windowed 截圖驗 ④commit。**所以 Codex 只需生上表的圖。**

## 優先
托缽路人 4 張(最顯眼的假人)＞木魚樂器+音符 ＞無戒分職正面(可先用現有 ascetic 頂著)。
