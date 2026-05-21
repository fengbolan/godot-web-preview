extends SceneTree

const FRAME_SIZE = 64
const DIRECTIONS = ["down", "right", "up", "left"]
const ACTIONS = {
	"idle": 4,
	"move": 8,
	"attack": 8,
	"dash": 6,
	"hurt": 4
}

func _init() -> void:
	_make_dir("res://assets/map")
	_make_dir("res://assets/sprites")
	_make_dir("res://assets/ui")

	var metadata = {}
	for action in ACTIONS.keys():
		metadata[action] = _generate_player_sheet(action, int(ACTIONS[action]))
	_generate_player_portrait()
	_generate_map()
	_generate_enemy_sprites()
	_generate_icons()
	_write_json("res://assets/sprites/player_dog_anim_meta.json", metadata)
	print("Generated Hoomans Are Gone assets")
	quit(0)

func _make_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))

func _write_json(path: String, data) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % path)
		quit(1)
	file.store_string(JSON.stringify(data, "\t"))

func _save_png(image: Image, path: String) -> void:
	var error = image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Could not save %s: %s" % [path, error])
		quit(1)

func _new_image(width: int, height: int, color = Color(0, 0, 0, 0)) -> Image:
	var image = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return image

func _generate_player_sheet(action: String, frames_per_direction: int) -> Dictionary:
	var sheet = _new_image(FRAME_SIZE * frames_per_direction, FRAME_SIZE * DIRECTIONS.size())
	var frames = {}
	for dir_index in range(DIRECTIONS.size()):
		var direction = String(DIRECTIONS[dir_index])
		frames[direction] = []
		for frame in range(frames_per_direction):
			var cell = _new_image(FRAME_SIZE, FRAME_SIZE)
			_draw_player_cell(cell, action, direction, frame, frames_per_direction)
			sheet.blend_rect(cell, Rect2i(0, 0, FRAME_SIZE, FRAME_SIZE), Vector2i(frame * FRAME_SIZE, dir_index * FRAME_SIZE))
			frames[direction].append({
				"source": [frame * FRAME_SIZE, dir_index * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE],
				"anchor": [32, 58],
				"source_size": [FRAME_SIZE, FRAME_SIZE]
			})
	_save_png(sheet, "res://assets/sprites/player_dog_%s_sheet.png" % action)
	return {
		"draw_scale": 1.0,
		"directions": DIRECTIONS,
		"frames_per_direction": frames_per_direction,
		"anchor": [32, 58],
		"source_size": [FRAME_SIZE, FRAME_SIZE],
		"frames": frames
	}

func _generate_player_portrait() -> void:
	var image = _new_image(FRAME_SIZE, FRAME_SIZE)
	_draw_player_cell(image, "idle", "down", 0, 4)
	_save_png(image, "res://assets/sprites/player_dog.png")

func _draw_player_cell(image: Image, action: String, direction: String, frame: int, frame_count: int) -> void:
	var dir = _direction_vector(direction)
	var side = Vector2(-dir.y, dir.x)
	var phase = float(frame) / max(1.0, float(frame_count))
	var gait = sin(phase * TAU)
	var foot = Vector2(32, 58)
	var body = Vector2(32, 38 + (gait * 1.4 if action == "move" else 0.0))
	var head = body + dir * 8.0 + Vector2(0, -13)
	if direction == "up":
		head = body + Vector2(0, -17)
	elif direction == "down":
		head = body + Vector2(0, -16)
	var fur = Color(0.93, 0.59, 0.22, 1)
	var fur_light = Color(1.0, 0.77, 0.34, 1)
	var scarf = Color(0.72, 0.05, 0.06, 1)
	var dark = Color(0.08, 0.04, 0.025, 1)
	var metal = Color(0.56, 0.65, 0.75, 1)
	var blade = Color(0.9, 0.98, 1.0, 1)
	if action == "hurt":
		fur = fur.lerp(Color(1.0, 0.25, 0.18), 0.35 if frame % 2 == 0 else 0.12)
		fur_light = fur_light.lerp(Color(1.0, 0.35, 0.24), 0.32)

	_ellipse(image, foot + Vector2(0, -1), Vector2(19, 5), Color(0, 0, 0, 0.28))
	if action == "dash":
		for i in range(3):
			_line(image, body - dir * float(18 + i * 7), body - dir * float(32 + i * 7), Color(0.1, 0.9, 1.0, 0.32 - i * 0.07), 5)

	var leg_swing = gait * (4.0 if action == "move" else 1.2)
	_circle(image, body + side * 10 + Vector2(0, 13 + leg_swing), 4.2, Color(0.68, 0.36, 0.13, 1))
	_circle(image, body - side * 10 + Vector2(0, 13 - leg_swing), 4.2, Color(0.68, 0.36, 0.13, 1))
	_ellipse(image, body, Vector2(17, 21), fur)
	_ellipse(image, body + Vector2(0, 3), Vector2(12, 14), fur_light)
	_line(image, body + Vector2(-14, -3), body + Vector2(14, -2), scarf, 4)

	var ear_left = head - side * 9 + Vector2(0, -7)
	var ear_right = head + side * 9 + Vector2(0, -7)
	_ellipse(image, ear_left, Vector2(5, 8), fur)
	_ellipse(image, ear_right, Vector2(5, 8), fur)
	_ellipse(image, head, Vector2(14, 13), fur_light)
	var muzzle = head + dir * 7 + Vector2(0, 3)
	_ellipse(image, muzzle, Vector2(7, 5), Color(1.0, 0.84, 0.5, 1))
	if direction != "up":
		_circle(image, head - side * 5 + dir * 4 + Vector2(0, -3), 1.8, dark)
		_circle(image, head + side * 5 + dir * 4 + Vector2(0, -3), 1.8, dark)
	_circle(image, muzzle + dir * 4, 2.2, dark)

	var shield_pos = body - side * 20 + dir * 4
	var sword_base = body + side * 18 + dir * 4
	var sword_len = 18.0
	if action == "attack":
		sword_len = 20.0 + sin(phase * PI) * 17.0
	elif action == "dash":
		sword_len = 26.0
	_circle(image, shield_pos, 9.5, metal)
	_circle(image, shield_pos, 6.5, Color(0.22, 0.34, 0.46, 1))
	_line(image, sword_base, sword_base + dir * sword_len, blade, 4)
	_line(image, sword_base - side * 5, sword_base + side * 5, Color(0.36, 0.2, 0.08, 1), 3)
	if action == "attack":
		_line(image, sword_base + dir * 8 - side * 10, sword_base + dir * sword_len + side * 10, Color(1.0, 0.88, 0.25, 0.48), 3)

