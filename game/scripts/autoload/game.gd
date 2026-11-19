extends Node
## Global state: settings, input map, fonts, theme and the current run.

## Beta numbering: 0.MILESTONE.BUILD. The leading 0 stays until release. MILESTONE goes up when a
## big system lands (0.1 prototype, 0.2 first loot/village/acts, 0.3 this build) and BUILD goes up for fixes and balance.
const VERSION := "0.5.11"
const SETTINGS_PATH := "user://settings.cfg"
const RECORD_PATH := "user://records.cfg"

const C_EMBER := Color(0.82, 0.17, 0.13)
const C_EMBER_HOT := Color(0.96, 0.82, 0.48)
const C_ASH := Color(0.62, 0.58, 0.55)
const C_BONE := Color(0.88, 0.82, 0.68)
const C_GOLD := Color(0.84, 0.68, 0.36)
const C_INK := Color(0.04, 0.035, 0.035)
const C_PANEL := Color(0.07, 0.06, 0.058, 0.94)
const C_TEXT := Color(0.86, 0.8, 0.68)
const C_DIM := Color(0.55, 0.52, 0.49)
const C_BANE := Color(0.72, 0.32, 0.3)

var font_display: FontFile
var font_display_bold: FontFile
var font_body: FontFile
var font_body_bold: FontFile
var font_italic: FontFile
var theme: Theme

var settings := {
	"master": 0.8,
	"music": 0.6,
	"sfx": 0.8,
	"shake": true,
	"numbers": true,
	"gore": true,
	"fullscreen": false,
	"vibration": true,
	"aim_assist": true,   # controller: aim at the nearest enemy when the right stick is idle
	"stick_deadzone": 0.25,
	"minimap": true,
	"loadout": {},        # per class: which ability sits on which bar slot
	"update_check": true,
	"last_version": "",    # the version whose notes the player has seen
	"brightness": 1.0,  # gamma of the world, calibrated in Settings
	"quality": 2,       # 0 Low, 1 Medium, 2 High, 3 Ultra
	"glow": true,
	"msaa": 2,          # 0 off, 1 2x, 2 4x, 3 8x
	"vsync": true,
	"fps_cap": 0,       # 0 = unlimited
	"voice": true,
	"subtitles": true,
	"fps_show": false,
	"tutorials": true,
	"tut_seen": [],
	"fps_corner": 1,    # 0 top-left, 1 top-right, 2 bottom-left, 3 bottom-right
}

func class_unlocked(id: String) -> bool:
	if not bool(Data.CLASSES[id].get("locked", false)):
		return true
	return int(records.get("wins", 0)) > 0 or bool(records.get("unlocked", false))


var records := {"runs": 0, "wins": 0, "best_zone": 0, "fastest": 0.0, "fallen": 0, "fallen_best_level": 0, "unlocked": false}

# Current run
var class_id := "knight"
var zone_index := 0
var fragments: Array[String] = []
var stats := {}
var using_gamepad := false

# Persistent character state for the run
signal gear_changed
signal settings_changed
signal quest_ready(title: String)
signal quests_changed
signal quest_accepted(id: String)

const INV_SIZE := 30
const STASH_SIZE := 60
const DIFF_NAMES := ["Wanderer", "Pilgrim", "Survivor", "Veteran", "Hardened", "Ashbound", "Scorched", "Cinderborn", "Marked", "Cursed",
	"Damned", "Wretched", "Forsaken", "Ruinous", "Infernal", "Abyssal", "Tormented", "Condemned", "Annihilation", "Oblivion"]
## Twenty steps. Index 2 (Survivor) is the baseline: 1.0 life and damage. Each step up gives more xp, gold and magic find.
var DIFFICULTIES: Array = _make_diffs()


func _make_diffs() -> Array:
	var out: Array = []
	for i in DIFF_NAMES.size():
		var k := i - 2
		out.append({"name": DIFF_NAMES[i], "hp": pow(1.14, k), "dmg": pow(1.085, k),
			"xp": maxf(0.8, 1.0 + 0.12 * k), "gold": maxf(0.85, 1.0 + 0.1 * k), "mf": maxf(0.0, 3.5 * k)})
	return out

var gold := 0
var inv: Array = []
var stash: Array = []
var equipment := {}
var gear := {}
var quests := {}  # id -> {"s": 1 active | 2 ready | 3 done, "p": progress}
var waypoints := {}
var zone_state := {}
var zone_seeds := {}
var max_zone := 0
var difficulty := 2
var potion_cd := 0.0
var stock := {}
var stock_dirty := true
var hero_name := "Nameless"
var acts_seen := {}
var look := {"accent": 0, "skin": 0, "hair": 0}


signal update_found(version: String, url: String)
const REPO := "astravail/ashen-crown"
var update_version := ""
var update_url := ""

