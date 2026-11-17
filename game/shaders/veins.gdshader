shader_type canvas_item;
render_mode blend_add, unshaded;
// Emissive ember veins in the ground cracks, and the glow of the abyss beyond the walls.

uniform sampler2D mask : filter_linear, repeat_disable;
uniform vec4 vein : source_color = vec4(1.0, 0.4, 0.1, 1.0);
uniform float vein_hdr = 3.0;
uniform float amount = 1.0;
uniform float pattern = 0.0;
uniform vec2 map_px = vec2(9600.0);

varying vec2 wpos;

#include "res://shaders/noise.gdshaderinc"

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 p = wpos;
	float m = texture(mask, p / map_px).r;
	float edge = m + (fbm(p * 0.018) - 0.5) * 0.42;
	float floor_amt = smoothstep(0.44, 0.56, edge);
	vec2 vor = voronoi(p * 0.012);
	float line = 1.0 - smoothstep(0.0, 0.016, vor.y);
	float soft = 1.0 - smoothstep(0.0, 0.07, vor.y);
	float zone_mask = smoothstep(0.6, 0.78, fbm(p * 0.0022 + 4.0));
	float pulse = 0.7 + 0.3 * sin(TIME * 1.1 + fbm(p * 0.01) * 12.0);
	float v = (line * 0.55 + soft * 0.12) * zone_mask * pulse * floor_amt;
	if (pattern > 0.5 && pattern < 1.5) {
		v *= step(0.75, hash(floor(p / vec2(112.0, 80.0))));
	}
	if (pattern > 4.5) {
		v *= step(0.8, hash(floor(p / vec2(64.0, 64.0))));
	}
	if (pattern > 2.5 && pattern < 3.5) {
		// Molten lava rivers, slowly churning
		float l = fbm(p * 0.0035 + 31.0);
		float lava = smoothstep(0.64, 0.72, l) * floor_amt;
		float churn = 0.6 + 0.4 * fbm(p * 0.02 + vec2(TIME * 0.15, -TIME * 0.1));
		v += lava * churn * 0.35 + smoothstep(0.6, 0.64, l) * (1.0 - smoothstep(0.64, 0.68, l)) * 0.25 * floor_amt;
	}
	// Abyss glow: embers smouldering far below the edges
	float abyss = (1.0 - floor_amt) * smoothstep(0.3, 0.46, edge) * 0.045;
	abyss += (1.0 - floor_amt) * smoothstep(0.7, 0.95, fbm(p * 0.004 + TIME * 0.02)) * 0.03;
	float total = (v * 0.5 + abyss) * amount;
	COLOR = vec4(vein.rgb * vein_hdr * total, 1.0);
}
