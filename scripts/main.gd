extends Node3D

const TRACK_LENGTH := 220.0
const PLAYER_SPEED := 10.0
const GRAVITY := 24.0
var player: CharacterBody3D
var follow_camera: Camera3D
var camera_yaw := 0.0
var camera_drag_active := false
var camera_last_touch := Vector2.ZERO
var joystick_base: Label
var joystick_knob: Label
var menu_actions: HBoxContainer
var racers: Array[CharacterBody3D] = []
var bots: Array[Dictionary] = []
var round_number := 1
var round_active := false
var race_time := 0.0
var coins := 0
var total_wins := 0
var total_races := 0
var best_rank := 20
var theme_index := 0
var skin_index := 0
var unlocked_skins: Array[int] = [0]
var quest_claimed := false
var skin_colors: Array[Color] = [Color(0.1,0.85,1.0), Color(1.0,0.25,0.42), Color(0.45,0.95,0.35), Color(1.0,0.72,0.15), Color(0.65,0.42,1.0), Color(1.0,0.45,0.12), Color(0.95,0.95,1.0), Color(0.12,0.95,0.75)]
var theme_names: Array[String] = ["NEON ŞEHİR", "LAV DENİZİ", "BUZ KRALLIĞI", "GÖKYÜZÜ", "ŞEKER DÜNYASI", "UZAY ÜSSÜ", "ORMAN TAPINAĞI", "ŞAMPİYON ARENASI"]
var theme_floor: Array[Color] = [Color(0.12,0.19,0.31), Color(0.32,0.09,0.07), Color(0.55,0.78,0.91), Color(0.25,0.42,0.68), Color(0.75,0.35,0.58), Color(0.10,0.12,0.25), Color(0.12,0.28,0.19), Color(0.28,0.19,0.42)]
var theme_glow: Array[Color] = [Color(0.05,0.9,1.0), Color(1.0,0.22,0.05), Color(0.6,0.92,1.0), Color(1.0,0.85,0.35), Color(1.0,0.35,0.72), Color(0.48,0.38,1.0), Color(0.3,1.0,0.52), Color(1.0,0.78,0.18)]
var joystick := Vector2.ZERO
var jump_requested := false
var jump_buffer := 0.0
var coyote_time := 0.0
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
var touch_id := -1

func _ready() -> void:
	_load_save()
	_build_world()
	_build_racers()
	_build_hud()
	_show_intro()

