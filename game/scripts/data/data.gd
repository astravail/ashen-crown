class_name Data
## Static game data: classes, upgrades, crown fragments, zones, enemies.

const CLASSES := {
	"knight": {
		"name": "Ashen Knight",
		"role": "Melee · Tank",
		"blurb": "Aldric's last bodyguard. The fire fused his armour to his skin, and he kept walking.",
		"resource": "Cinder",
		"resource_hint": "Builds as you strike and are struck.",
		"res_color": Color(1.0, 0.45, 0.12),
		"max_hp": 340.0,
		"speed": 225.0,
		"armor": 0.15,
		"ratings": {"Toughness": 5, "Damage": 3, "Range": 1, "Complexity": 2},
		"abilities": [
			{"id": "cleave", "name": "Cinder Cleave", "action": "attack_1", "cd": 0.42, "cost": 0.0, "desc": "A wide swing that sets enemies alight."},
			{"id": "rush", "name": "Shield Rush", "action": "attack_2", "cd": 4.0, "cost": 25.0, "desc": "Charge forward, stunning everything in your path."},
			{"id": "oath", "name": "Oathbound", "action": "skill_1", "cd": 12.0, "cost": 30.0, "desc": "Brace for 3 seconds. Take 60% less damage, then release what you blocked as fire."},
			{"id": "molten", "name": "Molten Armor", "action": "skill_2", "cd": 16.0, "cost": 40.0, "desc": "For 8 seconds, burn nearby enemies and anyone who strikes you."},
			{"id": "vanguard", "name": "Fallen Vanguard", "action": "ultimate", "cd": 1.0, "cost": 0.0, "desc": "Call the King's Guard back from the ash for 12 seconds."},
		],
	},
	"gravecaller": {
		"name": "Gravecaller",
		"role": "Minions · Control",
		"blurb": "A catacomb priest who learned to steal the dead back from the Ember King.",
		"resource": "Soul Embers",
		"resource_hint": "Gathered when enemies die nearby.",
		"res_color": Color(0.45, 0.85, 0.8),
		"max_hp": 250.0,
		"speed": 230.0,
		"armor": 0.0,
		"ratings": {"Toughness": 2, "Damage": 4, "Range": 4, "Complexity": 4},
		"abilities": [
			{"id": "lance", "name": "Bone Lance", "action": "attack_1", "cd": 0.5, "cost": 0.0, "desc": "A spear of bone that pierces every enemy in a line."},
			{"id": "raise", "name": "Raise Ashbound", "action": "attack_2", "cd": 0.5, "cost": 20.0, "desc": "Raise a skeletal warrior. Up to five serve at once."},
			{"id": "bloom", "name": "Grave Bloom", "action": "skill_1", "cd": 1.5, "cost": 15.0, "desc": "Detonate up to three corpses near the cursor."},
			{"id": "wither", "name": "Wither Mark", "action": "skill_2", "cd": 8.0, "cost": 20.0, "desc": "Curse an area. Marked enemies take 35% more damage and slow."},
			{"id": "titan", "name": "Ossuary Titan", "action": "ultimate", "cd": 1.0, "cost": 0.0, "desc": "Raise a giant of a thousand bones for 16 seconds."},
		],
	},
	"pyrewitch": {
		"name": "Pyrewitch",
		"role": "Ranged · Area",
		"blurb": "The academy burned with her inside it. She breathed the fire in and kept it.",
		"resource": "Heat",
		"resource_hint": "Spells add heat. More heat, more damage. Too much, and you burn.",
		"res_color": Color(1.0, 0.3, 0.18),
		"max_hp": 210.0,
		"speed": 235.0,
		"armor": 0.0,
		"ratings": {"Toughness": 1, "Damage": 5, "Range": 5, "Complexity": 4},
		"abilities": [
			{"id": "bolt", "name": "Ember Bolt", "action": "attack_1", "cd": 0.26, "cost": 0.0, "desc": "A fast bolt of fire that bursts on impact."},
			{"id": "storm", "name": "Firestorm", "action": "attack_2", "cd": 6.0, "cost": 0.0, "desc": "Call burning rain onto an area for 4 seconds."},
			{"id": "step", "name": "Flash Step", "action": "skill_1", "cd": 4.0, "cost": 0.0, "desc": "Teleport a short distance. The space you left explodes."},
			{"id": "smother", "name": "Smother", "action": "skill_2", "cd": 10.0, "cost": 0.0, "desc": "Encase enemies in hardened ash and vent 40 heat."},
			{"id": "phoenix", "name": "Phoenix Form", "action": "ultimate", "cd": 1.0, "cost": 0.0, "desc": "Become living flame for 9 seconds. Heat cannot hurt you."},
		],
	},
	"crownbearer": {
		"name": "Crownbearer",
		"role": "Unbound · Overpowered",
		"locked": true,
		"unlock_hint": "Reserved for those who have ended the Ember King's reign. Finish the whole story once, on any character, and the crown will answer to you.",
		"blurb": "The ash crown chose you. What once burned a kingdom now bends to your hand, and nothing in these lands can stand against it.",
		"resource": "Crown Fire",
		"resource_hint": "Never runs dry. Every ability is free.",
		"res_color": Color(1.0, 0.8, 0.25),
		"max_hp": 700.0,
		"speed": 260.0,
		"armor": 0.35,
		"ratings": {"Toughness": 5, "Damage": 5, "Range": 3, "Complexity": 1},
		"abilities": [
			{"id": "cleave", "name": "Sovereign Cleave", "action": "attack_1", "cd": 0.3, "cost": 0.0, "desc": "A crushing arc of crown fire."},
			{"id": "rush", "name": "Royal Charge", "action": "attack_2", "cd": 2.0, "cost": 0.0, "desc": "Charge forward and stun everything in your path."},
			{"id": "oath", "name": "Unbroken", "action": "skill_1", "cd": 6.0, "cost": 0.0, "desc": "Take far less damage, then release it as fire."},
			{"id": "molten", "name": "Crown Aura", "action": "skill_2", "cd": 8.0, "cost": 0.0, "desc": "Burn everything near you for 8 seconds."},
			{"id": "titan", "name": "Ossuary Titan", "action": "ultimate", "cd": 1.0, "cost": 0.0, "desc": "Raise a giant for 16 seconds."},
		],
	},
}

