class_name Items
## Gear: rarities, affixes, generation, prices and tooltips.

const RARITY_NAME := ["Common", "Magic", "Rare", "Ashforged"]
const RARITY_COLOR := [Color(0.80, 0.77, 0.72), Color(0.45, 0.65, 1.0), Color(1.0, 0.83, 0.32), Color(1.0, 0.52, 0.2)]
const RARITY_PRICE := [1.0, 3.0, 8.0, 28.0]
const SLOTS := ["weapon", "helm", "chest", "boots", "ring", "amulet"]
const SLOT_LABEL := {"weapon": "Weapon", "helm": "Helm", "chest": "Armour", "boots": "Boots", "ring": "Ring", "amulet": "Amulet"}
const SLOT_WEIGHT := {"weapon": 18, "helm": 16, "chest": 16, "boots": 16, "ring": 17, "amulet": 17}
const MAX_ARMOR := 0.7

## lo/hi = roll range at item level 1, grow = gain per item level, dec = decimals shown.
const STATS := {
	"dmg": {"name": "Damage", "unit": "%", "lo": 6.0, "hi": 10.0, "grow": 0.09, "dec": 0},
	"hp": {"name": "Life", "unit": "", "lo": 22.0, "hi": 36.0, "grow": 0.10, "dec": 0},
	"armor": {"name": "Armour", "unit": "%", "lo": 2.0, "hi": 3.5, "grow": 0.05, "dec": 1},
	"speed": {"name": "Movement speed", "unit": "%", "lo": 3.0, "hi": 5.0, "grow": 0.02, "dec": 0},
	"crit": {"name": "Critical chance", "unit": "%", "lo": 2.0, "hi": 3.5, "grow": 0.04, "dec": 1},
	"critd": {"name": "Critical damage", "unit": "%", "lo": 10.0, "hi": 18.0, "grow": 0.06, "dec": 0},
	"cdr": {"name": "Cooldown recovery", "unit": "%", "lo": 3.0, "hi": 5.0, "grow": 0.04, "dec": 0},
	"leech": {"name": "Life restored per kill", "unit": "%", "lo": 0.3, "hi": 0.6, "grow": 0.03, "dec": 1},
	"regen": {"name": "Life regeneration per second", "unit": "%", "lo": 0.15, "hi": 0.3, "grow": 0.03, "dec": 2},
	"gold": {"name": "Gold found", "unit": "%", "lo": 8.0, "hi": 14.0, "grow": 0.05, "dec": 0},
	"mf": {"name": "Magic find", "unit": "%", "lo": 6.0, "hi": 12.0, "grow": 0.05, "dec": 0},
	"ash": {"name": "Ash gained", "unit": "%", "lo": 6.0, "hi": 10.0, "grow": 0.03, "dec": 0},
	"blast": {"name": "Slain enemies explode for % of their life", "unit": "%", "lo": 12.0, "hi": 20.0, "grow": 0.02, "dec": 0},
	"fear": {"name": "chance to terrify enemies on hit", "unit": "%", "lo": 3.0, "hi": 5.0, "grow": 0.03, "dec": 0},
	"stunc": {"name": "chance to stun on hit", "unit": "%", "lo": 2.0, "hi": 3.5, "grow": 0.02, "dec": 1},
	"chill": {"name": "chance to chill on hit", "unit": "%", "lo": 5.0, "hi": 8.0, "grow": 0.03, "dec": 0},
	"ignite": {"name": "chance to ignite on hit", "unit": "%", "lo": 5.0, "hi": 8.0, "grow": 0.03, "dec": 0},
	"echo": {"name": "chance to strike a second time", "unit": "%", "lo": 2.0, "hi": 3.5, "grow": 0.02, "dec": 1},
	"flask": {"name": "Potion cooldown", "unit": "", "lo": 1.0, "hi": 1.0, "grow": 0.0, "dec": 0},
}

const IMPLICIT := {
	"weapon": {"k": "dmg", "lo": 14.0, "hi": 20.0, "grow": 0.10},
	"helm": {"k": "armor", "lo": 3.0, "hi": 4.0, "grow": 0.05},
	"chest": {"k": "armor", "lo": 5.0, "hi": 7.0, "grow": 0.05},
	"boots": {"k": "speed", "lo": 4.0, "hi": 6.0, "grow": 0.02},
}

