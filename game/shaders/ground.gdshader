shader_type canvas_item;
// Zone ground. Lit by the scene lights. The mask marks walkable cells.

uniform sampler2D mask : filter_linear, repeat_disable;
uniform vec4 col_a : source_color;
uniform vec4 col_b : source_color;
uniform vec4 col_wall : source_color;
uniform float pattern = 0.0;
uniform vec2 map_px = vec2(9600.0);

varying vec2 wpos;

#include "res://shaders/noise.gdshaderinc"

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 p = wpos;
	vec2 uv = p / map_px;
	float m = texture(mask, uv).r;
	float n = fbm(p * 0.003);
	float edge = m + (fbm(p * 0.018) - 0.5) * 0.42;
	float floor_amt = smoothstep(0.44, 0.56, edge);

	vec3 g = mix(col_b.rgb, col_a.rgb, smoothstep(0.25, 0.8, fbm(p * 0.0022 + n * 2.0)));
	g *= 0.82 + 0.32 * fbm(p * 0.045);
	float grit = hash(floor(p * 0.5));
	g *= 0.94 + 0.08 * grit;

	vec2 vor = voronoi(p * 0.012);
	if (pattern < 0.5) {
		// Cracked, burnt earth
		float crack = 1.0 - smoothstep(0.0, 0.06, vor.y);
		g *= 1.0 - crack * 0.55;
		g = mix(g, g * 0.6, smoothstep(0.55, 0.85, fbm(p * 0.006 + 7.0)) * 0.6);
	} else if (pattern < 1.5) {
		// Flagstones
		vec2 tp = p / vec2(112.0, 80.0);
		tp.x += step(1.0, mod(floor(tp.y), 2.0)) * 0.5;
		vec2 f = fract(tp);
		vec2 id = floor(tp);
		float mortar = smoothstep(0.0, 0.035, f.x) * smoothstep(0.0, 0.035, 1.0 - f.x) * smoothstep(0.0, 0.05, f.y) * smoothstep(0.0, 0.05, 1.0 - f.y);
		float tint = 0.82 + 0.3 * hash(id);
		g *= tint;
		g = mix(g * 0.35, g, mortar);
		float worn = fbm(p * 0.01 + 3.0);
		g = mix(g, col_b.rgb * 0.8, smoothstep(0.6, 0.9, worn) * 0.6);
		float crack = 1.0 - smoothstep(0.0, 0.04, vor.y);
		g *= 1.0 - crack * 0.35 * step(0.6, hash(id + 3.1));
	} else if (pattern < 2.5) {
		// Marsh: murky water between islands of silt
		float water = smoothstep(0.52, 0.6, fbm(p * 0.004 + 11.0));
		vec3 wc = vec3(0.05, 0.07, 0.065) + 0.04 * fbm(p * 0.02 + TIME * 0.05);
		g = mix(g, wc, water * 0.85);
		g *= 1.0 - (1.0 - smoothstep(0.0, 0.05, vor.y)) * 0.3 * (1.0 - water);
	} else if (pattern < 3.5) {
		// Hell: obsidian glass, scorched black around rivers of lava
		float facet = hash(vec2(floor(vor.x * 40.0), 3.0));
		g *= 0.7 + 0.5 * facet;
		float crack = 1.0 - smoothstep(0.0, 0.05, vor.y);
		g *= 1.0 - crack * 0.7;
		float lava = smoothstep(0.64, 0.7, fbm(p * 0.0035 + 31.0));
		float scorch = smoothstep(0.54, 0.66, fbm(p * 0.0035 + 31.0));
		g = mix(g, g * 0.35, scorch);
		g = mix(g, vec3(0.35, 0.08, 0.02), lava);
	} else if (pattern < 4.5) {
		// Forest floor: moss, leaf litter and roots
		float moss = smoothstep(0.45, 0.75, fbm(p * 0.008 + 21.0));
		g = mix(g, g * vec3(0.72, 0.95, 0.68), moss * 0.6);
		float leaves = step(0.8, hash(floor(p * 0.12))) * 0.22;
		g *= 1.0 - leaves;
		vec2 rv = voronoi(p * 0.006 + 5.0);
		float root = 1.0 - smoothstep(0.0, 0.03, rv.y);
		g = mix(g, vec3(0.08, 0.065, 0.045), root * 0.8 * smoothstep(0.4, 0.7, fbm(p * 0.01 + 2.0)));
		g = mix(g, g * 0.6, smoothstep(0.5, 0.8, fbm(p * 0.005 + 9.0)) * 0.5);
	} else {
		// Catacombs: small worn tiles, grime, and bones everywhere
		vec2 tp = p / vec2(64.0, 64.0);
		vec2 f = fract(tp);
		vec2 id = floor(tp);
		float mortar = smoothstep(0.0, 0.05, f.x) * smoothstep(0.0, 0.05, 1.0 - f.x) * smoothstep(0.0, 0.05, f.y) * smoothstep(0.0, 0.05, 1.0 - f.y);
		g *= 0.78 + 0.32 * hash(id);
		g = mix(g * 0.3, g, mortar);
		g = mix(g, col_b.rgb * 0.55, smoothstep(0.55, 0.85, fbm(p * 0.007 + 13.0)) * 0.55);
		vec2 bp = p * 0.035;
		vec2 bid = floor(bp);
		vec2 bf = fract(bp) - 0.5;
		if (hash(bid + 9.0) > 0.965) {
			float ang = hash(bid + 1.0) * 6.2831;
			vec2 dd = vec2(cos(ang), sin(ang));
			float along = dot(bf, dd);
			float across = abs(dot(bf, vec2(-dd.y, dd.x)));
			float bone = (1.0 - smoothstep(0.04, 0.07, across)) * (1.0 - smoothstep(0.26, 0.32, abs(along)));
			bone = max(bone, 1.0 - smoothstep(0.07, 0.1, length(vec2(abs(along) - 0.3, across))));
			g = mix(g, vec3(0.5, 0.47, 0.4), bone * 0.85);
		}
	}

	// Darken the floor close to walls
	float ao = smoothstep(0.35, 0.95, m);
	g *= 0.55 + 0.45 * ao;

	vec3 wall = col_wall.rgb * (0.5 + 0.9 * fbm(p * 0.008));
	float rim = smoothstep(0.38, 0.47, edge) * (1.0 - smoothstep(0.47, 0.56, edge));
	vec3 col = mix(wall, g, floor_amt);
	col += vec3(0.08, 0.07, 0.065) * rim;
	COLOR = vec4(col, 1.0);
}