const HEAT_COST := {"bolt": 6.0, "storm": 26.0, "step": 16.0, "smother": -40.0}

# Upgrades offered on level-up. "cls" empty = any class.
const UPGRADES := [
	{"id": "vigor", "name": "Vigor", "tag": "Passive", "desc": "+20% maximum life.", "max": 5},
	{"id": "ferocity", "name": "Ferocity", "tag": "Passive", "desc": "+12% damage.", "max": 5},
	{"id": "alacrity", "name": "Alacrity", "tag": "Passive", "desc": "Cooldowns recover 10% faster.", "max": 3},
	{"id": "swiftness", "name": "Swiftness", "tag": "Passive", "desc": "+10% movement speed.", "max": 3},
	{"id": "precision", "name": "Precision", "tag": "Passive", "desc": "+6% critical strike chance.", "max": 4},
	{"id": "reach", "name": "Reach", "tag": "Passive", "desc": "+15% area of effect.", "max": 3},
	{"id": "leech", "name": "Bloodash", "tag": "Passive", "desc": "Each kill restores 1.5% of your life.", "max": 3},
	{"id": "ashborn", "name": "Ashborn", "tag": "Passive", "desc": "The ash meter fills 25% faster.", "max": 2},
	{"id": "flaskmaker", "name": "Deep Flask", "tag": "Passive", "desc": "Your potion recovers 3 seconds sooner and heals 15% more.", "max": 2},
	{"id": "second_wind", "name": "Second Wind", "tag": "Passive", "desc": "Regenerate 1% of your life per second.", "max": 3},

	{"id": "cleave_wide", "cls": "knight", "name": "Broad Arc", "tag": "Cinder Cleave", "desc": "Wider swing, 25% more damage.", "max": 1},
	{"id": "cleave_wave", "cls": "knight", "name": "Firebrand", "tag": "Cinder Cleave", "desc": "Every third swing sends a wave of fire forward.", "max": 1},
	{"id": "rush_quake", "cls": "knight", "name": "Crashing Halt", "tag": "Shield Rush", "desc": "The charge ends in a shockwave.", "max": 1},
	{"id": "rush_refund", "cls": "knight", "name": "Momentum", "tag": "Shield Rush", "desc": "Hitting three or more enemies resets the cooldown.", "max": 1},
	{"id": "oath_nova", "cls": "knight", "name": "Retribution", "tag": "Oathbound", "desc": "The release deals double the damage you blocked.", "max": 1},
	{"id": "oath_heal", "cls": "knight", "name": "Last Watch", "tag": "Oathbound", "desc": "Heal 15% of your life when the brace ends.", "max": 1},
	{"id": "molten_spread", "cls": "knight", "name": "Slag Tide", "tag": "Molten Armor", "desc": "Aura radius +60%. It burns twice as hot.", "max": 1},
	{"id": "molten_long", "cls": "knight", "name": "Forge Heart", "tag": "Molten Armor", "desc": "Lasts 50% longer and gives 15% armour.", "max": 1},

	{"id": "lance_split", "cls": "gravecaller", "name": "Splinter", "tag": "Bone Lance", "desc": "Splits into three shards on the first hit.", "max": 1},
	{"id": "lance_marrow", "cls": "gravecaller", "name": "Marrow", "tag": "Bone Lance", "desc": "40% more damage and faster flight.", "max": 1},
	{"id": "raise_legion", "cls": "gravecaller", "name": "Legion", "tag": "Raise Ashbound", "desc": "Command up to three more Ashbound.", "max": 1},
	{"id": "raise_burn", "cls": "gravecaller", "name": "Kindled Bones", "tag": "Raise Ashbound", "desc": "Ashbound hit harder and set enemies on fire.", "max": 1},
	{"id": "bloom_big", "cls": "gravecaller", "name": "Rot Garden", "tag": "Grave Bloom", "desc": "40% larger, 40% more damage.", "max": 1},
	{"id": "bloom_raise", "cls": "gravecaller", "name": "Second Grave", "tag": "Grave Bloom", "desc": "Each detonated corpse raises an Ashbound for free.", "max": 1},
	{"id": "mark_spread", "cls": "gravecaller", "name": "Contagion", "tag": "Wither Mark", "desc": "Marked enemies pass the mark on when they die.", "max": 1},
	{"id": "mark_drain", "cls": "gravecaller", "name": "Tithe", "tag": "Wither Mark", "desc": "Hitting marked enemies heals you for 3% of the damage.", "max": 1},

	{"id": "bolt_split", "cls": "pyrewitch", "name": "Scatter", "tag": "Ember Bolt", "desc": "Fires two extra bolts in a fan.", "max": 1},
	{"id": "bolt_pierce", "cls": "pyrewitch", "name": "Lance of Flame", "tag": "Ember Bolt", "desc": "Bolts pass through enemies.", "max": 1},
	{"id": "storm_big", "cls": "pyrewitch", "name": "Conflagration", "tag": "Firestorm", "desc": "40% larger area.", "max": 1},
	{"id": "storm_pull", "cls": "pyrewitch", "name": "Eye of the Pyre", "tag": "Firestorm", "desc": "Lasts 2 seconds longer and drags enemies inward.", "max": 1},
	{"id": "step_double", "cls": "pyrewitch", "name": "Afterimage", "tag": "Flash Step", "desc": "Holds two charges.", "max": 1},
	{"id": "step_vent", "cls": "pyrewitch", "name": "Exhale", "tag": "Flash Step", "desc": "Vents heat instead of building it.", "max": 1},
	{"id": "smother_shatter", "cls": "pyrewitch", "name": "Brittle", "tag": "Smother", "desc": "Encased enemies take double damage.", "max": 1},
	{"id": "heat_master", "cls": "pyrewitch", "name": "White Heat", "tag": "Heat", "desc": "Above 70 heat, spells deal 25% more damage.", "max": 1},
]

