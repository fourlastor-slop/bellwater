shader_type canvas_item;
// The sea: one pass over the finished frame. Below the surface, tint by depth, wobble the image,
// and lay light on it. Colours step in bands with ordered dither so it stays pixel art.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform sampler2D wave_tex : filter_nearest, repeat_disable;
uniform float surface_y = 400.0;
uniform float tick = 0.0;
uniform vec2 cam = vec2(0.0);
uniform float wave_x0 = 0.0;
uniform float wave_w = 1024.0;
uniform float dark = 0.0;
uniform vec2 light = vec2(160.0, 90.0);

const vec2 VIEW = vec2(320.0, 180.0);
const vec3 SHALLOW = vec3(0.16, 0.62, 0.62);
const vec3 MID = vec3(0.07, 0.36, 0.48);
const vec3 DEEP = vec3(0.05, 0.20, 0.38);
const vec3 FOAM = vec3(0.86, 0.98, 0.92);
const vec3 EDGE = vec3(0.44, 0.86, 0.78);

float bayer4(vec2 p) {
	ivec2 i = ivec2(mod(p, 4.0));
	int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[i.x + i.y * 4]) + 0.5) / 16.0;
}

void fragment() {
	vec2 p = floor(SCREEN_UV * VIEW);
	float wx = p.x + cam.x;
	float wy = p.y + cam.y;
	float ripple = (texture(wave_tex, vec2((wx - wave_x0) / wave_w, 0.5)).r - 0.502) * 21.0;
	float swell = sin(wx * 0.052 + tick * 1.3) * 1.3 + sin(wx * 0.13 - tick * 1.9) * 0.7;
	float surf = floor(surface_y + swell + ripple);
	float d = p.y - surf;

	vec3 col;
	float a = 0.0;
	if (d >= 0.0) {
		a = 1.0;
		float wob = d > 3.0 ? floor(sin(wy * 0.28 + tick * 2.2) * 1.4 + 0.5) : 0.0;
		vec3 base = texture(screen_tex, (p + vec2(wob, 0.0) + 0.5) / VIEW).rgb;

		float k = clamp(d / 150.0, 0.0, 1.0);
		float bands = 7.0;
		float dith = bayer4(p) - 0.5;
		k = clamp(floor(k * bands + dith * 0.9) / bands, 0.0, 1.0);
		vec3 tint = k < 0.5 ? mix(SHALLOW, MID, k * 2.0) : mix(MID, DEEP, (k - 0.5) * 2.0);
		float keep = mix(0.66, 0.40, k);
		// the diver's own pool of light, so you can always read what's around you
		float near = clamp(1.0 - length(p - light) / 70.0, 0.0, 1.0);
		near = floor(near * 4.0 + dith + 0.5) / 4.0 * clamp(d / 130.0, 0.0, 1.0);
		col = mix(tint, base * mix(tint * 1.8, vec3(1.0), 0.45), keep);
		col += near * (vec3(0.05, 0.11, 0.11) + base * 0.75);

		// slanted light shafts near the surface
		float shaft = sin((wx + wy * 0.55) * 0.075 + tick * 0.35) * sin((wx - wy * 0.2) * 0.031 - tick * 0.2);
		float fall = clamp(1.0 - d / 90.0, 0.0, 1.0);
		if (shaft > 0.35 && fall + dith * 0.4 > 0.5) {
			col += vec3(0.05, 0.09, 0.08);
		}
		// edge of the water: foam, then a bright lip
		if (d < 1.0) {
			col = FOAM;
		} else if (d < 2.0) {
			col = mix(col, EDGE, 0.75);
		} else if (d < 5.0 && mod(wx * 0.5 + floor(tick * 3.0) + wy, 7.0) < 1.0) {
			col = mix(col, EDGE, 0.5);
		}
	}

	if (dark > 0.0) {
		vec3 under = a > 0.5 ? col : texture(screen_tex, (p + 0.5) / VIEW).rgb;
		float dist = length(p - light);
		float lit = clamp(1.0 - dist / 104.0, 0.0, 1.0);
		lit = floor(lit * 5.0 + bayer4(p) * 0.99) / 5.0;
		float keep_light = mix(1.0, lit * 0.95 + 0.05, dark);
		col = under * keep_light;
		a = 1.0;
	}

	COLOR = vec4(col, a);
}
