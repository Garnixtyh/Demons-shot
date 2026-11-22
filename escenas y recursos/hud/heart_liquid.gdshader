shader_type canvas_item;
// Líquido que llena el corazón. Se aplica a un TextureRect que usa vida_fondo.png:
// el propio alpha del fondo recorta el líquido, así nunca se sale del corazón.

uniform float fill : hint_range(0.0, 1.0) = 1.0;
// Rango vertical (en UV, 0 = arriba, 1 = abajo) que ocupa el corazón dentro de la imagen.
// Si el PNG tiene bordes vacíos, ajustá estos valores para que "lleno" y "vacío" coincidan.
uniform float top : hint_range(0.0, 1.0) = 0.0;
uniform float bottom : hint_range(0.0, 1.0) = 1.0;

uniform vec4 liquid_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform vec4 surface_color : source_color = vec4(1.0, 0.45, 0.45, 1.0);

uniform float wave_amp = 0.5;
uniform float wave_freq = 2.0;
uniform float wave_speed = 4.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// Posición X en "pixeles" del sprite, para que la ola se vea pixel art
	float px = floor(UV.x / TEXTURE_PIXEL_SIZE.x) * TEXTURE_PIXEL_SIZE.x;

	// La ola desaparece con el corazón vacío o lleno (si no, taparía el borde)
	float amp = wave_amp * smoothstep(0.0, 0.12, fill) * (1.0 - smoothstep(0.88, 1.0, fill));
	float wave = sin(px * wave_freq * 6.2832 + TIME * wave_speed) * amp
			+ sin(px * wave_freq * 2.3 * 6.2832 - TIME * wave_speed * 1.4) * amp * 0.5;

	float level = mix(bottom, top, fill) + wave;
	// Se ajusta a la grilla de píxeles
	level = floor(level / TEXTURE_PIXEL_SIZE.y) * TEXTURE_PIXEL_SIZE.y;

	float inside = step(level, UV.y);
	// Fila superior un poco más clara (borde de la "superficie")
	float surface_row = inside - step(level + TEXTURE_PIXEL_SIZE.y, UV.y);

	vec3 col = mix(liquid_color.rgb, surface_color.rgb, surface_row);
	float visible = step(0.001, fill);
	COLOR = vec4(col, tex.a * inside * visible);
}