const FRAGMENTS := [
	{"id": "hunger", "name": "Fragment of Hunger", "boon": "+30% damage.", "bane": "-20% maximum life."},
	{"id": "haste", "name": "Fragment of Haste", "boon": "Cooldowns recover 25% faster.", "bane": "Take 15% more damage."},
	{"id": "iron", "name": "Fragment of Iron", "boon": "+40% maximum life and 10% armour.", "bane": "-15% movement speed."},
	{"id": "pyre", "name": "Fragment of the Pyre", "boon": "The ash meter fills twice as fast.", "bane": "Holding a full meter burns twice as hard."},
	{"id": "greed", "name": "Fragment of Greed", "boon": "+50% experience.", "bane": "Enemies have 25% more life."},
	{"id": "embers", "name": "Fragment of Embers", "boon": "Slain enemies explode for 25% of their life.", "bane": "Health globes heal half as much."},
	{"id": "ruin", "name": "Fragment of Ruin", "boon": "+15% critical chance, +50% critical damage.", "bane": "One fewer flask charge."},
	{"id": "thorns", "name": "Fragment of Thorns", "boon": "Melee attackers take 60% of their damage back.", "bane": "Life regeneration stops working."},
	{"id": "hollow", "name": "Fragment of the Hollow King", "boon": "Your ultimate lasts 50% longer.", "bane": "Dodge takes twice as long to recover."},
]

const ENEMIES := {
	"husk": {"name": "Husk", "hp": 46.0, "speed": 78.0, "dmg": 11.0, "radius": 15.0, "xp": 3, "range": 34.0, "windup": 0.42, "cd": 1.2},
	"hound": {"name": "Cinder Hound", "hp": 30.0, "speed": 165.0, "dmg": 12.0, "radius": 13.0, "xp": 3, "range": 170.0, "windup": 0.45, "cd": 2.2},
	"acolyte": {"name": "Pyre Acolyte", "hp": 38.0, "speed": 85.0, "dmg": 14.0, "radius": 14.0, "xp": 4, "range": 340.0, "windup": 0.6, "cd": 2.6},
	"brute": {"name": "Oathless", "hp": 210.0, "speed": 62.0, "dmg": 30.0, "radius": 24.0, "xp": 10, "range": 70.0, "windup": 0.85, "cd": 2.4},
	"bloater": {"name": "Bloater", "hp": 70.0, "speed": 62.0, "dmg": 26.0, "radius": 19.0, "xp": 5, "range": 40.0, "windup": 0.7, "cd": 1.0},
	"wraith": {"name": "Ash Wraith", "hp": 80.0, "speed": 120.0, "dmg": 18.0, "radius": 15.0, "xp": 6, "range": 44.0, "windup": 0.35, "cd": 1.6},
	"ember_king": {"name": "Aldric, the Ember King", "hp": 6500.0, "speed": 95.0, "dmg": 30.0, "radius": 40.0, "xp": 0, "range": 90.0, "windup": 0.8, "cd": 1.0},
}