const POOL := {
	"weapon": ["dmg", "crit", "critd", "cdr", "leech", "ash", "mf", "hp", "fear", "stunc", "chill", "ignite", "echo"],
	"helm": ["hp", "armor", "cdr", "crit", "mf", "regen", "ash", "fear"],
	"chest": ["hp", "armor", "regen", "leech", "cdr", "dmg"],
	"boots": ["speed", "hp", "armor", "gold", "regen", "cdr"],
	"ring": ["dmg", "crit", "critd", "leech", "ash", "gold", "mf", "hp", "cdr", "ignite", "chill", "echo", "stunc"],
	"amulet": ["dmg", "critd", "cdr", "hp", "ash", "mf", "regen", "leech", "crit", "fear", "chill", "ignite"],
}

const BASES := {
	"weapon": [["Ashen Blade", "blade"], ["Cinder Mace", "mace"], ["Bone Staff", "staff"], ["Pyre Wand", "wand"], ["Grave Scepter", "scepter"]],
	"helm": [["Ash Cowl", "helm"], ["Iron Helm", "helm"], ["Bone Crown", "helm"], ["Charred Hood", "helm"]],
	"chest": [["Scorched Plate", "chest"], ["Gravecloth Robe", "chest"], ["Ember Jerkin", "chest"], ["Hollow Mail", "chest"]],
	"boots": [["Ash Boots", "boots"], ["Iron Greaves", "boots"], ["Grave Wraps", "boots"], ["Sabatons", "boots"]],
	"ring": [["Ash Band", "ring"], ["Cinder Signet", "ring"], ["Bone Loop", "ring"]],
	"amulet": [["Ember Pendant", "amulet"], ["Ashen Talisman", "amulet"], ["Grave Charm", "amulet"]],
}

const PREFIX := {
	"dmg": ["Brutal", "Savage", "Searing"], "hp": ["Stalwart", "Hale"], "armor": ["Bulwark", "Ironbound"],
	"speed": ["Fleet", "Hurried"], "crit": ["Keen", "Piercing"], "critd": ["Merciless", "Wicked"],
	"cdr": ["Swift", "Tireless"], "leech": ["Hungering", "Gorging"], "regen": ["Mending", "Knitting"],
	"gold": ["Gilded", "Covetous"], "mf": ["Lucky", "Fortune's"], "ash": ["Smouldering", "Cindered"],
	"fear": ["Dreadful", "Haunting"], "stunc": ["Crushing", "Staggering"], "chill": ["Frostbitten", "Chilling"],
	"ignite": ["Kindling", "Flaring"], "echo": ["Echoing", "Doubling"],
}
const SUFFIX := {
	"dmg": "of Ruin", "hp": "of the Bull", "armor": "of Warding", "speed": "of Haste", "crit": "of Precision",
	"critd": "of Cruelty", "cdr": "of Alacrity", "leech": "of Hunger", "regen": "of Mending",
	"gold": "of Greed", "mf": "of Fortune", "ash": "of Embers",
	"fear": "of Terror", "stunc": "of the Hammer", "chill": "of the Grave Cold", "ignite": "of Kindling", "echo": "of Echoes",
}
const RARE_A := ["Gloom", "Dread", "Cinder", "Ash", "Bone", "Grave", "Hollow", "Ember", "Pyre", "Wraith", "Blight", "Rot"]
const RARE_B := {
	"weapon": ["Fang", "Reaver", "Bite", "Wrath", "Cleaver", "Edge"], "helm": ["Gaze", "Visage", "Mask", "Crown"],
	"chest": ["Shell", "Ward", "Bulwark", "Carapace"], "boots": ["Stride", "Tread", "Step", "Fall"],
	"ring": ["Coil", "Loop", "Grasp", "Bond"], "amulet": ["Heart", "Tear", "Eye", "Ward"],
}

