shader_type canvas_item;
// The game's central image: everything above the highest tide reached is bleached to sepia.
// Applied to the static world only. Anything that matters to play keeps its colour.

uniform float wet_y = 9999.0;
uniform float cam_x = 0.0;
uniform bool wet_only = false;

const vec3 R0 = vec3(0.16, 0.13, 0.12);
const vec3 R1 = vec3(0.34, 0.27, 0.22);
const vec3 R2 = vec3(0.54, 0.45, 0.35);
const vec3 R3 = vec3(0.74, 0.65, 0.50);
const vec3 R4 = vec3(0.92, 0.87, 0.74);

vec3 sepia(vec3 c) {
	float l = dot(c, vec3(0.3, 0.55, 0.15));
	l = clamp(l * 1.25 + 0.05, 0.0, 1.0);
	float s = l * 4.0;
	if (s < 1.0) return mix(R0, R1, step(0.5, s));
	if (s < 2.0) return mix(R1, R2, step(0.5, s - 1.0));
	if (s < 3.0) return mix(R2, R3, step(0.5, s - 2.0));
	return mix(R3, R4, step(0.5, s - 3.0));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float y = floor(SCREEN_UV.y * 180.0);
	float x = floor(SCREEN_UV.x * 320.0) + cam_x;
	// the wrack line wanders, as a tide line does
	float jag = floor(sin(x * 0.11) * 1.5 + sin(x * 0.037 + 2.0) * 2.5 + sin(x * 0.61) * 0.8);
	float d = y - (wet_y + jag);
	if (d < 0.0) {
		c.rgb = sepia(c.rgb);
		if (wet_only) {
			c.a = 0.0;
		}
	} else if (d < 2.0 && !wet_only) {
		c.rgb *= vec3(0.55, 0.6, 0.5);
	}
	COLOR = c;
}
