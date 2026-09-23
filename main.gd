extends Node3D

const PLAYER_SCRIPT = preload("res://player.gd")

var player: CharacterBody3D
var score := 0
var lives := 3
var stage := 1
var elapsed := 0.0
var paused := false
var game_started := false
var stage_targets := [100.0, 210.0, 330.0]
var respawn_z := 4.0
var hazards: Array[Area3D] = []
var coins: Array[Area3D] = []

var hud: CanvasLayer
var menu_panel: Panel
var pause_panel: Panel
var score_label: Label
var lives_label: Label
var stage_label: Label
var timer_label: Label
var message_label: Label
var jump_button: Button
var pause_button: Button

func _ready() -> void:
    _build_world()
    _create_player()
    _create_hud()
    _show_menu()

func _build_world() -> void:
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.08, 0.12, 0.20)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.65, 0.75, 1.0)
    environment.ambient_light_energy = 0.9
    env.environment = environment
    add_child(env)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -25, 0)
    sun.light_energy = 1.3
    sun.shadow_enabled = true
    add_child(sun)

    _make_box("Ground", Vector3(14, 0.5, 380), Vector3(0, -0.5, -185), Color(0.18, 0.50, 0.25))
    _make_box("LeftWall", Vector3(0.7, 2.5, 380), Vector3(-7.2, 1.5, -185), Color(0.12, 0.30, 0.48))
    _make_box("RightWall", Vector3(0.7, 2.5, 380), Vector3(7.2, 1.5, -185), Color(0.12, 0.30, 0.48))

    _build_stage(1, -55.0, -4.0)
    _build_stage(2, -165.0, -105.0)
    _build_stage(3, -285.0, -225.0)

    _make_goal(-100.0, 1)
    _make_goal(-210.0, 2)
    _make_goal(-330.0, 3)

func _build_stage(number: int, start_z: float, end_z: float) -> void:
    for i in range(7):
        var z := start_z + float(i) * ((end_z - start_z) / 7.0)
        var x := [-3.5, 0.0, 3.5, 2.0, -2.0, 0.0, 3.0][i]
        _make_obstacle(Vector3(2.8, 0.8 + float(number) * 0.1, 1.4), Vector3(x, 0.7, z), Color(0.85, 0.25, 0.22))
        _make_coin(Vector3(x, 1.8, z - 3.0))

    for i in range(4):
        var z := start_z + float(i + 1) * ((end_z - start_z) / 5.0)
        _make_coin(Vector3(sin(float(i) * 2.0) * 4.0, 1.4, z))

    if number >= 2:
        _make_hazard(Vector3(-3.0, 1.0, start_z - 18.0), 3.0)
        _make_hazard(Vector3(3.0, 1.0, start_z - 38.0), -3.5)

func _create_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    player.set_script(PLAYER_SCRIPT)
    player.position = Vector3(0, 2, 4)
    add_child(player)

func _create_hud() -> void:
    hud = CanvasLayer.new()
    add_child(hud)

    score_label = _label("العملات: 0", Vector2(24, 18), 26)
    lives_label = _label("الحياة: ♥♥♥", Vector2(24, 52), 22)
    stage_label = _label("المرحلة: 1", Vector2(24, 82), 22)
    timer_label = _label("الوقت: 0:00", Vector2(24, 112), 20)
    message_label = _label("", Vector2(24, 148), 19)

    pause_button = Button.new()
    pause_button.text = "إيقاف"
    pause_button.position = Vector2(24, 180)
    pause_button.size = Vector2(110, 52)
    pause_button.pressed.connect(_toggle_pause)
    hud.add_child(pause_button)

    jump_button = Button.new()
    jump_button.text = "قفز"
    jump_button.position = Vector2(0, 0)
    jump_button.size = Vector2(150, 75)
    jump_button.anchor_left = 1.0
    jump_button.anchor_right = 1.0
    jump_button.anchor_top = 1.0
    jump_button.anchor_bottom = 1.0
    jump_button.offset_left = -175
    jump_button.offset_right = -25
    jump_button.offset_top = -110
    jump_button.offset_bottom = -35
    jump_button.pressed.connect(_jump_player)
    hud.add_child(jump_button)

