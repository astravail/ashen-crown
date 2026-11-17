shader_type canvas_item;
// Zone terrain. Every material is a height field as well as a colour, so the scene lights pick out
// each stone, root and ripple. Ground that is not walkable is raised: walls show a face to the south,
// throw a shadow, and their tops sink into darkness.

uniform sampler2D mask : filter_linear, repeat_disable;
uniform vec4 col_a : source_color;
uniform vec4 col_b : source_color;
uniform vec4 col_wall : source_color;
uniform float pattern = 0.0;
uniform vec2 map_px = vec2(9600.0);

varying vec2 wpos;
varying float gloss_v;

#include "res://shaders/terrain.gdshaderinc"

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 p = wpos;
	float e0 = edge_val(p);
	float e_s = edge_val(p + vec2(0.0, WALL_H));
	float fl = smoothstep(0.488, 0.512, e0);
	float face = (1.0 - fl) * smoothstep(0.488, 0.512, e_s);
	float fv = clamp((0.5 - e0) / max(e_s - e0, 0.03), 0.0, 1.0);

	vec3 A = col_a.rgb;
	vec3 B = col_b.rgb;
	float big = fbm(p * 0.0021);
	float mid = fbm3(p * 0.011 + 5.0);
	float fine = fbm3(p * 0.06);
	vec3 alb;
	float h = 0.0;
	float gloss = 0.0;

	if (pattern < 0.5) {
		// Trodden earth: paths worn pale and rutted by carts, ash in the hollows, stones and dry grass off the way
		float tn = fbm3(p * 0.0009 + 3.0);
		float off_path = abs(tn - 0.5);
		float path = 1.0 - smoothstep(0.016, 0.042, off_path);
		float rut = (1.0 - smoothstep(0.0, 0.004, abs(off_path - 0.0095))) * path;
		alb = mix(B * 1.5, A, smoothstep(0.25, 0.75, mid * 0.6 + big * 0.5)) * (0.84 + 0.32 * fine);
		h = mid * 5.0 + fine * 1.4;
		float ash = smoothstep(0.52, 0.74, fbm3(p * 0.006 + 40.0)) * (1.0 - path);
		alb = mix(alb, vec3(0.1, 0.092, 0.084) * (0.8 + 0.4 * fine), ash * 0.5);
		h = mix(h, h * 0.4 + 2.0, ash);
		alb = mix(alb, A * 1.18 * (0.9 + 0.2 * fine), path * 0.7);
		h = mix(h, 2.0 + fine * 0.8, path * 0.8);
		alb *= 1.0 - rut * 0.4;
		h -= rut * 2.2;
		// loose stones, in drifts
		vec3 pb = vor(p * 0.05 + 3.0);
		float peb = step(0.62, pb.z) * smoothstep(0.08 + 0.2 * fract(pb.z * 7.0), 0.04, pb.x) * smoothstep(0.5, 0.66, fbm3(p * 0.0045 + 90.0)) * (1.0 - path);
		alb = mix(alb, mix(B * 1.4, A * 1.1, fract(pb.z * 3.0)), peb);
		h += peb * 2.6;
		// dry grass: short blades, each at its own lean, in tufts
		vec2 gp = p * vec2(0.16, 0.085);
		gp.x += floor(gp.y) * 0.37;
		vec2 gi = floor(gp);
		float gh = hash(gi + 2.0);
		vec2 gf = fract(gp) - 0.5 - (hash2(gi) - 0.5) * vec2(0.7, 0.5);
		float blade = (1.0 - smoothstep(0.04, 0.13, abs(gf.x + gf.y * (gh - 0.5) * 2.2))) * step(abs(gf.y), 0.14 + 0.2 * gh);
		float tuft = blade * step(0.6, gh) * smoothstep(0.54, 0.7, fbm3(p * 0.007 + 55.0) + (fine - 0.5) * 0.2) * (1.0 - path) * (1.0 - ash);
		alb = mix(alb, mix(vec3(0.085, 0.07, 0.03), vec3(0.15, 0.125, 0.05), fract(gh * 5.0)), tuft * 0.8);
		h += tuft * 1.6;
	} else if (pattern < 1.5) {
		// Flagstones: uneven slabs, chipped edges, a few lifted or lost
		vec2 fc = flag_cell(p);
		float chip = fbm3(p * 0.045 + fc.y * 30.0);
		float d = fc.x - chip * 6.0 * step(0.5, fc.y);
		float missing = step(0.965, fc.y);
		float stone = smoothstep(0.4, 3.6, d) * (1.0 - missing);
		vec3 sc = mix(B * 1.25, A * 0.92, 0.3 + 0.7 * fract(fc.y * 7.3)) * (0.86 + 0.28 * fine);
		sc = mix(sc, B * 0.95, smoothstep(0.5, 0.8, big) * 0.5);
		sc *= 1.0 + 0.08 * smoothstep(4.0, 22.0, fc.x);
		vec3 seam = B * mix(0.42, 0.8, missing) * (0.7 + 0.6 * fine);
		alb = mix(seam, sc, stone);
		h = stone * (2.6 + (fract(fc.y * 3.1) - 0.5) * 1.8) + fine * 0.9 * stone + (1.0 - stone) * mid * 1.6;
		// a single fracture wandering across the odd stone
		float cn = fbm3(p * 0.013 + fc.y * 40.0);
		float crack = (1.0 - smoothstep(0.0, 0.011, abs(cn - 0.5))) * step(0.8, fract(fc.y * 5.7)) * stone * smoothstep(0.46, 0.54, fbm3(p * 0.03 + 77.0));
		alb *= 1.0 - crack * 0.5;
		h -= crack * 1.4;
		gloss = 0.25 * stone;
	} else if (pattern < 2.5) {
		// Marsh: silt and sedge, standing water in every low place
		float wl = fbm(p * 0.004 + 11.0);
		float water = smoothstep(0.53, 0.57, wl);
		float shore = smoothstep(0.44, 0.55, wl);
		vec3 mud = mix(B, A, smoothstep(0.3, 0.75, mid)) * (0.8 + 0.4 * fine);
		mud = mix(mud, mud * vec3(0.55, 0.6, 0.5), shore);
		float tuft = smoothstep(0.6, 0.78, fbm3(p * 0.02 + 70.0)) * (1.0 - shore);
		mud = mix(mud, A * vec3(0.72, 1.0, 0.58) * (0.7 + 0.6 * fbm3(p * 0.2)), tuft * 0.6);
		vec3 wc = mix(vec3(0.008, 0.014, 0.014), vec3(0.02, 0.034, 0.03), fbm3(p * 0.012 + vec2(TIME * 0.03, 0.0)));
		vec3 dw = vor(p * 0.09);
		float weed = step(0.78, dw.z) * smoothstep(0.3, 0.15, dw.x) * smoothstep(0.45, 0.7, fbm3(p * 0.008 + 3.0));
		wc = mix(wc, vec3(0.02, 0.04, 0.009), weed);
		alb = mix(mud, wc, water);
		float ripple = sin((p.x + p.y * 0.6) * 0.07 + TIME * 1.3 + mid * 9.0) * 0.3 + weed * 0.6;
		h = mix(mid * 6.0 + fine * 1.5 + tuft * 2.5 * fbm3(p * 0.2), ripple, water);
		gloss = mix(0.2 * shore, 1.0, water * (1.0 - weed));
	} else if (pattern < 3.5) {
		// Volcanic: plates of cooled crust over rivers of melt
		vec3 v = vor(p * 0.021 + mid * 0.6);
		float plate = smoothstep(0.02, 0.16, v.y - v.x);
		vec3 pc = mix(B, A, 0.25 + 0.75 * v.z) * (0.8 + 0.4 * fine);
		pc = mix(pc, pc * 0.6, smoothstep(0.5, 0.8, fbm3(p * 0.007 + 7.0)) * 0.6);
		alb = mix(B * 0.22, pc, plate);
		h = plate * (3.0 + v.z * 3.0) + fine * 1.2;
		float lv = fbm(p * 0.0035 + 31.0);
		float lava = smoothstep(0.64, 0.69, lv);
		alb = mix(alb, alb * 0.4, smoothstep(0.54, 0.66, lv));
		float crust = smoothstep(0.42, 0.6, fbm3(p * 0.03 + vec2(TIME * 0.05, TIME * 0.03)));
		alb = mix(alb, mix(vec3(0.5, 0.1, 0.02), vec3(0.01, 0.004, 0.003), crust), lava);
		h = mix(h, -2.0 + crust * 1.5, lava);
		gloss = 0.35 * plate * (1.0 - lava);
	} else if (pattern < 4.5) {
		// Forest floor: soil, moss, roots heaving through, a litter of needles
		vec3 soil = mix(B, A * vec3(0.85, 0.78, 0.6), smoothstep(0.3, 0.7, mid)) * (0.8 + 0.4 * fine);
		float mn = fbm3(p * 0.14);
		float moss = smoothstep(0.48, 0.7, fbm3(p * 0.008 + 21.0) + fine * 0.15);
		alb = mix(soil, A * vec3(0.7, 0.96, 0.55) * (0.6 + 0.5 * mn), moss * 0.75);
		h = mid * 5.0 + fine * 1.2 + moss * (1.5 + 1.5 * mn);
		// roots: long wandering ridges, thick where they leave the trunk and thinning to nothing
		float rn = fbm3(p * 0.0052 + 5.0);
		float rw = 0.004 + 0.012 * smoothstep(0.4, 0.7, fbm3(p * 0.004 + 2.0));
		float root = (1.0 - smoothstep(rw * 0.4, rw, abs(rn - 0.5))) * smoothstep(0.46, 0.6, fbm3(p * 0.0028 + 12.0));
		alb = mix(alb, vec3(0.014, 0.009, 0.006) * (0.8 + 0.6 * fine), root * 0.9);
		h += root * 5.0;
		vec2 lp = p * 0.07;
		vec2 li = floor(lp);
		float lh = hash(li + 4.0);
		vec2 lf = fract(lp) - 0.5 - (hash2(li) - 0.5) * 0.5;
		vec2 ld = vec2(cos(lh * 6.2831), sin(lh * 6.2831));
		float leaf = step(0.72, lh) * smoothstep(0.4, 0.6, fbm3(p * 0.006 + 33.0)) * (1.0 - smoothstep(0.03, 0.06, abs(dot(lf, vec2(-ld.y, ld.x))))) * (1.0 - smoothstep(0.16, 0.24, abs(dot(lf, ld))));
		alb = mix(alb, mix(vec3(0.033, 0.013, 0.004), vec3(0.064, 0.04, 0.008), fract(lh * 9.0)), leaf * 0.7 * (1.0 - root));
		h += leaf * 0.8;
		gloss = 0.1 * moss;
	} else {
		// Catacombs: small tiles on the diagonal, grime, and the dead underfoot
		vec3 dc = diamond_cell(p);
		float lost = step(0.93, dc.y);
		float tile = smoothstep(0.4, 4.0, dc.x - fbm3(p * 0.05 + dc.y * 20.0) * 5.0 * step(0.5, dc.y)) * (1.0 - lost);
		vec3 tc = mix(B * 1.15, A, 0.3 + 0.7 * fract(dc.y * 5.3)) * (0.85 + 0.3 * fine);
		tc *= 1.0 - 0.1 * dc.z;
		tc = mix(tc, B * 0.55, smoothstep(0.52, 0.82, fbm3(p * 0.007 + 13.0)) * 0.6);
		alb = mix(B * mix(0.34, 0.75, lost) * (0.75 + 0.5 * fine), tc, tile);
		h = tile * (2.6 + (fract(dc.y * 3.7) - 0.5) * 1.4) + fine * 0.8;
		vec2 bp = p * 0.035;
		vec2 bid = floor(bp);
		vec2 bf = fract(bp) - 0.5;
		if (hash(bid + 9.0) > 0.955) {
			float ang = hash(bid + 1.0) * 6.2831;
			vec2 dd = vec2(cos(ang), sin(ang));
			float along = dot(bf, dd);
			float across = abs(dot(bf, vec2(-dd.y, dd.x)));
			float shaft = (1.0 - smoothstep(0.035, 0.06, across)) * (1.0 - smoothstep(0.26, 0.31, abs(along)));
			float knob = 1.0 - smoothstep(0.06, 0.09, length(vec2(abs(along) - 0.3, across)));
			float bone = max(shaft, knob);
			alb = mix(alb, vec3(0.25, 0.21, 0.145) * (0.85 + 0.3 * fine), bone * 0.9);
			h += bone * 3.0;
		}
		gloss = 0.2 * tile;
	}

	// Dirt and rubble gather against the foot of every wall
	float foot = smoothstep(0.8, 0.52, e0);
	alb = mix(alb, B * 0.5 * (0.7 + 0.6 * fine), foot * 0.6);
	h += foot * mid * 3.0;
	gloss *= 1.0 - foot;

	vec2 g = vec2(dFdx(h) / dFdx(p.x), dFdy(h) / dFdy(p.y));
	vec3 n = normalize(vec3(-g * 0.9, 1.0));

	// Walls shade the ground beneath them: a low light from the north-west
	float s1 = smoothstep(0.47, 0.53, edge_val(p + vec2(-13.0, -24.0)));
	float s2 = smoothstep(0.45, 0.55, edge_val(p + vec2(-30.0, -54.0)));
	float shadow = mix(0.4, 1.0, s1 * (0.55 + 0.45 * s2));
	float ao = 0.62 + 0.38 * smoothstep(0.5, 0.92, e0);
	float sky = 0.84 + 0.4 * dot(n.xy, vec2(-0.55, -0.83));
	vec3 floor_col = alb * ao * shadow * sky * 0.5;

	// The face of the wall
	float fy = fv * WALL_H;
	vec3 wc;
	float wh;
	if ((pattern > 0.5 && pattern < 1.5) || pattern > 4.5) {
		// Coursed masonry
		float course = floor(fy / 14.5);
		float cy = fract(fy / 14.5);
		float bx = p.x / 36.0 + hash(vec2(course, 5.0)) * 3.0;
		float bid = hash(vec2(floor(bx), course));
		float bfx = fract(bx);
		float brick = smoothstep(0.6, 2.4, min(min(bfx, 1.0 - bfx) * 36.0, min(cy, 1.0 - cy) * 14.5));
		wc = mix(B * 0.9, A * 0.85, 0.3 + 0.7 * bid) * (0.8 + 0.4 * fine);
		wc = mix(B * 0.2, wc, brick * (1.0 - step(0.93, bid) * 0.7));
		wh = brick * 2.0;
	} else {
		// Living rock: strata, with fractures running down through it
		float strata = fbm3(vec2(p.x * 0.01, fy * 0.16 + mid * 3.0));
		float fracture = 1.0 - smoothstep(0.0, 0.03, abs(fbm3(vec2(p.x * 0.022, fy * 0.006) + 17.0) - 0.5));
		wc = mix(B * 0.75, A * 0.8, strata) * (0.8 + 0.4 * fine);
		wc *= 1.0 - fracture * 0.55;
		wh = strata * 3.0 - fracture * 2.0;
	}
	wc *= mix(0.25, 0.62, smoothstep(0.0, 0.55, fv));
	wc *= 1.0 + 0.55 * smoothstep(0.86, 0.98, fv);
	vec3 nf = normalize(vec3(-dFdx(wh) / dFdx(p.x) * 0.8, 0.72, 0.69));

	// The top of the wall, lost to the dark a little way back from its edge
	float near = max(e0, e_s);
	float vis = smoothstep(0.05, 0.5, near);
	vec3 top = mix(col_wall.rgb, B * 0.5, vis * vis) * (0.55 + 0.9 * fbm3(p * 0.02 + 3.0));
	float lip = smoothstep(0.4, 0.488, near) * (1.0 - face);
	top += A * 0.22 * lip * lip;

	vec3 col = mix(mix(top, wc, face), floor_col, fl);
	NORMAL = normalize(mix(mix(vec3(0.0, 0.0, 1.0), nf, face), n, fl));
	gloss_v = gloss * fl;
	COLOR = vec4(col, 1.0);
}

void light() {
	// Flat ground takes the light exactly as before; slopes toward the lamp brighten, slopes away fall off.
	vec3 L = LIGHT_DIRECTION;
	float d = clamp(dot(NORMAL, L) / max(L.z, 0.12), 0.0, 2.4);
	vec3 hv = normalize(L + vec3(0.0, 0.0, 1.0));
	float sp = pow(max(dot(NORMAL, hv), 0.0), 40.0) * gloss_v;
	LIGHT = vec4(LIGHT_COLOR.rgb * LIGHT_ENERGY * (COLOR.rgb * d + vec3(sp * 0.16)), LIGHT_COLOR.a);
}