func _build_world() -> void:
	follow_camera = Camera3D.new()
	follow_camera.position = Vector3(0, 7, 13)
	follow_camera.rotation_degrees = Vector3(-18, 0, 0)
	follow_camera.current = true
	follow_camera.fov = 72.0
	add_child(follow_camera)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = theme_floor[theme_index].lerp(Color(0.035, 0.055, 0.14), 0.42)
	sky_mat.sky_horizon_color = theme_glow[theme_index].lerp(Color(0.72, 0.78, 0.9), 0.72)
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
	_make_box("Track", Vector3(16, 0.5, TRACK_LENGTH + 12), Vector3(0, -0.35, -TRACK_LENGTH / 2), theme_floor[theme_index])
	_make_box("Left rail", Vector3(0.5, 1.5, TRACK_LENGTH + 8), Vector3(-8.1, 0.35, -TRACK_LENGTH / 2), theme_glow[theme_index])
	_make_box("Right rail", Vector3(0.5, 1.5, TRACK_LENGTH + 8), Vector3(8.1, 0.35, -TRACK_LENGTH / 2), theme_glow[theme_index].lerp(Color.WHITE, 0.22))
	for i in range(22):
		_make_box("Track stripe", Vector3(15.5, 0.035, 0.18), Vector3(0, -0.07, -float(i) * 10.0 - 5.0), Color(0.36, 0.48, 0.62))
	_make_box("Finish line", Vector3(16, 0.16, 1.6), Vector3(0, 0.12, -TRACK_LENGTH), Color(1.0, 0.82, 0.16))
	_make_obstacles()
	_make_decor()
	_make_theme_landmarks()

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
	for i in range(10):
		var z := -18.0 - float(i) * 20.0
		var pivot := Node3D.new()
		pivot.position = Vector3(0, 1.18, z)
		pivot.add_to_group("rotors")
		add_child(pivot)
		var rotor_body := StaticBody3D.new()
		pivot.add_child(rotor_body)
		var rotor_collision := CollisionShape3D.new()
		var rotor_shape := BoxShape3D.new()
		rotor_shape.size = Vector3(11.0, 0.48, 0.75)
		rotor_collision.shape = rotor_shape
		rotor_body.add_child(rotor_collision)
		var bar := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = rotor_shape.size
		bar.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = theme_glow[theme_index]
		mat.metallic = 0.28
		mat.roughness = 0.3
		mat.emission_enabled = true
		mat.emission = theme_glow[theme_index] * 0.28
		bar.material_override = mat
		rotor_body.add_child(bar)
		_make_box("Obstacle base", Vector3(1, 1.6, 1), Vector3(-6.0, 0.55, z), theme_floor[theme_index].lerp(theme_glow[theme_index], 0.35))
		_make_box("Obstacle base", Vector3(1, 1.6, 1), Vector3(6.0, 0.55, z), theme_floor[theme_index].lerp(theme_glow[theme_index], 0.35))
	for i in range(12):
		var lane : float = [-5.0, 0.0, 5.0][(i + theme_index) % 3]
		var height := 1.15 + float((i + theme_index) % 3) * 0.25
		var block := _make_box("Neon hurdle", Vector3(2.35, height, 1.8), Vector3(lane, height * 0.5, -26.0 - float(i) * 16.0), theme_glow[theme_index].lerp(Color(1.0,0.36,0.18), float(i % 3) * 0.18))
		block.rotation_degrees.y = float(i * 13 + theme_index * 9)
	for i in range(8):
		var gap_x : float = [-4.5, 4.5][(i + theme_index) % 2]
		_make_box("Low jump beam", Vector3(4.2, 0.42, 0.8), Vector3(gap_x, 1.82, -38.0 - float(i) * 23.0), theme_glow[theme_index].lerp(Color.WHITE, 0.18))
	for i in range(5):
		var lane2 : float = [-5.2, 0.0, 5.2][(i * 2 + theme_index) % 3]
		_make_box("Moving lane block", Vector3(2.8, 0.8, 2.2), Vector3(lane2, 0.4, -52.0 - float(i) * 37.0), theme_floor[theme_index].lerp(theme_glow[theme_index], 0.65))
func _make_decor() -> void:
	for i in range(32):
		for side in [-1.0, 1.0]:
			var pillar := _make_box("Arena pillar", Vector3(0.7, 3.0 + float(i % 3) * 0.5, 0.7), Vector3(side * 10.0, 1.2, -float(i) * 7.0 - 4.0), theme_floor[theme_index].lerp(theme_glow[theme_index], 0.25))
			pillar.rotation_degrees.y = 45
			_make_box("Arena light", Vector3(1.0, 0.18, 1.0), Vector3(side * 10.0, 2.85, -float(i) * 7.0 - 4.0), theme_glow[theme_index])
	for i in range(18):
		var arch_z := -float(i) * 12.0 - 8.0
		_make_box("Side neon marker", Vector3(0.18, 4.2, 0.18), Vector3(-7.55, 1.7, arch_z), theme_glow[theme_index])
		_make_box("Side neon marker", Vector3(0.18, 4.2, 0.18), Vector3(7.55, 1.7, arch_z), theme_glow[theme_index])