func _label(text_value: String, pos: Vector2, size: int) -> Label:
    var label := Label.new()
    label.text = text_value
    label.position = pos
    label.add_theme_font_size_override("font_size", size)
    hud.add_child(label)
    return label

func _show_menu() -> void:
    menu_panel = Panel.new()
    menu_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hud.add_child(menu_panel)

    var title := Label.new()
    title.text = "مغامرات 3D"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.position = Vector2(0, 120)
    title.size = Vector2(1280, 80)
    title.add_theme_font_size_override("font_size", 48)
    menu_panel.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "اركض • اقفز • اجمع العملات • تجاوز العقبات"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.position = Vector2(0, 205)
    subtitle.size = Vector2(1280, 50)
    subtitle.add_theme_font_size_override("font_size", 22)
    menu_panel.add_child(subtitle)

    var start := Button.new()
    start.text = "ابدأ اللعبة"
    start.position = Vector2(490, 300)
    start.size = Vector2(300, 80)
    start.add_theme_font_size_override("font_size", 28)
    start.pressed.connect(_start_game)
    menu_panel.add_child(start)

    var info := Label.new()
    info.text = "التحكم: اسحب يسار الشاشة للحركة واضغط قفز للقفز"
    info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    info.position = Vector2(0, 410)
    info.size = Vector2(1280, 50)
    info.add_theme_font_size_override("font_size", 18)
    menu_panel.add_child(info)

func _start_game() -> void:
    game_started = true
    menu_panel.hide()
    pause_button.show()
    jump_button.show()
    message_label.text = "ابدأ! الهدف هو الوصول إلى البوابات الثلاث."

func _toggle_pause() -> void:
    if not game_started:
        return
    paused = not paused
    get_tree().paused = paused
    if paused:
        pause_button.text = "متابعة"
        _show_pause_panel()
    else:
        pause_button.text = "إيقاف"
        if is_instance_valid(pause_panel):
            pause_panel.queue_free()

func _show_pause_panel() -> void:
    pause_panel = Panel.new()
    pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    pause_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
    hud.add_child(pause_panel)

    var title := Label.new()
    title.text = "اللعبة متوقفة"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.position = Vector2(0, 220)
    title.size = Vector2(1280, 60)
    title.add_theme_font_size_override("font_size", 40)
    pause_panel.add_child(title)

    var resume := Button.new()
    resume.text = "متابعة"
    resume.position = Vector2(490, 320)
    resume.size = Vector2(300, 70)
    resume.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
    resume.pressed.connect(_toggle_pause)
    pause_panel.add_child(resume)

func _jump_player() -> void:
    if game_started and not paused and is_instance_valid(player):
        player.jump()

func _process(delta: float) -> void:
    if not game_started or paused or not is_instance_valid(player):
        return

    elapsed += delta
    timer_label.text = "الوقت: %d:%02d" % [int(elapsed) / 60, int(elapsed) % 60]
    score_label.text = "العملات: %d" % score
    lives_label.text = "الحياة: " + "♥".repeat(lives) + "♡".repeat(3 - lives)
    stage_label.text = "المرحلة: %d / 3" % stage

    if player.position.y < -5.0:
        _take_damage()

    if stage == 1 and player.position.z <= -100.0:
        _advance_stage(2)
    elif stage == 2 and player.position.z <= -210.0:
        _advance_stage(3)
    elif stage == 3 and player.position.z <= -330.0:
        _win_game()

func _advance_stage(next_stage: int) -> void:
    stage = next_stage
    respawn_z = [-4.0, -104.0, -214.0][stage - 1]
    player.position = Vector3(0, 2, respawn_z)
    player.velocity = Vector3.ZERO
    message_label.text = "ممتاز! وصلت إلى المرحلة %d." % stage

func _win_game() -> void:
    game_started = false
    var win := Panel.new()
    win.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hud.add_child(win)

    var title := Label.new()
    title.text = "🎉 فزت!"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.position = Vector2(0, 180)
    title.size = Vector2(1280, 80)
    title.add_theme_font_size_override("font_size", 50)
    win.add_child(title)

    var stats := Label.new()
    stats.text = "العملات: %d\nالوقت: %d:%02d" % [score, int(elapsed) / 60, int(elapsed) % 60]
    stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stats.position = Vector2(0, 280)
    stats.size = Vector2(1280, 100)
    stats.add_theme_font_size_override("font_size", 26)
    win.add_child(stats)

    var again := Button.new()
    again.text = "العب من جديد"
    again.position = Vector2(490, 430)
    again.size = Vector2(300, 70)
    again.pressed.connect(func(): get_tree().reload_current_scene())
    win.add_child(again)

