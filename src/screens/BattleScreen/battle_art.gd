class_name BattleArt
extends RefCounted

## 戰鬥畫面美術：路徑解析 + 暗金霓虹框工廠（純函式，可 headless 測）。
## 沿用 UI 暗金×黑色系（見 project-art-direction / project-dialogue-vn-style）。

const BG_DIR := "res://assets/2d/backgrounds/"
const ENEMY_DIR := "res://assets/2d/portraits/enemies/"
const BOSS_DIR := "res://assets/2d/portraits/boss/"
const WUJIE_DIR := "res://assets/2d/portraits/wujie/"
const GOLD := Color(0.788, 0.659, 0.38)

const DISTRICT_BG := {
	"ximen": "bg_battle_ximen.png",
	"shrine": "bg_battle_ximen.png",        # 收區：神社區戰鬥用櫻木町水墨夜街
	"armory": "bg_battle_ares_forge.png",   # 軍火庫戰鬥用阿瑞斯熔爐水墨場
	"wanhua_old": "bg_battle_wanhua.png",
	"linsen": "bg_battle_linsen.png",
	"pantheon": "bg_battle_pantheon.png",
}

## boss.json 的 battle_bg 優先；否則依 enemies.json 的 district；再 fallback ximen。
static func resolve_battle_bg(data: Dictionary) -> String:
	var f: String = String(data.get("battle_bg", ""))
	if f == "":
		f = DISTRICT_BG.get(String(data.get("district", "")), "bg_battle_ximen.png")
	return BG_DIR + f

## 立繪裸檔名 → 先試 enemies/ 再試 boss/，皆無回 ""。
static func resolve_portrait_path(filename: String) -> String:
	if filename == "":
		return ""
	var e := ENEMY_DIR + filename
	if ResourceLoader.exists(e):
		return e
	var b := BOSS_DIR + filename
	if ResourceLoader.exists(b):
		return b
	return ""

## 玩家立繪：依職業（ascetic/chanter/beggar）+ 表情（calm/angry）。
static func player_portrait_path(job: String, mood: String = "calm") -> String:
	var j: String = job if job in ["ascetic", "chanter", "beggar"] else "ascetic"
	return "%swujie_%s_%s.jpg" % [WUJIE_DIR, j, mood]

## 站立戰姿透明圖優先用 cut/<basename>.png，缺則退回原框圖，再退回 enemies/boss 探測（安全）。
static func resolve_figure_path(group_dir: String, filename: String) -> String:
	if filename == "":
		return ""
	var cut := group_dir + "cut/" + filename.get_basename() + ".png"
	if ResourceLoader.exists(cut):
		return cut
	var orig := group_dir + filename
	if ResourceLoader.exists(orig):
		return orig
	return resolve_portrait_path(filename)

## 玩家站立背面圖：wujie/cut/wujie_<job>[_hurt].png；state ∈ {normal, hurt}。
## 背面無臉，低 HP 換受傷姿（_hurt）而非換表情。缺 cut 退回原 jpg 立繪（normal→calm、hurt→angry）。
static func player_figure_path(job: String, state: String = "normal") -> String:
	var j: String = job if job in ["ascetic", "chanter", "beggar"] else "ascetic"
	var suffix: String = "_hurt" if state == "hurt" else ""
	var cut := "%scut/wujie_%s%s.png" % [WUJIE_DIR, j, suffix]
	if ResourceLoader.exists(cut):
		return cut
	return player_portrait_path(j, "angry" if state == "hurt" else "calm")

## 暗金霓虹框：近黑底 + 金邊 + 金光暈（shadow）。
static func neon_frame() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.043, 0.043, 0.043, 0.85)
	sb.set_border_width_all(2)
	sb.border_color = GOLD
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.45)
	sb.shadow_size = 6
	sb.set_content_margin_all(6)
	return sb
