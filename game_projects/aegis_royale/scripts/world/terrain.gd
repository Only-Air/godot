class_name Terrain
extends StaticBody3D

## Real heightmap island: FastNoiseLite hills, flattened POI pads, road
## corridors and a coastline that drops into water.

const SIZE: float = 320.0
const RES: int = 100
const HALF: float = SIZE * 0.5

var heights: PackedFloat32Array = PackedFloat32Array()
var noise_a: FastNoiseLite
var noise_b: FastNoiseLite
var pads: Array = []
var roads: Array = []
var seed_value: int = 0

func generate(poi_pads: Array, road_list: Array, p_seed: int = 0) -> void:
	seed_value = p_seed
	pads = poi_pads
	roads = road_list
	collision_layer = 1
	collision_mask = 2 | 4
	add_to_group("terrain")
	_make_noise()
	_sample_field()
	_build_mesh()

func _make_noise() -> void:
	noise_a = FastNoiseLite.new()
	noise_a.seed = seed_value
	noise_a.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise_a.frequency = 0.0085
	noise_a.fractal_octaves = 4
	noise_a.fractal_gain = 0.48

	noise_b = FastNoiseLite.new()
	noise_b.seed = seed_value + 977
	noise_b.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise_b.frequency = 0.031
	noise_b.fractal_octaves = 2

func _raw_height(x: float, z: float) -> float:
	var d: float = maxf(absf(x), absf(z)) / HALF
	var coast: float = 1.0 - smoothstep(0.66, 1.02, d)
	var base: float = noise_a.get_noise_2d(x, z) * 11.0 + noise_b.get_noise_2d(x, z) * 2.4
	var plateau: float = 4.0 * (1.0 - smoothstep(0.0, 0.30, d))
	var h: float = (base + 8.0 + plateau) * coast
	return h - 2.2 * (1.0 - coast)

func _sample_field() -> void:
	var count: int = (RES + 1) * (RES + 1)
	heights.resize(count)
	var step: float = SIZE / float(RES)
	for j: int in RES + 1:
		for i: int in RES + 1:
			var x: float = -HALF + float(i) * step
			var z: float = -HALF + float(j) * step
			var h: float = _raw_height(x, z)
			heights[j * (RES + 1) + i] = h
	for pad in pads:
		var p: Dictionary = pad
		_flatten_pad(Vector2(p.get("x", 0.0), p.get("z", 0.0)), float(p.get("radius", 22.0)), float(p.get("blend", 16.0)))
	for road in roads:
		var r: Dictionary = road
		_flatten_road(r.get("a", Vector2.ZERO), r.get("b", Vector2.ZERO), float(r.get("width", 7.0)))

func _flatten_pad(center: Vector2, radius: float, blend: float) -> void:
	var target: float = _sample_raw(center.x, center.y)
	var step: float = SIZE / float(RES)
	for j: int in RES + 1:
		for i: int in RES + 1:
			var x: float = -HALF + float(i) * step
			var z: float = -HALF + float(j) * step
			var d: float = Vector2(x, z).distance_to(center)
			if d > radius + blend:
				continue
			var w: float = 1.0 - smoothstep(radius, radius + blend, d)
			var idx: int = j * (RES + 1) + i
			heights[idx] = lerpf(heights[idx], target, w)

func _flatten_road(a: Vector2, b: Vector2, width: float) -> void:
	var step: float = SIZE / float(RES)
	var ab: Vector2 = b - a
	var len_sq: float = maxf(ab.length_squared(), 0.001)
	for j: int in RES + 1:
		for i: int in RES + 1:
			var x: float = -HALF + float(i) * step
			var z: float = -HALF + float(j) * step
			var p: Vector2 = Vector2(x, z)
			var t: float = clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
			var closest: Vector2 = a + ab * t
			var d: float = p.distance_to(closest)
			if d > width + 9.0:
				continue
			var idx: int = j * (RES + 1) + i
			var w: float = 1.0 - smoothstep(width, width + 9.0, d)
			var road_h: float = _sample_raw(closest.x, closest.y) + 0.35
			heights[idx] = lerpf(heights[idx], road_h, w * 0.85)