## World-exclusive enemies. They borrow an archetype's behaviour and drawing (`arch`) but have their own
## name, tint and stat tweaks, and each one only lives in its own zone.
const VARIANTS := {
	"thornhusk": {"name": "Thornhusk", "arch": "husk", "tint": Color(0.75, 0.85, 0.6)},
	"black_wolf": {"name": "Black Wolf", "arch": "hound", "tint": Color(0.55, 0.55, 0.65), "spdm": 1.1},
	"hangman": {"name": "Hangman's Disciple", "arch": "acolyte", "tint": Color(0.85, 0.8, 0.7)},
	"root_crawler": {"name": "Root Crawler", "arch": "husk", "tint": Color(0.7, 0.55, 0.4), "hpm": 1.3, "emerge": true},
	"hollow_guard": {"name": "Hollow Guard", "arch": "husk", "tint": Color(0.8, 0.85, 1.0), "hpm": 1.3, "dmgm": 1.1},
	"keep_zealot": {"name": "Keep Zealot", "arch": "acolyte", "tint": Color(1.2, 0.7, 0.65)},
	"keep_hound": {"name": "Kennel Beast", "arch": "hound", "tint": Color(1.1, 0.8, 0.7)},
	"citizen": {"name": "Rotting Citizen", "arch": "husk", "tint": Color(0.9, 0.85, 0.8)},
	"gutter_hound": {"name": "Gutter Hound", "arch": "hound", "tint": Color(0.8, 0.9, 0.8)},
	"gilded_priest": {"name": "Gilded Priest", "arch": "acolyte", "tint": Color(1.4, 1.2, 0.7)},
	"plague_cart": {"name": "Plague Bearer", "arch": "bloater", "tint": Color(0.9, 1.1, 0.7)},
	"skeleton_warden": {"name": "Skeleton Warden", "arch": "husk", "tint": Color(1.4, 1.35, 1.2), "hpm": 0.9},
	"crypt_wraith": {"name": "Crypt Wraith", "arch": "wraith", "tint": Color(0.8, 1.1, 1.2)},
	"bone_brute": {"name": "Bone Colossus", "arch": "brute", "tint": Color(1.3, 1.25, 1.1)},
	"bone_heap": {"name": "Bone Heap", "arch": "husk", "tint": Color(1.5, 1.4, 1.2), "hpm": 1.2, "emerge": true},
	"mire_husk": {"name": "Mire Husk", "arch": "husk", "tint": Color(0.6, 0.8, 0.55)},
	"bog_bloater": {"name": "Bog Bloater", "arch": "bloater", "tint": Color(0.7, 1.0, 0.5)},
	"leech_hound": {"name": "Leech Hound", "arch": "hound", "tint": Color(0.6, 0.85, 0.6)},
	"mire_crawler": {"name": "Mire Crawler", "arch": "hound", "tint": Color(0.55, 0.7, 0.5), "emerge": true, "hpm": 1.2},
	"pilgrim": {"name": "Drowned Pilgrim", "arch": "husk", "tint": Color(0.6, 0.85, 1.0)},
	"bell_wraith": {"name": "Bell Wraith", "arch": "wraith", "tint": Color(0.6, 0.9, 1.3)},
	"tide_bloater": {"name": "Tide Bloater", "arch": "bloater", "tint": Color(0.6, 0.9, 1.1)},
	"drowned_acolyte": {"name": "Chapel Drowned", "arch": "acolyte", "tint": Color(0.6, 0.85, 1.1)},
	"miner": {"name": "Hollow Miner", "arch": "husk", "tint": Color(1.0, 0.85, 0.6), "dmgm": 1.15},
	"pit_hound": {"name": "Pit Hound", "arch": "hound", "tint": Color(1.0, 0.8, 0.65)},
	"cave_brute": {"name": "Cave Brute", "arch": "brute", "tint": Color(0.9, 0.8, 0.7)},
	"rock_husk": {"name": "Stone Husk", "arch": "husk", "tint": Color(0.85, 0.85, 0.9), "hpm": 1.5, "spdm": 0.85, "emerge": true},
	"magma_husk": {"name": "Magma Husk", "arch": "husk", "tint": Color(1.6, 0.8, 0.5)},
	"slag_brute": {"name": "Slag Brute", "arch": "brute", "tint": Color(1.5, 0.8, 0.5)},
	"deep_wraith": {"name": "Deep Wraith", "arch": "wraith", "tint": Color(1.5, 0.9, 0.6)},
	"deep_bloater": {"name": "Magma Bloater", "arch": "bloater", "tint": Color(1.5, 0.9, 0.5)},
	"cinder_hound": {"name": "Cinder Hound", "arch": "hound", "tint": Color(1.4, 0.8, 0.6)},
	"scarecrow": {"name": "Scarecrow", "arch": "husk", "tint": Color(1.2, 1.0, 0.7)},
	"ash_acolyte": {"name": "Ash Priest", "arch": "acolyte", "tint": Color(1.1, 0.9, 0.85)},
	"ash_revenant": {"name": "Ash Revenant", "arch": "husk", "tint": Color(0.9, 0.85, 0.85), "emerge": true, "hpm": 1.3},
	"courtier": {"name": "Court Courtier", "arch": "acolyte", "tint": Color(1.1, 0.7, 1.2)},
	"obsidian_guard": {"name": "Obsidian Guard", "arch": "brute", "tint": Color(0.7, 0.65, 0.85), "hpm": 1.2},
	"court_wraith": {"name": "Court Phantom", "arch": "wraith", "tint": Color(1.1, 0.7, 1.3)},
	"court_hound": {"name": "Gilded Hound", "arch": "hound", "tint": Color(1.2, 0.9, 1.1)},
	"imp": {"name": "Imp", "arch": "hound", "tint": Color(1.6, 0.6, 0.5), "hpm": 0.8, "spdm": 1.15},
	"pyre_wraith": {"name": "Pyre Wraith", "arch": "wraith", "tint": Color(1.7, 0.8, 0.5)},
	"demon_brute": {"name": "Demon Brute", "arch": "brute", "tint": Color(1.5, 0.6, 0.5)},
	"pyre_acolyte": {"name": "Flame Cultist", "arch": "acolyte", "tint": Color(1.6, 0.8, 0.6)},
	"ember_wraith": {"name": "Ember Wraith", "arch": "wraith", "tint": Color(1.8, 0.9, 0.5)},
	"throne_guard": {"name": "Throne Guard", "arch": "brute", "tint": Color(1.4, 0.7, 0.55), "hpm": 1.25},
	"flame_acolyte": {"name": "Throne Priest", "arch": "acolyte", "tint": Color(1.7, 0.7, 0.5)},
	"ember_hound": {"name": "Ember Hound", "arch": "hound", "tint": Color(1.8, 0.7, 0.4)},
	"cellar_ghoul": {"name": "Cellar Ghoul", "arch": "husk", "tint": Color(0.95, 0.9, 0.8)},
	"gravedigger_ghoul": {"name": "Grave Warden", "arch": "husk", "tint": Color(0.8, 0.9, 0.75)},
}


static func enemy_def(k: String) -> Dictionary:
	if ENEMIES.has(k):
		return ENEMIES[k]
	var v: Dictionary = VARIANTS[k]
	var d: Dictionary = (ENEMIES[v.arch] as Dictionary).duplicate()
	d.name = v.name
	d.arch = v.arch
	d.tint = v.get("tint", Color.WHITE)
	d.hp = float(d.hp) * float(v.get("hpm", 1.0))
	d.dmg = float(d.dmg) * float(v.get("dmgm", 1.0))
	d.speed = float(d.speed) * float(v.get("spdm", 1.0))
	d.emerge = v.get("emerge", false)
	return d


## The game is meant to be slow and grindy. Every pacing knob lives here.
const GRIND := {
	"xp_mult": 0.55,        # xp per kill
	"xp_zone": 0.35,        # extra xp per zone depth
	"drop_chance": 0.035,   # item chance per ordinary kill
	"gold_mult": 0.7,
	"enemy_hp": 1.35,       # baseline life of every enemy
	"pack_size": 1.0,
	"repair_mult": 1.0,
}

const MAX_LEVEL := 60
## The level at which each ability (primary, secondary, skill 1, skill 2, ultimate) becomes available.
const ABILITY_UNLOCK := [1, 3, 6, 10, 15]
## Each prestige rank is worth this much damage and life, and this much gold and magic find, up to rank 10.
const PRESTIGE_MAX_RANKS := 10


static func ability_unlock(i: int, cls: String) -> int:
	if cls == "crownbearer":
		return 1
	return int(ABILITY_UNLOCK[clampi(i, 0, 4)])


static func xp_for_level(level: int) -> float:
	return 24.0 + 16.0 * level + 1.2 * level * level

const LAST_ZONE := 11

const ACTS := [
	{"name": "Act I", "title": "The Ashen Road", "zones": [0, 1], "line": "The road to the keep is lined with the hanged."},
	{"name": "Act II", "title": "The Buried City", "zones": [2, 3], "line": "Valdremor buried its dead. The dead dug out."},
	{"name": "Act III", "title": "The Rot", "zones": [4, 5], "line": "The ash settles here, and rots."},
	{"name": "Act IV", "title": "The Deep Works", "zones": [6, 7], "line": "The miners dug too deep, and something answered."},
	{"name": "Act V", "title": "The Burning Court", "zones": [8, 9], "line": "Where the court still feasts on cinders."},
	{"name": "Act VI", "title": "The Pyre", "zones": [10, 11], "line": "Beneath the world, the crown was forged."},
]