## What changed in each version, newest first. Shown in What's new, and once after every update.
const RELEASE_NOTES := [
	{"v": "0.5.8", "items": [
		"Abilities unlock as you level: secondary at 3, skill 1 at 6, skill 2 at 10 and your ultimate at 15. The Abilities tab shows what is still locked.",
		"The maximum level is 60. At the top you can prestige from the skills screen: level and skills reset, and each rank (up to 10) gives lasting damage, life, gold and magic find.",
		"Balance pass on drops, chance-on-hit perks and enemy behaviour."]},
	{"v": "0.5.7", "items": [
		"Enemies move like individuals: they circle, hesitate, and sometimes fall back after an attack or when struck, instead of running straight at you.",
		"Gear can now carry chance-on-hit perks: terrify, stun, chill, ignite and a second strike. They are capped so they stay balanced.",
		"Controller support (preview): vibration, aim assist, and Interact picks up gear.",
		"Small shader savings."]},
	{"v": "0.5.6", "items": [
		"Tips appear at the moment they matter, freeze the game while you read, and can be closed after three seconds with your Interact key.",
		"The game resumes when a tip is closed."]},
	{"v": "0.5.5", "items": [
		"Abilities tab in the inventory: put any ability on any button of your bar.",
		"A better-looking inventory with a body-shaped equipment layout.",
		"Each hero cries out in their own voice now and then when struck.",
		"The Crownbearer is locked until you finish the game.",
		"Health globes drop rarely."]},
	{"v": "0.5.4", "items": [
		"Life is now blood, and each class has its own matter in the other orb: molten cinder, drifting souls, rising flame.",
		"Blood on the ground is more realistic: dark clotting rims, streaks and a mist of fine drops.",
		"Controls: rebindable keys and controller buttons, and the same input can no longer be used for two things.",
		"Health globes drop much less often, as in Diablo.",
		"What's new now opens after every update, and the game can check for new versions.",
		"Class and character screens fit their text again."]},
	{"v": "0.5.3", "items": [
		"A town portal now stays open in the village and leads back to where you left.",
		"Brightness calibration in Settings, and a darker picture overall.",
		"The map starts empty and no longer shows chests or shrines. Find them yourself.",
		"Rebindable keys and controller buttons, plus more controller settings.",
		"What's new, and a check for new versions.",
		"Gear name tags no longer pile on top of each other.",
		"Ash now drifts on the wind and no longer looks like snow."]},
	{"v": "0.5.2", "items": ["Runs and victories are no longer shown."]},
	{"v": "0.5.1", "items": ["Settings scrolls, and Back sits in the top left corner."]},
	{"v": "0.5.0", "items": [
		"New graphics: terrain lit in relief, a finishing pass, redrawn heroes, enemies, props and effects.",
		"Gear is picked up by clicking it, with a green arrow for upgrades and a red one for downgrades.",
		"Legendaries scale with your level.",
		"Reset statistics in Settings."]},
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_fonts()
	_build_theme()
	_setup_input()
	load_settings()
	load_binds()
	_load_records()
	apply_settings()
	if bool(settings.update_check) and not DisplayServer.get_name().begins_with("headless"):
		check_update.call_deferred()


func new_run(cls: String) -> void:
	char_id = "c%d" % int(Time.get_unix_time_from_system())
	world_seed = randi()
	player_state = {}
	prestige = 0
	class_id = cls
	zone_index = 0
	fragments.clear()
	stats = {"kills": 0, "time": 0.0, "damage_dealt": 0.0, "damage_taken": 0.0, "level": 1, "elites": 0}
	gold = 0
	inv = []
	inv.resize(INV_SIZE)
	stash = load_stash()
	equipment = {}
	gear = {}
	quests = {}
	waypoints = {"village": true, "g0": true}
	zone_state = {}
	zone_seeds = {}
	max_zone = 0
	acts_seen = {}
	markers = []
	in_run = true
	diff_cd = 0.0
	potion_cd = 0.0
	stock = {}
	stock_dirty = true
	records.runs += 1
	save_records()


const ACCENTS := [Color(0.38, 0.09, 0.06), Color(0.1, 0.22, 0.4), Color(0.12, 0.3, 0.16), Color(0.35, 0.28, 0.08), Color(0.28, 0.1, 0.34), Color(0.3, 0.3, 0.32)]
const ACCENT_NAMES := ["Ember red", "Dusk blue", "Moss green", "Old gold", "Violet", "Ash grey"]
const SKINS := [Color(0.55, 0.45, 0.4), Color(0.72, 0.58, 0.48), Color(0.42, 0.32, 0.27), Color(0.3, 0.22, 0.19), Color(0.68, 0.7, 0.68)]
const HAIRS := [Color(0.12, 0.05, 0.04), Color(0.4, 0.25, 0.12), Color(0.75, 0.7, 0.6), Color(0.05, 0.05, 0.06), Color(0.55, 0.12, 0.08)]


func beta_label() -> String:
	return "BETA  %s" % VERSION


var in_run := false
var markers: Array = []  # map markers placed by the player, in world pixels
const MAX_MARKERS := 5
var char_id := ""
var world_seed := 0
var player_state := {}
## How many times this character has prestiged: each rank is a lasting bonus, see Data.PRESTIGE_MAX_RANKS.
var prestige := 0
var hardcore := false
## Hardcore: one life. In return, everything comes a bit faster.
const HC_PERKS := {"xp": 1.25, "gold": 1.2, "mf": 20.0}
var diff_cd := 0.0
const DIFF_COOLDOWN := 45.0


## Difficulty moves one step at a time, with a wait in between, like swapping in the lobby: no big leaps mid-fight.
func change_difficulty(delta: int) -> bool:
	var target := clampi(difficulty + signi(delta), 0, DIFFICULTIES.size() - 1)
	if target == difficulty or diff_cd > 0.0:
		return false
	difficulty = target
	diff_cd = DIFF_COOLDOWN
	return true


func accent_color() -> Color:
	return ACCENTS[clampi(int(look.accent), 0, ACCENTS.size() - 1)]


func skin_color() -> Color:
	return SKINS[clampi(int(look.skin), 0, SKINS.size() - 1)]


func hair_color() -> Color:
	return HAIRS[clampi(int(look.hair), 0, HAIRS.size() - 1)]


func zs(i: int) -> Dictionary:
	if not zone_state.has(i):
		zone_state[i] = {"champ_dead": false, "claimed": false, "boss_dead": false, "chests": {}, "visited": false}
	return zone_state[i]


func diff() -> Dictionary:
	var d: Dictionary = DIFFICULTIES[difficulty]
	if not hardcore:
		return d
	var h := d.duplicate()
	h.xp = float(d.xp) * float(HC_PERKS.xp)
	h.gold = float(d.gold) * float(HC_PERKS.gold)
	h.mf = float(d.mf) + float(HC_PERKS.mf)
	return h


func unlock(id: String) -> bool:
	if waypoints.has(id):
		return false
	waypoints[id] = true
	return true


# ------------------------------------------------------------------ gold and items

func add_gold(n: int) -> void:
	gold += n
	stat_add("gold_earned", n)


## Chance-on-hit perks are capped, so stacking them never makes an enemy helpless.
const PROC_CAP := {"fear": 0.2, "stunc": 0.15, "chill": 0.3, "ignite": 0.3, "echo": 0.12}


func proc(k: String) -> float:
	return minf(float(PROC_CAP.get(k, 0.0)), gear_stat(k) / 100.0)


func prestige_ranks() -> int:
	return mini(prestige, Data.PRESTIGE_MAX_RANKS)


func gear_stat(k: String) -> float:
	var v := float(gear.get(k, 0.0))
	# prestige adds to gold and magic find as if it were gear
	if k == "mf" or k == "gold":
		v += 3.0 * prestige_ranks()
	return v


func recalc_gear() -> void:
	gear = Items.totals(equipment)
	gear_changed.emit()


func add_to(list: Array, item: Dictionary) -> bool:
	for i in list.size():
		if list[i] == null:
			list[i] = item
			return true
	return false


func add_item(item: Dictionary) -> bool:
	var ok := add_to(inv, item)
	if ok:
		stat_add("items_r%d" % int(item.rarity), 1)
	return ok


func free_slots(list: Array) -> int:
	var n := 0
	for x in list:
		if x == null:
			n += 1
	return n


## Swap the backpack item at `idx` with whatever is worn in its slot.
func equip(idx: int) -> void:
	var item: Dictionary = inv[idx]
	var old: Variant = equipment.get(item.slot)
	equipment[item.slot] = item
	inv[idx] = old
	recalc_gear()


func unequip(slot: String) -> bool:
	if not equipment.has(slot) or equipment[slot] == null:
		return false
	if not add_item(equipment[slot]):
		return false
	equipment.erase(slot)
	recalc_gear()
	return true


func repair_all_cost() -> int:
	var c := 0
	for s in equipment.keys():
		c += Items.repair_cost(equipment[s])
	return c


func repair_all() -> int:
	var cost := repair_all_cost()
	if cost > gold:
		return 0
	gold -= cost
	for s in equipment.keys():
		equipment[s].dur = equipment[s].dur_max
	recalc_gear()
	return cost


## Dying chips away at everything you wear.
func wear_on_death() -> void:
	for s in equipment.keys():
		var it: Dictionary = equipment[s]
		it.dur = maxi(0, int(it.dur) - maxi(1, int(it.dur_max * 0.1)))
	recalc_gear()


func vendor_stock(kind: String) -> Array:
	if stock_dirty or not stock.has(kind):
		stock[kind] = Items.vendor_stock(kind, 1 + max_zone * 4 + randi_range(0, 2))
		if kind == "mystic":
			stock_dirty = false
	return stock[kind]


# ------------------------------------------------------------------ quests

func quest_status(id: String) -> int:
	return int((quests.get(id, {"s": 0}) as Dictionary).s)


func quest_available(q: Dictionary) -> bool:
	if quest_status(q.id) != 0:
		return false
	if q.get("req", "") != "" and quest_status(q.req) != 3:
		return false
	var z: int = q.zone
	if z > Data.LAST_ZONE:
		return true
	# The road to a zone opens when the previous zone's fragment is claimed (zone 0 after the cellar).
	if z == 0:
		return quest_status("story_0") == 3
	return bool(zs(z - 1).claimed)


func quest_accept(id: String) -> void:
	quests[id] = {"s": 1, "p": 0}
	quest_accepted.emit(id)
	quests_changed.emit()


func quest_advance(type: String, zone: int, n := 1) -> void:
	for q in Data.QUESTS:
		var st: Dictionary = quests.get(q.id, {})
		if st.is_empty() or int(st.s) != 1 or q.type != type or int(q.zone) != zone:
			continue
		st.p = mini(int(q.goal), int(st.p) + n)
		if int(st.p) >= int(q.goal):
			st.s = 2
			quest_ready.emit(q.title)
	quests_changed.emit()


func quest_active_for(type: String, zone: int) -> bool:
	for q in Data.QUESTS:
		if q.type == type and int(q.zone) == zone and quest_status(q.id) == 1:
			return true
	return false


## "!" when something can be accepted, "?" when something can be handed in.
func quest_marker() -> String:
	var m := ""
	for q in Data.QUESTS:
		if quest_status(q.id) == 2:
			return "?"
		if quest_available(q):
			m = "!"
	return m


# ------------------------------------------------------------------ settings

## Which ability each of the four bar slots uses for a class, always a permutation of 0..3.
func loadout_for(cls: String) -> Array:
	var m: Variant = settings.get("loadout", {}).get(cls, [0, 1, 2, 3])
	if m is Array and m.size() == 4 and m.duplicate().map(func(x): return int(x)).has(0) and m.has(1) and m.has(2) and m.has(3):
		return m.map(func(x): return int(x))
	return [0, 1, 2, 3]


func set_loadout(cls: String, m: Array) -> void:
	var all: Dictionary = settings.get("loadout", {})
	all[cls] = m
	settings["loadout"] = all
	save_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		for k in settings.keys():
			settings[k] = cfg.get_value("settings", k, settings[k])
	apply_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in settings.keys():
		cfg.set_value("settings", k, settings[k])
	cfg.save(SETTINGS_PATH)


const QUALITY_NAMES := ["Low", "Medium", "High", "Ultra"]
const QUALITY_FACTOR := [0.15, 0.4, 0.75, 1.0]


## 0..1: scales ambient particles, effect buffers and similar costs. Low is meant for weak PCs.
func quality_factor() -> float:
	return QUALITY_FACTOR[clampi(int(settings.quality), 0, 3)]


func apply_preset(q: int) -> void:
	settings.quality = q
	settings.glow = q >= 1
	settings.msaa = [0, 0, 2, 3][q]
	settings.fps_cap = [60, 0, 0, 0][q]
	apply_settings()


func apply_settings() -> void:
	for a in ["move_up", "move_down", "move_left", "move_right"]:
		InputMap.action_set_deadzone(a, clampf(float(settings.stick_deadzone), 0.05, 0.6))
	Sfx.set_volumes(settings.master, settings.music, settings.sfx)
	Engine.max_fps = int(settings.fps_cap)
	if not DisplayServer.get_name().begins_with("headless"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings.vsync else DisplayServer.VSYNC_DISABLED)
		if get_viewport():
			get_viewport().msaa_2d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X][clampi(int(settings.msaa), 0, 3)]
	settings_changed.emit()
	if not DisplayServer.get_name().begins_with("headless"):
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want:
			DisplayServer.window_set_mode(want)


