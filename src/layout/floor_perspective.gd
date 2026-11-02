class_name FloorPerspective
extends RefCounted
## PROTOTYPE (floor-perspective, 2026-11-02): the projective map that turns the flat board into a "real 3/4"
## trapezoid, so the user can judge screenshots before a full spec. Opt-in: `--floor-perspective=<back_ratio>`
## (DemoArgs) or combat.json `floor.perspective.back_ratio`; 0 / absent = off and nothing here is built.
##
## The map is a homography H (3x3, homogeneous) defined by the flat board rect B = (x0, y0, w, h) in ART px and
## the back ratio r (0 < r <= 1). In board-normalised coordinates u = (x - x0) / w, v = (y - y0) / h (v = 0 is
## the back / top row, v = 1 the front / bottom edge):
##
##     D(v)  = 1 + (r - 1) v                       (the perspective divisor; 1 at the back, r at the front)
##     u'    = 0.5 + (u - 0.5) r / D(v)            (the bottom edge keeps its width, the top shrinks to r w,
##                                                  symmetric about the board's vertical centre line)
##     v'    = r v / D(v)                           (the same divisor, so the rows get shorter towards the back:
##                                                  the midline v = 0.5 lands at r / (1 + r) < 0.5)
##
## i.e. H_norm = [[r, (r-1)/2, (1-r)/2], [0, r, 0], [0, r-1, 1]] on (u, v, 1). H in art px is the conjugate by the
## affine board frame; [method warp] / [method unwarp] evaluate it in closed form (no matrix inversion needed:
## v = Y / (r + (1 - r) Y), u = 0.5 + (X - 0.5) D(v) / r). [method inverse_uv_basis] packs the inverse (warped
## canvas UV -> flat canvas UV) as a Basis for the canvas_item shader that resamples the flat floor texture.
## r = 1 is the identity. The map is defined on the whole plane (units stand above their cell), it only becomes
## singular at D = 0, i.e. v = 1 / (1 - r) board heights BELOW the board (5.6 h at r = 0.82): never on screen.
##
## Screen-px helpers ([method warp_screen] and friends) go through ScreenLayout's art frame (art_rect / art_scale,
## an exact affine map), so the HUD, drops and touch input share one definition with the art layers.

## Default when combat.json / the flag name nothing: off.
const OFF: float = 0.0
## Back ratios outside (MIN_RATIO, 1] are treated as off (the prototype reference is 0.82).
const MIN_RATIO: float = 0.3

## Back-row width over front-row width (0 < r <= 1).
var back_ratio: float = 1.0
## The flat board rect in ART px (the frame the homography is defined in).
var board: Rect2 = Rect2()
## Screen px of art px (0, 0) and the integer art scale (ScreenLayout.art_rect / art_scale): the art <-> screen frame.
var art_origin: Vector2 = Vector2.ZERO
var art_scale: float = 1.0
## The viewport size the instance was built for (cell polygons / cell_at read ScreenLayout with it).
var viewport_size: Vector2 = Vector2.ZERO


## Whether [param ratio] turns the perspective on (a finite ratio in (MIN_RATIO, 1]; exactly 1 is on but an identity,
## handy for tests).
static func is_on(ratio: float) -> bool:
	return is_finite(ratio) and ratio > MIN_RATIO and ratio <= 1.0


## The perspective of [param grid] at [param viewport_size] (screen px) with [param ratio], or null when off. The
## board frame is ScreenLayout.board_rect converted to art px the way FloorLayer converts cells (to_art_rect, so
## the warped board's edges land on the slabs' edges).
static func make(grid: BoardGrid, p_viewport_size: Vector2, ratio: float) -> FloorPerspective:
	if grid == null or not is_on(ratio):
		return null
	var out := FloorPerspective.new()
	out.back_ratio = ratio
	out.viewport_size = p_viewport_size
	out.board = Rect2(ScreenLayout.to_art_rect(p_viewport_size, ScreenLayout.board_rect(grid, p_viewport_size)))
	out.art_origin = ScreenLayout.art_rect(p_viewport_size).position
	out.art_scale = float(ScreenLayout.art_scale(p_viewport_size))
	return out


## The perspective of the battle [param combat] draws (its grid, viewport size and CombatView.floor_back_ratio),
## or null when off / unbound. Every layer and view asks this per draw; building one is a few float ops.
static func of(combat: CombatView) -> FloorPerspective:
	if combat == null or not is_instance_valid(combat) or combat.get_grid() == null or not combat.is_inside_tree():
		return null
	var ratio: float = combat.floor_back_ratio()
	if not is_on(ratio):
		return null
	return make(combat.get_grid(), combat.get_viewport_rect().size, ratio)