static func act_of(zone_idx: int) -> int:
	for i in ACTS.size():
		if zone_idx in ACTS[i].zones:
			return i
	return 0

const ZONES := [
	{
		"id": "blackwood", "name": "The Blackwood", "line": "The trees remember the hangings.", "act": 0,
		"style": "open", "size": Vector2i(150, 150), "ambient": "amb_forest", "prop_density": 2.4,
		"ground_a": Color(0.31, 0.33, 0.26), "ground_b": Color(0.14, 0.15, 0.12), "vein": Color(0.7, 1.6, 1.1), "vein_amt": 0.12,
		"wall": Color(0.02, 0.03, 0.025), "pattern": 4.0, "modulate": Color(0.5, 0.53, 0.51),
		"pool": {"imp": 4, "pyre_wraith": 3, "demon_brute": 2, "pyre_acolyte": 3}, "packs": 46, "hp_mult": 1.0, "dmg_mult": 1.1,
		"emerge": {"kind": "root_crawler", "from": ["stump", "rock", "grave"], "sites": 7},
		"props": ["pine", "pine", "pine", "dead_tree", "hanged", "stump", "rock", "bones"],
		"champion": {"kind": "black_wolf", "name": "Old Blackfang", "scale": 2.2},
	},
	{
		"id": "keep", "name": "The Hollow Keep", "line": "Aldric's hall. Only the guard remains.", "act": 0,
		"style": "dungeon", "size": Vector2i(150, 150), "ambient": "amb_crypt",
		"ground_a": Color(0.46, 0.44, 0.47), "ground_b": Color(0.25, 0.24, 0.27), "vein": Color(2.6, 0.9, 0.25), "vein_amt": 0.35,
		"wall": Color(0.04, 0.04, 0.05), "pattern": 1.0, "modulate": Color(0.44, 0.44, 0.48),
		"pool": {"hollow_guard": 4, "brute": 2, "keep_zealot": 3, "keep_hound": 1}, "packs": 50, "hp_mult": 1.55, "dmg_mult": 1.35,
		"props": ["pillar", "pillar", "brazier", "banner", "rubble", "impaled"],
		"champion": {"kind": "hollow_guard", "name": "Ser Hollis, Oathless", "scale": 1.6},
	},
	{
		"id": "quarter", "name": "The Sunken Quarter", "line": "The streets are still there. The people are not.", "act": 1,
		"style": "dungeon", "size": Vector2i(150, 150), "ambient": "amb_crypt", "prop_density": 1.6,
		"ground_a": Color(0.36, 0.34, 0.33), "ground_b": Color(0.19, 0.18, 0.18), "vein": Color(1.2, 1.2, 2.2), "vein_amt": 0.22,
		"wall": Color(0.03, 0.03, 0.035), "pattern": 1.0, "modulate": Color(0.42, 0.43, 0.47),
		"pool": {"citizen": 4, "gilded_priest": 3, "gutter_hound": 2, "plague_cart": 1}, "packs": 52, "hp_mult": 1.9, "dmg_mult": 1.5,
		"props": ["rubble", "barrel", "crate", "banner", "candles", "pillar"],
		"champion": {"kind": "gilded_priest", "name": "The Gilded Magistrate", "scale": 1.8},
	},
	{
		"id": "catacombs", "name": "The Catacombs", "line": "Valdremor buried its dead here. They did not stay buried.", "act": 1,
		"style": "dungeon", "size": Vector2i(150, 150), "ambient": "amb_crypt", "prop_density": 1.4,
		"ground_a": Color(0.40, 0.38, 0.34), "ground_b": Color(0.2, 0.19, 0.17), "vein": Color(0.5, 1.6, 1.3), "vein_amt": 0.3,
		"wall": Color(0.03, 0.03, 0.03), "pattern": 5.0, "modulate": Color(0.38, 0.38, 0.4),
		"pool": {"skeleton_warden": 4, "crypt_wraith": 3, "bone_brute": 1, "bloater": 1}, "packs": 54, "hp_mult": 2.3, "dmg_mult": 1.65,
		"emerge": {"kind": "bone_heap", "from": ["skull_pile", "bones", "sarcophagus"], "sites": 8},
		"props": ["skull_pile", "sarcophagus", "bones", "bones", "candles", "pillar"],
		"champion": {"kind": "crypt_wraith", "name": "The Weeping Abbess", "scale": 2.0},
	},
	{
		"id": "marsh", "name": "Greyrot Marsh", "line": "The ash settles here, and rots.", "act": 2,
		"style": "open", "size": Vector2i(160, 160), "ambient": "amb_marsh", "prop_density": 1.4,
		"ground_a": Color(0.38, 0.42, 0.36), "ground_b": Color(0.19, 0.21, 0.19), "vein": Color(1.4, 1.9, 0.5), "vein_amt": 0.4,
		"wall": Color(0.03, 0.045, 0.04), "pattern": 2.0, "modulate": Color(0.44, 0.48, 0.45),
		"pool": {"bog_bloater": 3, "mire_husk": 4, "leech_hound": 2, "hangman": 2}, "packs": 52, "hp_mult": 2.7, "dmg_mult": 1.8,
		"emerge": {"kind": "mire_crawler", "from": ["reeds", "grave", "rock"], "sites": 8},
		"props": ["dead_tree", "dead_tree", "reeds", "hanged", "rock", "grave"],
		"champion": {"kind": "bog_bloater", "name": "The Drowned Mother", "scale": 2.2},
	},
	{
		"id": "chapel", "name": "The Drowned Chapel", "line": "The bells still ring under the water.", "act": 2,
		"style": "dungeon", "size": Vector2i(150, 150), "ambient": "amb_marsh", "prop_density": 1.5,
		"ground_a": Color(0.34, 0.40, 0.38), "ground_b": Color(0.16, 0.2, 0.2), "vein": Color(0.5, 1.9, 1.7), "vein_amt": 0.35,
		"wall": Color(0.02, 0.035, 0.035), "pattern": 5.0, "modulate": Color(0.38, 0.45, 0.46),
		"pool": {"bell_wraith": 3, "tide_bloater": 2, "pilgrim": 3, "drowned_acolyte": 2}, "packs": 52, "hp_mult": 3.1, "dmg_mult": 1.95,
		"props": ["candles", "sarcophagus", "pillar", "grave", "bones", "banner"],
		"champion": {"kind": "drowned_acolyte", "name": "Brother Mire", "scale": 1.9},
	},
	{
		"id": "mine_upper", "name": "Ashmine, Upper Galleries", "line": "The timbers groan. Something is still working down there.", "act": 3,
		"style": "dungeon", "size": Vector2i(150, 150), "ambient": "amb_crypt", "prop_density": 1.8,
		"ground_a": Color(0.34, 0.28, 0.22), "ground_b": Color(0.16, 0.12, 0.09), "vein": Color(2.4, 1.2, 0.3), "vein_amt": 0.45,
		"wall": Color(0.03, 0.025, 0.02), "pattern": 3.0, "modulate": Color(0.45, 0.4, 0.36),
		"pool": {"miner": 5, "cave_brute": 2, "pit_hound": 2, "bloater": 1}, "packs": 54, "hp_mult": 3.5, "dmg_mult": 2.1,
		"emerge": {"kind": "rock_husk", "from": ["rock", "rubble"], "sites": 9},
		"props": ["rubble", "rock", "crate", "barrel", "brazier", "bones"],
		"champion": {"kind": "cave_brute", "name": "The Foreman", "scale": 1.7},
	},
	{
		"id": "mine_deep", "name": "Ashmine, the Depths", "line": "The air is warm. It should not be warm.", "act": 3,
		"style": "dungeon", "size": Vector2i(150, 150), "ambient": "amb_hell", "prop_density": 1.6,
		"ground_a": Color(0.30, 0.22, 0.19), "ground_b": Color(0.14, 0.09, 0.08), "vein": Color(3.2, 1.0, 0.2), "vein_amt": 0.6,
		"wall": Color(0.03, 0.015, 0.012), "pattern": 3.0, "modulate": Color(0.5, 0.42, 0.4),
		"pool": {"deep_wraith": 3, "slag_brute": 2, "deep_bloater": 2, "magma_husk": 3}, "packs": 56, "hp_mult": 4.0, "dmg_mult": 2.3,
		"emerge": {"kind": "rock_husk", "from": ["rock", "rubble", "spike"], "sites": 7},
		"props": ["rubble", "spike", "brazier", "skull_pile", "chain", "rock"],
		"champion": {"kind": "deep_bloater", "name": "The Bottomless", "scale": 2.3},
	},
	{
		"id": "fields", "name": "The Cinder Fields", "line": "Nothing grows. Nothing has grown in years.", "act": 4,
		"style": "open", "size": Vector2i(160, 160), "ambient": "amb_hell", "prop_density": 1.2,
		"ground_a": Color(0.33, 0.27, 0.25), "ground_b": Color(0.15, 0.11, 0.1), "vein": Color(3.0, 0.9, 0.2), "vein_amt": 0.55,
		"wall": Color(0.03, 0.02, 0.02), "pattern": 0.0, "modulate": Color(0.5, 0.44, 0.43),
		"pool": {"cinder_hound": 4, "scarecrow": 3, "ash_acolyte": 3, "ash_revenant": 1}, "packs": 54, "hp_mult": 4.6, "dmg_mult": 2.5,
		"emerge": {"kind": "ash_revenant", "from": ["rock", "bones", "spike"], "sites": 7},
		"props": ["dead_tree", "spike", "rock", "impaled", "bones", "chain"],
		"champion": {"kind": "cinder_hound", "name": "Cinder Alpha", "scale": 2.4},
	},
	{
		"id": "court", "name": "The Obsidian Court", "line": "The court still feasts. You are the course.", "act": 4,
		"style": "dungeon", "size": Vector2i(150, 150), "ambient": "amb_hell", "prop_density": 1.4,
		"ground_a": Color(0.22, 0.2, 0.24), "ground_b": Color(0.1, 0.09, 0.12), "vein": Color(3.4, 0.7, 0.4), "vein_amt": 0.6,
		"wall": Color(0.015, 0.012, 0.02), "pattern": 1.0, "modulate": Color(0.42, 0.38, 0.46),
		"pool": {"courtier": 4, "court_wraith": 3, "obsidian_guard": 2, "court_hound": 2}, "packs": 56, "hp_mult": 5.2, "dmg_mult": 2.8,
		"props": ["pillar", "brazier", "banner", "impaled", "skull_pile", "candles"],
		"champion": {"kind": "court_wraith", "name": "The Obsidian Queen", "scale": 2.1},
	},
	{
		"id": "pyre", "name": "The Infernal Pyre", "line": "Beneath the world, in the fires of hell, the crown was forged.", "act": 5,
		"style": "open", "size": Vector2i(150, 150), "ambient": "amb_hell",
		"ground_a": Color(0.30, 0.2, 0.18), "ground_b": Color(0.13, 0.07, 0.07), "vein": Color(4.0, 0.8, 0.15), "vein_amt": 0.9,
		"wall": Color(0.03, 0.008, 0.008), "pattern": 3.0, "modulate": Color(0.5, 0.4, 0.4),
		"pool": {"wraith": 3, "acolyte": 3, "brute": 2, "hound": 2}, "packs": 52, "hp_mult": 5.9, "dmg_mult": 3.1,
		"props": ["spike", "spike", "impaled", "chain", "brazier", "skull_pile"],
		"champion": {"kind": "demon_brute", "name": "Warden of Cinders", "scale": 1.9},
	},
	{
		"id": "throne", "name": "The Throne of Ash", "line": "He has been waiting. He is very tired.", "act": 5,
		"style": "open", "size": Vector2i(130, 130), "ambient": "amb_hell",
		"ground_a": Color(0.28, 0.18, 0.16), "ground_b": Color(0.12, 0.06, 0.06), "vein": Color(4.0, 0.8, 0.15), "vein_amt": 1.0,
		"wall": Color(0.03, 0.008, 0.008), "pattern": 3.0, "modulate": Color(0.5, 0.38, 0.38),
		"pool": {"ember_wraith": 3, "flame_acolyte": 3, "throne_guard": 2, "ember_hound": 2}, "packs": 40, "hp_mult": 6.6, "dmg_mult": 3.4,
		"props": ["spike", "impaled", "chain", "brazier", "skull_pile"],
		"champion": {},
	},
	# Interiors: houses and mines you walk into. Not part of the main route.
	{
		"id": "cellar", "name": "Maren's Cellar", "line": "Someone has been keeping things down here.", "interior": true, "parent": -1, "act": 0,
		"style": "dungeon", "size": Vector2i(64, 64), "ambient": "amb_crypt", "prop_density": 2.0, "chests": 4, "tier": 0,
		"ground_a": Color(0.34, 0.3, 0.26), "ground_b": Color(0.16, 0.14, 0.12), "vein": Color(1.8, 0.8, 0.3), "vein_amt": 0.1,
		"wall": Color(0.03, 0.025, 0.02), "pattern": 1.0, "modulate": Color(0.46, 0.42, 0.4),
		"pool": {"cellar_ghoul": 3, "thornhusk": 1}, "packs": 6, "hp_mult": 1.0, "dmg_mult": 1.0,
		"props": ["barrel", "crate", "candles", "bones", "rubble"], "champion": {},
	},
	{
		"id": "old_mine", "name": "The Collapsed Mine", "line": "The shaft was sealed for a reason.", "interior": true, "parent": 0, "act": 0,
		"style": "dungeon", "size": Vector2i(90, 90), "ambient": "amb_crypt", "prop_density": 1.8, "chests": 6, "tier": 1,
		"ground_a": Color(0.34, 0.28, 0.22), "ground_b": Color(0.16, 0.12, 0.09), "vein": Color(2.4, 1.2, 0.3), "vein_amt": 0.4,
		"wall": Color(0.03, 0.025, 0.02), "pattern": 3.0, "modulate": Color(0.44, 0.4, 0.36),
		"pool": {"miner": 4, "pit_hound": 2, "cave_brute": 1, "root_crawler": 2}, "packs": 16, "hp_mult": 1.4, "dmg_mult": 1.25,
		"emerge": {"kind": "rock_husk", "from": ["rock", "rubble"], "sites": 5},
		"props": ["rubble", "rock", "crate", "barrel", "brazier", "bones"], "champion": {},
	},
	{
		"id": "gravedigger", "name": "The Gravedigger's Hut", "line": "He dug too many holes.", "interior": true, "parent": 4, "act": 2,
		"style": "dungeon", "size": Vector2i(80, 80), "ambient": "amb_marsh", "prop_density": 1.6, "chests": 6, "tier": 4,
		"ground_a": Color(0.34, 0.36, 0.32), "ground_b": Color(0.17, 0.19, 0.17), "vein": Color(1.4, 1.9, 0.5), "vein_amt": 0.35,
		"wall": Color(0.03, 0.04, 0.035), "pattern": 2.0, "modulate": Color(0.42, 0.46, 0.44),
		"pool": {"gravedigger_ghoul": 3, "bog_bloater": 2, "crypt_wraith": 2}, "packs": 14, "hp_mult": 2.8, "dmg_mult": 1.85,
		"props": ["grave", "bones", "candles", "skull_pile", "barrel"], "champion": {},
	},
]