func _load_records() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RECORD_PATH) == OK:
		for k in records.keys():
			records[k] = cfg.get_value("records", k, records[k])


## Wipes the lifetime statistics (runs, wins, best zone, fastest win, fallen). Saved characters are untouched.
func reset_records() -> void:
	var keep := bool(records.get("unlocked", false)) or int(records.get("wins", 0)) > 0
	records = {"runs": 0, "wins": 0, "best_zone": 0, "fastest": 0.0, "fallen": 0, "fallen_best_level": 0, "unlocked": keep}
	save_records()


func save_records() -> void:
	var cfg := ConfigFile.new()
	for k in records.keys():
		cfg.set_value("records", k, records[k])
	cfg.save(RECORD_PATH)


# ------------------------------------------------------------------ input

func _setup_input() -> void:
	var defs := {
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"skill_1": [KEY_Q],
		"skill_2": [KEY_E],
		"ultimate": [KEY_R],
		"dodge": [KEY_SPACE],
		"flask": [KEY_F],
		"pause": [KEY_ESCAPE],
		"map": [KEY_TAB],
		"interact": [KEY_G],
		"inventory": [KEY_I],
		"quests": [KEY_J],
		"skills": [KEY_K],
		"recall": [KEY_T],
	}
	for action in defs.keys():
		_ensure(action)
		for key in defs[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	_mouse("attack_1", MOUSE_BUTTON_LEFT)
	_mouse("attack_2", MOUSE_BUTTON_RIGHT)
	_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)
	_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_axis("attack_1", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_axis("attack_2", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_button("skill_1", JOY_BUTTON_X)
	_button("skill_2", JOY_BUTTON_Y)
	_button("ultimate", JOY_BUTTON_RIGHT_SHOULDER)
	_button("dodge", JOY_BUTTON_A)
	_button("flask", JOY_BUTTON_LEFT_SHOULDER)
	_button("pause", JOY_BUTTON_START)
	_button("map", JOY_BUTTON_BACK)
	_button("interact", JOY_BUTTON_B)
	_button("inventory", JOY_BUTTON_DPAD_UP)
	_button("quests", JOY_BUTTON_DPAD_LEFT)
	_button("skills", JOY_BUTTON_DPAD_RIGHT)
	_button("recall", JOY_BUTTON_DPAD_DOWN)
	for a in ["move_up", "move_down", "move_left", "move_right"]:
		InputMap.action_set_deadzone(a, 0.25)


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.3)


func _mouse(action: String, button: MouseButton) -> void:
	_ensure(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _axis(action: String, axis: JoyAxis, value: float) -> void:
	_ensure(action)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)


func _button(action: String, button: JoyButton) -> void:
	_ensure(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.4):
		if not using_gamepad:
			using_gamepad = true
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	elif event is InputEventMouseMotion or event is InputEventKey or event is InputEventMouseButton:
		if using_gamepad:
			using_gamepad = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## What the player can rebind: [action, label, controller button can be changed]
const BINDABLE := [
	["attack_1", "Primary attack", false], ["attack_2", "Secondary attack", false],
	["skill_1", "Skill 1", true], ["skill_2", "Skill 2", true], ["ultimate", "Ultimate", true],
	["dodge", "Dodge", true], ["flask", "Potion", true], ["interact", "Interact", true],
	["inventory", "Inventory", true], ["quests", "Quest log", true], ["skills", "Skill tree", true],
	["recall", "Town portal", true], ["map", "Map", true],
	["move_up", "Move up", false], ["move_down", "Move down", false], ["move_left", "Move left", false], ["move_right", "Move right", false],
]
## Keys that stay bound whatever the player picks, so a hand is never left without a way to move or pause.
const KEEP_KEYS := {"move_up": [KEY_UP], "move_down": [KEY_DOWN], "move_left": [KEY_LEFT], "move_right": [KEY_RIGHT], "pause": [KEY_ESCAPE]}
const BIND_PATH := "user://binds.cfg"
const PAD_NAMES := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_BACK: "Back", JOY_BUTTON_START: "Start", JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down",
	JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right"}
var _default_events := {}


## Remembers what each action is bound to as shipped, so the keybind screen can reset to it.
func _remember_defaults() -> void:
	if not _default_events.is_empty():
		return
	for b in BINDABLE:
		_default_events[b[0]] = InputMap.action_get_events(b[0]).duplicate()


func _is_pad(ev: InputEvent) -> bool:
	return ev is InputEventJoypadButton or ev is InputEventJoypadMotion


func _primary(action: String, pad: bool) -> InputEvent:
	for ev in InputMap.action_get_events(action):
		if pad and ev is InputEventJoypadButton:
			return ev
		if not pad and (ev is InputEventKey or ev is InputEventMouseButton):
			return ev
	return null


## Which other action already uses `ev`, or "" if nobody does.
func bind_conflict(action: String, ev: InputEvent) -> String:
	var pad := _is_pad(ev)
	for b in BINDABLE:
		var other: String = b[0]
		if other == action:
			continue
		var cur := _primary(other, pad)
		if cur and cur.is_match(ev, true):
			return String(b[1])
		if not pad and KEEP_KEYS.has(other) and ev is InputEventKey and KEEP_KEYS[other].has(ev.physical_keycode):
			return String(b[1])
	if not pad and ev is InputEventKey and ev.physical_keycode == KEY_ESCAPE:
		return "Pause"
	return ""


## Rebinds one action. `ev` replaces its keyboard or mouse input, or its controller button.
## Call bind_conflict first: an input can only belong to one action.
func rebind(action: String, ev: InputEvent) -> void:
	_remember_defaults()
	var pad := _is_pad(ev)
	for e in InputMap.action_get_events(action):
		if (pad and e is InputEventJoypadButton) or (not pad and (e is InputEventKey or e is InputEventMouseButton) and not _kept(action, e)):
			InputMap.action_erase_event(action, e)
	InputMap.action_add_event(action, ev)
	save_binds()


func _kept(action: String, e: InputEvent) -> bool:
	return e is InputEventKey and KEEP_KEYS.get(action, []).has(e.physical_keycode)


func reset_binds() -> void:
	_remember_defaults()
	for action in _default_events.keys():
		InputMap.action_erase_events(action)
		for e in _default_events[action]:
			InputMap.action_add_event(action, e)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BIND_PATH))


