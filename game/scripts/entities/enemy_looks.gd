class_name EnemyLooks
## What makes a world's own enemy look like itself: an accessory and a bit of animation on top of the
## archetype body. Drawn inside Enemy._draw, in the enemy's facing-right local space.

const HEAD := {"husk": Vector2(10, -40), "hound": Vector2(24, -16), "acolyte": Vector2(3, -40), "brute": Vector2(0, -68), "bloater": Vector2(12, -46), "wraith": Vector2(0, -48)}
const BODY := {"husk": Vector2(4, -26), "hound": Vector2(0, -14), "acolyte": Vector2(0, -24), "brute": Vector2(0, -40), "bloater": Vector2(0, -26), "wraith": Vector2(0, -30)}

const LOOKS := {
	"thornhusk": "thorns", "black_wolf": "antlers", "hangman": "noose", "root_crawler": "roots",
	"hollow_guard": "helm_shield", "keep_zealot": "mitre", "keep_hound": "spiked_collar",
	"citizen": "hat", "gutter_hound": "mange", "gilded_priest": "halo_gold", "plague_cart": "flies",
	"skeleton_warden": "ribs", "crypt_wraith": "chains", "bone_brute": "bone_spikes", "bone_heap": "bone_pile",
	"mire_husk": "moss", "bog_bloater": "bubbles", "leech_hound": "leeches", "mire_crawler": "tendrils",
	"pilgrim": "drip", "bell_wraith": "bell", "tide_bloater": "barnacles", "drowned_acolyte": "mitre",
	"miner": "lamp_helmet", "pit_hound": "soot", "cave_brute": "boulders", "rock_husk": "rock_plates",
	"magma_husk": "magma_cracks", "slag_brute": "slag", "deep_wraith": "eyes_many", "deep_bloater": "magma_boil",
	"cinder_hound": "flame_mane", "scarecrow": "straw", "ash_acolyte": "ash_cloud", "ash_revenant": "ash_trail",
	"courtier": "mask_fan", "obsidian_guard": "obsidian", "court_wraith": "crown_shards", "court_hound": "gilded_collar",
	"imp": "wings", "pyre_wraith": "fire_wreath", "demon_brute": "big_horns", "pyre_acolyte": "flame_hood",
	"ember_wraith": "ember_crown", "throne_guard": "king_helm", "flame_acolyte": "scepter", "ember_hound": "fire_tail",
	"cellar_ghoul": "cobwebs", "gravedigger_ghoul": "shovel",
}