const VILLAGE := {
	"id": "village", "name": "Cinderfall", "line": "A few fires. A few of the living.",
	"style": "village", "size": Vector2i(78, 64), "ambient": "amb_forest",
	"ground_a": Color(0.36, 0.31, 0.25), "ground_b": Color(0.17, 0.14, 0.12), "vein": Color(1.8, 0.8, 0.3), "vein_amt": 0.06,
	"wall": Color(0.02, 0.02, 0.02), "pattern": 0.0, "modulate": Color(0.5, 0.45, 0.43),
	"pool": {}, "packs": 0, "hp_mult": 1.0, "dmg_mult": 1.0, "props": [], "champion": {},
}

## The story, in order. Each chapter hunts the holder of one fragment of the crown, and each needs the one before it.
## Chapter 0 happens in the village itself: Maren's cellar.
const STORY := [
	{"zone": 12, "type": "chest", "title": "The Cellar Door", "desc": "Maren's cellar has been broken into from below. Fetch the Warden's Ledger from the reliquary chest.",
		"say": "My cellar was sealed for twenty years. Last night something knocked from inside. The Warden's Ledger is down there: the only record of how the crown was forged. Bring it to me."},
	{"zone": 0, "title": "The Hound of the Road", "desc": "The Ledger names who carried the first shard out of the keep: Aldric's hound, Blackfang.",
		"say": "The Ledger is clear. Aldric's favourite hound carried the first shard down the road before the keep fell. It still guards it. The Blackwood has not forgiven anyone since."},
	{"zone": 1, "title": "The Captain Who Stayed", "desc": "Ser Hollis held the keep gate and never left. He bears the second shard.",
		"say": "Ser Hollis swore he would hold the gate until the king returned. The king did return. Hollis is still holding it. End his watch and take what he guards."},
	{"zone": 2, "title": "The Man Who Sold the Gates", "desc": "The Gilded Magistrate sold Valdremor's gate keys for gold. His shard is the third.",
		"say": "Someone opened the city to the fire. The Ledger names the Magistrate, who counted his coin while the city burned. He is still counting, down in the Sunken Quarter."},
	{"zone": 3, "title": "The Abbess Who Prayed", "desc": "The Weeping Abbess binds the dead to the crown with her prayers. Silence her and the fourth shard is yours.",
		"say": "Her prayers keep the dead walking. She meant them as comfort, and the crown made them a leash. Go down into the Catacombs and end the song."},
	{"zone": 4, "title": "The Mother in the Mire", "desc": "The Drowned Mother lost her children to the fire and took the fifth shard into the marsh.",
		"say": "A mother carried her children into the water to save them from the fire. The water kept them. Something in the marsh is still carrying them. Be gentle, if you can. You cannot."},
	{"zone": 5, "title": "The Last Blessing", "desc": "Brother Mire blessed the coronation. The sixth shard rings in his drowned chapel.",
		"say": "Brother Mire blessed the crown on Aldric's head. He has been ringing the chapel bell ever since, in case someone forgives him. No one will."},
	{"zone": 6, "title": "What the Miners Dug", "desc": "The Foreman dug too deep at Aldric's order, searching for forge-stone. The seventh shard is in Ashmine.",
		"say": "The king wanted forge-stone, hotter than anything on the surface. His foreman dug until the rock answered. Go into Ashmine. Bring your own light."},
	{"zone": 7, "title": "The Bottom of the Shaft", "desc": "Whatever answered the Foreman lies at the bottom of the depths, wearing the eighth shard.",
		"say": "The Foreman was only the first. Whatever he woke is below him, and it has the eighth shard. Do not look straight at the glow."},
	{"zone": 8, "title": "The Pack Master", "desc": "Cinder Alpha leads the hounds of the Burning Court across the Cinder Fields. The ninth shard hangs from its collar.",
		"say": "The Court hunts on the Cinder Fields. Their pack master wears the ninth shard on its collar. Kill the leader and the pack scatters."},
	{"zone": 9, "title": "The Queen of Glass", "desc": "Aldric's queen sits in the Obsidian Court, fused to her throne. The tenth shard is in her crown.",
		"say": "Aldric's queen would not leave him. The fire made her glass, and she still receives guests. The tenth shard is in her crown. Do not bow."},
	{"zone": 10, "title": "The Warden of the Forge", "desc": "The Warden of Cinders guards the stair to the throne. The last shard is his.",
		"say": "Below the court there is a stair, and on the stair, the Warden. He keeps the last shard, and the way to the throne. Take both."},
	{"zone": 11, "type": "boss", "title": "The Ember King", "desc": "Every shard is yours. Walk the Throne of Ash and end Aldric, or wear the crown yourself.",
		"say": "You carry all of them now. Every shard is warm against you, and the crown is calling its own back. Go to the throne. Whatever you choose, make it count."},
]


