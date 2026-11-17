extends SceneTree
## Item balance check: godot --headless --path game -s res://scripts/debug/item_sim.gd

func _init() -> void:
	seed(7)
	for zone in 5:
		var il := 1 + zone * 4 + 2
		var counts := [0, 0, 0, 0]
		for i in 2000:
			var it := Items.roll_drop("normal", il)
			counts[it.rarity] += 1
		print("zone %d ilvl %d  normal drops per 2000: common %d magic %d rare %d legend %d" % [zone + 1, il, counts[0], counts[1], counts[2], counts[3]])
		var best := {}
		for slot in Items.SLOTS:
			var top: Dictionary = {}
			var top_v := -1.0
			for i in 400:
				var it := Items.make(slot, 2, il)
				var s := Items.item_stats(it)
				var v := float(s.get("dmg", 0.0)) * 2.0 + float(s.get("hp", 0.0)) * 0.3 + float(s.get("armor", 0.0)) * 3.0
				if v > top_v:
					top_v = v
					top = it
			best[slot] = top
		var t := Items.totals(best)
		print("   best-of-400 rare per slot totals: dmg %+.0f%% life +%d armour %.0f%% speed %.0f%%  | rare price %d  magic price %d" % [t.get("dmg", 0.0), int(t.get("hp", 0.0)), t.get("armor", 0.0), t.get("speed", 0.0), Items.price(Items.make("weapon", 2, il)), Items.price(Items.make("weapon", 1, il))])
	var l := Items.make_legend("weapon", 18, true, "crownbreaker")
	print(l.name, " ", Items.item_stats(l))
	print(Items.make("ring", 2, 9))
	quit()
