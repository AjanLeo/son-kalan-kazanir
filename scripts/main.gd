extends Node3D

const TRACK_LENGTH := 120.0
const PLAYER_SPEED := 10.0
const GRAVITY := 24.0
var player: CharacterBody3D
var racers: Array[CharacterBody3D] = []
var bots: Array[Dictionary] = []
var round_number := 1
var round_active := false
var race_time := 0.0
var coins := 0
var total_wins := 0
var joystick := Vector2.ZERO
var jump_requested := false
var dive_requested := false
var hud: CanvasLayer
var status_label: Label
var count_label: Label
var progress_label: Label
var coin_label: Label
var round_label: Label
var result_panel: PanelContainer
var result_label: Label
var start_button: Button
var touch_origin := Vector2.ZERO
var touch_active := false

func _ready() -> void:
	_load_save()
	_build_world()
	_build_racers()
	_build_hud()
	_show_intro()

func _build_world() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(0, 7, 13)
	camera.rotation_degrees = Vector3(-18, 0, 0)
	camera.current = true
	add_child(camera)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.12, 0.30, 0.55)
	sky_mat.sky_horizon_color = Color(0.75, 0.82, 0.92)
	environment.sky.sky_material = sky_mat
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.65, 0.72, 0.85)
	environment.ambient_light_energy = 0.8
	env.environment = environment
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)
	_make_box("Track", Vector3(12, 0.5, TRACK_LENGTH + 12), Vector3(0, -0.35, -TRACK_LENGTH / 2), Color(0.16, 0.25, 0.36))
	_make_box("Left rail", Vector3(0.45, 1.3, TRACK_LENGTH + 8), Vector3(-6.1, 0.35, -TRACK_LENGTH / 2), Color(0.08, 0.72, 0.88))
	_make_box("Right rail", Vector3(0.45, 1.3, TRACK_LENGTH + 8), Vector3(6.1, 0.35, -TRACK_LENGTH / 2), Color(0.95, 0.34, 0.42))
	for i in range(12):
		_make_box("Track stripe", Vector3(11.5, 0.035, 0.16), Vector3(0, -0.07, -float(i) * 10.0 - 5.0), Color(0.36, 0.48, 0.62))
	_make_box("Finish line", Vector3(12, 0.12, 1.2), Vector3(0, 0.12, -TRACK_LENGTH), Color(1.0, 0.82, 0.16))
	_make_obstacles()
	_make_decor()