static func draw(e: Enemy, walk: float) -> void:
	var look: String = LOOKS.get(e.variant, "")
	if look == "":
		return
	var arch := e.kind
	var h: Vector2 = HEAD[arch]
	var b: Vector2 = BODY[arch]
	if arch == "wraith":
		var fl := sin(e.anim * 3.0) * 4.0
		h.y += fl
		b.y += fl
	var t := e.anim
	e.draw_set_transform(Vector2.ZERO, 0.0, Vector2(e.facing.x * e.scale_mult, e.scale_mult))
	var big := arch == "brute"
	var hot := Color(3.0, 1.1, 0.25)
	match look:
		"thorns":
			for i in 5:
				var p := b + Vector2(-9 + i * 5, -8 - i * 3)
				e.draw_colored_polygon(PackedVector2Array([p, p + Vector2(-4, -2), p + Vector2(-8, -12 - i)]), Color(0.3, 0.38, 0.2))
		"antlers":
			for s in [-1.0, 1.0]:
				var base := h + Vector2(s * 4.0, -8)
				e.draw_line(base, base + Vector2(s * 6, -14), Color(0.72, 0.66, 0.55), 2.0, true)
				e.draw_line(base + Vector2(s * 3, -7), base + Vector2(s * 10, -11), Color(0.72, 0.66, 0.55), 1.5, true)
				e.draw_line(base + Vector2(s * 6, -14), base + Vector2(s * 3, -22), Color(0.72, 0.66, 0.55), 1.5, true)
		"noose":
			e.draw_arc(h + Vector2(0, 9), 6.0, 0.0, TAU, 12, Color(0.45, 0.36, 0.22), 2.0, true)
			e.draw_line(h + Vector2(0, 3), h + Vector2(-2, -18 + sin(t * 2.0) * 2.0), Color(0.45, 0.36, 0.22), 2.0, true)
		"roots":
			for i in 4:
				var x := -12.0 + i * 8.0
				e.draw_line(Vector2(x, -2), Vector2(x + sin(t * 3.0 + i) * 4.0, 8 + (i % 2) * 3), Color(0.32, 0.2, 0.12), 3.0, true)
			e.draw_circle(Vector2(0, 2), 14.0, Color(0.2, 0.14, 0.1, 0.8), true, -1.0, true)
		"helm_shield":
			e.draw_arc(h + Vector2(0, 1), 8.0, PI, TAU, 14, Color(0.5, 0.52, 0.6), 4.0, true)
			e.draw_line(h + Vector2(0, -7), h + Vector2(0, 4), Color(0.4, 0.42, 0.5), 2.0)
			e.draw_colored_polygon(PackedVector2Array([b + Vector2(-20, -10), b + Vector2(-8, -10), b + Vector2(-9, 4), b + Vector2(-14, 10), b + Vector2(-20, 4)]), Color(0.28, 0.3, 0.38))
		"mitre":
			e.draw_colored_polygon(PackedVector2Array([h + Vector2(-6, -5), h + Vector2(6, -5), h + Vector2(0, -24)]), Color(0.65, 0.2, 0.15))
			e.draw_line(h + Vector2(0, -22), h + Vector2(0, -8), Color(0.9, 0.8, 0.5), 1.5)
		"spiked_collar":
			for i in 4:
				var p2 := h + Vector2(-10 + i * 3.0, 7 - i * 0.5)
				e.draw_line(p2, p2 + Vector2(-2, 5), Color(0.6, 0.6, 0.65), 2.0, true)
		"hat":
			e.draw_rect(Rect2(h + Vector2(-8, -9), Vector2(16, 4)), Color(0.22, 0.18, 0.14))
			e.draw_rect(Rect2(h + Vector2(-5, -15), Vector2(10, 7)), Color(0.22, 0.18, 0.14))
		"mange":
			for i in 3:
				e.draw_line(b + Vector2(-8 + i * 6, -6), b + Vector2(-7 + i * 6, 2), Color(0.5, 0.45, 0.4), 1.5, true)
		"halo_gold":
			e.draw_arc(h + Vector2(0, -14 + sin(t * 2.0) * 1.5), 8.0, 0.0, TAU, 20, Color(3.0, 2.4, 0.8), 2.5, true)
		"flies":
			for i in 4:
				var a := t * 4.0 + i * 1.57
				e.draw_circle(b + Vector2(cos(a) * 24.0, sin(a * 1.3) * 18.0 - 6.0), 1.8, Color(0.05, 0.05, 0.05), true, -1.0, true)
		"ribs":
			for i in 4:
				e.draw_line(b + Vector2(-8, -12 + i * 5), b + Vector2(8, -12 + i * 5), Color(0.85, 0.82, 0.72), 2.0, true)
			e.draw_circle(h, 5.5, Color(0.88, 0.85, 0.76), true, -1.0, true)
			e.draw_circle(h + Vector2(-2, -1), 1.4, Color(0.02, 0.02, 0.02), true, -1.0, true)
			e.draw_circle(h + Vector2(2, -1), 1.4, Color(0.02, 0.02, 0.02), true, -1.0, true)
		"chains":
			for i in 3:
				var p3 := b + Vector2(-10 + i * 10.0, 4 + sin(t * 2.0 + i) * 2.0)
				e.draw_arc(p3, 4.0, 0.0, TAU, 8, Color(0.45, 0.45, 0.5), 1.8, true)
				e.draw_arc(p3 + Vector2(0, 6), 4.0, 0.0, TAU, 8, Color(0.45, 0.45, 0.5), 1.8, true)
		"bone_spikes":
			for s in [-1.0, 1.0]:
				for i in 3:
					var p4 := b + Vector2(s * (14.0 + i * 3.0), -16 - i * 5)
					e.draw_colored_polygon(PackedVector2Array([p4, p4 + Vector2(s * 4, 3), p4 + Vector2(s * 8, -10)]), Color(0.88, 0.85, 0.75))
		"bone_pile":
			for i in 5:
				e.draw_line(Vector2(-14 + i * 7, 2), Vector2(-10 + i * 7, -3 - (i % 2) * 3), Color(0.85, 0.82, 0.72), 2.0, true)
		"moss":
			e.draw_circle(b + Vector2(-8, -12), 5.0, Color(0.2, 0.38, 0.16), true, -1.0, true)
			e.draw_circle(b + Vector2(7, -6), 4.0, Color(0.24, 0.42, 0.18), true, -1.0, true)
		"bubbles":
			for i in 4:
				var ph := fmod(t * 0.9 + i * 0.27, 1.0)
				e.draw_circle(b + Vector2(-10 + i * 7.0, -ph * 40.0), 2.5 * (1.0 - ph), Color(0.6, 0.85, 0.4, 1.0 - ph), true, -1.0, true)
		"leeches":
			for i in 3:
				e.draw_line(b + Vector2(-6 + i * 6.0, -8), b + Vector2(-8 + i * 6.0 + sin(t * 5.0 + i) * 2.0, 3), Color(0.1, 0.12, 0.08), 3.0, true)
		"tendrils":
			for i in 4:
				var a2 := -0.6 + i * 0.4
				e.draw_line(h, h + Vector2(cos(a2), sin(a2)) * 14.0 + Vector2(sin(t * 6.0 + i) * 3.0, 0), Color(0.3, 0.4, 0.28), 2.0, true)
		"drip":
			for i in 3:
				var ph2 := fmod(t * 1.2 + i * 0.33, 1.0)
				e.draw_circle(b + Vector2(-8 + i * 8.0, -4 + ph2 * 14.0), 1.8, Color(0.4, 0.65, 0.9, 1.0 - ph2), true, -1.0, true)
		"bell":
			var sw := sin(t * 3.0) * 0.4
			var bp := h + Vector2(12, 8)
			e.draw_line(h + Vector2(4, 0), bp, Color(0.4, 0.32, 0.2), 1.5)
			e.draw_set_transform(bp, sw, Vector2(e.facing.x * e.scale_mult, e.scale_mult))
			e.draw_colored_polygon(PackedVector2Array([Vector2(-6, 6), Vector2(6, 6), Vector2(4, -4), Vector2(0, -8), Vector2(-4, -4)]), Color(0.7, 0.55, 0.2))
			e.draw_circle(Vector2(0, 8), 1.8, Color(0.5, 0.4, 0.2), true, -1.0, true)
		"barnacles":
			for i in 5:
				e.draw_circle(b + Vector2(-12 + i * 6.0, -10 + (i % 2) * 8.0), 2.5, Color(0.65, 0.68, 0.7), true, -1.0, true)
		"lamp_helmet":
			e.draw_arc(h + Vector2(0, 1), 8.0, PI, TAU, 14, Color(0.7, 0.55, 0.15), 4.0, true)
			e.draw_circle(h + Vector2(7, -2), 3.0, Color(3.2, 2.4, 0.9), true, -1.0, true)
			var hand := b + Vector2(14, -4)
			e.draw_line(hand + Vector2(-6, 12), hand + Vector2(6, -14), Color(0.35, 0.28, 0.2), 2.5, true)
			e.draw_line(hand + Vector2(1, -14), hand + Vector2(12, -10), Color(0.55, 0.55, 0.6), 3.0, true)
		"soot":
			for i in 4:
				e.draw_circle(b + Vector2(-9 + i * 6.0, -6 + (i % 2) * 5.0), 3.5, Color(0.02, 0.02, 0.02, 0.6), true, -1.0, true)
		"boulders":
			e.draw_circle(b + Vector2(-26, -14), 11.0, Color(0.36, 0.34, 0.32), true, -1.0, true)
			e.draw_circle(b + Vector2(26, -14), 11.0, Color(0.32, 0.3, 0.28), true, -1.0, true)
		"rock_plates":
			for i in 3:
				var p5 := b + Vector2(-8 + i * 7.0, -12 + (i % 2) * 6.0)
				e.draw_colored_polygon(PackedVector2Array([p5, p5 + Vector2(7, -2), p5 + Vector2(8, 7), p5 + Vector2(1, 9)]), Color(0.38, 0.38, 0.42))
		"magma_cracks":
			var pulse := 0.7 + 0.3 * sin(t * 4.0)
			e.draw_polyline(PackedVector2Array([b + Vector2(-8, -14), b + Vector2(-2, -8), b + Vector2(-6, -2), b + Vector2(2, 6)]), Color(3.0 * pulse, 1.0, 0.2), 2.0, true)
			e.draw_polyline(PackedVector2Array([b + Vector2(8, -16), b + Vector2(5, -8), b + Vector2(10, 0)]), Color(3.0 * pulse, 1.0, 0.2), 2.0, true)
		"slag":
			for i in 3:
				var ph3 := fmod(t * 1.1 + i * 0.4, 1.0)
				e.draw_circle(b + Vector2(18 + i * 3.0, -8 + ph3 * 22.0), 2.4 * (1.0 - ph3 * 0.5), hot, true, -1.0, true)
		"eyes_many":
			for i in 3:
				e.draw_circle(h + Vector2(-4 + i * 4.0, -2 + (i % 2) * 4.0), 1.6, Color(1.0, 3.0, 2.8), true, -1.0, true)
		"magma_boil":
			for i in 4:
				var ph4 := fmod(t * 1.3 + i * 0.25, 1.0)
				e.draw_circle(b + Vector2(-10 + i * 7.0, -4 - ph4 * 12.0), 3.5 * (1.0 - ph4), hot, true, -1.0, true)
		"flame_mane":
			for i in 5:
				var f := 1.0 + 0.4 * sin(t * 10.0 + i)
				var p6 := b + Vector2(-12 + i * 6.0, -8)
				e.draw_colored_polygon(PackedVector2Array([p6, p6 + Vector2(6, 0), p6 + Vector2(3, -12 * f)]), Color(3.0, 1.3 + i * 0.1, 0.3))
		"straw":
			e.draw_colored_polygon(PackedVector2Array([h + Vector2(-10, -6), h + Vector2(10, -6), h + Vector2(0, -16)]), Color(0.62, 0.5, 0.22))
			e.draw_line(b + Vector2(8, -6), b + Vector2(22, -10), Color(0.62, 0.5, 0.22), 2.0)
			e.draw_line(b + Vector2(-6, -6), b + Vector2(-20, -2), Color(0.62, 0.5, 0.22), 2.0)
		"ash_cloud":
			for i in 3:
				var a3 := t * 1.5 + i * 2.1
				e.draw_circle(b + Vector2(cos(a3) * 14.0, sin(a3) * 8.0 - 10.0), 6.0, Color(0.45, 0.43, 0.42, 0.35), true, -1.0, true)
		"ash_trail":
			for i in 4:
				e.draw_circle(Vector2(-10 - i * 8.0, -8 - sin(t * 4.0 + i) * 3.0), 5.0 - i, Color(0.5, 0.48, 0.47, 0.4 - i * 0.08), true, -1.0, true)
		"mask_fan":
			e.draw_colored_polygon(PackedVector2Array([h + Vector2(-5, -3), h + Vector2(7, -3), h + Vector2(5, 2), h + Vector2(-3, 2)]), Color(0.75, 0.55, 0.85))
			for i in 3:
				e.draw_line(h + Vector2(-2 + i * 3.0, -7), h + Vector2(-6 + i * 6.0, -22 - (i % 2) * 4.0), Color(1.2, 0.6, 1.4), 2.0, true)
		"obsidian":
			for i in 3:
				var p7 := b + Vector2(-10 + i * 8.0, -14 + (i % 2) * 8.0)
				e.draw_colored_polygon(PackedVector2Array([p7, p7 + Vector2(6, -4), p7 + Vector2(9, 6), p7 + Vector2(1, 9)]), Color(0.18, 0.12, 0.28))
		"crown_shards":
			for i in 5:
				var a4 := t * 1.2 + i * 1.26
				var p8 := h + Vector2(cos(a4) * 12.0, -12.0 + sin(a4) * 4.0)
				e.draw_colored_polygon(PackedVector2Array([p8, p8 + Vector2(2, -5), p8 + Vector2(4, 0)]), Color(1.6, 0.9, 2.2))
		"gilded_collar":
			e.draw_arc(h + Vector2(-8, 7), 5.0, 0.0, TAU, 10, Color(2.6, 1.9, 0.6), 2.5, true)
		"wings":
			var fl2 := sin(t * 12.0) * 0.5
			for s in [-1.0, 1.0]:
				var root := b + Vector2(-2, -12)
				e.draw_colored_polygon(PackedVector2Array([root, root + Vector2(s * 8, -16 - fl2 * 10), root + Vector2(s * 20, -10 - fl2 * 14), root + Vector2(s * 12, -2)]), Color(0.3, 0.05, 0.05))
		"fire_wreath":
			for i in 6:
				var a5 := TAU * i / 6.0 + t * 2.0
				var p9 := b + Vector2(cos(a5) * 14.0, sin(a5) * 20.0)
				e.draw_circle(p9, 3.0 + sin(t * 8.0 + i), hot, true, -1.0, true)
		"big_horns":
			for s in [-1.0, 1.0]:
				e.draw_polyline(PackedVector2Array([h + Vector2(s * 8, -6), h + Vector2(s * 18, -12), h + Vector2(s * 20, -26), h + Vector2(s * 14, -32)]), Color(0.75, 0.7, 0.6), 4.0, true)
		"flame_hood":
			for i in 3:
				var f2 := 1.0 + 0.4 * sin(t * 9.0 + i)
				var p10 := h + Vector2(-5 + i * 5.0, -6)
				e.draw_colored_polygon(PackedVector2Array([p10, p10 + Vector2(5, 0), p10 + Vector2(2, -14 * f2)]), Color(3.0, 1.2 + i * 0.3, 0.3))
		"ember_crown":
			for i in 5:
				var p11 := h + Vector2(-8 + i * 4.0, -8)
				e.draw_colored_polygon(PackedVector2Array([p11, p11 + Vector2(4, 0), p11 + Vector2(2, -9 - (i % 2) * 4.0)]), Color(3.0, 1.6, 0.5))
		"king_helm":
			e.draw_arc(h + Vector2(0, 1), 12.0, PI, TAU, 14, Color(0.3, 0.25, 0.25), 5.0, true)
			e.draw_line(h + Vector2(0, -12), h + Vector2(-8 + sin(t * 3.0) * 3.0, -26), Color(0.7, 0.1, 0.08), 4.0, true)
		"scepter":
			var hnd := b + Vector2(16, -2)
			e.draw_line(hnd + Vector2(0, 16), hnd + Vector2(0, -24), Color(0.3, 0.22, 0.15), 3.0, true)
			e.draw_circle(hnd + Vector2(0, -26), 5.0 + sin(t * 6.0), Color(3.0, 1.3, 0.3), true, -1.0, true)
		"fire_tail":
			for i in 4:
				var f3 := 1.0 + 0.3 * sin(t * 12.0 + i)
				e.draw_circle(Vector2(-22 - i * 6.0, -22 - sin(t * 8.0 + i) * 3.0), (5.0 - i) * f3, Color(3.0, 1.2 + i * 0.2, 0.3), true, -1.0, true)
		"cobwebs":
			for i in 3:
				e.draw_line(h + Vector2(-8, -8), h + Vector2(-2 + i * 6.0, 8), Color(0.85, 0.85, 0.85, 0.5), 1.0, true)
		"shovel":
			var hs := b + Vector2(16, -4)
			e.draw_line(hs + Vector2(0, 14), hs + Vector2(2, -22), Color(0.4, 0.3, 0.2), 3.0, true)
			e.draw_colored_polygon(PackedVector2Array([hs + Vector2(-4, 14), hs + Vector2(6, 14), hs + Vector2(5, 26), hs + Vector2(-3, 26)]), Color(0.5, 0.5, 0.55))
	e.draw_set_transform(Vector2.ZERO, 0.0, Vector2(e.facing.x * e.scale_mult, e.scale_mult))