func save_binds() -> void:
	var cfg := ConfigFile.new()
	for b in BINDABLE:
		var kb := _primary(b[0], false)
		if kb is InputEventKey:
			cfg.set_value("kb", b[0], ["key", kb.physical_keycode])
		elif kb is InputEventMouseButton:
			cfg.set_value("kb", b[0], ["mouse", kb.button_index])
		var pd := _primary(b[0], true)
		if pd is InputEventJoypadButton:
			cfg.set_value("pad", b[0], pd.button_index)
	cfg.save(BIND_PATH)


func load_binds() -> void:
	_remember_defaults()
	var cfg := ConfigFile.new()
	if cfg.load(BIND_PATH) != OK:
		return
	for b in BINDABLE:
		var a: String = b[0]
		if cfg.has_section_key("kb", a):
			var v: Array = cfg.get_value("kb", a)
			var ev: InputEvent
			if v[0] == "key":
				ev = InputEventKey.new()
				ev.physical_keycode = int(v[1])
			else:
				ev = InputEventMouseButton.new()
				ev.button_index = int(v[1])
			for e in InputMap.action_get_events(a):
				if (e is InputEventKey or e is InputEventMouseButton) and not _kept(a, e):
					InputMap.action_erase_event(a, e)
			InputMap.action_add_event(a, ev)
		if cfg.has_section_key("pad", a):
			var pe := InputEventJoypadButton.new()
			pe.button_index = int(cfg.get_value("pad", a))
			for e in InputMap.action_get_events(a):
				if e is InputEventJoypadButton:
					InputMap.action_erase_event(a, e)
			InputMap.action_add_event(a, pe)


