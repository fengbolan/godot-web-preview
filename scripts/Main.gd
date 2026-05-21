extends Node2D

const WORLD_SIZE = Vector2(1280, 720)
const ARENA_CENTER = Vector2(640, 366)
const ARENA_RADII = Vector2(560, 326)
const PLAYER_START = ARENA_CENTER + Vector2(0, 84)
const RUN_TARGET = 720.0
const BOSS_TIMES = [180.0, 360.0, 540.0, 720.0]
const SAVE_PATH = "user://hoomans_save.json"

var rng = RandomNumberGenerator.new()
var font: Font

var state = "menu"
var enemy_defs: Dictionary = {}
var upgrade_defs: Array = []
var upgrade_by_id: Dictionary = {}
var meta_defs: Array = []
var animation_meta: Dictionary = {}
var arena_texture: Texture2D
var enemy_textures: Dictionary = {}
var player_textures: Dictionary = {}
var ui_icons: Dictionary = {}
var save_data: Dictionary = {}

var player: Dictionary = {}
var stats: Dictionary = {}
var enemies: Array = []
var pickups: Array = []
var projectiles: Array = []
var pools: Array = []
var hazards: Array = []
var supply_crates: Array = []
var effects: Array = []
var damage_numbers: Array = []
var notifications: Array = []
var upgrade_stacks: Dictionary = {}
var build_counts: Dictionary = {"电": 0, "刀": 0, "毒": 0, "生存": 0}
var upgrade_choices: Array = []
var boss_spawned: Array = [false, false, false, false]

var run_time = 0.0
var spawn_timer = 0.0
var next_supply_time = 42.0
var hitstop = 0.0
var shake = 0.0
var next_enemy_uid = 1
var game_summary: Dictionary = {}
var hover_pos = Vector2.ZERO
var static_ruins: Array = []
var static_crystals: Array = []
var static_fires: Array = []

func _ready() -> void:
	rng.randomize()
	font = ThemeDB.fallback_font
	_load_data()
	_load_save()
	_ensure_input_actions()
	_build_static_props()
	state = "menu"
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if state == "play":
		_update_game(delta)
	else:
		_update_effects(delta)
		_update_damage_numbers(delta)
		_update_notifications(delta)
		shake = max(0.0, shake - delta * 1.8)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover_pos = event.position
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_handle_escape()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hover_pos = event.position
		match state:
			"menu":
				_handle_menu_click(event.position)
			"meta":
				_handle_meta_click(event.position)
			"game_over":
				_handle_game_over_click(event.position)
			"level_up":
				_handle_level_up_click(event.position)
			"play":
				_try_slash(true)

func _load_data() -> void:
	enemy_defs.clear()
	for row in _load_json_array("res://Data/enemies.json"):
		enemy_defs[String(row["id"])] = row

	upgrade_defs = _load_json_array("res://Data/upgrades.json")
	upgrade_by_id.clear()
	for row in upgrade_defs:
		upgrade_by_id[String(row["id"])] = row

	meta_defs = _load_json_array("res://Data/meta_upgrades.json")
	var meta_variant = _load_json_dict("res://assets/sprites/player_dog_anim_meta.json")
	if typeof(meta_variant) == TYPE_DICTIONARY:
		animation_meta = meta_variant
	_load_player_textures()
	_load_world_textures()
	_load_enemy_textures()
	_load_ui_icons()

func _load_player_textures() -> void:
	player_textures.clear()
	for action in ["idle", "move", "attack", "dash", "hurt"]:
		var texture = _load_png_texture("res://assets/sprites/player_dog_%s_sheet.png" % action)
		if texture != null:
			player_textures[action] = texture
	var fallback = _load_png_texture("res://assets/sprites/player_dog.png")
	if fallback != null:
		player_textures["fallback"] = fallback

func _load_world_textures() -> void:
	arena_texture = _load_png_texture("res://assets/map/arena_base.png")

func _load_enemy_textures() -> void:
	enemy_textures.clear()
	for kind in enemy_defs.keys():
		var definition: Dictionary = enemy_defs[kind]
		var sprite_name = String(definition.get("sprite", ""))
		if sprite_name == "":
			continue
		var texture = _load_png_texture("res://assets/sprites/%s.png" % sprite_name)
		if texture != null:
			enemy_textures[String(kind)] = texture

func _load_ui_icons() -> void:
	ui_icons.clear()
	for icon_name in ["electric", "blade", "poison", "survival"]:
		var texture = _load_png_texture("res://assets/ui/icon_%s.png" % icon_name)
		if texture != null:
			ui_icons[icon_name] = texture

func _load_png_texture(path: String) -> Texture2D:
	var resource = load(path)
	if resource is Texture2D:
		return resource
	if not FileAccess.file_exists(path):
		return null
	var image = Image.load_from_file(path)
	if image == null or image.is_empty():
		push_warning("Could not load PNG texture: %s" % path)
		return null
	return ImageTexture.create_from_image(image)

func _load_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		push_warning("Missing JSON file: %s" % path)
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) == TYPE_ARRAY:
		return parsed
	push_warning("JSON file is not an array: %s" % path)
	return []

func _load_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Missing JSON file: %s" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	push_warning("JSON file is not a dictionary: %s" % path)
	return {}

func _default_save() -> Dictionary:
	return {
		"scrap": 0,
		"meta": {},
		"best_time": 0.0,
		"best_kills": 0,
		"best_combo": 0
	}

func _load_save() -> void:
	save_data = _default_save()
	if FileAccess.file_exists(SAVE_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			for key in save_data.keys():
				if parsed.has(key):
					save_data[key] = parsed[key]

func _save_game() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(save_data, "\t"))

func _ensure_input_actions() -> void:
	_bind_keys("move_left", [KEY_A, KEY_LEFT])
	_bind_keys("move_right", [KEY_D, KEY_RIGHT])
	_bind_keys("move_up", [KEY_W, KEY_UP])
	_bind_keys("move_down", [KEY_S, KEY_DOWN])
	_bind_keys("dash", [KEY_SPACE])
	_bind_keys("poison", [KEY_Q])
	_bind_keys("magnet", [KEY_R])