const LEGENDS := [
	{"key": "ashbrand", "slot": "weapon", "icon": "blade", "name": "Ashbrand", "tag": "Forged from the sword Aldric lost to the fire.", "mods": ["dmg", "critd", "leech", "blast"]},
	{"key": "reaver", "slot": "weapon", "icon": "scepter", "name": "The Weeping Reaver", "tag": "It cries when it is drawn.", "mods": ["dmg", "cdr", "mf", "ash"]},
	{"key": "crownbreaker", "slot": "weapon", "icon": "blade", "name": "Crownbreaker", "tag": "Made for one purpose.", "mods": ["dmg", "crit", "critd", "cdr", "blast"], "boss": true},
	{"key": "hollowcrown", "slot": "helm", "icon": "helm", "name": "The Hollow Crown", "tag": "Empty, and still too heavy.", "mods": ["hp", "cdr", "armor", "flask"]},
	{"key": "hanged", "slot": "helm", "icon": "helm", "name": "Visage of the Hanged", "tag": "Its eyes follow you.", "mods": ["mf", "crit", "hp", "regen"]},
	{"key": "heartpyre", "slot": "chest", "icon": "chest", "name": "Heartpyre Plate", "tag": "Something still burns inside.", "mods": ["hp", "regen", "armor", "blast"]},
	{"key": "abbess", "slot": "chest", "icon": "chest", "name": "Shroud of the Abbess", "tag": "She prayed in it until the end.", "mods": ["hp", "regen", "leech", "cdr"]},
	{"key": "cinderstride", "slot": "boots", "icon": "boots", "name": "Cinderstride", "tag": "The ground is hot where they step.", "mods": ["speed", "dmg", "gold", "regen"]},
	{"key": "gravewalkers", "slot": "boots", "icon": "boots", "name": "Gravewalkers", "tag": "They know the way down.", "mods": ["speed", "hp", "regen", "flask"]},
	{"key": "oathless", "slot": "ring", "icon": "ring", "name": "Oathless Signet", "tag": "A promise, broken in iron.", "mods": ["dmg", "crit", "leech", "ash"]},
	{"key": "drowned", "slot": "ring", "icon": "ring", "name": "Ring of the Drowned Mother", "tag": "Cold. Always cold.", "mods": ["hp", "regen", "armor", "gold"]},
	{"key": "tear", "slot": "amulet", "icon": "amulet", "name": "Valdremor's Tear", "tag": "The last thing the city wept.", "mods": ["critd", "cdr", "ash", "mf"]},
	{"key": "kingheart", "slot": "amulet", "icon": "amulet", "name": "Heart of the Ember King", "tag": "Still beating, slowly.", "mods": ["dmg", "hp", "blast", "leech", "crit"], "boss": true},
]

## Rarity weights: common, magic, rare, ashforged.
const TABLES := {
	"normal": [72.0, 25.0, 2.95, 0.05],
	"elite": [0.0, 72.0, 27.0, 1.0],
	"champion": [0.0, 45.0, 52.0, 3.0],
	"chest": [45.0, 45.0, 9.85, 0.15],
	"iron": [0.0, 62.0, 37.0, 1.0],
	"quest": [0.0, 45.0, 53.0, 2.0],
	"shop": [20.0, 55.0, 25.0, 0.0],
}

static var _uid := 0


# ------------------------------------------------------------------ generation

static func _round(v: float, dec: int) -> float:
	return snappedf(v, 1.0 / pow(10.0, dec))


static func roll_stat(k: String, ilvl: int, quality := 1.0) -> float:
	var d: Dictionary = STATS[k]
	var v := randf_range(float(d.lo), float(d.hi)) * (1.0 + (ilvl - 1) * float(d.grow)) * quality
	return _round(v, int(d.dec))


static func random_slot() -> String:
	var total := 0
	for s in SLOTS:
		total += int(SLOT_WEIGHT[s])
	var r := randi_range(1, total)
	for s in SLOTS:
		r -= int(SLOT_WEIGHT[s])
		if r <= 0:
			return s
	return "weapon"


static func roll_rarity(table: String, mf := 0.0, min_r := 0) -> int:
	var w: Array = (TABLES[table] as Array).duplicate()
	var m := clampf(mf / 100.0, 0.0, 3.0)
	w[1] = float(w[1]) * (1.0 + m)
	w[2] = float(w[2]) * (1.0 + m * 1.5)
	w[3] = float(w[3]) * (1.0 + m * 2.0)
	# Ashforged gear is a late find: none below level 8, full chance from level 30
	w[3] = float(w[3]) * clampf((float(Game.stats.get("level", 1)) - 8.0) / 22.0, 0.0, 1.0)
	for i in min_r:
		w[i] = 0.0
	var total := 0.0
	for x in w:
		total += float(x)
	if total <= 0.0:
		return min_r
	var r := randf() * total
	for i in 4:
		r -= float(w[i])
		if r <= 0.0:
			return i
	return 3