func _sample_raw(x: float, z: float) -> float:
	var h: float = _raw_height(x, z)
	for pad in pads:
		var p: Dictionary = pad
		var d: float = Vector2(x, z).distance_to(Vector2(p.get("x", 0.0), p.get("z", 0.0)))
		var radius: float = float(p.get("radius", 22.0))
		var blend: float = float(p.get("blend", 16.0))
		if d <= radius + blend:
			var w: float = 1.0 - smoothstep(radius, radius + blend, d)
			h = lerpf(h, _raw_height(p.get("x", 0.0), p.get("z", 0.0)), w)
	return h

func height_at(x: float, z: float) -> float:
	if heights.is_empty():
		return 0.0
	var gx: float = (x + HALF) / SIZE * float(RES)
	var gz: float = (z + HALF) / SIZE * float(RES)
	gx = clampf(gx, 0.0, float(RES) - 0.001)
	gz = clampf(gz, 0.0, float(RES) - 0.001)
	var i0: int = int(gx)
	var j0: int = int(gz)
	var i1: int = mini(i0 + 1, RES)
	var j1: int = mini(j0 + 1, RES)
	var fx: float = gx - float(i0)
	var fz: float = gz - float(j0)
	var h00: float = heights[j0 * (RES + 1) + i0]
	var h10: float = heights[j0 * (RES + 1) + i1]
	var h01: float = heights[j1 * (RES + 1) + i0]
	var h11: float = heights[j1 * (RES + 1) + i1]
	return lerpf(lerpf(h00, h10, fx), lerpf(h01, h11, fx), fz)

func normal_at(x: float, z: float) -> Vector3:
	var e: float = 2.0
	var hl: float = height_at(x - e, z)
	var hr: float = height_at(x + e, z)
	var hd: float = height_at(x, z - e)
	var hu: float = height_at(x, z + e)
	return Vector3(hl - hr, 2.0 * e, hd - hu).normalized()

func slope_at(x: float, z: float) -> float:
	return 1.0 - normal_at(x, z).dot(Vector3.UP)

func _build_mesh() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step: float = SIZE / float(RES)
	var sand: Color = Color("c8bb8e")
	var grass: Color = Color("5d9450")
	var grass_dark: Color = Color("44703c")
	var rock: Color = Color("7b7268")
	var snow: Color = Color("d9dee2")

	for j: int in RES:
		for i: int in RES:
			var x0: float = -HALF + float(i) * step
			var z0: float = -HALF + float(j) * step
			var x1: float = x0 + step
			var z1: float = z0 + step
			var p00: Vector3 = Vector3(x0, heights[j * (RES + 1) + i], z0)
			var p10: Vector3 = Vector3(x1, heights[j * (RES + 1) + i + 1], z0)
			var p01: Vector3 = Vector3(x0, heights[(j + 1) * (RES + 1) + i], z1)
			var p11: Vector3 = Vector3(x1, heights[(j + 1) * (RES + 1) + i + 1], z1)
			var n: Vector3 = (p10 - p00).cross(p01 - p00).normalized()
			if n.y < 0.0:
				n = -n
			_emit(st, p00, p10, p11, n, sand, grass, grass_dark, rock, snow)
			_emit(st, p00, p11, p01, n, sand, grass, grass_dark, rock, snow)

	var mesh: ArrayMesh = st.commit()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mi.material_override = mat
	mi.name = "TerrainMesh"
	add_child(mi)

	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	cs.name = "TerrainCollision"
	add_child(cs)

func _emit(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3,
		sand: Color, grass: Color, grass_dark: Color, rock: Color, snow: Color) -> void:
	for p in [a, b, c]:
		st.set_normal(n)
		st.set_color(_vertex_color(p, n, sand, grass, grass_dark, rock, snow))
		st.add_vertex(p)

func _vertex_color(p: Vector3, n: Vector3, sand: Color, grass: Color, grass_dark: Color, rock: Color, snow: Color) -> Color:
	var slope: float = 1.0 - n.y
	var col: Color = grass
	if p.y < 1.1:
		col = sand
	elif slope > 0.42:
		col = rock
	elif p.y > 12.5:
		col = snow.lerp(rock, clampf((14.5 - p.y) / 2.0, 0.0, 1.0))
	else:
		var mix: float = clampf(slope * 1.8, 0.0, 1.0)
		col = grass.lerp(grass_dark, mix)
		if p.y > 9.0:
			col = col.lerp(snow, clampf((p.y - 9.0) / 4.0, 0.0, 0.55))
	var jitter: float = 0.94 + 0.12 * sin(p.x * 0.7) * cos(p.z * 0.6)
	return Color(col.r * jitter, col.g * jitter, col.b * jitter)