## Pure: flat point [param p] (any coordinate space) -> warped point, for the flat board frame [param b] and
## [param r] (the equations in the class doc).
static func warp_point(b: Rect2, r: float, p: Vector2) -> Vector2:
	if b.size.x <= 0.0 or b.size.y <= 0.0:
		return p
	var u: float = (p.x - b.position.x) / b.size.x
	var v: float = (p.y - b.position.y) / b.size.y
	var d: float = 1.0 + (r - 1.0) * v
	if absf(d) < 1e-9:
		return p
	var uw: float = 0.5 + (u - 0.5) * r / d
	var vw: float = r * v / d
	return Vector2(b.position.x + uw * b.size.x, b.position.y + vw * b.size.y)


## Pure: the inverse of [method warp_point] (warped -> flat).
static func unwarp_point(b: Rect2, r: float, p: Vector2) -> Vector2:
	if b.size.x <= 0.0 or b.size.y <= 0.0:
		return p
	var xw: float = (p.x - b.position.x) / b.size.x
	var yw: float = (p.y - b.position.y) / b.size.y
	var denom: float = r + (1.0 - r) * yw
	if absf(denom) < 1e-9:
		return p
	var v: float = yw / denom
	var d: float = 1.0 + (r - 1.0) * v
	var u: float = 0.5 + (xw - 0.5) * d / r
	return Vector2(b.position.x + u * b.size.x, b.position.y + v * b.size.y)


## Pure: the homography of [method warp_point] on the board frame [param b] as a row-major 3x3 (9 floats) acting on
## (x, y, 1) in the frame's own px; the warped point is (m0 x + m1 y + m2, m3 x + m4 y + m5) / (m6 x + m7 y + m8).
static func matrix_rows(b: Rect2, r: float) -> PackedFloat64Array:
	# H = T * H_norm * N where N: px -> (u, v, 1) and T: (u', v', 1) -> px (both affine), see the class doc.
	var n: PackedFloat64Array = PackedFloat64Array([1.0 / b.size.x, 0.0, -b.position.x / b.size.x, 0.0, 1.0 / b.size.y, -b.position.y / b.size.y, 0.0, 0.0, 1.0])
	var h: PackedFloat64Array = PackedFloat64Array([r, (r - 1.0) * 0.5, (1.0 - r) * 0.5, 0.0, r, 0.0, 0.0, r - 1.0, 1.0])
	var t: PackedFloat64Array = PackedFloat64Array([b.size.x, 0.0, b.position.x, 0.0, b.size.y, b.position.y, 0.0, 0.0, 1.0])
	return _mul3(t, _mul3(h, n))


## Pure: the inverse homography as a row-major 3x3 (the same frame as [method matrix_rows]).
static func inverse_matrix_rows(b: Rect2, r: float) -> PackedFloat64Array:
	var n: PackedFloat64Array = PackedFloat64Array([1.0 / b.size.x, 0.0, -b.position.x / b.size.x, 0.0, 1.0 / b.size.y, -b.position.y / b.size.y, 0.0, 0.0, 1.0])
	var h_inv: PackedFloat64Array = _inv3(PackedFloat64Array([r, (r - 1.0) * 0.5, (1.0 - r) * 0.5, 0.0, r, 0.0, 0.0, r - 1.0, 1.0]))
	var t: PackedFloat64Array = PackedFloat64Array([b.size.x, 0.0, b.position.x, 0.0, b.size.y, b.position.y, 0.0, 0.0, 1.0])
	return _mul3(t, _mul3(h_inv, n))


# The adjugate inverse of a row-major 3x3 (the identity when singular; the homography never is for r > 0).
static func _inv3(m: PackedFloat64Array) -> PackedFloat64Array:
	var det: float = m[0] * (m[4] * m[8] - m[5] * m[7]) - m[1] * (m[3] * m[8] - m[5] * m[6]) + m[2] * (m[3] * m[7] - m[4] * m[6])
	if absf(det) < 1e-12:
		return PackedFloat64Array([1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0])
	var inv: float = 1.0 / det
	return PackedFloat64Array([
		(m[4] * m[8] - m[5] * m[7]) * inv, (m[2] * m[7] - m[1] * m[8]) * inv, (m[1] * m[5] - m[2] * m[4]) * inv,
		(m[5] * m[6] - m[3] * m[8]) * inv, (m[0] * m[8] - m[2] * m[6]) * inv, (m[2] * m[3] - m[0] * m[5]) * inv,
		(m[3] * m[7] - m[4] * m[6]) * inv, (m[1] * m[6] - m[0] * m[7]) * inv, (m[0] * m[4] - m[1] * m[3]) * inv,
	])


## Pure: applies a row-major 3x3 [param m] to [param p] with the perspective divide.
static func apply_rows(m: PackedFloat64Array, p: Vector2) -> Vector2:
	var wz: float = m[6] * p.x + m[7] * p.y + m[8]
	if absf(wz) < 1e-12:
		return p
	return Vector2((m[0] * p.x + m[1] * p.y + m[2]) / wz, (m[3] * p.x + m[4] * p.y + m[5]) / wz)