func _take_damage() -> void:
    lives -= 1
    if lives <= 0:
        _game_over()
        return
    player.position = Vector3(0, 2, respawn_z)
    player.velocity = Vector3.ZERO
    message_label.text = "انتبه! خسرت حياة."

func _game_over() -> void:
    game_started = false
    var over := Panel.new()
    over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hud.add_child(over)

    var title := Label.new()
    title.text = "انتهت اللعبة"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.position = Vector2(0, 220)
    title.size = Vector2(1280, 70)
    title.add_theme_font_size_override("font_size", 42)
    over.add_child(title)

    var again := Button.new()
    again.text = "إعادة المحاولة"
    again.position = Vector2(490, 330)
    again.size = Vector2(300, 70)
    again.pressed.connect(func(): get_tree().reload_current_scene())
    over.add_child(again)

func _make_box(n: String, size: Vector3, pos: Vector3, color: Color) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.name = n
    body.position = pos
    add_child(body)

    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    mesh_instance.material_override = material
    body.add_child(mesh_instance)

    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)
    return body

func _make_obstacle(size: Vector3, pos: Vector3, color: Color) -> void:
    _make_box("Obstacle", size, pos, color)

func _make_coin(pos: Vector3) -> void:
    var area := Area3D.new()
    area.position = pos
    add_child(area)
    coins.append(area)

    var mesh_instance := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = 0.35
    mesh.height = 0.7
    mesh_instance.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(1.0, 0.82, 0.12)
    material.metallic = 0.7
    mesh_instance.material_override = material
    area.add_child(mesh_instance)

    var collision := CollisionShape3D.new()
    var shape := SphereShape3D.new()
    shape.radius = 0.5
    collision.shape = shape
    area.add_child(collision)
    area.body_entered.connect(_on_coin.bind(area))

func _on_coin(body: Node3D, coin: Area3D) -> void:
    if body == player and is_instance_valid(coin):
        score += 1
        coin.queue_free()

func _make_hazard(pos: Vector3, speed: float) -> void:
    var area := Area3D.new()
    area.position = pos
    area.set_meta("base_x", pos.x)
    area.set_meta("speed", speed)
    add_child(area)
    hazards.append(area)

    var mesh_instance := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = 0.75
    mesh.height = 1.5
    mesh_instance.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.95, 0.1, 0.12)
    material.emission_enabled = true
    material.emission = Color(0.5, 0.02, 0.02)
    mesh_instance.material_override = material
    area.add_child(mesh_instance)

    var collision := CollisionShape3D.new()
    var shape := SphereShape3D.new()
    shape.radius = 0.9
    collision.shape = shape
    area.add_child(collision)
    area.body_entered.connect(_on_hazard.bind(area))

func _on_hazard(body: Node3D, _hazard: Area3D) -> void:
    if body == player:
        _take_damage()

func _make_goal(z: float, _number: int) -> void:
    var portal := MeshInstance3D.new()
    var mesh := TorusMesh.new()
    mesh.inner_radius = 2.0
    mesh.outer_radius = 2.5
    portal.mesh = mesh
    portal.position = Vector3(0, 2.8, z)
    portal.rotation_degrees.x = 90
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.15, 0.85, 1.0)
    mat.emission_enabled = true
    mat.emission = Color(0.05, 0.65, 1.0)
    mat.emission_energy_multiplier = 2.5
    portal.material_override = mat
    add_child(portal)

func _physics_process(_delta: float) -> void:
    for i in range(hazards.size()):
        var h := hazards[i]
        if is_instance_valid(h):
            var base_x: float = h.get_meta("base_x")
            var speed: float = h.get_meta("speed")
            h.position.x = base_x + sin(Time.get_ticks_msec() / 1000.0 * speed) * 3.0