## The short name of the input an action is bound to, for the keybind screen and the HUD.
func input_label(action: String, pad: bool) -> String:
	var ev := _primary(action, pad)
	if ev is InputEventKey:
		var code: int = DisplayServer.keyboard_get_keycode_from_physical(ev.physical_keycode)
		return OS.get_keycode_string(code).to_upper()
	if ev is InputEventMouseButton:
		return {MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB", MOUSE_BUTTON_MIDDLE: "MMB"}.get(ev.button_index, "MOUSE %d" % ev.button_index)
	if ev is InputEventJoypadButton:
		return PAD_NAMES.get(ev.button_index, "Button %d" % ev.button_index)
	if pad:
		return {"attack_1": "RT", "attack_2": "LT"}.get(action, "")
	return ""


## The short name of an input event on its own.
func input_label_for(ev: InputEvent) -> String:
	if ev is InputEventKey:
		return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(ev.physical_keycode)).to_upper()
	if ev is InputEventMouseButton:
		return {MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB", MOUSE_BUTTON_MIDDLE: "MMB"}.get(ev.button_index, "MOUSE %d" % ev.button_index)
	if ev is InputEventJoypadButton:
		return PAD_NAMES.get(ev.button_index, "Button %d" % ev.button_index)
	return ""


func key_label(action: String) -> String:
	if using_gamepad:
		return input_label(action, true)
	return input_label(action, false)


# ------------------------------------------------------------------ look

func _load_fonts() -> void:
	font_display = load("res://assets/fonts/cinzel-latin-500-normal.woff2")
	font_display_bold = load("res://assets/fonts/cinzel-latin-700-normal.woff2")
	font_body = load("res://assets/fonts/spectral-latin-400-normal.woff2")
	font_body_bold = load("res://assets/fonts/spectral-latin-600-normal.woff2")
	font_italic = load("res://assets/fonts/spectral-latin-400-italic.woff2")


func _box(bg: Color, border: Color, bw := 1, radius := 2, pad := 14.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad * 1.6
	sb.content_margin_right = pad * 1.6
	sb.content_margin_top = pad * 0.7
	sb.content_margin_bottom = pad * 0.7
	sb.anti_aliasing = true
	return sb


func _build_theme() -> void:
	theme = Theme.new()
	theme.default_font = font_body
	theme.default_font_size = 22
	theme.set_color("font_color", "Label", C_TEXT)

	theme.set_font("font", "Button", font_display_bold)
	theme.set_font_size("font_size", "Button", 24)
	theme.set_color("font_color", "Button", C_GOLD)
	theme.set_color("font_hover_color", "Button", C_EMBER_HOT)
	theme.set_color("font_focus_color", "Button", C_EMBER_HOT)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color(0.4, 0.38, 0.36))
	theme.set_stylebox("normal", "Button", Ornate.box("btn"))
	theme.set_stylebox("hover", "Button", Ornate.box("btn_hot"))
	theme.set_stylebox("focus", "Button", Ornate.box("btn_hot"))
	theme.set_stylebox("pressed", "Button", Ornate.box("btn_press"))
	theme.set_stylebox("disabled", "Button", Ornate.box("btn_off"))

	theme.set_stylebox("panel", "PanelContainer", Ornate.box("panel"))
	theme.set_stylebox("panel", "Panel", Ornate.box("panel"))

	var grab := StyleBoxFlat.new()
	grab.bg_color = C_EMBER
	grab.set_corner_radius_all(2)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.16, 0.14, 0.13)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	track.set_corner_radius_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.55, 0.26, 0.1)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	fill.set_corner_radius_all(2)
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var knob := _knob(Color(0.95, 0.85, 0.72))
	var knob_hot := _knob(C_EMBER_HOT)
	theme.set_icon("grabber", "HSlider", knob)
	theme.set_icon("grabber_highlight", "HSlider", knob_hot)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = C_EMBER
	focus.set_border_width_all(1)
	focus.expand_margin_top = 6
	focus.expand_margin_bottom = 6
	focus.expand_margin_left = 6
	focus.expand_margin_right = 6
	theme.set_stylebox("focus", "HSlider", focus)

	theme.set_font("font", "CheckButton", font_body)
	theme.set_color("font_color", "CheckButton", C_TEXT)
	theme.set_color("font_hover_color", "CheckButton", C_EMBER_HOT)
	theme.set_color("font_focus_color", "CheckButton", C_EMBER_HOT)
	theme.set_stylebox("focus", "CheckButton", focus)
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "hover_pressed"]:
		theme.set_stylebox(s, "CheckButton", empty)


