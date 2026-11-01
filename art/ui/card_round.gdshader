shader_type canvas_item;

// 卡牌圆角遮罩：按 UV 换算到像素坐标，用圆角矩形 SDF 做 alpha 裁剪。
uniform vec2 card_size = vec2(140.0, 184.0);
uniform float radius : hint_range(0.0, 48.0) = 12.0;

void fragment() {
	vec2 p = UV * card_size;
	vec2 half_size = card_size * 0.5;
	vec2 q = abs(p - half_size) - (half_size - vec2(radius));
	float d = length(max(q, vec2(0.0))) - radius;
	float mask = 1.0 - smoothstep(-1.2, 1.2, d);
	vec4 col = texture(TEXTURE, UV);
	COLOR = vec4(col.rgb, col.a * mask);
}