func _make_theme_landmarks() -> void:
	for i in range(18):
		for side in [-1.0, 1.0]:
			var landmark := MeshInstance3D.new()
			var material := StandardMaterial3D.new()
			material.albedo_color = theme_glow[theme_index].lerp(theme_floor[theme_index], 0.28)
			material.metallic = 0.22
			material.roughness = 0.34
			material.emission_enabled = true
			material.emission = theme_glow[theme_index] * 0.2
			match theme_index:
				0, 7:
					var shape := BoxMesh.new()
					shape.size = Vector3(1.1, 3.2 + float(i % 3), 1.1)
					landmark.mesh = shape
				1, 4, 6:
					var shape := CylinderMesh.new()
					shape.top_radius = 0.18 if theme_index == 1 else 0.55
					shape.bottom_radius = 0.85
					shape.height = 3.4
					landmark.mesh = shape
				2:
					var shape := CapsuleMesh.new()
					shape.radius = 0.62
					shape.height = 3.0
					landmark.mesh = shape
				3, 5:
					var shape := SphereMesh.new()
					shape.radius = 1.05
					shape.height = 1.8
					landmark.mesh = shape
			landmark.material_override = material
			landmark.position = Vector3(side * (10.8 + float(i % 2) * 0.8), 1.6, -float(i) * 12.0 - 5.0)
			landmark.rotation_degrees.y = float(i * 23)
			add_child(landmark)

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
	# Karakter yüzü ve ayırt edici yarışçı ekipmanları.
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.035, 0.055, 0.09)
	eye_mat.roughness = 0.25
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.075
		eye_mesh.height = 0.12
		eye.mesh = eye_mesh
		eye.position = Vector3(side * 0.14, 1.79, -0.355)
		eye.material_override = eye_mat
		body.add_child(eye)
		var arm := MeshInstance3D.new()
		var arm_mesh := CapsuleMesh.new()
		arm_mesh.radius = 0.16
		arm_mesh.height = 0.78
		arm.mesh = arm_mesh
		arm.position = Vector3(side * 0.53, 0.91, 0.0)
		arm.rotation_degrees.z = side * -12.0
		arm.material_override = mat
		body.add_child(arm)
	for side in [-1.0, 1.0]:
		var leg := MeshInstance3D.new()
		var leg_mesh := CapsuleMesh.new()
		leg_mesh.radius = 0.19
		leg_mesh.height = 0.62
		leg.mesh = leg_mesh
		leg.position = Vector3(side * 0.23, 0.32, 0.0)
		leg.material_override = mat
		body.add_child(leg)
		var shoe := MeshInstance3D.new()
		var shoe_mesh := SphereMesh.new()
		shoe_mesh.radius = 0.23
		shoe_mesh.height = 0.28
		shoe.mesh = shoe_mesh
		shoe.scale = Vector3(1.0, 0.65, 1.35)
		shoe.position = Vector3(side * 0.23, 0.12, -0.12)
		var shoe_mat := StandardMaterial3D.new()
		shoe_mat.albedo_color = Color(0.96, 0.98, 1.0)
		shoe_mat.metallic = 0.18
		shoe.material_override = shoe_mat
		body.add_child(shoe)
	var crest := MeshInstance3D.new()
	var crest_mesh := SphereMesh.new()
	crest_mesh.radius = 0.22
	crest_mesh.height = 0.25
	crest.mesh = crest_mesh
	crest.position = Vector3(0, 2.05, 0.02)
	crest.scale = Vector3(1.4, 0.55, 1.0)
	crest.material_override = mat
	body.add_child(crest)
	var belt := MeshInstance3D.new()
	var belt_mesh := BoxMesh.new()
	belt_mesh.size = Vector3(0.72, 0.16, 0.55)
	belt.mesh = belt_mesh
	belt.position = Vector3(0, 0.55, 0)
	var belt_mat := StandardMaterial3D.new()
	belt_mat.albedo_color = Color(0.055, 0.075, 0.12)
	belt.material_override = belt_mat
	body.add_child(belt)
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
	player = _create_racer(skin_colors[skin_index], Vector3(0, 1, 3), true)
	racers.append(player)
	for i in range(19):
		var x := -6.0 + float(i % 7) * 2.0
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
	jump.add_theme_font_size_override("font_size", 24)
	jump.pressed.connect(_request_jump)
	hud.add_child(jump)
	var dive := Button.new()
	dive.text = "DAL"
	dive.position = Vector2(890, 580)
	dive.size = Vector2(140, 60)
	dive.pressed.connect(func(): dive_requested = true)
	hud.add_child(dive)
	result_panel = PanelContainer.new()
	result_panel.position = Vector2(350, 175)
	result_panel.size = Vector2(580, 350)
	result_panel.visible = false
	hud.add_child(result_panel)
	var box := VBoxContainer.new()
	result_panel.add_child(box)
	box.add_theme_constant_override("separation", 16)
	result_label = _label("", 30)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(result_label)
	menu_actions = HBoxContainer.new()
	menu_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_actions.add_theme_constant_override("separation", 10)
	box.add_child(menu_actions)
	_add_menu_button("KARAKTER", _open_characters)
	_add_menu_button("MAĞAZA", _open_shop)
	_add_menu_button("AYARLAR", _open_settings)
	_add_menu_button("HARİTA", _open_maps)
	_add_menu_button("GÖREVLER", _open_quests)
	start_button = Button.new()
	start_button.text = "YARIŞA BAŞLA"
	start_button.custom_minimum_size = Vector2(260, 58)
	start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_button.pressed.connect(_start_round)
	box.add_child(start_button)
	var touch_hint := _label("SOL: HAREKET   •   SAĞ: KAMERA   •   ZIPLA / DAL", 15)
	touch_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(touch_hint)
	joystick_base = _label("◯", 112)
	joystick_base.position = Vector2(42, 500)
	joystick_base.modulate = Color(0.55, 0.85, 1.0, 0.62)
	hud.add_child(joystick_base)
	joystick_knob = _label("●", 42)
	joystick_knob.position = Vector2(77, 535)
	joystick_knob.modulate = Color(1, 1, 1, 0.85)
	hud.add_child(joystick_knob)