func _knob(c: Color) -> ImageTexture:
	var img := Image.create(18, 18, false, Image.FORMAT_RGBA8)
	for y in 18:
		for x in 18:
			var d := Vector2(x - 8.5, y - 8.5).length()
			var a := clampf(8.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, a))
	return ImageTexture.create_from_image(img)


func fmt_time(t: float) -> String:
	var s := int(t)
	return "%d:%02d" % [s / 60, s % 60]


# ------------------------------------------------------------------ saved characters

const SAVE_DIR := "user://characters"
const STASH_PATH := "user://stash.save"
const STASH_HC_PATH := "user://stash_hardcore.save"
const FALLEN_PATH := "user://fallen.save"
var last_killer := "the ash"


## Hardcore heroes keep a stash of their own, as in Diablo 3.
func _stash_path() -> String:
	return STASH_HC_PATH if hardcore else STASH_PATH


func load_stash() -> Array:
	var out: Array = []
	if FileAccess.file_exists(_stash_path()):
		var f := FileAccess.open(_stash_path(), FileAccess.READ)
		var v: Variant = f.get_var(false)
		if v is Array:
			out = v
	out.resize(STASH_SIZE)
	return out


func save_character() -> void:
	if char_id == "" or not in_run:
		return
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var d := {"v": 1, "name": hero_name, "cls": class_id, "hardcore": hardcore, "difficulty": difficulty, "look": look,
		"gold": gold, "inv": inv, "equipment": equipment, "quests": quests, "waypoints": waypoints, "zone_state": zone_state,
		"max_zone": max_zone, "acts_seen": acts_seen, "stats": stats, "fragments": Array(fragments), "world_seed": world_seed,
		"player": player_state, "prestige": prestige, "markers": markers, "saved": int(Time.get_unix_time_from_system())}
	var f := FileAccess.open("%s/%s.save" % [SAVE_DIR, char_id], FileAccess.WRITE)
	if f:
		f.store_var(d, false)
	var sf := FileAccess.open(_stash_path(), FileAccess.WRITE)
	if sf:
		sf.store_var(stash, false)


