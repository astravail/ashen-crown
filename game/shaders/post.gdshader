shader_type canvas_item;
render_mode unshaded, blend_disabled;
// The finishing pass over the world (never the HUD): drifting mist, a split-toned grade, lens
// falloff and fringing, film grain, heat shimmer, and the red closing-in when life runs low.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform vec3 shadow_tint = vec3(0.88, 0.96, 1.08);
uniform vec3 high_tint = vec3(1.08, 1.0, 0.9);
uniform vec3 fog_color = vec3(0.05, 0.055, 0.06);
uniform float fog_amount = 0.4;
uniform float saturation = 1.0;
uniform float exposure = 1.0;
uniform float vignette = 0.5;
uniform float grain = 0.05;
uniform float fringe = 0.0011;
uniform float kick = 0.0;
uniform float hurt = 0.0;
uniform float heat = 0.0;
uniform vec2 cam_pos = vec2(0.0);
uniform vec2 view_size = vec2(1280.0, 720.0);

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	vec2 wp = cam_pos + c * view_size;
	if (heat > 0.001) {
		vec2 wob = vec2(vnoise(wp * 0.018 + vec2(0.0, TIME * 1.6)), vnoise(wp * 0.018 + vec2(31.0, TIME * 1.3))) - 0.5;
		uv += wob * 0.0035 * heat;
	}
	float r2 = dot(c, c);
	vec2 off = c * (fringe * r2 * 6.0 + kick * 0.012 * (0.3 + r2 * 5.0));
	vec3 col = texture(screen_tex, uv).rgb;
	if (fringe + kick > 0.00001) {
		col.r = texture(screen_tex, uv + off).r;
		col.b = texture(screen_tex, uv - off).b;
	}

	// Mist lying over the ground, in slow banks, thicker at the edge of sight
	float bank = vnoise(wp * 0.0017 + vec2(TIME * 0.021, TIME * 0.008)) * 0.62 + vnoise(wp * 0.0052 - vec2(TIME * 0.03, 0.0)) * 0.38;
	float mist = smoothstep(0.3, 0.85, bank) * fog_amount * (0.15 + 1.6 * smoothstep(0.03, 0.4, r2));
	col = col * (1.0 - 0.18 * mist) + fog_color * mist;

	// The grade is for lit surfaces. Anything burning brighter than white keeps the colour it was given.
	float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
	vec3 graded = mix(vec3(lum), col, saturation) * mix(shadow_tint, high_tint, smoothstep(0.015, 0.4, lum));
	col = mix(graded, col, smoothstep(0.8, 1.6, max(col.r, max(col.g, col.b)))) * exposure;

	float vg = smoothstep(0.86, 0.22, length(c * vec2(1.0, 1.12)));
	col *= mix(1.0 - vignette, 1.0, vg);
	col = mix(col, col * vec3(1.3, 0.3, 0.26) + vec3(0.035, 0.0, 0.0), hurt * (1.0 - vg));

	float g = hash(FRAGCOORD.xy + fract(TIME) * 61.7) - 0.5;
	col += (min(col, vec3(1.0)) * 1.6 + 0.012) * g * grain;
	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
