// Shared by ground.gdshader and veins.gdshader, so the glow in the seams lines up with the stones.
// The including shader declares `mask` and `map_px` first.

const float WALL_H = 58.0;

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

vec2 hash2(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.xx + q.yz) * q.zy);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm3(vec2 p) {
	float v = 0.5 * vnoise(p);
	p = p * 2.03 + vec2(1.7, 9.2);
	v += 0.25 * vnoise(p);
	p = p * 2.03 + vec2(1.7, 9.2);
	v += 0.125 * vnoise(p);
	return v * 1.1429;
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

// x: distance to the nearest cell point, y: to the second nearest, z: an id for the cell.
// (y - x) falls to zero on the joints between cells.
vec3 vor(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + hash2(n + g) - f;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = hash(n + g + 7.7);
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec3(sqrt(d1), sqrt(d2), id);
}

// Above 0.5 is walkable floor. The grid is softened and nudged about so no wall runs dead straight.
float edge_val(vec2 p) {
	float m = texture(mask, p / map_px).r;
	return m + (vnoise(p * 0.017) * 0.6 + vnoise(p * 0.051 + 13.7) * 0.4 - 0.5) * 0.36;
}

// Paving of uneven slabs laid in courses, some of them cut into two smaller stones.
// x: distance in px to the stone's edge, y: an id for the stone.
vec2 flag_cell(vec2 p) {
	float row = floor(p.y / 76.0);
	float fy = fract(p.y / 76.0);
	float x = p.x / 104.0 + hash(vec2(row, 3.0)) * 9.0;
	float col = floor(x);
	float fx = fract(x);
	float jl = (hash(vec2(col, row)) - 0.5) * 0.34;
	float jr = (hash(vec2(col + 1.0, row)) - 0.5) * 0.34;
	if (fx < jl) {
		col -= 1.0;
		fx += 1.0;
		jr = jl;
		jl = (hash(vec2(col, row)) - 0.5) * 0.34;
	} else if (fx > 1.0 + jr) {
		col += 1.0;
		fx -= 1.0;
		jl = jr;
		jr = (hash(vec2(col + 1.0, row)) - 0.5) * 0.34;
	}
	float w = 1.0 + jr - jl;
	vec2 uv = vec2((fx - jl) / w, fy);
	vec2 size = vec2(w * 104.0, 76.0);
	float id = hash(vec2(col, row) + 0.37);
	float sp = hash(vec2(col, row) + 5.11);
	if (sp > 0.6) {
		float s = 0.38 + 0.24 * fract(sp * 13.0);
		if (uv.x < s) {
			size.x *= s;
			uv.x /= s;
			id = fract(id * 3.7 + 0.11);
		} else {
			size.x *= 1.0 - s;
			uv.x = (uv.x - s) / (1.0 - s);
			id = fract(id * 5.3 + 0.57);
		}
	} else if (sp > 0.38) {
		float s = 0.4 + 0.2 * fract(sp * 17.0);
		if (uv.y < s) {
			size.y *= s;
			uv.y /= s;
			id = fract(id * 3.7 + 0.11);
		} else {
			size.y *= 1.0 - s;
			uv.y = (uv.y - s) / (1.0 - s);
			id = fract(id * 5.3 + 0.57);
		}
	}
	vec2 dd = min(uv, 1.0 - uv) * size;
	return vec2(min(dd.x, dd.y), id);
}

// Small tiles set on the diagonal. x: distance in px to the tile's edge, y: an id, z: chequer parity.
vec3 diamond_cell(vec2 p) {
	vec2 q = vec2(p.x + p.y, p.x - p.y) * 0.7071 / 60.0;
	vec2 id = floor(q);
	vec2 f = fract(q);
	float d = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)) * 60.0;
	return vec3(d, hash(id), mod(id.x + id.y, 2.0));
}