func _bind_keys(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	for keycode in keys:
		var event = InputEventKey.new()
		event.physical_keycode = int(keycode)
		InputMap.action_add_event(action, event)

func _build_static_props() -> void:
	static_ruins = [
		Rect2(86, 84, 154, 42),
		Rect2(1010, 104, 136, 48),
		Rect2(60, 552, 190, 58),
		Rect2(1018, 548, 176, 64),
		Rect2(492, 82, 68, 36),
		Rect2(716, 604, 104, 30),
		Rect2(310, 184, 62, 34),
		Rect2(870, 224, 74, 34)
	]
	static_crystals = [
		{"pos": Vector2(276, 132), "size": 22},
		{"pos": Vector2(978, 176), "size": 30},
		{"pos": Vector2(190, 482), "size": 26},
		{"pos": Vector2(1104, 462), "size": 24},
		{"pos": Vector2(586, 138), "size": 18},
		{"pos": Vector2(762, 554), "size": 20}
	]
	static_fires = [
		Vector2(148, 174),
		Vector2(1124, 202),
		Vector2(236, 592),
		Vector2(1028, 586)
	]

func _base_stats_from_meta() -> Dictionary:
	var meta: Dictionary = save_data.get("meta", {})
	var kennel = int(meta.get("kennel_training", 0))
	var coil = int(meta.get("coil_research", 0))
	var pockets = int(meta.get("field_pockets", 0))
	var boots = int(meta.get("old_world_boots", 0))
	return {
		"max_hp": 95.0 + kennel * 10.0,
		"move_speed": 154.0 + boots * 4.0,
		"damage_mult": 1.0 + coil * 0.05,
		"armor": 0.0,
		"pickup_radius": 58.0 + pockets * 12.0,
		"xp_gain": 1.0,
		"scrap_gain": 0.0,
		"electric_damage": 21.0,
		"electric_cooldown": 0.78,
		"chain_count": 3,
		"chain_range": 155.0,
		"fork_chance": 0.0,
		"thunder_cores": 0,
		"core_cds": [],
		"overload": false,
		"shock_damage": 0.0,
		"shock_execute": 0.0,
		"slash_damage": 25.0,
		"slash_cooldown": 0.96,
		"slash_range": 92.0,
		"slash_arc": 0.72,
		"slash_knockback": 42.0,
		"frenzy_duration": 0.0,
		"bleed_dps": 0.0,
		"execute_threshold": 0.0,
		"combo_damage": 0.0,
		"dash_slash": false,
		"dash_slash_damage": 0.0,
		"dash_cooldown": 2.5,
		"poison_damage": 9.0,
		"poison_cooldown": 5.2,
		"poison_duration": 4.0,
		"poison_radius": 54.0,
		"poison_slow": 0.0,
		"poison_vulnerability": 0.0,
		"death_poison": false,
		"plague_chain": false,
		"supply_luck": 0,
		"shield_burst": false,
		"shield_burst_damage": 0.0,
		"low_hp_damage": 0.0,
		"low_hp_speed": 0.0
	}

func _start_run() -> void:
	run_time = 0.0
	spawn_timer = 0.0
	next_supply_time = 42.0
	hitstop = 0.0
	shake = 0.0
	next_enemy_uid = 1
	boss_spawned = [false, false, false, false]
	enemies.clear()
	pickups.clear()
	projectiles.clear()
	pools.clear()
	hazards.clear()
	supply_crates.clear()
	effects.clear()
	damage_numbers.clear()
	notifications.clear()
	upgrade_stacks.clear()
	build_counts = {"电": 0, "刀": 0, "毒": 0, "生存": 0}
	upgrade_choices.clear()
	stats = _base_stats_from_meta()
	player = {
		"pos": PLAYER_START,
		"vel": Vector2.ZERO,
		"hp": stats["max_hp"],
		"max_hp": stats["max_hp"],
		"radius": 20.0,
		"level": 1,
		"xp": 0.0,
		"xp_next": 16.0,
		"kills": 0,
		"run_scrap": 0,
		"score": 0,
		"combo": 0,
		"combo_timer": 0.0,
		"max_combo": 0,
		"dash_cd": 0.0,
		"dash_time": 0.0,
		"dash_anim": 0.0,
		"dash_dir": Vector2.RIGHT,
		"dash_slash_pending": false,
		"invuln": 0.0,
		"hurt_time": 0.0,
		"attack_time": 0.0,
		"slash_cd": 0.25,
		"electric_cd": 0.35,
		"poison_cd": 1.0,
		"magnet_cd": 0.0,
		"shield_burst_cd": 0.0,
		"frenzy_timer": 0.0,
		"last_aim": Vector2.RIGHT,
		"facing": "down",
		"anim_time": 0.0
	}
	for i in range(8):
		_spawn_enemy("crawler")
	_notify("坚持 12 分钟，击败终局晶化首领。", Color(0.78, 0.95, 1.0))
	state = "play"

func _update_game(delta: float) -> void:
	if hitstop > 0.0:
		hitstop = max(0.0, hitstop - delta)
		_update_effects(delta)
		_update_damage_numbers(delta)
		return

	run_time += delta
	_update_player_timers(delta)
	_update_player_movement(delta)
	_update_spawning(delta)
	_update_boss_spawns()
	_update_hazards(delta)
	_update_supply(delta)
	_update_enemies(delta)
	_update_projectiles(delta)
	_update_pools(delta)
	_update_pickups(delta)
	_update_auto_weapons(delta)
	_update_effects(delta)
	_update_damage_numbers(delta)
	_update_notifications(delta)
	_cleanup_dead_enemies()
	_check_player_death()
	shake = max(0.0, shake - delta * 1.9)

func _update_player_timers(delta: float) -> void:
	for key in ["dash_cd", "slash_cd", "electric_cd", "poison_cd", "magnet_cd", "shield_burst_cd", "invuln", "hurt_time", "attack_time", "dash_anim", "frenzy_timer"]:
		player[key] = max(0.0, float(player.get(key, 0.0)) - delta)
	if player["combo_timer"] > 0.0:
		player["combo_timer"] = max(0.0, player["combo_timer"] - delta)
		if player["combo_timer"] <= 0.0:
			player["combo"] = 0
	player["anim_time"] += delta

func _update_player_movement(delta: float) -> void:
	var input_vec = Vector2.ZERO
	if Input.is_action_pressed("move_left"):
		input_vec.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_vec.x += 1.0
	if Input.is_action_pressed("move_up"):
		input_vec.y -= 1.0
	if Input.is_action_pressed("move_down"):
		input_vec.y += 1.0
	if input_vec.length() > 1.0:
		input_vec = input_vec.normalized()

	if Input.is_action_just_pressed("dash"):
		_try_dash(input_vec)
	if Input.is_action_just_pressed("poison"):
		_try_poison(true)
	if Input.is_action_just_pressed("magnet"):
		_try_magnet()

	var velocity = Vector2.ZERO
	if player["dash_time"] > 0.0:
		player["dash_time"] = max(0.0, player["dash_time"] - delta)
		velocity = player["dash_dir"] * 620.0
		if player["dash_time"] <= 0.0 and player["dash_slash_pending"]:
			player["dash_slash_pending"] = false
			if stats["dash_slash"]:
				_perform_dash_slash()
	else:
		var speed = float(stats["move_speed"])
		if player["frenzy_timer"] > 0.0:
			speed += 34.0
		if _player_hp_ratio() < 0.35:
			speed += float(stats["low_hp_speed"])
		velocity = input_vec * speed

	if input_vec.length() > 0.05:
		player["last_aim"] = input_vec.normalized()
		player["facing"] = _direction_name(input_vec)

	player["vel"] = velocity
	player["pos"] += velocity * delta
	player["pos"] = _clamp_to_arena(player["pos"], player["radius"])

func _try_dash(input_vec: Vector2) -> void:
	if player["dash_cd"] > 0.0:
		return
	var dir = input_vec
	if dir.length() < 0.1:
		dir = _aim_direction()
	if dir.length() < 0.1:
		dir = player["last_aim"]
	dir = dir.normalized()
	player["dash_dir"] = dir
	player["last_aim"] = dir
	player["facing"] = _direction_name(dir)
	player["dash_time"] = 0.18
	player["dash_anim"] = 0.30
	player["invuln"] = max(player["invuln"], 0.32)
	player["dash_cd"] = max(0.55, float(stats["dash_cooldown"]))
	player["dash_slash_pending"] = bool(stats["dash_slash"])
	effects.append({"type": "ring", "pos": player["pos"], "radius": 24.0, "ttl": 0.24, "max_ttl": 0.24, "color": Color(0.2, 0.9, 1.0, 0.72)})

func _try_slash(manual: bool) -> void:
	if state != "play" or player["slash_cd"] > 0.0:
		return
	var dir = _aim_direction() if manual else _direction_to_nearest_enemy()
	if dir.length() < 0.1:
		dir = player["last_aim"]
	_perform_slash(dir.normalized(), "manual" if manual else "auto")
	player["slash_cd"] = max(0.12, float(stats["slash_cooldown"]))

func _perform_slash(dir: Vector2, source: String) -> void:
	player["last_aim"] = dir
	player["facing"] = _direction_name(dir)
	player["attack_time"] = 0.25
	var slash_range = float(stats["slash_range"])
	var slash_arc = float(stats["slash_arc"])
	var hit_any = false
	for enemy in enemies:
		if enemy["hp"] <= 0.0:
			continue
		var to_enemy: Vector2 = enemy["pos"] - player["pos"]
		var distance = to_enemy.length()
		if distance <= slash_range + float(enemy["radius"]) and abs(dir.angle_to(to_enemy.normalized())) <= slash_arc:
			var dealt = _damage_enemy(enemy, float(stats["slash_damage"]), "slash")
			if dealt > 0.0:
				hit_any = true
				var push = dir * (float(stats["slash_knockback"]) / max(1.0, float(enemy["mass"])))
				enemy["pos"] += push
	var slash_color = Color(1.0, 0.78, 0.22, 0.86) if source == "manual" else Color(0.82, 0.95, 1.0, 0.72)
	effects.append({"type": "slash", "source": source, "pos": player["pos"], "dir": dir, "radius": slash_range, "arc": slash_arc, "ttl": 0.18, "max_ttl": 0.18, "color": slash_color})
	if hit_any:
		hitstop = max(hitstop, 0.018)

func _perform_dash_slash() -> void:
	var radius = 102.0
	var amount = float(stats["slash_damage"]) * (0.82 + float(stats["dash_slash_damage"]))
	for enemy in enemies:
		if enemy["hp"] > 0.0 and enemy["pos"].distance_to(player["pos"]) <= radius + float(enemy["radius"]):
			_damage_enemy(enemy, amount, "slash")
			var away: Vector2 = (enemy["pos"] - player["pos"]).normalized()
			enemy["pos"] += away * 70.0 / max(1.0, float(enemy["mass"]))
	effects.append({"type": "ring", "pos": player["pos"], "radius": radius, "ttl": 0.38, "max_ttl": 0.38, "color": Color(1.0, 0.82, 0.25, 0.78)})

func _try_poison(manual: bool) -> void:
	if state != "play" or player["poison_cd"] > 0.0:
		return
	var target = get_global_mouse_position() if manual else _nearest_enemy_position(player["pos"], 520.0)
	if not manual and target == Vector2.INF:
		return
	if manual and target.distance_to(player["pos"]) < 32.0:
		target = player["pos"] + player["last_aim"] * 180.0
	target = _clamp_to_arena(target, 8.0)
	var dir = (target - player["pos"]).normalized()
	if dir.length() < 0.1:
		dir = player["last_aim"]
	projectiles.append({
		"kind": "poison_vial",
		"pos": player["pos"] + dir * 18.0,
		"target": target,
		"vel": dir * 420.0,
		"life": 0.8,
		"radius": 9.0
	})
	player["poison_cd"] = max(0.12, float(stats["poison_cooldown"]))

func _try_magnet() -> void:
	if state != "play" or player["magnet_cd"] > 0.0:
		return
	for pickup in pickups:
		pickup["magnetized"] = true
	player["magnet_cd"] = 7.5
	effects.append({"type": "ring", "pos": player["pos"], "radius": float(stats["pickup_radius"]) + 220.0, "ttl": 0.42, "max_ttl": 0.42, "color": Color(0.45, 0.95, 1.0, 0.52)})

func _update_spawning(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer > 0.0:
		return
	spawn_timer = max(0.24, 1.08 - run_time / 620.0)
	var max_alive = int(46 + min(92.0, run_time / 4.0))
	if enemies.size() >= max_alive:
		return
	var pack = 1 + int(run_time / 110.0)
	for i in range(pack):
		if enemies.size() >= max_alive:
			break
		_spawn_enemy(_choose_enemy_kind())

func _choose_enemy_kind() -> String:
	var roll = rng.randf()
	if run_time > 130.0 and roll > 0.86:
		return "brute"
	if run_time > 55.0 and roll > 0.68:
		return "spitter"
	return "crawler"

func _update_boss_spawns() -> void:
	for i in range(BOSS_TIMES.size()):
		if not boss_spawned[i] and run_time >= BOSS_TIMES[i]:
			boss_spawned[i] = true
			var final = i == BOSS_TIMES.size() - 1
			_spawn_enemy("alpha", Vector2.INF, true, i, final)
			_notify("终局晶化首领出现！" if final else "晶化首领加入战场。", Color(1.0, 0.44, 0.34) if final else Color(0.75, 0.9, 1.0))

func _spawn_enemy(kind: String, pos = Vector2.INF, is_boss = false, boss_index = 0, final = false) -> void:
	if not enemy_defs.has(kind):
		return
	var base: Dictionary = enemy_defs[kind]
	var enemy_pos = pos
	if enemy_pos == Vector2.INF:
		enemy_pos = _spawn_point(56.0 if is_boss else 44.0)
	var hp = float(base["hp"])
	var speed = float(base["speed"])
	var damage = float(base["damage"])
	var radius = float(base["radius"])
	var elite = ""
	if is_boss:
		var hp_mult = 1.0 + boss_index * 0.58
		if final:
			hp_mult += 1.45
			radius += 16.0
		hp *= hp_mult
		speed *= 1.0 + boss_index * 0.08
		damage *= 1.0 + boss_index * 0.18
	else:
		hp *= 1.0 + run_time / 520.0
		speed *= 1.0 + run_time / 1100.0
		damage *= 1.0 + run_time / 720.0
		var elite_chance = clamp((run_time - 85.0) / 760.0, 0.0, 0.24)
		if rng.randf() < elite_chance:
			elite = ["swift", "armored", "volatile", "regenerating"][rng.randi_range(0, 3)]
			match elite:
				"swift":
					speed *= 1.45
					hp *= 0.88
				"armored":
					hp *= 1.68
					speed *= 0.84
				"volatile":
					damage *= 1.28
					speed *= 1.1
				"regenerating":
					hp *= 1.25
	var enemy = {
		"uid": next_enemy_uid,
		"id": kind,
		"name": base["name"],
		"pos": enemy_pos,
		"vel": Vector2.ZERO,
		"hp": hp,
		"max_hp": hp,
		"speed": speed,
		"damage": damage,
		"xp": int(base["xp"]),
		"radius": radius,
		"mass": float(base["mass"]) * (1.45 if elite == "armored" else 1.0),
		"score": int(base["score"]),
		"elite": elite,
		"is_boss": is_boss,
		"boss_index": boss_index,
		"final": final,
		"flash": 0.0,
		"poison_time": 0.0,
		"poison_dps": 0.0,
		"poison_slow": 0.0,
		"poison_vuln": 0.0,
		"bleed_time": 0.0,
		"bleed_dps": 0.0,
		"shock_time": 0.0,
		"shock_stacks": 0,
		"status_tick": 0.35,
		"regen_tick": 0.8,
		"shoot_cd": rng.randf_range(1.7, 2.7) if kind == "spitter" else 0.0,
		"cast_cd": rng.randf_range(3.2, 5.4) if is_boss else 0.0,
		"last_damage_kind": ""
	}
	next_enemy_uid += 1
	enemies.append(enemy)

func _spawn_point(extra: float) -> Vector2:
	var angle = rng.randf_range(0.0, TAU)
	var radii = ARENA_RADII + Vector2(extra, extra * 0.65)
	return ARENA_CENTER + Vector2(cos(angle) * radii.x, sin(angle) * radii.y)

func _random_point_inside() -> Vector2:
	var angle = rng.randf_range(0.0, TAU)
	var radius = sqrt(rng.randf())
	var pos = ARENA_CENTER + Vector2(cos(angle) * ARENA_RADII.x * radius, sin(angle) * ARENA_RADII.y * radius)
	return _clamp_to_arena(pos, 22.0)

func _update_enemies(delta: float) -> void:
	for enemy in enemies:
		if enemy["hp"] <= 0.0:
			continue
		_update_enemy_status(enemy, delta)
		if enemy["is_boss"]:
			_update_boss_cast(enemy, delta)
		var to_player: Vector2 = player["pos"] - enemy["pos"]
		var distance = max(1.0, to_player.length())
		var dir = to_player / distance
		var speed = float(enemy["speed"])
		if enemy["poison_time"] > 0.0:
			speed *= max(0.25, 1.0 - float(enemy["poison_slow"]))
		if enemy["id"] == "spitter" and distance < 330.0:
			speed *= 0.28
			enemy["shoot_cd"] = max(0.0, float(enemy["shoot_cd"]) - delta)
			if enemy["shoot_cd"] <= 0.0:
				_enemy_shoot(enemy, dir)
				enemy["shoot_cd"] = rng.randf_range(1.7, 2.7)
		enemy["vel"] = dir * speed
		enemy["pos"] += enemy["vel"] * delta
		enemy["pos"] = _clamp_to_arena(enemy["pos"], enemy["radius"], 44.0)
		if distance < float(enemy["radius"]) + float(player["radius"]) + 4.0:
			_damage_player(float(enemy["damage"]))

func _update_enemy_status(enemy: Dictionary, delta: float) -> void:
	enemy["flash"] = max(0.0, float(enemy["flash"]) - delta)
	if enemy["poison_time"] > 0.0:
		enemy["poison_time"] = max(0.0, float(enemy["poison_time"]) - delta)
	if enemy["bleed_time"] > 0.0:
		enemy["bleed_time"] = max(0.0, float(enemy["bleed_time"]) - delta)
	if enemy["shock_time"] > 0.0:
		enemy["shock_time"] = max(0.0, float(enemy["shock_time"]) - delta)
		if enemy["shock_time"] <= 0.0:
			enemy["shock_stacks"] = 0
	enemy["status_tick"] = float(enemy["status_tick"]) - delta
	if enemy["status_tick"] <= 0.0:
		enemy["status_tick"] = 0.35
		if enemy["poison_time"] > 0.0:
			_damage_enemy(enemy, float(enemy["poison_dps"]) * 0.35, "poison_dot")
		if enemy["bleed_time"] > 0.0:
			_damage_enemy(enemy, float(enemy["bleed_dps"]) * 0.35, "bleed")
	if enemy["elite"] == "regenerating":
		enemy["regen_tick"] = float(enemy["regen_tick"]) - delta
		if enemy["regen_tick"] <= 0.0:
			enemy["regen_tick"] = 0.8
			enemy["hp"] = min(float(enemy["max_hp"]), float(enemy["hp"]) + float(enemy["max_hp"]) * 0.018)

func _enemy_shoot(enemy: Dictionary, dir: Vector2) -> void:
	projectiles.append({
		"kind": "spit",
		"pos": enemy["pos"] + dir * float(enemy["radius"]),
		"vel": dir * 245.0,
		"damage": float(enemy["damage"]),
		"life": 4.0,
		"radius": 8.0
	})

func _update_boss_cast(enemy: Dictionary, delta: float) -> void:
	enemy["cast_cd"] = max(0.0, float(enemy["cast_cd"]) - delta)
	if enemy["cast_cd"] > 0.0:
		return
	var final = bool(enemy["final"])
	enemy["cast_cd"] = rng.randf_range(3.2, 4.8) if final else rng.randf_range(4.4, 6.4)
	var mode = rng.randi_range(0, 2)
	match mode:
		0:
			hazards.append({"type": "nova", "pos": enemy["pos"], "radius": 172.0 if final else 132.0, "warn": 0.88, "damage": float(enemy["damage"]) * 1.08, "armed": false})
		1:
			var count = 7 if final else 4
			for i in range(count):
				var offset = Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(48.0, 168.0)
				hazards.append({"type": "mark", "pos": _clamp_to_arena(player["pos"] + offset, 20.0), "radius": 42.0, "warn": rng.randf_range(0.62, 1.02), "damage": float(enemy["damage"]) * 0.82, "armed": false})
		2:
			var count = 5 if final else 3
			for i in range(count):
				_spawn_enemy("crawler" if rng.randf() < 0.78 else "spitter", _clamp_to_arena(enemy["pos"] + Vector2.from_angle(rng.randf_range(0, TAU)) * rng.randf_range(64, 110), 22.0))

func _update_hazards(delta: float) -> void:
	for i in range(hazards.size() - 1, -1, -1):
		var hazard: Dictionary = hazards[i]
		hazard["warn"] = float(hazard["warn"]) - delta
		if hazard["warn"] <= 0.0 and not bool(hazard["armed"]):
			hazard["armed"] = true
			if player["pos"].distance_to(hazard["pos"]) <= float(hazard["radius"]) + float(player["radius"]):
				_damage_player(float(hazard["damage"]))
			effects.append({"type": "ring", "pos": hazard["pos"], "radius": float(hazard["radius"]), "ttl": 0.24, "max_ttl": 0.24, "color": Color(1.0, 0.24, 0.18, 0.75)})
			hazards.remove_at(i)

func _update_supply(delta: float) -> void:
	if run_time >= next_supply_time:
		supply_crates.append({"pos": _random_point_inside(), "opened": false, "pulse": 0.0})
		next_supply_time = run_time + rng.randf_range(58.0, 78.0)
	for i in range(supply_crates.size() - 1, -1, -1):
		var crate: Dictionary = supply_crates[i]
		crate["pulse"] = float(crate["pulse"]) + delta
		if player["pos"].distance_to(crate["pos"]) < 46.0:
			_open_supply(crate["pos"])
			supply_crates.remove_at(i)

func _open_supply(pos: Vector2) -> void:
	var luck = int(stats["supply_luck"])
	var scrap_amount = 8 + int(run_time / 95.0) + luck * 3
	_spawn_pickup("scrap", pos + Vector2(-16, 4), scrap_amount)
	var xp_count = 4 + luck
	for i in range(xp_count):
		var angle = TAU * i / max(1, xp_count)
		_spawn_pickup("xp", pos + Vector2(cos(angle), sin(angle)) * 30.0, 10 + luck * 2)
	if rng.randf() < 0.55 + luck * 0.08:
		_spawn_pickup("heal", pos + Vector2(18, -4), 18 + luck * 4)
	effects.append({"type": "ring", "pos": pos, "radius": 74.0, "ttl": 0.38, "max_ttl": 0.38, "color": Color(0.45, 1.0, 0.62, 0.58)})

func _update_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = projectiles[i]
		projectile["life"] = float(projectile["life"]) - delta
		projectile["pos"] += projectile["vel"] * delta
		var remove = false
		if projectile["kind"] == "spit":
			if projectile["pos"].distance_to(player["pos"]) <= float(projectile["radius"]) + float(player["radius"]):
				_damage_player(float(projectile["damage"]))
				_create_poison_pool(projectile["pos"], 0.55, true)
				remove = true
		elif projectile["kind"] == "poison_vial":
			if projectile["pos"].distance_to(projectile["target"]) < 18.0 or projectile["life"] <= 0.0:
				_create_poison_pool(projectile["target"], 1.0, false)
				remove = true
		if projectile["life"] <= 0.0:
			remove = true
		if remove:
			projectiles.remove_at(i)

func _create_poison_pool(pos: Vector2, scale: float, hostile: bool) -> void:
	pools.append({
		"pos": _clamp_to_arena(pos, 8.0),
		"radius": float(stats["poison_radius"]) * scale,
		"duration": float(stats["poison_duration"]) * scale,
		"tick": 0.05,
		"damage": float(stats["poison_damage"]) * scale,
		"slow": float(stats["poison_slow"]),
		"vuln": float(stats["poison_vulnerability"]),
		"hostile": hostile
	})
	effects.append({"type": "ring", "pos": pos, "radius": float(stats["poison_radius"]) * scale, "ttl": 0.28, "max_ttl": 0.28, "color": Color(0.25, 1.0, 0.36, 0.42)})

func _update_pools(delta: float) -> void:
	for i in range(pools.size() - 1, -1, -1):
		var pool: Dictionary = pools[i]
		pool["duration"] = float(pool["duration"]) - delta
		pool["tick"] = float(pool["tick"]) - delta
		if pool["tick"] <= 0.0:
			pool["tick"] += 0.28
			if pool["hostile"]:
				if player["pos"].distance_to(pool["pos"]) <= float(pool["radius"]) + float(player["radius"]):
					_damage_player(max(2.0, float(pool["damage"]) * 0.35))
			else:
				for enemy in enemies:
					if enemy["hp"] > 0.0 and enemy["pos"].distance_to(pool["pos"]) <= float(pool["radius"]) + float(enemy["radius"]):
						_damage_enemy(enemy, float(pool["damage"]) * 0.28, "poison_dot")
						enemy["poison_time"] = max(float(enemy["poison_time"]), 3.6 + float(stats["poison_duration"]) * 0.18)
						enemy["poison_dps"] = max(float(enemy["poison_dps"]), float(stats["poison_damage"]) * 1.25)
						enemy["poison_slow"] = max(float(enemy["poison_slow"]), float(pool["slow"]))
						enemy["poison_vuln"] = max(float(enemy["poison_vuln"]), float(pool["vuln"]))
		if pool["duration"] <= 0.0:
			pools.remove_at(i)

func _update_pickups(delta: float) -> void:
	for i in range(pickups.size() - 1, -1, -1):
		var pickup: Dictionary = pickups[i]
		var to_player: Vector2 = player["pos"] - pickup["pos"]
		var distance = to_player.length()
		var radius = float(stats["pickup_radius"]) + (220.0 if pickup["magnetized"] else 0.0)
		if distance < radius:
			var pull_speed = 190.0 + (radius - distance) * 3.0
			pickup["pos"] += to_player.normalized() * pull_speed * delta
		if distance < 24.0:
			_collect_pickup(pickup)
			pickups.remove_at(i)

func _spawn_pickup(kind: String, pos: Vector2, amount: int) -> void:
	pickups.append({"kind": kind, "pos": _clamp_to_arena(pos, 8.0), "amount": amount, "magnetized": false, "bob": rng.randf_range(0.0, TAU)})

func _collect_pickup(pickup: Dictionary) -> void:
	match pickup["kind"]:
		"xp":
			_grant_xp(float(pickup["amount"]) * float(stats["xp_gain"]))
		"scrap":
			player["run_scrap"] += int(round(float(pickup["amount"]) * (1.0 + float(stats["scrap_gain"]))))
		"heal":
			player["hp"] = min(float(player["max_hp"]), float(player["hp"]) + float(pickup["amount"]))

func _grant_xp(amount: float) -> void:
	if state != "play":
		return
	player["xp"] += amount
	if player["xp"] >= player["xp_next"]:
		player["xp"] -= player["xp_next"]
		player["level"] += 1
		player["xp_next"] = floor(float(player["xp_next"]) * 1.18 + 8.0)
		_enter_level_up()

func _enter_level_up() -> void:
	_pick_upgrade_choices()
	state = "level_up"

func _pick_upgrade_choices() -> void:
	var available: Array = []
	for upgrade in upgrade_defs:
		var id = String(upgrade["id"])
		if int(upgrade_stacks.get(id, 0)) < int(upgrade["max_stacks"]):
			available.append(upgrade)
	available.shuffle()
	upgrade_choices = available.slice(0, min(3, available.size()))

func _apply_upgrade(id: String) -> void:
	if not upgrade_by_id.has(id):
		return
	var upgrade: Dictionary = upgrade_by_id[id]
	upgrade_stacks[id] = int(upgrade_stacks.get(id, 0)) + 1
	var build = String(upgrade["build"])
	build_counts[build] = int(build_counts.get(build, 0)) + 1
	var effects_dict: Dictionary = upgrade["effects"]
	for key in effects_dict.keys():
		var value = effects_dict[key]
		match String(key):
			"max_hp":
				stats["max_hp"] += float(value)
				player["max_hp"] += float(value)
				player["hp"] += float(value)
			"armor", "pickup_radius", "xp_gain", "scrap_gain", "move_speed", "low_hp_damage", "low_hp_speed", "chain_range", "electric_damage", "fork_chance", "shock_damage", "shock_execute", "slash_damage", "slash_arc", "slash_knockback", "frenzy_duration", "bleed_dps", "execute_threshold", "combo_damage", "dash_slash_damage", "poison_damage", "poison_duration", "poison_radius", "poison_slow", "poison_vulnerability", "shield_burst_damage":
				stats[String(key)] = stats.get(String(key), 0.0) + float(value)
			"chain_count", "supply_luck":
				stats[String(key)] = int(stats.get(String(key), 0)) + int(value)
			"thunder_cores":
				stats["thunder_cores"] = int(stats["thunder_cores"]) + int(value)
				stats["core_cds"].append(0.25)
			"electric_cooldown", "slash_cooldown", "poison_cooldown":
				stats[String(key)] = max(0.12, float(stats[String(key)]) + float(value))
			"dash_cooldown":
				stats["dash_cooldown"] = max(0.55, float(stats["dash_cooldown"]) + float(value))
			"overload", "dash_slash", "death_poison", "plague_chain", "shield_burst":
				stats[String(key)] = bool(value)
			_:
				push_warning("Unhandled upgrade effect key: %s" % String(key))
	state = "play"
	_notify("%s +1" % String(upgrade["name"]), _build_color(build))

func _update_auto_weapons(delta: float) -> void:
	if player["slash_cd"] <= 0.0:
		_try_slash(false)
	if player["electric_cd"] <= 0.0:
		_cast_electric(player["pos"], 1.0)
		player["electric_cd"] = max(0.12, float(stats["electric_cooldown"]))
	if float(stats["poison_cooldown"]) < 4.4 and player["poison_cd"] <= 0.0:
		_try_poison(false)
	var core_cds: Array = stats["core_cds"]
	for i in range(core_cds.size()):
		core_cds[i] = max(0.0, float(core_cds[i]) - delta)
		if core_cds[i] <= 0.0:
			var angle = run_time * 2.1 + TAU * float(i) / max(1.0, float(core_cds.size()))
			var core_pos: Vector2 = player["pos"] + Vector2(cos(angle), sin(angle)) * 66.0
			_cast_electric(core_pos, 0.62)
			core_cds[i] = 0.58

func _cast_electric(start_pos: Vector2, damage_scale: float) -> void:
	var origin = start_pos
	var visited: Array = []
	var chains = int(stats["chain_count"])
	for hop in range(chains):
		var search_range = float(stats["chain_range"]) + (80.0 if hop == 0 else 0.0)
		var target = _nearest_enemy(origin, search_range, visited)
		if target.is_empty():
			return
		visited.append(int(target["uid"]))
		_damage_enemy(target, float(stats["electric_damage"]) * damage_scale, "electric")
		effects.append({"type": "bolt", "from": origin, "to": target["pos"], "ttl": 0.14, "max_ttl": 0.14, "color": Color(0.27, 0.95, 1.0, 0.95)})
		if rng.randf() < float(stats["fork_chance"]):
			var fork = _nearest_enemy(target["pos"], float(stats["chain_range"]) * 0.85, visited)
			if not fork.is_empty():
				visited.append(int(fork["uid"]))
				_damage_enemy(fork, float(stats["electric_damage"]) * 0.58 * damage_scale, "electric")
				effects.append({"type": "bolt", "from": target["pos"], "to": fork["pos"], "ttl": 0.11, "max_ttl": 0.11, "color": Color(0.62, 1.0, 1.0, 0.75)})
		origin = target["pos"]

func _nearest_enemy(origin: Vector2, max_range: float, visited: Array = []) -> Dictionary:
	var best: Dictionary = {}
	var best_dist = max_range
	for enemy in enemies:
		if enemy["hp"] <= 0.0 or visited.has(int(enemy["uid"])):
			continue
		var dist = origin.distance_to(enemy["pos"])
		if dist < best_dist:
			best_dist = dist
			best = enemy
	return best

func _nearest_enemy_position(origin: Vector2, max_range: float) -> Vector2:
	var enemy = _nearest_enemy(origin, max_range)
	if enemy.is_empty():
		return Vector2.INF
	return enemy["pos"]

func _direction_to_nearest_enemy() -> Vector2:
	var enemy = _nearest_enemy(player["pos"], 420.0)
	if enemy.is_empty():
		return player["last_aim"]
	return (enemy["pos"] - player["pos"]).normalized()

func _damage_enemy(enemy: Dictionary, base_amount: float, kind: String, force_crit = false) -> float:
	if enemy.is_empty() or enemy["hp"] <= 0.0:
		return 0.0
	var dmg = base_amount * float(stats["damage_mult"])
	if _player_hp_ratio() < 0.35:
		dmg *= 1.0 + float(stats["low_hp_damage"])
	if int(player["combo"]) > 0 and float(stats["combo_damage"]) > 0.0:
		dmg *= 1.0 + min(0.45, int(player["combo"]) * float(stats["combo_damage"]))
	if enemy["poison_time"] > 0.0 and kind != "poison_dot":
		dmg *= 1.0 + float(enemy["poison_vuln"])
	var crit = force_crit
	var hp_ratio = float(enemy["hp"]) / max(1.0, float(enemy["max_hp"]))
	if kind == "slash" and float(stats["execute_threshold"]) > 0.0:
		var threshold = float(stats["execute_threshold"]) + min(0.08, int(player["combo"]) * 0.001)
		if hp_ratio <= threshold:
			dmg *= 1.75
			crit = true
	if kind == "electric" and float(stats["shock_execute"]) > 0.0 and int(enemy["shock_stacks"]) > 0:
		if hp_ratio <= float(stats["shock_execute"]):
			dmg *= 1.55
			crit = true
	if kind == "slash":
		var crit_chance = 0.05 + min(0.16, int(player["combo"]) * 0.002)
		if rng.randf() < crit_chance:
			crit = true
	if crit:
		dmg *= 1.85
	enemy["hp"] = float(enemy["hp"]) - dmg
	enemy["flash"] = 0.08
	enemy["last_damage_kind"] = kind
	_damage_number(enemy["pos"] + Vector2(rng.randf_range(-8, 8), -float(enemy["radius"])), int(round(dmg)), _damage_color(kind, crit))

	if kind == "electric":
		enemy["shock_stacks"] = min(8, int(enemy["shock_stacks"]) + 1)
		enemy["shock_time"] = 3.2
		if bool(stats["overload"]) and int(enemy["shock_stacks"]) >= 4:
			enemy["shock_stacks"] = 0
			effects.append({"type": "ring", "pos": enemy["pos"], "radius": 82.0, "ttl": 0.28, "max_ttl": 0.28, "color": Color(0.18, 0.93, 1.0, 0.65)})
			for other in enemies:
				if other["hp"] > 0.0 and other["uid"] != enemy["uid"] and other["pos"].distance_to(enemy["pos"]) <= 82.0 + float(other["radius"]):
					_damage_enemy(other, float(stats["electric_damage"]) + float(stats["shock_damage"]), "overload")
	if kind == "slash" and float(stats["bleed_dps"]) > 0.0:
		enemy["bleed_time"] = max(float(enemy["bleed_time"]), 2.6)
		enemy["bleed_dps"] = min(70.0, float(enemy["bleed_dps"]) + float(stats["bleed_dps"]))
	return dmg

func _damage_player(amount: float) -> void:
	if player.is_empty() or player["invuln"] > 0.0 or state != "play":
		return
	if bool(stats["shield_burst"]) and player["shield_burst_cd"] <= 0.0:
		player["shield_burst_cd"] = 7.5
		player["invuln"] = 0.75
		var burst_damage = 46.0 + float(stats["electric_damage"]) + float(stats["shield_burst_damage"])
		for enemy in enemies:
			if enemy["hp"] > 0.0 and enemy["pos"].distance_to(player["pos"]) <= 150.0 + float(enemy["radius"]):
				_damage_enemy(enemy, burst_damage, "electric")
		effects.append({"type": "ring", "pos": player["pos"], "radius": 150.0, "ttl": 0.32, "max_ttl": 0.32, "color": Color(0.34, 0.95, 1.0, 0.62)})
		return
	var taken = max(1.0, amount - float(stats["armor"]))
	player["hp"] = float(player["hp"]) - taken
	player["invuln"] = 0.48
	player["hurt_time"] = 0.32
	player["combo"] = 0
	player["combo_timer"] = 0.0
	hitstop = max(hitstop, 0.045)
	shake = max(shake, 0.34)
	_damage_number(player["pos"] + Vector2(0, -34), int(round(taken)), Color(1.0, 0.25, 0.22))

func _cleanup_dead_enemies() -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[i]
		if enemy["hp"] > 0.0:
			continue
		enemies.remove_at(i)
		_on_enemy_killed(enemy)

func _on_enemy_killed(enemy: Dictionary) -> void:
	if enemy["elite"] == "volatile":
		_volatile_explosion(enemy)
	if bool(stats["death_poison"]):
		_create_poison_pool(enemy["pos"], 0.8, false)
	if bool(stats["plague_chain"]) and enemy["poison_time"] > 0.0:
		for other in enemies:
			if other["hp"] > 0.0 and other["pos"].distance_to(enemy["pos"]) < 118.0:
				other["poison_time"] = max(float(other["poison_time"]), 2.6)
				other["poison_dps"] = max(float(other["poison_dps"]), float(stats["poison_damage"]) * 1.1)

	player["kills"] = int(player["kills"]) + 1
	player["combo"] = int(player["combo"]) + 1
	player["max_combo"] = max(int(player["max_combo"]), int(player["combo"]))
	player["combo_timer"] = 3.2
	player["score"] = int(player["score"]) + int(round(int(enemy["score"]) * (1.0 + min(1.0, int(player["combo"]) * 0.018))))
	if String(enemy["last_damage_kind"]) == "slash" and float(stats["frenzy_duration"]) > 0.0:
		player["frenzy_timer"] = max(float(player["frenzy_timer"]), float(stats["frenzy_duration"]))

	if enemy["is_boss"]:
		player["run_scrap"] += 24 + int(enemy["boss_index"]) * 8
		for i in range(8):
			_spawn_pickup("xp", enemy["pos"] + Vector2.from_angle(TAU * i / 8.0) * 36.0, 16)
		if enemy["final"]:
			_end_run("终局晶化首领倒下。", true)
	else:
		_spawn_pickup("xp", enemy["pos"], int(enemy["xp"]))
		if rng.randf() < 0.16:
			_spawn_pickup("scrap", enemy["pos"] + Vector2(rng.randf_range(-10, 10), rng.randf_range(-10, 10)), 1 + int(run_time / 240.0))
		if rng.randf() < 0.035:
			_spawn_pickup("heal", enemy["pos"] + Vector2(rng.randf_range(-10, 10), rng.randf_range(-10, 10)), 14)

func _volatile_explosion(enemy: Dictionary) -> void:
	var radius = 92.0
	var player_damage = float(enemy["damage"]) * 1.2
	if player["pos"].distance_to(enemy["pos"]) <= radius + float(player["radius"]):
		_damage_player(player_damage)
	for other in enemies:
		if other["hp"] > 0.0 and other["pos"].distance_to(enemy["pos"]) <= radius + float(other["radius"]):
			_damage_enemy(other, player_damage * 0.45, "blast")
			other["pos"] += (other["pos"] - enemy["pos"]).normalized() * 58.0
	effects.append({"type": "ring", "pos": enemy["pos"], "radius": radius, "ttl": 0.3, "max_ttl": 0.3, "color": Color(1.0, 0.34, 0.82, 0.58)})

func _check_player_death() -> void:
	if state == "play" and float(player["hp"]) <= 0.0:
		_end_run("刀盾狗倒在废墟中。", false)

func _end_run(reason: String, won: bool) -> void:
	if state == "game_over":
		return
	var earned = int(player.get("run_scrap", 0)) + int(int(player.get("score", 0)) / 125)
	if won:
		earned += 80
	save_data["scrap"] = int(save_data.get("scrap", 0)) + earned
	save_data["best_time"] = max(float(save_data.get("best_time", 0.0)), run_time)
	save_data["best_kills"] = max(int(save_data.get("best_kills", 0)), int(player.get("kills", 0)))
	save_data["best_combo"] = max(int(save_data.get("best_combo", 0)), int(player.get("max_combo", 0)))
	_save_game()
	game_summary = {
		"won": won,
		"reason": reason,
		"time": run_time,
		"level": int(player.get("level", 1)),
		"kills": int(player.get("kills", 0)),
		"max_combo": int(player.get("max_combo", 0)),
		"score": int(player.get("score", 0)),
		"run_scrap": int(player.get("run_scrap", 0)),
		"earned": earned,
		"total_scrap": int(save_data.get("scrap", 0))
	}
	state = "game_over"

func _handle_escape() -> void:
	match state:
		"play":
			_end_run("主动撤回营地。", false)
		"meta", "game_over":
			state = "menu"
		"level_up":
			_skip_upgrade()

func _handle_menu_click(pos: Vector2) -> void:
	var rects = _menu_button_rects()
	if rects["start"].has_point(pos):
		_start_run()
	elif rects["meta"].has_point(pos):
		state = "meta"
	elif rects["reset"].has_point(pos):
		save_data = _default_save()
		_save_game()
		_notify("存档已重置。", Color(0.8, 0.95, 1.0))

func _handle_meta_click(pos: Vector2) -> void:
	if Rect2(54, 604, 180, 42).has_point(pos):
		state = "menu"
		return
	for i in range(meta_defs.size()):
		var button = Rect2(892, 146 + i * 96, 150, 38)
		if button.has_point(pos):
			_purchase_meta(meta_defs[i])
			return

func _purchase_meta(def: Dictionary) -> void:
	var id = String(def["id"])
	var meta: Dictionary = save_data.get("meta", {})
	var level = int(meta.get(id, 0))
	var max_level = int(def["max"])
	if level >= max_level:
		return
	var cost = _meta_cost(def, level)
	if int(save_data.get("scrap", 0)) < cost:
		_notify("废料不足。", Color(1.0, 0.68, 0.36))
		return
	save_data["scrap"] = int(save_data["scrap"]) - cost
	meta[id] = level + 1
	save_data["meta"] = meta
	_save_game()

func _meta_cost(def: Dictionary, level: int) -> int:
	var base = int(def["base_cost"])
	return int(base + level * base / 2.0)

func _handle_game_over_click(pos: Vector2) -> void:
	if Rect2(424, 556, 142, 44).has_point(pos):
		_start_run()
	elif Rect2(584, 556, 142, 44).has_point(pos):
		state = "meta"
	elif Rect2(744, 556, 142, 44).has_point(pos):
		state = "menu"

func _handle_level_up_click(pos: Vector2) -> void:
	for i in range(upgrade_choices.size()):
		if _level_card_rect(i).has_point(pos):
			_apply_upgrade(String(upgrade_choices[i]["id"]))
			return
	if Rect2(368, 532, 190, 38).has_point(pos):
		if int(player["run_scrap"]) >= 3:
			player["run_scrap"] = int(player["run_scrap"]) - 3
			_pick_upgrade_choices()
	elif Rect2(722, 532, 190, 38).has_point(pos):
		_skip_upgrade()

func _skip_upgrade() -> void:
	player["hp"] = min(float(player["max_hp"]), float(player["hp"]) + 18.0)
	player["run_scrap"] = int(player["run_scrap"]) + 2
	state = "play"

func _player_hp_ratio() -> float:
	return float(player.get("hp", 1.0)) / max(1.0, float(player.get("max_hp", 1.0)))

func _aim_direction() -> Vector2:
	var dir = get_global_mouse_position() - player["pos"]
	if dir.length() < 24.0:
		return player["last_aim"]
	return dir.normalized()

func _direction_name(vec: Vector2) -> String:
	if abs(vec.x) > abs(vec.y):
		return "right" if vec.x >= 0.0 else "left"
	return "down" if vec.y >= 0.0 else "up"

func _clamp_to_arena(pos: Vector2, margin: float, extra = 0.0) -> Vector2:
	var radii = ARENA_RADII - Vector2(margin, margin) + Vector2(extra, extra)
	var offset = pos - ARENA_CENTER
	var normalized = Vector2(offset.x / radii.x, offset.y / radii.y)
	if normalized.length() <= 1.0:
		return pos
	var clamped = normalized.normalized()
	return ARENA_CENTER + Vector2(clamped.x * radii.x, clamped.y * radii.y)

func _damage_number(pos: Vector2, value: int, color: Color) -> void:
	damage_numbers.append({"pos": pos, "value": value, "ttl": 0.62, "max_ttl": 0.62, "color": color})

func _update_damage_numbers(delta: float) -> void:
	for i in range(damage_numbers.size() - 1, -1, -1):
		var number: Dictionary = damage_numbers[i]
		number["ttl"] = float(number["ttl"]) - delta
		number["pos"] += Vector2(0, -26) * delta
		if number["ttl"] <= 0.0:
			damage_numbers.remove_at(i)

func _update_effects(delta: float) -> void:
	for i in range(effects.size() - 1, -1, -1):
		var effect: Dictionary = effects[i]
		effect["ttl"] = float(effect["ttl"]) - delta
		if effect["ttl"] <= 0.0:
			effects.remove_at(i)

func _notify(text: String, color: Color) -> void:
	notifications.append({"text": text, "color": color, "ttl": 3.2, "max_ttl": 3.2})

func _update_notifications(delta: float) -> void:
	for i in range(notifications.size() - 1, -1, -1):
		var note: Dictionary = notifications[i]
		note["ttl"] = float(note["ttl"]) - delta
		if note["ttl"] <= 0.0:
			notifications.remove_at(i)

func _damage_color(kind: String, crit: bool) -> Color:
	if crit:
		return Color(1.0, 0.93, 0.36)
	match kind:
		"electric", "overload":
			return Color(0.38, 0.95, 1.0)
		"slash", "bleed":
			return Color(1.0, 0.78, 0.28)
		"poison_dot":
			return Color(0.46, 1.0, 0.35)
		_:
			return Color(1.0, 0.82, 0.72)

func _build_color(build: String) -> Color:
	match build:
		"电":
			return Color(0.24, 0.88, 1.0)
		"刀":
			return Color(1.0, 0.74, 0.24)
		"毒":
			return Color(0.32, 1.0, 0.42)
		"生存":
			return Color(0.58, 0.82, 1.0)
		_:
			return Color.WHITE

func _build_icon_name(build: String) -> String:
	match build:
		"电":
			return "electric"
		"刀":
			return "blade"
		"毒":
			return "poison"
		"生存":
			return "survival"
		_:
			return ""

func _draw_icon_texture(icon_name: String, rect: Rect2, modulate = Color(1, 1, 1, 1)) -> bool:
	if icon_name == "" or not ui_icons.has(icon_name):
		return false
	var texture: Texture2D = ui_icons[icon_name]
	if texture == null:
		return false
	draw_texture_rect(texture, rect, false, modulate)
	return true

func _draw_build_icon(center: Vector2, build: String, size: float) -> void:
	var icon_name = _build_icon_name(build)
	var rect = Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size))
	if _draw_icon_texture(icon_name, rect):
		return
	draw_circle(center, size * 0.42, _build_color(build))