func _read_save(id: String) -> Dictionary:
	var path := "%s/%s.save" % [SAVE_DIR, id]
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var v: Variant = f.get_var(false)
	return v if v is Dictionary else {}


## Short summaries for the character list, newest first.
func list_characters() -> Array:
	var out: Array = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return out
	for fn in dir.get_files():
		if not fn.ends_with(".save"):
			continue
		var id := fn.get_basename()
		var d := _read_save(id)
		if d.is_empty():
			continue
		out.append({"id": id, "name": d.name, "cls": d.cls, "hardcore": d.get("hardcore", false), "difficulty": d.get("difficulty", 2),
			"level": int((d.get("player", {}) as Dictionary).get("level", 1)), "saved": d.get("saved", 0), "max_zone": d.get("max_zone", 0)})
	out.sort_custom(func(a, b): return a.saved > b.saved)
	return out


func load_character(id: String) -> bool:
	var d := _read_save(id)
	if d.is_empty():
		return false
	char_id = id
	hero_name = d.name
	class_id = d.cls
	hardcore = d.get("hardcore", false)
	difficulty = int(d.get("difficulty", 2))
	look = d.get("look", look)
	gold = int(d.gold)
	inv = d.inv
	inv.resize(INV_SIZE)
	stash = load_stash()
	equipment = d.equipment
	quests = d.quests
	waypoints = d.waypoints
	zone_state = d.zone_state
	max_zone = int(d.max_zone)
	acts_seen = d.acts_seen
	stats = d.stats
	prestige = int(d.get("prestige", 0))
	fragments.assign(d.fragments)
	world_seed = int(d.world_seed)
	player_state = d.player
	markers = d.get("markers", [])
	stock = {}
	stock_dirty = true
	potion_cd = 0.0
	diff_cd = 0.0
	in_run = true
	var top := 0
	for list in [inv, stash, equipment.values()]:
		for it in list:
			if it != null:
				top = maxi(top, int(it.uid))
	Items._uid = maxi(Items._uid, top + 1)
	recalc_gear()
	return true


