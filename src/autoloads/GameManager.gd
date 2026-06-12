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
		SaveManager.save_game()
	time_advanced.emit(player.period)

func add_merit(v: int) -> void:
	player.merit = clampi(player.merit + v, 0, MAX_MERIT)
	stat_changed.emit("merit", player.merit)
	if player.merit >= MAX_MERIT:
		EventBus.merit_maxed.emit()
	SkillUnlockManager.check_unlocks()

func add_karma(v: int) -> void:
	player.karma = clampi(player.karma + v, 0, MAX_KARMA)
	stat_changed.emit("karma", player.karma)
	if player.karma >= MAX_KARMA:
		set_flag("karma_maxed_once", true)
		EventBus.karma_maxed.emit()
	SkillUnlockManager.check_unlocks()

func take_damage(v: int) -> void:
	player.current_hp = clampi(player.current_hp - v, 0, player.max_hp)
	stat_changed.emit("current_hp", player.current_hp)
	if player.current_hp <= 0:
		EventBus.player_died.emit()
	elif player.current_hp < player.max_hp * 0.2:
		set_flag("near_death_triggered", true)
		SkillUnlockManager.check_unlocks()

func heal(v: int) -> void:
	player.current_hp = clampi(player.current_hp + v, 0, player.max_hp)
	stat_changed.emit("current_hp", player.current_hp)

func spend_gold(v: int) -> bool:
	if player.gold < v:
		return false
	player.gold -= v
	stat_changed.emit("gold", player.gold)
	return true

func add_gold(v: int) -> void:
	player.gold += v
	stat_changed.emit("gold", player.gold)

func switch_job(job: String) -> void:
	if job not in ["ascetic", "chanter", "beggar"]:
		return
	player.job = job
	job_changed.emit(job)

func set_flag(key: String, val: Variant) -> void:
	player.flags[key] = val

func get_flag(key: String, default: Variant = false) -> Variant:
	return player.flags.get(key, default)