static func make(slot: String, rarity: int, ilvl: int) -> Dictionary:
	_uid += 1
	var base: Array = (BASES[slot] as Array)[randi() % (BASES[slot] as Array).size()]
	var item := {"uid": _uid, "slot": slot, "icon": base[1], "base": base[0], "rarity": rarity, "ilvl": ilvl,
		"implicit": {}, "mods": [], "legend": "", "tag": "", "dur": 0, "dur_max": 0}
	item.dur_max = [40, 50, 60, 80][rarity]
	item.dur = item.dur_max
	if IMPLICIT.has(slot):
		var im: Dictionary = IMPLICIT[slot]
		var v := randf_range(float(im.lo), float(im.hi)) * (1.0 + (ilvl - 1) * float(im.grow))
		item.implicit = {"k": im.k, "v": _round(v, int(STATS[im.k].dec))}
	var n := 0
	match rarity:
		Items_R.MAGIC: n = randi_range(1, 2)
		Items_R.RARE: n = randi_range(3, 4)
	var pool: Array = (POOL[slot] as Array).duplicate()
	pool.shuffle()
	for i in mini(n, pool.size()):
		item.mods.append({"k": pool[i], "v": roll_stat(pool[i], ilvl)})
	item.name = _name_for(item)
	return item


static func make_legend(slot: String, ilvl: int, allow_boss := false, key := "") -> Dictionary:
	# a legendary is never weaker than the hero who finds it: it is at least a few levels above the zone
	# and above the hero's own level
	ilvl = maxi(ilvl + 1, int(Game.stats.get("level", 1)))
	var opts: Array = []
	for l in LEGENDS:
		if key != "":
			if l.key == key:
				opts.append(l)
		elif l.slot == slot and (allow_boss or not l.get("boss", false)):
			opts.append(l)
	if opts.is_empty():
		return make(slot, Items_R.RARE, ilvl)
	var def: Dictionary = opts[randi() % opts.size()]
	var item := make(def.slot, Items_R.LEGENDARY, ilvl)
	item.icon = def.icon
	item.base = String(def.slot).capitalize()
	item.legend = def.key
	item.tag = def.tag
	item.name = def.name
	item.mods = []
	for k in def.mods:
		item.mods.append({"k": k, "v": roll_stat(k, ilvl, 1.25)})
	if item.implicit.has("v"):
		item.implicit.v = _round(float(item.implicit.v) * 1.2, int(STATS[item.implicit.k].dec))
	return item


static func _name_for(item: Dictionary) -> String:
	var mods: Array = item.mods
	match int(item.rarity):
		Items_R.COMMON:
			return item.base
		Items_R.MAGIC:
			var a: String = mods[0].k
			if mods.size() == 1:
				if randf() < 0.5:
					return "%s %s" % [(PREFIX[a] as Array).pick_random(), item.base]
				return "%s %s" % [item.base, SUFFIX[a]]
			var b: String = mods[1].k
			return "%s %s %s" % [(PREFIX[a] as Array).pick_random(), item.base, SUFFIX[b]]
		_:
			return "%s %s" % [RARE_A.pick_random(), (RARE_B[item.slot] as Array).pick_random()]


static func drop_ilvl(zone_idx: int, bonus := 0) -> int:
	# Most drops sit a little below the zone, so a real upgrade is the exception
	return maxi(1, 1 + zone_idx * 4 + randi_range(-3, 2) + bonus)


## One drop from a table. `slot` forces a slot, `min_r` a minimum rarity.
static func roll_drop(table: String, ilvl: int, mf := 0.0, slot := "", min_r := 0) -> Dictionary:
	var r := roll_rarity(table, mf, min_r)
	var s := slot if slot != "" else random_slot()
	if r == Items_R.LEGENDARY:
		return make_legend(s, ilvl)
	return make(s, r, ilvl)