func _add_menu_button(caption: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(150, 48)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(callback)
	menu_actions.add_child(button)

func _label(value: String, size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color.WHITE)
	return label

func _show_intro() -> void:
	result_panel.visible = true
	result_label.text = "SON KALAN KAZANIR\n20 YARIŞMACI  •  3 ELEME TURU\n\nİlk 10, ardından ilk 5 ve finalde şampiyon!\nHARİTA: %s  •  KOSTÜM: %d" % [theme_names[theme_index], skin_index + 1]
	start_button.text = "YARIŞA BAŞLA"
	if start_button.pressed.is_connected(_back_to_menu):
		start_button.pressed.disconnect(_back_to_menu)
	if not start_button.pressed.is_connected(_start_round):
		start_button.pressed.connect(_start_round)
	menu_actions.visible = true
func _request_jump() -> void:
	jump_requested = true

func _start_round() -> void:
	jump_requested = false
	jump_buffer = 0.0
	coyote_time = 0.0
	joystick = Vector2.ZERO
	result_panel.visible = false
	menu_actions.visible = false
	round_active = true
	race_time = 0.0
	for r in racers:
		if not r.visible:
			continue
		r.set_meta("finished", false)
		r.velocity = Vector3.ZERO
		r.position = Vector3(randf_range(-6.0, 6.0), 1, randf_range(2, 8))
	if player:
		player.position = Vector3(0, 1, 3)

func _process(delta: float) -> void:
	if player and is_instance_valid(follow_camera):
		var orbit: Vector3 = Basis(Vector3.UP, camera_yaw) * Vector3(0, 8.0, 15.5)
		var desired: Vector3 = player.global_position + orbit
		follow_camera.global_position = follow_camera.global_position.lerp(desired, 1.0 - exp(-5.5 * delta))
		follow_camera.look_at(player.global_position + Vector3(0, 1.0, -2.0), Vector3.UP)
	if joystick_knob and joystick_base:
		joystick_knob.position = joystick_base.position + Vector2(35, 35) + joystick * 31.0

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
	if player.is_on_floor():
		coyote_time = 0.12
	else:
		coyote_time = maxf(0.0, coyote_time - delta)
	if jump_requested:
		jump_buffer = 0.18
	else:
		jump_buffer = maxf(0.0, jump_buffer - delta)
	if (jump_buffer > 0.0 and coyote_time > 0.0) or Input.is_action_just_pressed("ui_accept"):
		player.velocity.y = 10.5
		jump_buffer = 0.0
		coyote_time = 0.0
	if dive_requested:
		player.velocity.y = -7.0
	jump_requested = false
	dive_requested = false
	player.velocity.y -= GRAVITY * delta
	player.move_and_slide()
	player.rotation.z = lerpf(player.rotation.z, -direction.x * 0.16, delta * 8.0)
	player.position.x = clampf(player.position.x, -7.25, 7.25)
	if player.position.y < -8:
		player.position = Vector3(0, 1, maxf(-TRACK_LENGTH + 15, player.position.z + 10))
		player.velocity = Vector3.ZERO
	_check_player_finish()

func _update_racers(delta: float) -> void:
	for data in bots:
		var bot: CharacterBody3D = data.node
		if not bot.visible or bot.get_meta("finished", false):
			continue
		var phase: float = data.phase
		var speed := PLAYER_SPEED * float(bot.get_meta("speed_factor"))
		var target_x := sin(race_time * 1.1 + phase) * 5.5
		bot.velocity.x = move_toward(bot.velocity.x, (target_x - bot.position.x) * 1.8, 8.0 * delta)
		bot.velocity.z = -speed
		data.jump_cd -= delta
		if bot.is_on_floor() and data.jump_cd <= 0:
			bot.velocity.y = 7.5
			data.jump_cd = randf_range(2.2, 4.5)
		bot.velocity.y -= GRAVITY * delta
		bot.move_and_slide()
		bot.rotation.z = lerpf(bot.rotation.z, -signf(bot.velocity.x) * 0.12, delta * 5.0)
		bot.position.x = clampf(bot.position.x, -7.2, 7.2)
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
		if r != player and r.visible and r.position.z < player.position.z:
			rank += 1
	return rank

func _retain_qualifiers(bot_count: int) -> void:
	var candidates: Array[CharacterBody3D] = []
	for data in bots:
		var bot: CharacterBody3D = data.node
		candidates.append(bot)
	candidates.sort_custom(func(a: CharacterBody3D, b: CharacterBody3D) -> bool: return a.position.z < b.position.z)
	for i in range(candidates.size()):
		candidates[i].visible = i < bot_count

func _finish_round(place: int) -> void:
	total_races += 1
	best_rank = mini(best_rank, place)
	var qualified := (round_number == 1 and place <= 10) or (round_number == 2 and place <= 5) or (round_number == 3 and place == 1)
	if qualified:
		if round_number == 1:
			_retain_qualifiers(9)
		elif round_number == 2:
			_retain_qualifiers(4)
		coins += 100 if round_number == 3 else 35
		if round_number == 3:
			total_wins += 1
			for data in bots:
				(data.node as CharacterBody3D).visible = true
		result_label.text = "ŞAMPİYON OLDUN!\nSıralama: %d\n+%d ALTIN" % [place, 100 if round_number == 3 else 35]
		round_number = 1 if round_number == 3 else round_number + 1
	else:
		for data in bots:
			(data.node as CharacterBody3D).visible = true
		result_label.text = "ELENDİN!\nSıralama: %d\nTekrar dene!" % place
		round_number = 1
	_save_game()
	round_label.text = "TUR %d / 3" % round_number
	coin_label.text = "ALTIN: %d" % coins
	result_panel.visible = true
	menu_actions.visible = false
	start_button.text = "YENİDEN OYNA" if round_number == 1 else "SONRAKİ TUR"

func _open_characters() -> void:
	var state := "AÇIK" if unlocked_skins.has(skin_index) else "KİLİTLİ"
	_show_submenu("KARAKTER SEÇİMİ\n\nKostüm %d / 8\nDurum: %s\n\nAçık kostümler arasında seçim yap." % [skin_index + 1, state])
	_add_submenu_action("SONRAKİ KARAKTER", _next_skin)

func _next_skin() -> void:
	for i in range(1, skin_colors.size() + 1):
		var candidate := (skin_index + i) % skin_colors.size()
		if unlocked_skins.has(candidate):
			skin_index = candidate
			break
	player.queue_free()
	racers.erase(player)
	player = _create_racer(skin_colors[skin_index], Vector3(0, 1, 3), true)
	racers.push_front(player)
	_open_characters()

func _show_submenu(message: String) -> void:
	for child in menu_actions.get_children():
		menu_actions.remove_child(child)
		child.queue_free()
	result_label.text = message
	start_button.text = "GERİ DÖN"
	if start_button.pressed.is_connected(_start_round):
		start_button.pressed.disconnect(_start_round)
	if not start_button.pressed.is_connected(_back_to_menu):
		start_button.pressed.connect(_back_to_menu)
	menu_actions.visible = false

func _add_submenu_action(caption: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(220, 48)
	button.pressed.connect(callback)
	menu_actions.add_child(button)
	menu_actions.visible = true
func _open_shop() -> void:
	_show_submenu("KOSTÜM MAĞAZASI\n\nBakiyen: %d ALTIN\nKilitli kostümler 75 ALTIN.\nAçık kostümler kalıcı olarak kaydedilir." % coins)
	_add_submenu_action("KOSTÜM SATIN AL", _buy_skin)

func _buy_skin() -> void:
	var next_locked := -1
	for i in range(skin_colors.size()):
		if not unlocked_skins.has(i):
			next_locked = i
			break
	if next_locked == -1:
		_show_submenu("Bütün kostümler açık!")
	elif coins >= 75:
		coins -= 75
		unlocked_skins.append(next_locked)
		skin_index = next_locked
		_save_game()
		get_tree().reload_current_scene()
	else:
		_show_submenu("YETERSİZ ALTIN\n\nBu kostüm 75 altın.\nBakiyen: %d" % coins)
	_add_submenu_action("MAĞAZAYA DÖN", _open_shop)
func _open_maps() -> void:
	_show_submenu("HARİTA SEÇİMİ\n\n%s\nHarita %d / 8\n\nHer haritada farklı renk paleti ve engel dizilimi bulunur." % [theme_names[theme_index], theme_index + 1])
	_add_submenu_action("SONRAKİ HARİTA", _next_map)

func _next_map() -> void:
	theme_index = (theme_index + 1) % theme_names.size()
	_save_game()
	get_tree().reload_current_scene()

func _open_quests() -> void:
	_show_submenu("3 YARIŞ GÖREVİ\n\n3 yarış tamamla: %d / 3\nToplam yarış: %d\nEn iyi derece: %d\n\nÖdül: 100 ALTIN" % [mini(total_races, 3), total_races, best_rank])
	if total_races >= 3 and not quest_claimed:
		_add_submenu_action("100 ALTIN ÖDÜLÜNÜ AL", _claim_quest)

func _claim_quest() -> void:
	if total_races >= 3 and not quest_claimed:
		coins += 100
		quest_claimed = true
		_save_game()
	_show_submenu("GÖREV TAMAMLANDI!\n\nYeni bakiyen: %d ALTIN" % coins)

func _open_settings() -> void:
	_show_submenu("AYARLAR VE KONTROLLER\n\nEKRAN: YATAY 16:9\nSOL ALT: JOYSTICK\nSAĞ TARAF: KAMERA\nSAĞ ALT: ZIPLA / DAL\n\nGRAFİK: 3D MOBİL DENGELİ\nTOPLAM GALİBİYET: %d" % total_wins)
func _back_to_menu() -> void:
	for child in menu_actions.get_children():
		child.queue_free()
	if start_button.pressed.is_connected(_back_to_menu):
		start_button.pressed.disconnect(_back_to_menu)
	if not start_button.pressed.is_connected(_start_round):
		start_button.pressed.connect(_start_round)
	_add_menu_button("KARAKTER", _open_characters)
	_add_menu_button("MAĞAZA", _open_shop)
	_add_menu_button("HARİTA", _open_maps)
	_add_menu_button("GÖREVLER", _open_quests)
	_add_menu_button("AYARLAR", _open_settings)
	_show_intro()
func _update_hud() -> void:
	var alive := 0
	for r in racers:
		if r.visible and not r.get_meta("finished", false):
			alive += 1
	count_label.text = "%d YARIŞMACI" % alive
	progress_label.text = "İLERLEME %d%%" % int(clampf((-player.position.z / TRACK_LENGTH) * 100.0, 0, 100))
	coin_label.text = "ALTIN: %d" % coins
	round_label.text = "TUR %d / 3" % round_number
	status_label.text = "SIRALAMAN: %d / %d" % [_player_rank(), racers.count(func(r: CharacterBody3D) -> bool: return r.visible)]

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var size := get_viewport().get_visible_rect().size
		if event.pressed:
			if event.position.x < size.x * 0.48 and event.position.y > size.y * 0.48:
				touch_active = true
				touch_id = event.index
				touch_origin = event.position
			elif event.position.x >= size.x * 0.48 and event.position.y > size.y * 0.20:
				camera_drag_active = true
				camera_last_touch = event.position
		else:
			if event.index == touch_id:
				touch_active = false
				touch_id = -1
				joystick = Vector2.ZERO
			camera_drag_active = false
	elif event is InputEventScreenDrag:
		if touch_active and event.index == touch_id:
			var drag: Vector2 = (event.position - touch_origin) / 85.0
			joystick = Vector2(clampf(drag.x, -1, 1), clampf(drag.y, -1, 1))
		elif camera_drag_active:
			var motion: Vector2 = event.position - camera_last_touch
			camera_yaw = clampf(camera_yaw - motion.x * 0.004, -0.75, 0.75)
			camera_last_touch = event.position

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game()

func _save_game() -> void:
	var f := FileAccess.open("user://savegame.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"coins": coins, "wins": total_wins, "races": total_races, "best_rank": best_rank, "theme": theme_index, "skin": skin_index, "unlocked": unlocked_skins, "quest_claimed": quest_claimed}))

func _load_save() -> void:
	if not FileAccess.file_exists("user://savegame.json"):
		return
	var f := FileAccess.open("user://savegame.json", FileAccess.READ)
	if f:
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			coins = int(parsed.get("coins", 0))
			total_wins = int(parsed.get("wins", 0))
			total_races = int(parsed.get("races", 0))
			best_rank = int(parsed.get("best_rank", 20))
			theme_index = clampi(int(parsed.get("theme", 0)), 0, 7)
			skin_index = clampi(int(parsed.get("skin", 0)), 0, 7)
			var saved_unlocked = parsed.get("unlocked", [0])
			if saved_unlocked is Array:
				unlocked_skins.clear()
				for item in saved_unlocked:
					var idx := int(item)
					if idx >= 0 and idx < 8 and not unlocked_skins.has(idx): unlocked_skins.append(idx)
			if not unlocked_skins.has(0): unlocked_skins.append(0)
			quest_claimed = bool(parsed.get("quest_claimed", false))
