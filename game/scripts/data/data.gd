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
	{"id": "flaskmaker", "name": "Deep Flask", "tag": "Passive", "desc": "+1 flask charge. Flasks heal 15% more.", "max": 2},
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

const ZONES := [
	{
		"id": "blackwood", "name": "The Blackwood", "line": "The trees remember the hangings.",
		"style": "open", "size": Vector2i(150, 150), "ambient": "amb_forest", "prop_density": 2.4,
		"ground_a": Color(0.31, 0.33, 0.26), "ground_b": Color(0.14, 0.15, 0.12), "vein": Color(0.7, 1.6, 1.1), "vein_amt": 0.12,
		"wall": Color(0.02, 0.03, 0.025), "pattern": 4.0, "modulate": Color(0.5, 0.53, 0.51),
		"pool": {"husk": 5, "hound": 4, "acolyte": 1}, "packs": 46, "hp_mult": 1.0, "dmg_mult": 1.1,
		"props": ["pine", "pine", "pine", "dead_tree", "hanged", "stump", "rock", "bones"],
		"champion": {"kind": "hound", "name": "Old Blackfang", "scale": 2.2},
	},
	{
		"id": "keep", "name": "The Hollow Keep", "line": "Aldric's hall. Only the guard remains.",
		"style": "dungeon", "size": Vector2i(150, 150), "ambient": "amb_crypt",
		"ground_a": Color(0.46, 0.44, 0.47), "ground_b": Color(0.25, 0.24, 0.27), "vein": Color(2.6, 0.9, 0.25), "vein_amt": 0.35,
		"wall": Color(0.04, 0.04, 0.05), "pattern": 1.0, "modulate": Color(0.44, 0.44, 0.48),
		"pool": {"husk": 4, "brute": 2, "acolyte": 3, "hound": 1}, "packs": 50, "hp_mult": 1.55, "dmg_mult": 1.35,
		"props": ["pillar", "pillar", "brazier", "banner", "rubble", "impaled"],
		"champion": {"kind": "brute", "name": "Ser Hollis, Oathless", "scale": 1.6},
	},
	{
		"id": "catacombs", "name": "The Catacombs", "line": "Valdremor buried its dead here. They did not stay buried.",
		"style": "dungeon", "size": Vector2i(150, 150), "ambient": "amb_crypt", "prop_density": 1.4,
		"ground_a": Color(0.40, 0.38, 0.34), "ground_b": Color(0.2, 0.19, 0.17), "vein": Color(0.5, 1.6, 1.3), "vein_amt": 0.3,
		"wall": Color(0.03, 0.03, 0.03), "pattern": 5.0, "modulate": Color(0.38, 0.38, 0.4),
		"pool": {"husk": 4, "wraith": 3, "brute": 1, "bloater": 1}, "packs": 54, "hp_mult": 1.9, "dmg_mult": 1.55,
		"props": ["skull_pile", "sarcophagus", "bones", "bones", "candles", "pillar"],
		"champion": {"kind": "wraith", "name": "The Weeping Abbess", "scale": 2.0},
	},
	{
		"id": "marsh", "name": "Greyrot Marsh", "line": "The ash settles here, and rots.",
		"style": "open", "size": Vector2i(160, 160), "ambient": "amb_marsh", "prop_density": 1.4,
		"ground_a": Color(0.38, 0.42, 0.36), "ground_b": Color(0.19, 0.21, 0.19), "vein": Color(1.4, 1.9, 0.5), "vein_amt": 0.4,
		"wall": Color(0.03, 0.045, 0.04), "pattern": 2.0, "modulate": Color(0.44, 0.48, 0.45),
		"pool": {"bloater": 3, "husk": 4, "hound": 2, "acolyte": 2}, "packs": 52, "hp_mult": 2.4, "dmg_mult": 1.8,
		"props": ["dead_tree", "dead_tree", "reeds", "hanged", "rock", "grave"],
		"champion": {"kind": "bloater", "name": "The Drowned Mother", "scale": 2.2},
	},
	{
		"id": "hell", "name": "The Infernal Pyre", "line": "Beneath the world, in the fires of hell, the crown was forged.",
		"style": "open", "size": Vector2i(130, 130), "ambient": "amb_hell",
		"ground_a": Color(0.30, 0.2, 0.18), "ground_b": Color(0.13, 0.07, 0.07), "vein": Color(4.0, 0.8, 0.15), "vein_amt": 0.9,
		"wall": Color(0.03, 0.008, 0.008), "pattern": 3.0, "modulate": Color(0.5, 0.4, 0.4),
		"pool": {"wraith": 3, "acolyte": 3, "brute": 2, "hound": 2}, "packs": 42, "hp_mult": 3.2, "dmg_mult": 2.1,
		"props": ["spike", "spike", "impaled", "chain", "brazier", "skull_pile"],
		"champion": {},
	},
]


static func roman(n: int) -> String:
	return ["0", "I", "II", "III", "IV", "V"][clampi(n, 0, 5)]