func _generate_map() -> void:
	var image = _new_image(1280, 720, Color(0.05, 0.065, 0.075, 1))
	for y in range(720):
		var t = float(y) / 719.0
		for x in range(1280):
			var noise = fmod(float((x * 37 + y * 71) % 97), 97.0) / 97.0
			var base = Color(0.045 + t * 0.025 + noise * 0.012, 0.055 + noise * 0.012, 0.065 + t * 0.025, 1)
			image.set_pixel(x, y, base)
	_ellipse_outline(image, Vector2(640, 366), Vector2(560, 326), Color(0.23, 0.96, 1.0, 0.72), 4)
	for rect in [
		Rect2i(86, 84, 154, 42),
		Rect2i(1010, 104, 136, 48),
		Rect2i(60, 552, 190, 58),
		Rect2i(1018, 548, 176, 64),
		Rect2i(492, 82, 68, 36),
		Rect2i(716, 604, 104, 30),
		Rect2i(310, 184, 62, 34),
		Rect2i(870, 224, 74, 34)
	]:
		image.fill_rect(rect, Color(0.13, 0.13, 0.14, 1))
		_rect_outline(image, rect, Color(0.36, 0.32, 0.25, 1), 2)
	for crystal in [Vector2(276, 132), Vector2(978, 176), Vector2(190, 482), Vector2(1104, 462), Vector2(586, 138), Vector2(762, 554)]:
		_diamond(image, crystal, 18, Color(0.14, 0.9, 1.0, 0.72))
	_save_png(image, "res://assets/map/arena_base.png")

func _generate_enemy_sprites() -> void:
	_draw_enemy_sprite("crawler", Color(0.48, 0.18, 0.62, 1), 19, 4, false)
	_draw_enemy_sprite("spitter", Color(0.54, 0.22, 0.68, 1), 21, 5, true)
	_draw_enemy_sprite("brute", Color(0.33, 0.16, 0.43, 1), 29, 6, false)
	_draw_enemy_sprite("alpha", Color(0.58, 0.28, 0.88, 1), 38, 8, false)

func _draw_enemy_sprite(name: String, color: Color, radius: int, limbs: int, spitter: bool) -> void:
	var image = _new_image(96, 96)
	var center = Vector2(48, 50)
	_ellipse(image, center + Vector2(0, 8), Vector2(radius * 0.9, radius * 0.25), Color(0, 0, 0, 0.25))
	if name == "alpha":
		for i in range(8):
			var a = TAU * float(i) / 8.0
			_line(image, center, center + Vector2(cos(a), sin(a)) * (radius + (8 if i % 2 == 0 else 0)), color.lerp(Color.WHITE, 0.16), 9)
	else:
		for i in range(limbs):
			var a = TAU * float(i) / float(limbs)
			_line(image, center, center + Vector2(cos(a), sin(a)) * (radius + 10), color.darkened(0.22), 4)
	_circle(image, center, radius, color)
	_circle(image, center + Vector2(0, -4), radius * 0.48, color.lerp(Color.WHITE, 0.12))
	if spitter:
		_circle(image, center + Vector2(0, -10), 8, Color(0.3, 1.0, 0.32, 0.9))
	_circle(image, center + Vector2(-7, -7), 2.2, Color(0.05, 0.02, 0.06, 1))
	_circle(image, center + Vector2(7, -7), 2.2, Color(0.05, 0.02, 0.06, 1))
	_save_png(image, "res://assets/sprites/enemy_%s.png" % name)