## Pure: a row-major 3x3 as a Basis such that `basis * Vector3(x, y, 1)` equals the matrix product (Basis takes its
## three COLUMN vectors; a Basis shader parameter becomes the same mat3, so `mat * vec3(uv, 1.0)` agrees).
static func rows_to_basis(m: PackedFloat64Array) -> Basis:
	return Basis(Vector3(m[0], m[3], m[6]), Vector3(m[1], m[4], m[7]), Vector3(m[2], m[5], m[8]))


static func _mul3(a: PackedFloat64Array, b: PackedFloat64Array) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	out.resize(9)
	for i: int in 3:
		for j: int in 3:
			out[i * 3 + j] = a[i * 3] * b[j] + a[i * 3 + 1] * b[3 + j] + a[i * 3 + 2] * b[6 + j]
	return out


## Flat art point -> warped art point.
func warp(p: Vector2) -> Vector2:
	return warp_point(board, back_ratio, p)


## Warped art point -> flat art point (the inverse of [method warp]).
func unwarp(p: Vector2) -> Vector2:
	return unwarp_point(board, back_ratio, p)


## The four corners of flat art rect [param rect] warped, clockwise from the top-left (a convex quad; straight
## lines stay straight under a homography, so the edges are exact).
func warp_rect_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([warp(rect.position), warp(Vector2(rect.end.x, rect.position.y)), warp(rect.end), warp(Vector2(rect.position.x, rect.end.y))])


## The warped polygon (art px) of board cell [param cell] of [param grid]: its flat FloorLayer art rect through
## [method warp_rect_polygon].
func warped_cell_polygon(grid: BoardGrid, cell: Vector2i) -> PackedVector2Array:
	return warp_rect_polygon(Rect2(ScreenLayout.to_art_rect(viewport_size, ScreenLayout.cell_rect(grid, viewport_size, cell))))


## The board cell under the warped ART point [param point]: unwarp, then ScreenLayout.cell_at on the flat board
## (NO_CELL outside it; a missing cell is still returned, check BoardGrid.is_in_board).
func cell_at_warped(grid: BoardGrid, point: Vector2) -> Vector2i:
	return ScreenLayout.cell_at(grid, viewport_size, to_screen(unwarp(point)))


## Art px (float) -> screen px through the art frame (the float form of ScreenLayout.from_art).
func to_screen(art: Vector2) -> Vector2:
	return art_origin + art * art_scale


## Screen px -> art px (float; the unfloored form of ScreenLayout.to_art).
func to_art(screen: Vector2) -> Vector2:
	return (screen - art_origin) / art_scale


## Flat SCREEN point -> warped screen point.
func warp_screen(p: Vector2) -> Vector2:
	return to_screen(warp(to_art(p)))


## Warped SCREEN point -> flat screen point.
func unwarp_screen(p: Vector2) -> Vector2:
	return to_screen(unwarp(to_art(p)))


## The warped polygon of board cell [param cell] in SCREEN px (the HUD's ghost piece).
func warped_cell_polygon_screen(grid: BoardGrid, cell: Vector2i) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for pt: Vector2 in warped_cell_polygon(grid, cell):
		out.append(to_screen(pt))
	return out


## The board cell under the warped SCREEN point [param point] (touch input): [method cell_at_warped] in art px.
func cell_at_warped_screen(grid: BoardGrid, point: Vector2) -> Vector2i:
	return cell_at_warped(grid, to_art(point))


## The inverse homography (warped -> flat) in canvas UV space (art px / (800, 360)) as a Basis for the floor
## shader: `vec3 q = inv * vec3(UV, 1.0); flat_uv = q.xy / q.z`.
func inverse_uv_basis() -> Basis:
	var canvas: Vector2 = Vector2(ScreenLayout.ART_CANVAS_WIDTH, ScreenLayout.ART_CANVAS_HEIGHT)
	var to_px: PackedFloat64Array = PackedFloat64Array([canvas.x, 0.0, 0.0, 0.0, canvas.y, 0.0, 0.0, 0.0, 1.0])
	var to_uv: PackedFloat64Array = PackedFloat64Array([1.0 / canvas.x, 0.0, 0.0, 0.0, 1.0 / canvas.y, 0.0, 0.0, 0.0, 1.0])
	return rows_to_basis(_mul3(to_uv, _mul3(inverse_matrix_rows(board, back_ratio), to_px)))


## The flat divider's x as a canvas U (0..1) for the shader's half tints.
func divider_u(grid: BoardGrid) -> float:
	return to_art(Vector2(ScreenLayout.divider_x(grid, viewport_size), 0.0)).x / ScreenLayout.ART_CANVAS_WIDTH
