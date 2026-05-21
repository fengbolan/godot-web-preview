extends SceneTree

var failures: Array = []

func _init() -> void:
	var packed = load("res://scenes/Main.tscn")
	_check(packed != null, "Main scene loads")
	if packed == null:
		_finish()
		return

	var main = packed.instantiate()
	root.add_child(main)
	if main.animation_meta.is_empty():
		main._ready()

	_check(main.has_method("start_run_for_tests"), "Main exposes test start helper")
	_check(main.animation_meta.has("idle"), "Animation metadata loaded")
	if not main.animation_meta.has("idle"):
		_finish()
		return
	_check(main.animation_meta["idle"]["frames_per_direction"] == 4, "Idle animation frame count")
	_check(main.animation_meta["move"]["frames_per_direction"] == 8, "Move animation frame count")
	_check(main.animation_meta["attack"]["frames_per_direction"] == 8, "Attack animation frame count")
	_check(main.animation_meta["dash"]["frames_per_direction"] == 6, "Dash animation frame count")
	_check(main.animation_meta["hurt"]["frames_per_direction"] == 4, "Hurt animation frame count")
	_check(main.animation_meta["attack"].has("frames"), "Animation metadata includes frame source rects")
	for asset_path in [
		"res://assets/map/arena_base.png",
		"res://assets/sprites/player_dog.png",
		"res://assets/sprites/player_dog_idle_sheet.png",
		"res://assets/sprites/player_dog_move_sheet.png",
		"res://assets/sprites/player_dog_attack_sheet.png",
		"res://assets/sprites/player_dog_dash_sheet.png",
		"res://assets/sprites/player_dog_hurt_sheet.png",
		"res://assets/sprites/enemy_crawler.png",
		"res://assets/sprites/enemy_spitter.png",
		"res://assets/sprites/enemy_brute.png",
		"res://assets/sprites/enemy_alpha.png",
		"res://assets/ui/icon_electric.png",
		"res://assets/ui/icon_blade.png",
		"res://assets/ui/icon_poison.png",
		"res://assets/ui/icon_survival.png"
	]:
		_check(FileAccess.file_exists(asset_path), "Required asset exists: %s" % asset_path)
	_check(main.arena_texture != null, "Arena texture is loaded for rendering")
	for enemy_id in ["crawler", "spitter", "brute", "alpha"]:
		_check(main.enemy_textures.has(enemy_id), "Enemy texture is loaded for rendering: %s" % enemy_id)
	for icon_name in ["electric", "blade", "poison", "survival"]:
		_check(main.ui_icons.has(icon_name), "UI icon is loaded for rendering: %s" % icon_name)
	_check(main.ARENA_RADII.x == 560 and main.ARENA_RADII.y == 326, "Arena uses the wide ellipse from the design")

	main.start_run_for_tests()
	_check(main.state == "play", "Can start a run")
	_check(main.enemies.size() >= 8, "Run starts with enemies")
	_check(main.player.pos.distance_to(main.ARENA_CENTER + Vector2(0, 84)) < 0.1, "Player starts at design position")

	var combat_steps = 0
	while main.state == "play" and main.run_time <= 6.0 and combat_steps < 140:
		main.debug_step(0.1)
		combat_steps += 1
	_check(main.run_time > 5.9, "Combat can simulate several seconds")

	main.debug_force_level_up()
	_check(main.state == "level_up", "XP can enter level-up state")
	_check(main.upgrade_choices.size() == 3, "Level-up offers three cards")
	main.debug_choose_first_upgrade()
	_check(main.state == "play", "Choosing an upgrade resumes play")

	var old_luck = int(main.stats["supply_luck"])
	main._apply_upgrade("field_scavenger")
	_check(int(main.stats["supply_luck"]) == old_luck + 1, "Field Scavenger applies supply luck")

	main.debug_spawn_supply()
	main.debug_step(0.1)
	_check(main.supply_crates.size() >= 1, "Supply crates can spawn")

	main.debug_force_boss_time(180.0)
	main.debug_step(0.2)
	_check(main.count_bosses() >= 1, "Boss pressure point spawns a boss")

	main.debug_damage_player(12.0)
	_check(main.player.hp < main.player.max_hp, "Player can take damage")

	_finish()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _finish() -> void:
	if failures.is_empty():
		print("Smoke tests passed")
		quit(0)
	else:
		print("Smoke tests failed: %s" % [", ".join(failures)])
		quit(1)