func _generate_icons() -> void:
	_draw_icon("electric", Color(0.16, 0.92, 1.0, 1))
	_draw_icon("blade", Color(1.0, 0.78, 0.22, 1))
	_draw_icon("poison", Color(0.4, 1.0, 0.28, 1))
	_draw_icon("survival", Color(0.78, 0.9, 1.0, 1))

func _draw_icon(name: String, color: Color) -> void:
	var image = _new_image(64, 64)
	_circle(image, Vector2(32, 32), 26, Color(0.04, 0.06, 0.075, 1))
	_circle(image, Vector2(32, 32), 22, color.darkened(0.58))
	match name:
		"electric":
			_line(image, Vector2(34, 11), Vector2(22, 33), color, 5)
			_line(image, Vector2(22, 33), Vector2(35, 30), color, 5)
			_line(image, Vector2(35, 30), Vector2(27, 53), color, 5)
		"blade":
			_line(image, Vector2(20, 48), Vector2(45, 15), Color(0.95, 0.98, 1.0, 1), 5)
			_line(image, Vector2(17, 43), Vector2(27, 53), Color(0.45, 0.23, 0.08, 1), 5)
		"poison":
			_circle(image, Vector2(32, 36), 13, color)
			_line(image, Vector2(26, 17), Vector2(38, 17), color, 4)
			_line(image, Vector2(32, 17), Vector2(32, 29), color, 6)
		"survival":
			_circle(image, Vector2(32, 31), 16, Color(0.48, 0.58, 0.68, 1))
			_line(image, Vector2(32, 18), Vector2(32, 46), color, 4)
			_line(image, Vector2(19, 31), Vector2(45, 31), color, 4)
	_save_png(image, "res://assets/ui/icon_%s.png" % name)

func _direction_vector(direction: String) -> Vector2:
	match direction:
		"right":
			return Vector2.RIGHT
		"left":
			return Vector2.LEFT
		"up":
			return Vector2.UP
		_:
			return Vector2.DOWN

func _blend_pixel(image: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height() or color.a <= 0.0:
		return
	var dst = image.get_pixel(x, y)
	var out_a = color.a + dst.a * (1.0 - color.a)
	if out_a <= 0.0:
		image.set_pixel(x, y, Color(0, 0, 0, 0))
		return
	var out = Color(
		(color.r * color.a + dst.r * dst.a * (1.0 - color.a)) / out_a,
		(color.g * color.a + dst.g * dst.a * (1.0 - color.a)) / out_a,
		(color.b * color.a + dst.b * dst.a * (1.0 - color.a)) / out_a,
		out_a
	)
	image.set_pixel(x, y, out)

func _circle(image: Image, center: Vector2, radius: float, color: Color) -> void:
	var min_x = int(floor(center.x - radius))
	var max_x = int(ceil(center.x + radius))
	var min_y = int(floor(center.y - radius))
	var max_y = int(ceil(center.y + radius))
	var rr = radius * radius
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if center.distance_squared_to(Vector2(x, y)) <= rr:
				_blend_pixel(image, x, y, color)

func _ellipse(image: Image, center: Vector2, radii: Vector2, color: Color) -> void:
	var min_x = int(floor(center.x - radii.x))
	var max_x = int(ceil(center.x + radii.x))
	var min_y = int(floor(center.y - radii.y))
	var max_y = int(ceil(center.y + radii.y))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var dx = (float(x) - center.x) / max(1.0, radii.x)
			var dy = (float(y) - center.y) / max(1.0, radii.y)
			if dx * dx + dy * dy <= 1.0:
				_blend_pixel(image, x, y, color)

func _line(image: Image, start: Vector2, end: Vector2, color: Color, thickness: float) -> void:
	var steps = int(max(abs(end.x - start.x), abs(end.y - start.y))) + 1
	for i in range(steps + 1):
		var t = float(i) / max(1.0, float(steps))
		_circle(image, start.lerp(end, t), thickness * 0.5, color)

func _ellipse_outline(image: Image, center: Vector2, radii: Vector2, color: Color, thickness: int) -> void:
	var previous = center + Vector2(radii.x, 0)
	for i in range(1, 241):
		var a = TAU * float(i) / 240.0
		var next = center + Vector2(cos(a) * radii.x, sin(a) * radii.y)
		_line(image, previous, next, color, thickness)
		previous = next

func _rect_outline(image: Image, rect: Rect2i, color: Color, thickness: int) -> void:
	var a = Vector2(rect.position)
	var b = a + Vector2(rect.size.x, 0)
	var c = a + Vector2(rect.size)
	var d = a + Vector2(0, rect.size.y)
	_line(image, a, b, color, thickness)
	_line(image, b, c, color, thickness)
	_line(image, c, d, color, thickness)
	_line(image, d, a, color, thickness)

func _diamond(image: Image, center: Vector2, radius: float, color: Color) -> void:
	for y in range(int(center.y - radius), int(center.y + radius) + 1):
		for x in range(int(center.x - radius), int(center.x + radius) + 1):
			if abs(float(x) - center.x) + abs(float(y) - center.y) <= radius:
				_blend_pixel(image, x, y, color)
