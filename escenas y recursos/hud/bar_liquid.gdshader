shader_type canvas_item;
// Barra de líquido horizontal (versión de heart_liquid.gdshader para barras).
// Se aplica a un ColorRect: se llena de izquierda a derecha y el borde del líquido ondula.
// Lo usan la barra del combo (combo_hud.gd) y la de vida de los enemigos (enemy_base.gd).

uniform float fill : hint_range(0.0, 1.0) = 1.0;
// Tamaño real del ColorRect en píxeles (lo setea el script; hace falta para la grilla de píxeles)
uniform vec2 bar_size = vec2(70.0, 7.0);
// Tamaño de cada "píxel" del efecto (1 = fino, 2 = más grueso)
uniform float pixel_size = 1.0;

uniform vec4 liquid_color : source_color = vec4(0.85, 0.2, 0.2, 1.0);
uniform vec4 surface_color : source_color = vec4(1.0, 0.55, 0.55, 1.0);
// Color del fondo de la barra (alpha 0 = transparente)
uniform vec4 back_color : source_color = vec4(0.0, 0.0, 0.0, 0.7);

// Cuánto se mueve el borde del líquido (en píxeles)
uniform float wave_amp = 1.5;
// Cantidad de ondas a lo alto de la barra
uniform float wave_freq = 1.0;
uniform float wave_speed = 4.0;

void fragment() {
	// Posición del píxel (ajustada a la grilla) dentro de la barra
	vec2 p = floor(UV * bar_size / pixel_size) * pixel_size;
	float y = p.y / bar_size.y;

	// La ola desaparece con la barra vacía o llena (si no, se saldría de los bordes)
	float amp = wave_amp * smoothstep(0.0, 0.1, fill) * (1.0 - smoothstep(0.9, 1.0, fill));
	float wave = sin(y * wave_freq * 6.2832 + TIME * wave_speed) * amp
			+ sin(y * wave_freq * 2.3 * 6.2832 - TIME * wave_speed * 1.4) * amp * 0.5;

	float edge = fill * bar_size.x + wave;
	float inside = step(p.x, edge) * step(0.001, fill);
	// Columna del borde un poco más clara (la "superficie"); no se ve con la barra llena
	float surface = inside * step(edge, p.x + pixel_size) * (1.0 - step(0.995, fill));

	vec4 liquid = vec4(mix(liquid_color.rgb, surface_color.rgb, surface), liquid_color.a);
	COLOR = mix(back_color, liquid, inside);
}
