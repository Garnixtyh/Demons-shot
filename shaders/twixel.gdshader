shader_type canvas_item;
// Efecto "Twixel" para TODO el juego (se dibuja encima con twixel_overlay.gd).
// Pixela la pantalla sobre una grilla ROTADA (por eso los píxeles quedan como rombos)
// y, opcionalmente, reemplaza cada color por el más parecido de una paleta.
//
// Es la versión 2D de un shader "spatial": la NIEBLA se sacó porque necesita la textura
// de profundidad (hint_depth_texture), que no existe en 2D.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;

// ------------------------------------------------------------------ TWIXEL
group_uniforms Twixel;
// Ángulo de la grilla (0 = píxeles cuadrados normales, 45 = rombos)
uniform float twixel_angle : hint_range(0.0, 45.0) = 45.0;
// Tamaño de cada "píxel", en píxeles REALES de la ventana
// (con 16 el juego se ve muy borroso: probá entre 2 y 6)
uniform float pixel_size : hint_range(1.0, 32.0) = 4.0;

// ------------------------------------------------------------------ PALETA
group_uniforms Paleta;
// Requiere asignar palette_texture (una imagen con los colores de la paleta, 1 píxel por color).
// Si no hay textura asignada, dejalo en false.
uniform bool quantize = false;
uniform sampler2D palette_texture : source_color, filter_nearest;


vec3 nearest_palette_color(vec3 original_color) {
	ivec2 palette_size = textureSize(palette_texture, 0);
	vec3 best = vec3(0.0, 1.0, 0.0); // verde de debug: si lo ves, la paleta está vacía
	float min_dist = 9999.0;
	for (int y = 0; y < palette_size.y; y++) {
		for (int x = 0; x < palette_size.x; x++) {
			// Se toma el centro de cada píxel de la paleta, no la esquina
			vec2 palette_uv = (vec2(float(x), float(y)) + 0.5) / vec2(palette_size);
			vec3 palette_color = textureLod(palette_texture, palette_uv, 0.0).rgb;
			float dist = distance(original_color, palette_color);
			if (dist < min_dist) {
				min_dist = dist;
				best = palette_color;
			}
		}
	}
	return best;
}

void fragment() {
	vec2 frag_coord = FRAGCOORD.xy;
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;

	// Se rota la coordenada, se redondea a la grilla y se vuelve a rotar
	float a = radians(twixel_angle);
	mat2 rotation = mat2(vec2(cos(a), -sin(a)), vec2(sin(a), cos(a)));
	vec2 rotated_coord = rotation * frag_coord;
	vec2 pixelated_coord = round(rotated_coord / pixel_size) * pixel_size;
	vec2 final_coord = transpose(rotation) * pixelated_coord;
	final_coord = clamp(final_coord, vec2(1.0), screen_size - vec2(1.0));

	vec3 color = textureLod(screen_tex, final_coord * SCREEN_PIXEL_SIZE, 0.0).rgb;
	if (quantize) {
		color = nearest_palette_color(color);
	}
	COLOR = vec4(color, 1.0);
}