func _rarity_color(rarity: String) -> Color:
	match rarity:
		"common":
			return Color(0.58, 0.68, 0.78)
		"uncommon":
			return Color(0.3, 0.9, 1.0)
		"rare":
			return Color(1.0, 0.76, 0.25)
		"epic":
			return Color(0.72, 0.44, 1.0)
		_:
			return Color.WHITE

func _format_time(seconds: float) -> String:
	var whole = int(max(0.0, seconds))
	return "%02d:%02d" % [whole / 60, whole % 60]

func _draw() -> void:
	var offset = Vector2.ZERO
	if shake > 0.0:
		offset = Vector2(rng.randf_range(-8, 8), rng.randf_range(-5, 5)) * shake
	draw_set_transform(offset, 0.0, Vector2.ONE)
	_draw_world()
	if state in ["play", "level_up", "game_over"]:
		_draw_entities()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	match state:
		"menu":
			_draw_menu()
		"meta":
			_draw_meta()
		"play":
			_draw_hud()
		"level_up":
			_draw_hud()
			_draw_level_up()
		"game_over":
			_draw_game_over()
	_draw_notifications()

func _draw_world() -> void:
	if arena_texture != null:
		draw_texture_rect(arena_texture, Rect2(Vector2.ZERO, WORLD_SIZE), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color(0.035, 0.052, 0.068))
		var arena_poly = _ellipse_points(ARENA_CENTER, ARENA_RADII + Vector2(24, 16), 96)
		draw_colored_polygon(arena_poly, Color(0.075, 0.096, 0.115))
		for y in range(86, 676, 58):
			var shade = Color(0.105, 0.124, 0.14, 0.42)
			draw_line(Vector2(100, y), Vector2(1180, y + sin(y * 0.03) * 18.0), shade, 2.0)
		for x in range(126, 1180, 72):
			draw_line(Vector2(x, 92), Vector2(x + cos(x * 0.04) * 24.0, 640), Color(0.08, 0.1, 0.12, 0.3), 1.5)
		for rect in static_ruins:
			draw_rect(rect.grow(6), Color(0.028, 0.032, 0.038, 0.54))
			draw_rect(rect, Color(0.18, 0.18, 0.19, 0.72))
			draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color(0.38, 0.42, 0.45, 0.35), 2.0)
		for crystal in static_crystals:
			_draw_crystal(crystal["pos"], float(crystal["size"]), Color(0.26, 0.88, 1.0, 0.68))
	for fire_pos in static_fires:
		draw_circle(fire_pos, 32.0, Color(1.0, 0.38, 0.1, 0.09))
		draw_circle(fire_pos, 12.0, Color(1.0, 0.46, 0.12, 0.72))
		draw_circle(fire_pos + Vector2(0, -6), 6.0, Color(1.0, 0.86, 0.32, 0.88))
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color(0.0, 0.02, 0.04, 0.22))
	var boundary = _ellipse_points(ARENA_CENTER, ARENA_RADII, 128)
	boundary.append(boundary[0])
	draw_polyline(boundary, Color(0.52, 0.72, 0.78, 0.22), 3.0, true)
	var progress = clamp(run_time / RUN_TARGET, 0.0, 1.0)
	if progress > 0.0:
		var arc = _ellipse_points(ARENA_CENTER, ARENA_RADII + Vector2(9, 5), max(4, int(128 * progress)), -PI / 2.0, -PI / 2.0 + TAU * progress)
		draw_polyline(arc, Color(0.2, 0.92, 1.0, 0.62), 4.0, true)

