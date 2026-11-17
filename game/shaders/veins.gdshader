shader_type canvas_item;
render_mode blend_add, unshaded;
// What glows in the ground: embers in the seams between stones, the melt between plates of crust,
// spores on the marsh water, fungus among the roots.

uniform sampler2D mask : filter_linear, repeat_disable;
uniform vec4 vein : source_color = vec4(1.0, 0.4, 0.1, 1.0);
uniform float vein_hdr = 3.0;
uniform float amount = 1.0;
uniform float pattern = 0.0;
uniform vec2 map_px = vec2(9600.0);

varying vec2 wpos;

#include "res://shaders/terrain.gdshaderinc"

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 p = wpos;
	float fl = smoothstep(0.52, 0.6, edge_val(p));
	float v = 0.0;
	float pulse = 1.0;
	// off the floor nothing glows, and the work below is expensive
	if (fl > 0.0) {
		float mid = fbm3(p * 0.011 + 5.0);
		float region = smoothstep(0.56, 0.74, fbm3(p * 0.0022 + 4.0));
		pulse = 0.7 + 0.3 * sin(TIME * 1.1 + vnoise(p * 0.01) * 12.0);
		if (pattern < 0.5) {
			// embers still alive under the ash, breathing
			vec3 em = vor(p * 0.035 + 4.0);
			float ash = smoothstep(0.52, 0.74, fbm3(p * 0.006 + 40.0));
			v = step(0.7, em.z) * smoothstep(0.22, 0.02, em.x) * ash * region * 1.6;
		} else if (pattern < 1.5) {
			vec2 fc = flag_cell(p);
			float lit = smoothstep(0.56, 0.74, fbm3(p * 0.017 + 60.0));
			v = ((1.0 - smoothstep(0.0, 1.6, fc.x)) * 0.6 + (1.0 - smoothstep(0.0, 9.0, fc.x)) * 0.1) * lit * region;
		} else if (pattern < 2.5) {
			float water = smoothstep(0.53, 0.57, fbm(p * 0.004 + 11.0));
			vec3 sp = vor(p * 0.05 + 2.0);
			float tw = 0.5 + 0.5 * sin(TIME * (1.0 + sp.z * 2.0) + sp.z * 40.0);
			v = step(0.86, sp.z) * smoothstep(0.16, 0.02, sp.x) * tw * water * 1.4;
			pulse = 1.0;
		} else if (pattern < 3.5) {
			vec3 pl = vor(p * 0.021 + mid * 0.6);
			float gap = pl.y - pl.x;
			v = ((1.0 - smoothstep(0.0, 0.03, gap)) * 0.5 + (1.0 - smoothstep(0.0, 0.14, gap)) * 0.1) * region;
			float lv = fbm(p * 0.0035 + 31.0);
			float lava = smoothstep(0.64, 0.69, lv);
			float crust = smoothstep(0.42, 0.6, fbm3(p * 0.03 + vec2(TIME * 0.05, TIME * 0.03)));
			v = mix(v, (1.0 - crust) * 0.9 + 0.08, lava);
			v += smoothstep(0.6, 0.64, lv) * (1.0 - smoothstep(0.64, 0.68, lv)) * 0.3;
		} else if (pattern < 4.5) {
			float near_root = (1.0 - smoothstep(0.0, 0.07, abs(fbm3(p * 0.0052 + 5.0) - 0.5))) * smoothstep(0.46, 0.6, fbm3(p * 0.0028 + 12.0));
			vec3 sp = vor(p * 0.07 + 8.0);
			v = step(0.8, sp.z) * smoothstep(0.2, 0.04, sp.x) * near_root * 1.6;
		} else {
			vec3 dc = diamond_cell(p);
			float lit = smoothstep(0.56, 0.74, fbm3(p * 0.017 + 60.0));
			v = ((1.0 - smoothstep(0.0, 1.5, dc.x)) * 0.6 + (1.0 - smoothstep(0.0, 8.0, dc.x)) * 0.1) * lit * region;
		}
	}
	COLOR = vec4(vein.rgb * vein_hdr * v * pulse * fl * amount * 0.5, 1.0);
}
