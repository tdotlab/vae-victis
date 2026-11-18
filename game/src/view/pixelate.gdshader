// Turns what is under it into chunky pixels, optionally snapped to a fixed
// palette with ordered dithering. Used by the pixel art styles (Art).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float px = 3.0;          // size of one art pixel, in 720p screen pixels
uniform vec2 origin = vec2(0.0); // where the map's origin is on screen, in real pixels
uniform vec3 palette[32];
uniform int palette_size = 0;
uniform float dither = 0.0;

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float cell = px * res.y / 720.0;
	// The grid moves with the map, so standing things don't shimmer as the
	// camera scrolls.
	vec2 g = floor((FRAGCOORD.xy - origin) / cell);
	vec2 base = g * cell + origin;
	vec3 c = vec3(0.0);
	for (int i = 0; i < 3; i++) {
		for (int j = 0; j < 3; j++) {
			vec2 p = base + cell * (vec2(float(i), float(j)) + 0.5) / 3.0;
			c += texture(screen_tex, p * SCREEN_PIXEL_SIZE).rgb;
		}
	}
	c /= 9.0;
	if (palette_size > 0) {
		ivec2 b = ivec2(mod(g, 4.0));
		c += (BAYER[b.y * 4 + b.x] / 16.0 - 0.47) * dither * 0.12;
		float best = 1e9;
		vec3 pick = c;
		for (int k = 0; k < 32; k++) {
			if (k >= palette_size) {
				break;
			}
			vec3 d = (palette[k] - c) * vec3(0.30, 0.59, 0.11);
			float e = dot(d, d) + 0.25 * dot(palette[k] - c, palette[k] - c);
			if (e < best) {
				best = e;
				pick = palette[k];
			}
		}
		c = pick;
	}
	COLOR = vec4(c, 1.0);
}