func _draw_entities() -> void:
	for pool in pools:
		var color = Color(0.42, 1.0, 0.22, 0.18) if not pool["hostile"] else Color(0.36, 0.8, 0.18, 0.15)
		draw_circle(pool["pos"], float(pool["radius"]), color)
		draw_arc(pool["pos"], float(pool["radius"]), 0, TAU, 48, Color(0.34, 1.0, 0.28, 0.48), 2.0, true)
	for hazard in hazards:
		var armed_t = clamp(1.0 - float(hazard["warn"]) / 1.02, 0.0, 1.0)
		var color = Color(0.28, 0.94, 1.0, 0.2).lerp(Color(1.0, 0.15, 0.1, 0.44), armed_t)
		draw_circle(hazard["pos"], float(hazard["radius"]), color)
		draw_arc(hazard["pos"], float(hazard["radius"]), 0, TAU, 42, Color(1.0, 0.18, 0.12, 0.78), 2.0, true)
		draw_line(hazard["pos"] + Vector2(-float(hazard["radius"]), 0), hazard["pos"] + Vector2(float(hazard["radius"]), 0), Color(1.0, 0.18, 0.12, 0.55), 2.0)
		draw_line(hazard["pos"] + Vector2(0, -float(hazard["radius"])), hazard["pos"] + Vector2(0, float(hazard["radius"])), Color(1.0, 0.18, 0.12, 0.55), 2.0)
	for crate in supply_crates:
		_draw_supply(crate)
	for pickup in pickups:
		_draw_pickup(pickup)
	for projectile in projectiles:
		_draw_projectile(projectile)
	for enemy in enemies:
		_draw_enemy(enemy)
	_draw_player()
	_draw_effects()
	for number in damage_numbers:
		var alpha = clamp(float(number["ttl"]) / float(number["max_ttl"]), 0.0, 1.0)
		_text(number["pos"], str(number["value"]), 16, Color(number["color"].r, number["color"].g, number["color"].b, alpha))