## Quests are handed out by the Elder. Bosses only exist while their quest is active.
## type: kill (any enemy in the zone), chest, champion (the zone's boss), boss (Ember King).
static var QUESTS: Array = _build_quests()

static func _build_quests() -> Array:
	var out: Array = []
	var prev := ""
	for i in STORY.size():
		var st: Dictionary = STORY[i]
		var z: int = st.zone
		var id := "story_%d" % i
		var type: String = st.get("type", "champion")
		var sc := 1.0 + 0.7 * maxi(z, 0) if z <= LAST_ZONE else 1.0
		out.append({"id": id, "story": true, "chapter": i, "zone": z, "type": type, "goal": 1, "title": st.title, "desc": st.desc, "say": st.say,
			"req": prev, "gold": int(180 * sc), "xp": int(60 * (1.0 + 0.8 * maxi(z, 0))), "min_r": 2 if i > 0 else 1, "slot": "weapon"})
		prev = id
	# Side bounties for each zone. They open once the road to the zone is open.
	for z in LAST_ZONE + 1:
		var zn: Dictionary = ZONES[z]
		var sc2 := 1.0 + 0.6 * z
		out.append({"id": "%s_cull" % zn.id, "zone": z, "type": "kill", "goal": 28 + 4 * z, "title": "Cull: %s" % zn.name,
			"desc": "Cut down %d of the dead in %s." % [28 + 4 * z, zn.name], "gold": int(90 * sc2), "xp": int(20 * (1.0 + 0.8 * z)), "min_r": 0, "req": ""})
		out.append({"id": "%s_chests" % zn.id, "zone": z, "type": "chest", "goal": 3 + z / 4, "title": "Plunder: %s" % zn.name,
			"desc": "Open %d chests in %s." % [3 + z / 4, zn.name], "gold": int(70 * sc2), "xp": int(15 * (1.0 + 0.8 * z)), "min_r": 1, "req": ""})
		out.append({"id": "%s_elites" % zn.id, "zone": z, "type": "elite", "goal": 3 + z / 3, "title": "Marked Ones: %s" % zn.name,
			"desc": "Slay %d elite monsters in %s." % [3 + z / 3, zn.name], "gold": int(110 * sc2), "xp": int(30 * (1.0 + 0.8 * z)), "min_r": 2, "req": ""})
	return out

