shader_type canvas_item;
// Efecto de pantalla para TODO el juego (se dibuja encima con crt_overlay.gd).
// Une dos efectos en uno solo:
//   1. CRT:      aberración cromática + líneas de barrido fijas + brillo.
//   2. ESTÁTICA: líneas que se mueven + ruido de TV + viñeta (bordes oscuros).
// Todo lo que se puede ajustar está acá arriba, agrupado por efecto.

// ------------------------------------------------------------------ CRT
group_uniforms CRT;
uniform bool crt_enabled = true;
uniform float scanLineFac : hint_range(0.0, 1.0) = 0.1;      // oscuridad de las líneas fijas
uniform float scanLineWidth : hint_range(0.0, 0.5) = 0.25;   // grosor de las líneas fijas
uniform vec2 RESOLUTION = vec2(320.0, 180.0);                // cantidad de líneas (más alto = más finas)
uniform float linearFac = 1.3;                               // brillo de la imagen
uniform float nearestFac = 0.0;                              // mezcla con la imagen sin suavizar
uniform bool abberation_enabled = true;                      // aberración cromática
uniform float abberationFac = 0.002;                         // cuánto se separan los colores

// ------------------------------------------------------------------ ESTÁTICA
group_uniforms Estatica;
uniform bool static_enabled = true;
// Líneas que se mueven
uniform float scanlines_1 = 250.0;
uniform float scanlines_2 = 250.0;
uniform float scan_reduction = 0.02;                          // oscuridad de esas líneas
// Ruido de TV
uniform float static_noise_strength : hint_range(0.0, 1.0) = 0.15;
// Viñeta
uniform float vinnette_alpla : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float vinnette_inner_radius = 0.0;
uniform float vinnette_outer_radius = 1.0;
uniform float vinnette_strength : hint_range(0.0, 1.0) = 0.5; // qué tan oscuros quedan los bordes

// ------------------------------------------------------------------ Imagen de la pantalla
group_uniforms;
uniform sampler2D viewportNearest : hint_screen_texture, filter_nearest, repeat_disable;
uniform sampler2D viewportLinear : hint_screen_texture, filter_linear, repeat_disable;


float random(vec2 uv) {
	return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec4 color = texture(viewportNearest, uv);

	// 1. CRT
	if (crt_enabled) {
		float fy = fract(uv * RESOLUTION).y;
		float scanLine = 0.0;
		float chromaticStrength = abberation_enabled ? 1.0 : 0.0;
		if (fy < scanLineWidth || fy > 1.0 - scanLineWidth) {
			scanLine = scanLineFac;
		}
		color = vec4(0.0, 0.0, 0.0, 1.0);
		color.r += texture(viewportLinear, uv - vec2(chromaticStrength * abberationFac, 0.0)).r;
		color.b += texture(viewportLinear, uv + vec2(chromaticStrength * abberationFac, 0.0)).b;
		color.g += texture(viewportLinear, uv).g;
		color = mix(color * linearFac, vec4(0.0, 0.0, 0.0, 1.0), scanLine);
		color += texture(viewportNearest, uv) * nearestFac;
	}

	// 2. Estática: se aplica SOBRE el resultado del CRT
	if (static_enabled) {
		// Líneas que se mueven
		float moving1 = sin((uv.y + TIME) * scanlines_1) * scan_reduction - scan_reduction;
		float moving2 = sin((uv.y + TIME * 0.4) * scanlines_2) * scan_reduction - scan_reduction;
		color.rgb += vec3(moving1 + moving2);

		// Ruido de TV (cambia en cada cuadro)
		float noise = random(uv + vec2(fract(TIME), fract(TIME * 1.7)));
		color.rgb *= 1.0 + (noise - 0.5) * 2.0 * static_noise_strength;

		// Viñeta: oscurece los bordes
		float vx = abs(uv.x - 0.5) * 2.0;
		float vy = abs(uv.y - 0.5) * 0.0;
		float vq = 1.0 - (1.0 - sqrt(vx * vx + vy * vy) / vinnette_outer_radius) / (1.0 - vinnette_inner_radius);
		color.rgb *= 1.0 - clamp(vq, 0.0, 1.0) * vinnette_alpla * vinnette_strength;
	}

	COLOR = vec4(max(color.rgb, vec3(0.0)), 1.0);
}