func _draw_player() -> void:
	if player.is_empty():
		return
	var pos: Vector2 = player["pos"]
	var action = "idle"
	if player["hurt_time"] > 0.0:
		action = "hurt"
	elif player["attack_time"] > 0.0:
		action = "attack"
	elif player["dash_anim"] > 0.0:
		action = "dash"
	elif player["vel"].length() > 5.0:
		action = "move"
	var frame_count = int(animation_meta.get(action, {}).get("frames_per_direction", 4))
	var frame = int(float(player["anim_time"]) * (12.0 if action != "idle" else 6.0)) % max(1, frame_count)
	var bob = sin(float(frame) / max(1.0, float(frame_count)) * TAU) * (2.5 if action == "move" else 1.2)
	var facing = String(player["facing"])
	var foot = pos + Vector2(0, 26)
	var invuln_alpha = 0.55 if player["invuln"] > 0.0 and int(player["anim_time"] * 18.0) % 2 == 0 else 1.0
	draw_circle(foot + Vector2(0, 2), 18, Color(0, 0, 0, 0.22))
	if _draw_player_sprite(action, facing, frame, foot, Color(1, 1, 1, invuln_alpha)):
		return
	var body = foot + Vector2(0, -34 + bob)
	var fur = Color(0.96, 0.66, 0.26, invuln_alpha)
	var fur_light = Color(1.0, 0.82, 0.42, invuln_alpha)
	var scarf = Color(0.78, 0.08, 0.07, invuln_alpha)
	var shield = Color(0.52, 0.62, 0.72, invuln_alpha)
	var blade = Color(0.92, 0.96, 1.0, invuln_alpha)
	var dir = _dir_vector(facing)
	draw_circle(body, 21, fur)
	draw_circle(body + Vector2(0, -18), 17, fur_light)
	var ear_offset = Vector2(13, -24)
	draw_circle(body + Vector2(-ear_offset.x, ear_offset.y), 7, fur)
	draw_circle(body + ear_offset, 7, fur)
	draw_circle(body + Vector2(-6, -22), 2.1, Color(0.05, 0.035, 0.025, invuln_alpha))
	draw_circle(body + Vector2(6, -22), 2.1, Color(0.05, 0.035, 0.025, invuln_alpha))
	draw_circle(body + Vector2(0, -15), 3.0, Color(0.08, 0.04, 0.03, invuln_alpha))
	draw_rect(Rect2(body + Vector2(-22, 2), Vector2(44, 14)), Color(0.23, 0.16, 0.1, invuln_alpha))
	draw_rect(Rect2(body + Vector2(-20, -5), Vector2(40, 7)), scarf)
	var side = Vector2(-dir.y, dir.x)
	var shield_pos = body - side * 22.0 + dir * 6.0
	var sword_base = body + side * 22.0 + dir * 5.0
	draw_circle(shield_pos, 12.0, shield)
	draw_arc(shield_pos, 12.0, 0, TAU, 24, Color(0.88, 0.96, 1.0, invuln_alpha), 2.0, true)
	draw_line(sword_base, sword_base + dir * (30.0 if action == "attack" else 20.0), blade, 5.0)
	draw_line(sword_base, sword_base + side * 9.0, Color(0.35, 0.22, 0.12, invuln_alpha), 4.0)