func _make_box(label: String, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var body := StaticBody3D.new()
	body.name = label + "Body"
	body.position = pos
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.72
	node.material_override = mat
	body.add_child(node)
	add_child(body)
	return node

func _make_obstacles() -> void:
	for i in range(5):
		var z := -18.0 - float(i) * 19.0
		var pivot := Node3D.new()
		pivot.position = Vector3(0, 1.15, z)
		add_child(pivot)
		var bar := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(8.5, 0.42, 0.65)
		bar.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = [Color(1,0.32,0.25), Color(0.95,0.72,0.16), Color(0.25,0.82,0.72)][i % 3]
		mat.metallic = 0.18
		mat.roughness = 0.35
		bar.material_override = mat
		pivot.add_child(bar)
		_make_box("Obstacle base", Vector3(1, 1.6, 1), Vector3(-4.5, 0.55, z), Color(0.24,0.30,0.42))
		_make_box("Obstacle base", Vector3(1, 1.6, 1), Vector3(4.5, 0.55, z), Color(0.24,0.30,0.42))
	for i in range(4):
		var block := _make_box("Jump block", Vector3(2, 1.3, 1.5), Vector3(0, 0.55, -27.0 - float(i) * 24.0), Color(0.45,0.38,0.85))
		block.rotation_degrees.y = float(i * 17)

func _make_decor() -> void:
	for i in range(18):
		for side in [-1.0, 1.0]:
			var pillar := _make_box("Arena pillar", Vector3(0.7, 3.0, 0.7), Vector3(side * 8.0, 1.2, -float(i) * 7.0 - 4.0), Color(0.18,0.34,0.52))
			pillar.rotation_degrees.y = 45
			_make_box("Arena light", Vector3(1.0, 0.18, 1.0), Vector3(side * 8.0, 2.85, -float(i) * 7.0 - 4.0), Color(0.12,0.85,1.0))

func _create_racer(color: Color, pos: Vector3, is_player: bool) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.position = pos
	body.set_meta("is_player", is_player)
	body.set_meta("finished", false)
	body.set_meta("speed_factor", 0.88 + randf() * 0.24)
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.48
	capsule.height = 1.55
	var shell := MeshInstance3D.new()
	shell.mesh = capsule
	shell.position.y = 0.83
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.12
	mat.roughness = 0.32
	shell.material_override = mat
	body.add_child(shell)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.39
	head_mesh.height = 0.78
	head.mesh = head_mesh
	head.position = Vector3(0, 1.72, -0.02)
	head.material_override = mat
	body.add_child(head)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.48
	shape.height = 1.55
	collision.shape = shape
	collision.position.y = 0.83
	body.add_child(collision)
	add_child(body)
	return body

func _build_racers() -> void:
	player = _create_racer(Color(0.1, 0.85, 1.0), Vector3(0, 1, 3), true)
	racers.append(player)
	for i in range(19):
		var x := -4.5 + float(i % 7) * 1.5
		var z := 5.0 + float(i / 7) * 2.0
		var hue := float(i) / 19.0
		var bot := _create_racer(Color.from_hsv(hue, 0.72, 0.95), Vector3(x, 1, z), false)
		racers.append(bot)
		bots.append({"node": bot, "phase": randf() * 6.28, "jump_cd": randf_range(1.0, 3.0)})

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var top := HBoxContainer.new()
	top.position = Vector2(24, 18)
	top.add_theme_constant_override("separation", 24)
	hud.add_child(top)
	status_label = _label("HAZIR OL!", 22)
	count_label = _label("20 YARIŞMACI", 18)
	progress_label = _label("İLERLEME 0%", 18)
	coin_label = _label("ALTIN: %d" % coins, 18)
	round_label = _label("TUR 1 / 3", 18)
	for item in [status_label, count_label, progress_label, coin_label, round_label]:
		top.add_child(item)
	var jump := Button.new()
	jump.text = "ZIPLA"
	jump.position = Vector2(1060, 560)
	jump.size = Vector2(170, 72)
	jump.pressed.connect(func(): jump_requested = true)
	hud.add_child(jump)
	var dive := Button.new()
	dive.text = "DAL"
	dive.position = Vector2(890, 580)
	dive.size = Vector2(140, 60)
	dive.pressed.connect(func(): dive_requested = true)
	hud.add_child(dive)
	result_panel = PanelContainer.new()
	result_panel.position = Vector2(390, 220)
	result_panel.size = Vector2(500, 230)
	result_panel.visible = false
	hud.add_child(result_panel)
	var box := VBoxContainer.new()
	result_panel.add_child(box)
	result_label = _label("", 28)
	box.add_child(result_label)
	start_button = Button.new()
	start_button.text = "YARIŞA BAŞLA"
	start_button.pressed.connect(_start_round)
	box.add_child(start_button)

func _label(value: String, size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color.WHITE)
	return label

func _show_intro() -> void:
	result_panel.visible = true
	result_label.text = "SON KALAN KAZANIR\n20 yarışmacı, tek şampiyon!"
	start_button.text = "YARIŞA BAŞLA"

func _start_round() -> void:
	result_panel.visible = false
	round_active = true
	race_time = 0.0
	for r in racers:
		r.set_meta("finished", false)
		r.velocity = Vector3.ZERO
		r.position = Vector3(randf_range(-4.5, 4.5), 1, randf_range(2, 8))
	if player:
		player.position = Vector3(0, 1, 3)

func _physics_process(delta: float) -> void:
	for obstacle in get_tree().get_nodes_in_group("rotors"):
		obstacle.rotation.y += delta
	if not round_active:
		return
	race_time += delta
	_update_player(delta)
	_update_racers(delta)
	_update_hud()
	if race_time > 75.0:
		round_active = false
		_finish_round(_player_rank())

func _update_player(delta: float) -> void:
	var direction := joystick
	if Input.is_action_pressed("ui_left"): direction.x -= 1
	if Input.is_action_pressed("ui_right"): direction.x += 1
	if Input.is_action_pressed("ui_up"): direction.y -= 1
	if Input.is_action_pressed("ui_down"): direction.y += 1
	var speed := PLAYER_SPEED
	player.velocity.x = move_toward(player.velocity.x, direction.x * speed, 24.0 * delta)
	player.velocity.z = -speed if direction.length() < 0.1 else -speed * maxf(0.35, -direction.y)
	if player.is_on_floor() and (jump_requested or Input.is_action_just_pressed("ui_accept")):
		player.velocity.y = 8.0
	if dive_requested:
		player.velocity.y = -7.0
	jump_requested = false
	dive_requested = false
	player.velocity.y -= GRAVITY * delta
	player.move_and_slide()
	player.position.x = clampf(player.position.x, -5.35, 5.35)
	if player.position.y < -8:
		player.position = Vector3(0, 1, maxf(-TRACK_LENGTH + 15, player.position.z + 10))
		player.velocity = Vector3.ZERO
	_check_player_finish()

func _update_racers(delta: float) -> void:
	for data in bots:
		var bot: CharacterBody3D = data.node
		if bot.get_meta("finished", false):
			continue
		var phase: float = data.phase
		var speed := PLAYER_SPEED * float(bot.get_meta("speed_factor"))
		var target_x := sin(race_time * 1.1 + phase) * 3.6
		bot.velocity.x = move_toward(bot.velocity.x, (target_x - bot.position.x) * 1.8, 8.0 * delta)
		bot.velocity.z = -speed
		data.jump_cd -= delta
		if bot.is_on_floor() and data.jump_cd <= 0:
			bot.velocity.y = 7.5
			data.jump_cd = randf_range(2.2, 4.5)
		bot.velocity.y -= GRAVITY * delta
		bot.move_and_slide()
		bot.position.x = clampf(bot.position.x, -5.3, 5.3)
		if bot.position.y < -5:
			bot.position = Vector3(randf_range(-3.5, 3.5), 1, minf(0, bot.position.z + 12))
			bot.velocity = Vector3.ZERO
		if bot.position.z <= -TRACK_LENGTH:
			bot.set_meta("finished", true)

func _check_player_finish() -> void:
	if player.position.z <= -TRACK_LENGTH and not player.get_meta("finished", false):
		player.set_meta("finished", true)
		round_active = false
		_finish_round(_player_rank())

func _player_rank() -> int:
	var rank := 1
	for r in racers:
		if r != player and r.position.z < player.position.z:
			rank += 1
	return rank

func _finish_round(place: int) -> void:
	var qualified := (round_number == 1 and place <= 10) or (round_number == 2 and place <= 5) or (round_number == 3 and place == 1)
	if qualified:
		coins += 100 if round_number == 3 else 35
		if round_number == 3:
			total_wins += 1
		result_label.text = "ŞAMPİYON OLDUN!\nSıralama: %d\n+%d ALTIN" % [place, 100 if round_number == 3 else 35]
		round_number = 1 if round_number == 3 else round_number + 1
	else:
		result_label.text = "ELENDİN!\nSıralama: %d\nTekrar dene!" % place
		round_number = 1
	_save_game()
	round_label.text = "TUR %d / 3" % round_number
	coin_label.text = "ALTIN: %d" % coins
	result_panel.visible = true
	start_button.text = "YENİDEN OYNA" if round_number == 1 else "SONRAKİ TUR"

func _update_hud() -> void:
	var alive := 0
	for r in racers:
		if not r.get_meta("finished", false):
			alive += 1
	count_label.text = "%d YARIŞMACI" % alive
	progress_label.text = "İLERLEME %d%%" % int(clampf((-player.position.z / TRACK_LENGTH) * 100.0, 0, 100))
	coin_label.text = "ALTIN: %d" % coins
	round_label.text = "TUR %d / 3" % round_number
	status_label.text = "SIRALAMAN: %d / 20" % _player_rank()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var size := get_viewport().get_visible_rect().size
		if event.pressed and event.position.x < size.x * 0.48 and event.position.y > size.y * 0.48:
			touch_active = true
			touch_origin = event.position
		elif not event.pressed:
			touch_active = false
			joystick = Vector2.ZERO
	elif event is InputEventScreenDrag and touch_active:
		var delta: Vector2 = (event.position - touch_origin) / 85.0
		joystick = Vector2(clampf(delta.x, -1, 1), clampf(delta.y, -1, 1))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game()

func _save_game() -> void:
	var f := FileAccess.open("user://savegame.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"coins": coins, "wins": total_wins}))

func _load_save() -> void:
	if not FileAccess.file_exists("user://savegame.json"):
		return
	var f := FileAccess.open("user://savegame.json", FileAccess.READ)
	if f:
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			coins = int(parsed.get("coins", 0))
			total_wins = int(parsed.get("wins", 0))
