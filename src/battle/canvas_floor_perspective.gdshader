// canvas_floor_perspective.gdshader — battle floor perspective, ADR-0002 (Claude Code, 2026-11-02; on by default).
// Purpose: resamples the FLAT floor texture (FloorLayer + FloorDynamicLayer rendered into their own 800x360
// SubViewport) through the INVERSE homography per fragment, so the board shows as a true projective trapezoid
// (FloorPerspective.inverse_uv_basis). A 2-triangle textured quad would show the affine seam along its diagonal.
// Drawn by BattleCanvas on a Sprite2D covering the whole art canvas, between BackdropLayer and UnitLayer.
// Nearest sampling: the warp never blends two art px (pixel-art rule); rows at the back drop / repeat source
// rows (accepted look, ADR-0002). A "row snap" of the sampled flat v to whole art rows was tried and dropped: the
// inverse map gives every output row ONE flat v, and nearest sampling already picks that whole row, so the snap changed
// 0 px of the 1280x720 capture (2026-11-02).
// Target: Godot 4.6 canvas_item, Mobile / Compatibility renderers (mobile touch-first game). Budget: one texture
// sample, one 3x3 multiply and one divide per fragment over the 800x360 art canvas; no loops, no variants.
shader_type canvas_item;
render_mode blend_mix;

group_uniforms perspective;
// Warped canvas UV -> flat canvas UV (homogeneous; FloorPerspective.inverse_uv_basis).
uniform mat3 inv_h = mat3(1.0);
// Flat U (0..1 across the canvas) of the divider between the halves (player left, enemy right).
uniform float divider_u : hint_range(0.0, 1.0) = 0.5;
group_uniforms;

group_uniforms half_tints;
// Multiply tints of the two halves (white = none); approved look: player teal-green, enemy purple.
uniform vec4 tint_player : source_color = vec4(1.0);
uniform vec4 tint_enemy : source_color = vec4(1.0);
group_uniforms;

void fragment() {
	vec3 q = inv_h * vec3(UV, 1.0);
	vec2 flat_uv = q.xy / q.z;
	// Outside the flat canvas (or behind the horizon, q.z <= 0): nothing of the floor maps here.
	float inside = step(0.0, q.z) * step(0.0, flat_uv.x) * step(flat_uv.x, 1.0) * step(0.0, flat_uv.y) * step(flat_uv.y, 1.0);
	if (inside < 0.5) {
		discard;
	}
	vec4 c = texture(TEXTURE, flat_uv);
	vec4 tint = mix(tint_player, tint_enemy, step(divider_u, flat_uv.x));
	COLOR = vec4(c.rgb * tint.rgb, c.a) * tint.a;
}
