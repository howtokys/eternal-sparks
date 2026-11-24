shader_type canvas_item;
render_mode unshaded;

void fragment() {
	// Keep the glow within the painted silhouette and on the sprite's pixel grid.
	vec4 bolt = COLOR;
	float column = mod(floor(UV.x / TEXTURE_PIXEL_SIZE.x), 30.0);
	float wave = 0.5 + 0.5 * sin(column * 0.5 - TIME * 18.0);
	float highlight = max(bolt.r, max(bolt.g, bolt.b));
	bolt.rgb = mix(bolt.rgb, vec3(1.0), wave * smoothstep(0.58, 1.0, highlight) * 0.19);
	COLOR = bolt;
}