static func boss_loot(ilvl: int) -> Array:
	var out: Array = [make_legend("weapon", ilvl + 1, true, "crownbreaker")]
	if randf() < 0.35:
		out.append(make_legend(random_slot(), ilvl + 1, true))
	for i in 2:
		out.append(make(random_slot(), Items_R.RARE, ilvl + 1))
	return out


static func vendor_stock(kind: String, ilvl: int) -> Array:
	var slots: Array = []
	if kind == "smith":
		slots = ["weapon", "weapon", "weapon", "weapon", "helm", "helm", "chest", "chest", "chest", "boots", "boots", "weapon"]
	else:
		slots = ["ring", "ring", "ring", "ring", "amulet", "amulet", "amulet", "amulet", "helm", "boots", "ring", "amulet"]
	var out: Array = []
	for s in slots:
		var r := roll_rarity("shop")
		out.append(make(s, r, maxi(1, ilvl + randi_range(-1, 1))))
	return out


# ------------------------------------------------------------------ values

static func price(item: Dictionary) -> int:
	var base := 10.0 * pow(1.0 + float(item.ilvl) * 0.4, 1.15) * float(RARITY_PRICE[int(item.rarity)])
	base *= 0.85 + 0.075 * (item.mods as Array).size()
	return maxi(1, int(round(base)))


static func sell_price(item: Dictionary) -> int:
	return maxi(1, int(price(item) * 0.2))


## Cost to bring an item back to full durability.
static func repair_cost(item: Dictionary) -> int:
	var missing := float(item.dur_max - item.dur) / maxf(1.0, float(item.dur_max))
	return int(ceil(price(item) * 0.25 * missing))


static func is_broken(item: Dictionary) -> bool:
	return int(item.dur) <= 0


## A broken item gives nothing until it is repaired.
static func item_stats(item: Dictionary) -> Dictionary:
	var out := {}
	if is_broken(item):
		return out
	if item.implicit.has("k"):
		out[item.implicit.k] = float(item.implicit.v)
	for m in item.mods:
		out[m.k] = float(out.get(m.k, 0.0)) + float(m.v)
	return out


## How much a stat is worth when judging whether one piece of gear beats another.
const RATING_W := {"dmg": 1.0, "hp": 0.15, "armor": 3.0, "speed": 1.2, "crit": 3.0, "critd": 0.5, "cdr": 2.0,
	"leech": 6.0, "regen": 8.0, "fear": 2.0, "stunc": 3.0, "chill": 1.5, "ignite": 1.5, "echo": 4.0, "gold": 0.3, "mf": 0.3, "ash": 0.4, "blast": 0.5, "flask": 4.0}


static func rating(item: Variant) -> float:
	if item == null:
		return 0.0
	var r := 0.0
	var s := item_stats(item)
	for k in s.keys():
		r += float(s[k]) * float(RATING_W.get(k, 0.5))
	return r


## 1 if `item` beats what is worn in its slot, -1 if it is worse, 0 if about the same.
static func verdict(item: Dictionary, equipment: Dictionary) -> int:
	var a := rating(item)
	var b := rating(equipment.get(item.slot))
	if a > b * 1.03 + 0.2:
		return 1
	if a < b * 0.97 - 0.2:
		return -1
	return 0


static func totals(equipment: Dictionary) -> Dictionary:
	var out := {}
	for slot in equipment.keys():
		var it: Variant = equipment[slot]
		if it == null:
			continue
		var s := item_stats(it)
		for k in s.keys():
			out[k] = float(out.get(k, 0.0)) + float(s[k])
	return out


# ------------------------------------------------------------------ text

static func stat_text(k: String, v: float) -> String:
	var d: Dictionary = STATS[k]
	if k == "blast":
		return "Slain enemies explode for %d%% of their life" % int(v)
	if k == "flask":
		return "Potion cooldown reduced by %d seconds" % (5 * int(v))
	var num := ("%d" % int(round(v))) if int(d.dec) == 0 else ("%.*f" % [int(d.dec), v])
	return "+%s%s %s" % [num, d.unit, d.name]


static func color_of(item: Dictionary) -> Color:
	return RARITY_COLOR[int(item.rarity)]


class Items_R:
	const COMMON := 0
	const MAGIC := 1
	const RARE := 2
	const LEGENDARY := 3