func _draw_player_sprite(action: String, facing: String, frame: int, foot: Vector2, modulate: Color) -> bool:
	if not player_textures.has(action):
		return false
	var action_meta = animation_meta.get(action, {})
	if typeof(action_meta) != TYPE_DICTIONARY:
		return false
	var frames_by_dir = action_meta.get("frames", {})
	if typeof(frames_by_dir) != TYPE_DICTIONARY or not frames_by_dir.has(facing):
		return false
	var frames: Array = frames_by_dir[facing]
	if frames.is_empty():
		return false
	var frame_meta = frames[frame % frames.size()]
	if typeof(frame_meta) != TYPE_DICTIONARY:
		return false
	var source = _rect_from_meta(frame_meta.get("source", [0, 0, 64, 64]))
	var anchor = _vector2_from_meta(frame_meta.get("anchor", action_meta.get("anchor", [32, 58])))
	var source_size = _vector2_from_meta(frame_meta.get("source_size", action_meta.get("source_size", [source.size.x, source.size.y])))
	var draw_scale = float(action_meta.get("draw_scale", 1.0))
	var dest = foot - anchor * draw_scale
	draw_texture_rect_region(player_textures[action], Rect2(dest, source_size * draw_scale), source, modulate)
	return true

func _rect_from_meta(value) -> Rect2:
	if typeof(value) == TYPE_ARRAY and value.size() >= 4:
		return Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
	if value is Rect2:
		return value
	return Rect2(0, 0, 64, 64)

func _vector2_from_meta(value) -> Vector2:
	if typeof(value) == TYPE_ARRAY and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if value is Vector2:
		return value
	return Vector2.ZERO

func _draw_enemy_sprite(enemy: Dictionary) -> bool:
	var kind = String(enemy["id"])
	if not enemy_textures.has(kind):
		return false
	var texture: Texture2D = enemy_textures[kind]
	if texture == null:
		return false
	var source_size = texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return false
	var scale = float(enemy["radius"]) / max(1.0, _enemy_sprite_reference_radius(kind))
	var draw_size = source_size * scale
	var rect = Rect2(Vector2(enemy["pos"]) - draw_size * 0.5, draw_size)
	var modulate = Color(1, 1, 1, 1)
	if enemy["flash"] > 0.0:
		modulate = Color(1.75, 1.75, 1.75, 1)
	draw_texture_rect(texture, rect, false, modulate)
	return true

func _enemy_sprite_reference_radius(kind: String) -> float:
	match kind:
		"crawler":
			return 19.0
		"spitter":
			return 21.0
		"brute":
			return 29.0
		"alpha":
			return 38.0
		_:
			return 24.0