static func quest(id: String) -> Dictionary:
	for q in QUESTS:
		if q.id == id:
			return q
	return {}


## Skill tree: you start with nothing and earn one point per level. A node needs 2 points spent
## in its column for every tier above the first, so each column is a path, not a menu.
const TREE_COLS := ["Offence", "Resilience", "Mastery", "Utility"]
const TREE := {
	"ferocity": [0, 0], "precision": [0, 1], "reach": [0, 2],
	"vigor": [1, 0], "second_wind": [1, 1], "flaskmaker": [1, 2],
	"swiftness": [3, 0], "alacrity": [3, 1], "ashborn": [3, 2], "leech": [3, 3],
	"cleave_wide": [2, 0], "cleave_wave": [2, 0], "rush_quake": [2, 1], "rush_refund": [2, 1],
	"oath_nova": [2, 2], "oath_heal": [2, 2], "molten_spread": [2, 3], "molten_long": [2, 3],
	"lance_split": [2, 0], "lance_marrow": [2, 0], "raise_legion": [2, 1], "raise_burn": [2, 1],
	"bloom_big": [2, 2], "bloom_raise": [2, 2], "mark_spread": [2, 3], "mark_drain": [2, 3],
	"bolt_split": [2, 0], "bolt_pierce": [2, 0], "storm_big": [2, 1], "storm_pull": [2, 1],
	"step_double": [2, 2], "step_vent": [2, 2], "smother_shatter": [2, 3], "heat_master": [2, 3],
}


static func tree_nodes(col: int, cls: String) -> Array:
	var out: Array = []
	for u in UPGRADES:
		if not TREE.has(u.id) or int(TREE[u.id][0]) != col:
			continue
		var c: String = u.get("cls", "")
		if c != "" and c != cls:
			continue
		var d: Dictionary = (u as Dictionary).duplicate()
		d.tier = int(TREE[u.id][1])
		out.append(d)
	out.sort_custom(func(a, b): return a.tier < b.tier)
	return out


static func roman(n: int) -> String:
	return ["0", "I", "II", "III", "IV", "V"][clampi(n, 0, 5)]
