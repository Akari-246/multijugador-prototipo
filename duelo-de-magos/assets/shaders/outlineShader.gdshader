shader_type canvas_item;

uniform bool enabled = false;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 0.0, 1.0);
uniform float outline_width = 2.0;

void fragment() {
	vec4 color = texture(TEXTURE, UV);

	if (enabled && color.a < 0.5) {
		for (float y = -outline_width; y <= outline_width; y += 1.0) {
			for (float x = -outline_width; x <= outline_width; x += 1.0) {
				vec2 offset = vec2(x, y) / vec2(textureSize(TEXTURE, 0));
				if (texture(TEXTURE, UV + offset).a > 0.5) {
					color = outline_color;
					break;
				}
			}
		}
	}

	COLOR = color;
}