func delete_character(id: String) -> void:
	DirAccess.remove_absolute("%s/%s.save" % [SAVE_DIR, id])


# ------------------------------------------------------------------ hall of the fallen

func fallen_list() -> Array:
	if not FileAccess.file_exists(FALLEN_PATH):
		return []
	var f := FileAccess.open(FALLEN_PATH, FileAccess.READ)
	var v: Variant = f.get_var(false)
	return v if v is Array else []


func record_fallen(zone_name: String) -> void:
	var list := fallen_list()
	list.push_front({"name": hero_name, "cls": class_id, "level": int(stats.level), "zone": zone_name, "killer": last_killer,
		"difficulty": difficulty, "time": float(stats.time), "kills": int(stats.kills), "date": int(Time.get_unix_time_from_system())})
	list.resize(mini(list.size(), 100))
	var f := FileAccess.open(FALLEN_PATH, FileAccess.WRITE)
	if f:
		f.store_var(list, false)


# ------------------------------------------------------------------ statistics

const LIFETIME_PATH := "user://lifetime.save"
var lifetime := {}
var _life_loaded := false


func _life() -> Dictionary:
	if not _life_loaded:
		_life_loaded = true
		if FileAccess.file_exists(LIFETIME_PATH):
			var f := FileAccess.open(LIFETIME_PATH, FileAccess.READ)
			var v: Variant = f.get_var(false)
			if v is Dictionary:
				lifetime = v
	return lifetime


## Counts toward both this character and the lifetime totals.
func stat_add(key: String, n: float, sub := "") -> void:
	var l := _life()
	if sub == "":
		l[key] = float(l.get(key, 0.0)) + n
		stats[key] = float(stats.get(key, 0.0)) + n
		return
	var d: Dictionary = l.get(key, {})
	d[sub] = float(d.get(sub, 0.0)) + n
	l[key] = d
	var rd: Dictionary = stats.get(key, {})
	rd[sub] = float(rd.get(sub, 0.0)) + n
	stats[key] = rd


func stat_max(key: String, v: float) -> void:
	var l := _life()
	l[key] = maxf(float(l.get(key, 0.0)), v)


func save_lifetime() -> void:
	var f := FileAccess.open(LIFETIME_PATH, FileAccess.WRITE)
	if f:
		f.store_var(_life(), false)


# ------------------------------------------------------------------ updates

## Asks GitHub for the newest release. Nothing about the player is sent, and it can be switched off.
func check_update() -> void:
	var req := HTTPRequest.new()
	req.timeout = 8.0
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray):
		req.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			return
		var data: Variant = JSON.parse_string(body.get_string_from_utf8())
		if not data is Dictionary:
			return
		var tag := String(data.get("tag_name", "")).trim_prefix("v")
		if tag != "" and _newer(tag, VERSION):
			update_version = tag
			update_url = String(data.get("html_url", "https://github.com/%s/releases" % REPO))
			update_found.emit(update_version, update_url))
	req.request("https://api.github.com/repos/%s/releases/latest" % REPO, PackedStringArray(["User-Agent: AshenCrown", "Accept: application/vnd.github+json"]))


static func _newer(a: String, b: String) -> bool:
	var pa := a.split(".")
	var pb := b.split(".")
	for i in 3:
		var x := int(pa[i]) if i < pa.size() else 0
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y:
			return x > y
	return false