func _draw_enemy(enemy: Dictionary) -> void:
	var pos: Vector2 = enemy["pos"]
	var radius = float(enemy["radius"])
	var base_color = Color(0.45, 0.18, 0.62)
	match enemy["id"]:
		"spitter":
			base_color = Color(0.54, 0.22, 0.68)
		"brute":
			base_color = Color(0.34, 0.17, 0.44)
		"alpha":
			base_color = Color(0.58, 0.28, 0.88)
	if enemy["flash"] > 0.0:
		base_color = Color.WHITE
	draw_circle(pos + Vector2(0, radius * 0.28), radius * 0.92, Color(0, 0, 0, 0.22))
	if _draw_enemy_sprite(enemy):
		if enemy["is_boss"]:
			draw_arc(pos, radius * 1.18, 0, TAU, 36, Color(0.4, 0.95, 1.0, 0.5), 3.0, true)
	else:
		if enemy["is_boss"]:
			var points = PackedVector2Array()
			for i in range(8):
				var a = TAU * i / 8.0 - PI / 2.0
				var r = radius * (1.15 if i % 2 == 0 else 0.78)
				points.append(pos + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(points, base_color)
			draw_arc(pos, radius * 1.18, 0, TAU, 36, Color(0.4, 0.95, 1.0, 0.5), 3.0, true)
		else:
			draw_circle(pos, radius, base_color)
			if enemy["id"] == "brute":
				draw_arc(pos, radius * 0.78, -PI * 0.1, PI * 1.1, 24, Color(0.7, 0.52, 0.86, 0.75), 5.0)
			elif enemy["id"] == "spitter":
				draw_circle(pos + (player["pos"] - pos).normalized() * radius * 0.45, radius * 0.28, Color(0.3, 1.0, 0.32, 0.65))
			else:
				for i in range(4):
					var a = TAU * i / 4.0 + run_time
					draw_line(pos, pos + Vector2(cos(a), sin(a)) * radius * 1.15, Color(0.64, 0.35, 0.8, 0.5), 2.0)
	if enemy["elite"] != "":
		draw_arc(pos, radius + 5.0, 0, TAU, 36, _elite_color(enemy["elite"]), 3.0, true)
	if enemy["hp"] < enemy["max_hp"]:
		var bar_w = 112.0 if enemy["is_boss"] else 42.0
		var bar_pos = pos + Vector2(-bar_w * 0.5, -radius - 18.0)
		draw_rect(Rect2(bar_pos, Vector2(bar_w, 5)), Color(0.06, 0.02, 0.04, 0.75))
		draw_rect(Rect2(bar_pos, Vector2(bar_w * clamp(float(enemy["hp"]) / float(enemy["max_hp"]), 0.0, 1.0), 5)), Color(0.94, 0.16, 0.28))
	_draw_enemy_status_marks(enemy)

func _draw_enemy_status_marks(enemy: Dictionary) -> void:
	var pos: Vector2 = enemy["pos"]
	var radius = float(enemy["radius"]) + 9.0
	if enemy["poison_time"] > 0.0:
		draw_arc(pos, radius, -PI / 2.0, PI * 0.15, 20, Color(0.42, 1.0, 0.28, 0.82), 3.0, true)
	if enemy["bleed_time"] > 0.0:
		draw_arc(pos, radius + 4.0, PI * 0.2, PI * 0.95, 20, Color(1.0, 0.3, 0.15, 0.78), 3.0, true)
	if int(enemy["shock_stacks"]) > 0:
		draw_arc(pos, radius + 8.0, PI, PI + int(enemy["shock_stacks"]) * 0.38, 22, Color(0.25, 0.92, 1.0, 0.86), 3.0, true)

func _elite_color(elite: String) -> Color:
	match elite:
		"swift":
			return Color(0.52, 0.9, 1.0, 0.8)
		"armored":
			return Color(0.78, 0.72, 0.56, 0.8)
		"volatile":
			return Color(1.0, 0.26, 0.74, 0.82)
		"regenerating":
			return Color(0.35, 1.0, 0.44, 0.8)
		_:
			return Color.WHITE

func _draw_supply(crate: Dictionary) -> void:
	var pos: Vector2 = crate["pos"]
	var rect = Rect2(pos - Vector2(18, 15), Vector2(36, 30))
	draw_circle(pos, 42.0 + sin(float(crate["pulse"]) * 4.0) * 3.0, Color(0.24, 1.0, 0.58, 0.09))
	draw_rect(rect, Color(0.36, 0.22, 0.1))
	draw_rect(rect, Color(1.0, 0.74, 0.28, 0.72), false, 2.0)
	draw_line(rect.position + Vector2(18, 0), rect.position + Vector2(18, 30), Color(0.22, 0.12, 0.05), 3.0)

func _draw_pickup(pickup: Dictionary) -> void:
	var pos: Vector2 = pickup["pos"] + Vector2(0, sin(run_time * 4.0 + float(pickup["bob"])) * 3.0)
	var color = Color(0.22, 0.95, 1.0)
	if pickup["kind"] == "scrap":
		color = Color(1.0, 0.75, 0.22)
	elif pickup["kind"] == "heal":
		color = Color(0.36, 1.0, 0.42)
	var points = PackedVector2Array([pos + Vector2(0, -8), pos + Vector2(8, 0), pos + Vector2(0, 8), pos + Vector2(-8, 0)])
	draw_colored_polygon(points, color)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color(1, 1, 1, 0.45), 1.4, true)

func _draw_projectile(projectile: Dictionary) -> void:
	var color = Color(0.38, 1.0, 0.28) if projectile["kind"] == "poison_vial" else Color(0.58, 1.0, 0.3)
	draw_circle(projectile["pos"], float(projectile["radius"]), color)
	draw_circle(projectile["pos"], float(projectile["radius"]) * 1.8, Color(color.r, color.g, color.b, 0.12))

func _draw_effects() -> void:
	for effect in effects:
		var alpha = clamp(float(effect["ttl"]) / float(effect["max_ttl"]), 0.0, 1.0)
		var color: Color = effect["color"]
		color.a *= alpha
		match effect["type"]:
			"bolt":
				var from_pos: Vector2 = effect["from"]
				var to_pos: Vector2 = effect["to"]
				var mid = (from_pos + to_pos) * 0.5 + Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8))
				draw_polyline(PackedVector2Array([from_pos, mid, to_pos]), color, 4.0, true)
			"slash":
				var dir: Vector2 = effect["dir"]
				var base_angle = dir.angle()
				draw_arc(effect["pos"], float(effect["radius"]), base_angle - float(effect["arc"]), base_angle + float(effect["arc"]), 28, color, 8.0, true)
			"ring":
				var radius = float(effect["radius"]) * (1.0 + (1.0 - alpha) * 0.14)
				draw_arc(effect["pos"], radius, 0, TAU, 44, color, 4.0, true)

func _draw_hud() -> void:
	_panel(Rect2(18, 18, 304, 112), Color(0.025, 0.034, 0.045, 0.78))
	_text(Vector2(34, 44), "刀盾狗 Lv.%d" % int(player["level"]), 20, Color(0.9, 0.96, 1.0))
	_bar(Rect2(34, 58, 258, 14), _player_hp_ratio(), Color(0.92, 0.16, 0.22), Color(0.12, 0.04, 0.06))
	_text(Vector2(34, 92), "HP %d/%d" % [int(player["hp"]), int(player["max_hp"])], 14, Color(1.0, 0.82, 0.82))
	_bar(Rect2(34, 101, 258, 10), float(player["xp"]) / max(1.0, float(player["xp_next"])), Color(0.25, 0.95, 1.0), Color(0.04, 0.1, 0.13))
	_text(Vector2(34, 126), "击杀 %d  废料 %d" % [int(player["kills"]), int(player["run_scrap"])], 14, Color(0.84, 0.9, 0.95))

	_panel(Rect2(366, 18, 314, 50), Color(0.025, 0.034, 0.045, 0.58))
	if int(player["combo"]) >= 3:
		_text(Vector2(382, 48), "连杀 x%d" % int(player["combo"]), 20, Color(1.0, 0.84, 0.28))
	else:
		_text(Vector2(382, 48), "构筑", 18, Color(0.75, 0.86, 0.9))
	var bx = 458
	for build in ["电", "刀", "毒", "生存"]:
		_draw_build_icon(Vector2(bx, 42), build, 24.0)
		_text(Vector2(bx + 14, 48), str(int(build_counts.get(build, 0))), 14, Color(0.86, 0.94, 0.96))
		bx += 56

	_panel(Rect2(1018, 18, 244, 152), Color(0.025, 0.034, 0.045, 0.72))
	_text(Vector2(1034, 46), "%s / 12:00" % _format_time(run_time), 22, Color(0.88, 0.98, 1.0))
	_text(Vector2(1034, 72), "补给 %s" % ("已就绪" if next_supply_time <= run_time else _format_time(next_supply_time - run_time)), 14, Color(0.76, 0.86, 0.9))
	_draw_minimap(Rect2(1102, 84, 138, 72))

	_draw_skill_bar()
	if _active_bosses().size() > 0:
		_draw_boss_bars()

func _draw_skill_bar() -> void:
	var x = 824
	var y = 642
	var slots = [
		{"key": "Space", "name": "冲刺", "icon": "blade", "cd": float(player["dash_cd"]), "max": max(0.55, float(stats["dash_cooldown"]))},
		{"key": "Q", "name": "毒瓶", "icon": "poison", "cd": float(player["poison_cd"]), "max": max(0.12, float(stats["poison_cooldown"]))},
		{"key": "R", "name": "磁吸", "icon": "survival", "cd": float(player["magnet_cd"]), "max": 7.5},
		{"key": "AUTO", "name": "电链", "icon": "electric", "cd": float(player["electric_cd"]), "max": max(0.12, float(stats["electric_cooldown"]))}
	]
	for i in range(slots.size()):
		var rect = Rect2(x + i * 108, y, 96, 58)
		_panel(rect, Color(0.025, 0.034, 0.045, 0.78))
		_draw_icon_texture(String(slots[i]["icon"]), Rect2(rect.position + Vector2(9, 8), Vector2(27, 27)))
		_text(rect.position + Vector2(42, 26), slots[i]["key"], 16, Color(0.9, 0.96, 1.0))
		_text(rect.position + Vector2(12, 47), slots[i]["name"], 13, Color(0.74, 0.82, 0.86))
		var ratio = clamp(float(slots[i]["cd"]) / max(0.01, float(slots[i]["max"])), 0.0, 1.0)
		if ratio > 0.0:
			draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * ratio)), Color(0.0, 0.0, 0.0, 0.42))

func _draw_boss_bars() -> void:
	var bosses = _active_bosses()
	var y = 686
	for boss in bosses:
		var w = 360.0
		var x = 460.0
		_bar(Rect2(x, y, w, 12), float(boss["hp"]) / float(boss["max_hp"]), Color(0.86, 0.22, 0.95), Color(0.08, 0.02, 0.1))
		_text(Vector2(x, y - 6), boss["name"], 14, Color(0.94, 0.82, 1.0))
		y -= 20

func _active_bosses() -> Array:
	var bosses: Array = []
	for enemy in enemies:
		if enemy["is_boss"] and enemy["hp"] > 0.0:
			bosses.append(enemy)
	return bosses

func _draw_minimap(rect: Rect2) -> void:
	draw_rect(rect, Color(0.015, 0.024, 0.032, 0.9))
	var center = rect.position + rect.size * 0.5
	var scale = min(rect.size.x / (ARENA_RADII.x * 2.0), rect.size.y / (ARENA_RADII.y * 2.0))
	draw_polyline(_ellipse_points(center, ARENA_RADII * scale, 48), Color(0.42, 0.76, 0.82, 0.45), 1.4, true)
	for enemy in enemies:
		var p = center + (enemy["pos"] - ARENA_CENTER) * scale
		draw_circle(p, 2.2 if not enemy["is_boss"] else 4.2, Color(0.92, 0.18, 0.32) if not enemy["is_boss"] else Color(0.78, 0.28, 1.0))
	for pickup in pickups:
		draw_circle(center + (pickup["pos"] - ARENA_CENTER) * scale, 1.8, Color(1.0, 0.78, 0.22))
	for crate in supply_crates:
		draw_circle(center + (crate["pos"] - ARENA_CENTER) * scale, 2.8, Color(0.38, 1.0, 0.48))
	draw_circle(center + (player["pos"] - ARENA_CENTER) * scale, 3.2, Color(0.28, 0.92, 1.0))

