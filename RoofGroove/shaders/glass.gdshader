shader_type canvas_item;
// Liquid-Glass style panel for Roof Groove (works in the GL Compatibility renderer).
// Blurs what is behind the panel, bends it a little near the edges (lens), adds a soft tint,
// a bright rim that faces the light and a faint top highlight. Set `size` from script.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec2 size = vec2(400.0, 300.0);
uniform float radius = 26.0;
uniform float blur : hint_range(0.0, 6.0) = 2.6;
uniform float refract_px = 14.0;
uniform vec4 tint : source_color = vec4(0.45, 0.55, 1.0, 0.20);
uniform vec2 light_dir = vec2(-0.6, -0.8);
uniform float rim_strength : hint_range(0.0, 1.5) = 0.9;

float sd_round_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - (half_size - vec2(r));
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = (UV - 0.5) * size;
	float d = sd_round_box(p, size * 0.5, radius);
	float shape = clamp(0.5 - d, 0.0, 1.0);

	// lens: near the edge, sample the screen slightly toward the centre
	float edge = smoothstep(-22.0, 0.0, d);
	vec2 n = normalize(p + vec2(0.0001));
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 suv = SCREEN_UV - n * edge * edge * refract_px * px;

	vec3 col = textureLod(screen_tex, suv, blur).rgb;
	col = mix(col, tint.rgb, tint.a);

	// soft top sheen
	float sheen = smoothstep(0.55, 0.0, UV.y) * 0.10;
	col += vec3(sheen);

	// specular rim facing the light, dim on the far side
	float rim = smoothstep(-2.2, -0.4, d) * shape;
	float facing = dot(n, normalize(light_dir)) * 0.5 + 0.5;
	col += vec3(1.0) * rim * rim_strength * (0.18 + 0.82 * facing * facing);

	COLOR = vec4(col, shape);
}