func _draw_menu() -> void:
	_panel(Rect2(54, 60, 396, 560), Color(0.026, 0.036, 0.048, 0.86))
	_text(Vector2(84, 126), "人类没了！", 38, Color(0.96, 0.82, 0.38))
	_text(Vector2(86, 160), "Hoomans Are Gone", 21, Color(0.5, 0.94, 1.0))
	_text(Vector2(86, 214), "金毛刀盾犬在废墟竞技场中抵抗异变群。", 16, Color(0.84, 0.9, 0.92))
	_text(Vector2(86, 242), "坚持 12 分钟，击败终局晶化首领。", 16, Color(0.84, 0.9, 0.92))
	var rects = _menu_button_rects()
	_draw_button(rects["start"], "进入废墟", false)
	_draw_button(rects["meta"], "局外背包", false)
	_draw_button(rects["reset"], "重置存档", false)
	_text(Vector2(86, 548), "WASD/方向键移动  Space 冲刺", 14, Color(0.68, 0.78, 0.84))
	_text(Vector2(86, 574), "左键刀弧  Q 毒瓶  R 磁吸  Esc 撤回", 14, Color(0.68, 0.78, 0.84))
	_text(Vector2(86, 602), "总废料 %d" % int(save_data.get("scrap", 0)), 16, Color(1.0, 0.78, 0.28))

func _menu_button_rects() -> Dictionary:
	return {
		"start": Rect2(86, 314, 250, 46),
		"meta": Rect2(86, 374, 250, 46),
		"reset": Rect2(86, 434, 250, 46)
	}

func _draw_meta() -> void:
	_panel(Rect2(54, 60, 1080, 588), Color(0.026, 0.036, 0.048, 0.88))
	_text(Vector2(84, 116), "局外背包", 34, Color(0.9, 0.96, 1.0))
	_text(Vector2(84, 150), "总废料 %d" % int(save_data.get("scrap", 0)), 20, Color(1.0, 0.78, 0.28))
	var meta: Dictionary = save_data.get("meta", {})
	for i in range(meta_defs.size()):
		var def: Dictionary = meta_defs[i]
		var y = 126 + i * 96
		var level = int(meta.get(String(def["id"]), 0))
		var max_level = int(def["max"])
		_panel(Rect2(84, y, 960, 72), Color(0.06, 0.078, 0.094, 0.72))
		_text(Vector2(108, y + 30), "%s  %d/%d" % [String(def["name"]), level, max_level], 19, Color(0.88, 0.96, 1.0))
		_text(Vector2(108, y + 56), String(def["desc"]), 14, Color(0.68, 0.78, 0.84))
		var disabled = level >= max_level or int(save_data.get("scrap", 0)) < _meta_cost(def, level)
		var label = "已满" if level >= max_level else "购买 %d" % _meta_cost(def, level)
		_draw_button(Rect2(892, y + 20, 150, 38), label, disabled)
	_draw_button(Rect2(54, 604, 180, 42), "回到标题", false)

func _draw_level_up() -> void:
	_panel(Rect2(226, 108, 828, 484), Color(0.022, 0.03, 0.044, 0.94))
	_text(Vector2(258, 154), "选择一次质变", 30, Color(0.94, 0.98, 1.0))
	_text(Vector2(258, 184), "随机不是盲选：每张卡都推动一条可预期构筑。", 15, Color(0.68, 0.78, 0.84))
	for i in range(upgrade_choices.size()):
		_draw_upgrade_card(upgrade_choices[i], _level_card_rect(i))
	_draw_button(Rect2(368, 532, 190, 38), "重抽 -3 废料", int(player["run_scrap"]) < 3)
	_draw_button(Rect2(722, 532, 190, 38), "跳过：回血 + 废料", false)

func _level_card_rect(index: int) -> Rect2:
	return Rect2(258 + index * 258, 214, 230, 292)

func _draw_upgrade_card(card: Dictionary, rect: Rect2) -> void:
	var build = String(card["build"])
	var rarity = String(card["rarity"])
	_panel(rect, Color(0.05, 0.068, 0.084, 0.96))
	draw_rect(rect, _rarity_color(rarity), false, 3.0)
	_draw_build_icon(rect.position + Vector2(36, 38), build, 44.0)
	_text(rect.position + Vector2(66, 34), String(card["name"]), 19, Color(0.95, 0.98, 1.0))
	_text(rect.position + Vector2(18, 72), "%s / %s / %d/%d" % [rarity, build, int(upgrade_stacks.get(String(card["id"]), 0)), int(card["max_stacks"])], 13, _rarity_color(rarity))
	_text(rect.position + Vector2(18, 112), String(card["summary"]), 14, Color(0.78, 0.86, 0.88))
	var y = rect.position.y + 154
	var effects_dict: Dictionary = card["effects"]
	var shown = 0
	for key in effects_dict.keys():
		_text(Vector2(rect.position.x + 22, y), "• %s %s" % [String(key), str(effects_dict[key])], 13, Color(0.74, 0.82, 0.86))
		y += 22
		shown += 1
		if shown >= 4:
			break
	_draw_button(Rect2(rect.position.x + 22, rect.position.y + 238, rect.size.x - 44, 34), "选择质变", false)

func _draw_game_over() -> void:
	_panel(Rect2(364, 118, 552, 514), Color(0.025, 0.034, 0.046, 0.92))
	var title = "清剿成功" if bool(game_summary.get("won", false)) else "撤离/阵亡"
	_text(Vector2(414, 174), title, 36, Color(0.96, 0.82, 0.34) if bool(game_summary.get("won", false)) else Color(0.92, 0.94, 0.96))
	_text(Vector2(414, 210), String(game_summary.get("reason", "")), 16, Color(0.76, 0.84, 0.88))
	var y = 260
	var rows = [
		"生存时间 %s / 12:00" % _format_time(float(game_summary.get("time", 0.0))),
		"等级 %d  击杀 %d  最高连杀 %d" % [int(game_summary.get("level", 1)), int(game_summary.get("kills", 0)), int(game_summary.get("max_combo", 0))],
		"分数 %d" % int(game_summary.get("score", 0)),
		"本局废料 %d  结算废料 %d" % [int(game_summary.get("run_scrap", 0)), int(game_summary.get("earned", 0))],
		"总废料 %d" % int(game_summary.get("total_scrap", 0))
	]
	for row in rows:
		_text(Vector2(414, y), row, 18, Color(0.84, 0.92, 0.95))
		y += 44
	_draw_button(Rect2(424, 556, 142, 44), "再来一局", false)
	_draw_button(Rect2(584, 556, 142, 44), "局外背包", false)
	_draw_button(Rect2(744, 556, 142, 44), "回到标题", false)

func _draw_notifications() -> void:
	var y = 190.0
	for note in notifications:
		var alpha = clamp(float(note["ttl"]) / float(note["max_ttl"]), 0.0, 1.0)
		var color: Color = note["color"]
		color.a *= alpha
		_text(Vector2(34, y), String(note["text"]), 16, color)
		y += 24.0

func _panel(rect: Rect2, color: Color) -> void:
	draw_rect(rect, color)
	draw_rect(rect, Color(0.58, 0.78, 0.86, 0.18), false, 1.5)

func _draw_button(rect: Rect2, label: String, disabled: bool) -> void:
	var hovered = rect.has_point(hover_pos) and not disabled
	var fill = Color(0.14, 0.22, 0.27, 0.94)
	if hovered:
		fill = Color(0.18, 0.34, 0.4, 0.98)
	if disabled:
		fill = Color(0.08, 0.09, 0.1, 0.8)
	draw_rect(rect, fill)
	draw_rect(rect, Color(0.42, 0.86, 0.95, 0.36) if not disabled else Color(0.32, 0.34, 0.36, 0.45), false, 1.6)
	_text(rect.position + Vector2(16, rect.size.y * 0.62), label, 16, Color(0.9, 0.98, 1.0) if not disabled else Color(0.46, 0.5, 0.54))

func _bar(rect: Rect2, ratio: float, fill: Color, bg: Color) -> void:
	draw_rect(rect, bg)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clamp(ratio, 0.0, 1.0), rect.size.y)), fill)
	draw_rect(rect, Color(1, 1, 1, 0.16), false, 1.0)

func _text(pos: Vector2, text: String, size: int, color: Color) -> void:
	if font != null:
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw_crystal(pos: Vector2, size: float, color: Color) -> void:
	var points = PackedVector2Array([
		pos + Vector2(0, -size),
		pos + Vector2(size * 0.42, -size * 0.14),
		pos + Vector2(size * 0.22, size),
		pos + Vector2(-size * 0.35, size * 0.44),
		pos + Vector2(-size * 0.52, -size * 0.1)
	])
	draw_colored_polygon(points, color)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[4], points[0]]), Color(0.72, 1.0, 1.0, 0.44), 1.6, true)

func _ellipse_points(center: Vector2, radii: Vector2, count: int, start_angle = 0.0, end_angle = TAU) -> PackedVector2Array:
	var points = PackedVector2Array()
	if count <= 1:
		points.append(center + Vector2(cos(start_angle) * radii.x, sin(start_angle) * radii.y))
		return points
	for i in range(count):
		var t = float(i) / float(count - 1)
		var angle = lerp(start_angle, end_angle, t)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points

func _dir_vector(direction: String) -> Vector2:
	match direction:
		"right":
			return Vector2.RIGHT
		"left":
			return Vector2.LEFT
		"up":
			return Vector2.UP
		_:
			return Vector2.DOWN

func start_run_for_tests() -> void:
	rng.seed = 19052026
	_start_run()
	player["invuln"] = 30.0
	player["xp_next"] = 9999.0

func debug_step(delta: float) -> void:
	if state == "play":
		_update_game(delta)

func debug_force_level_up() -> void:
	if state != "play":
		return
	player["xp"] = player["xp_next"]
	_grant_xp(0.0)

func debug_choose_first_upgrade() -> void:
	if state == "level_up" and not upgrade_choices.is_empty():
		_apply_upgrade(String(upgrade_choices[0]["id"]))

func debug_spawn_supply() -> void:
	next_supply_time = run_time

func debug_force_boss_time(seconds: float) -> void:
	run_time = seconds
	for i in range(BOSS_TIMES.size()):
		if BOSS_TIMES[i] >= seconds:
			boss_spawned[i] = false

func count_bosses() -> int:
	return _active_bosses().size()

func debug_damage_player(amount: float) -> void:
	player["invuln"] = 0.0
	player["shield_burst_cd"] = 7.5
	_damage_player(amount)

