extends Node3D

const PLAYER_SCRIPT = preload("res://player.gd")

var player: CharacterBody3D
var score := 0
var total_coins := 0
var finish_z := -150.0
var message_label: Label
var score_label: Label
var finish_label: Label

func _ready() -> void:
    _create_world()
    _create_player()
    _create_ui()

func _create_world() -> void:
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.10, 0.16, 0.25)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.65, 0.75, 1.0)
    environment.ambient_light_energy = 0.8
    env.environment = environment
    add_child(env)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -25, 0)
    sun.light_energy = 1.2
    sun.shadow_enabled = true
    add_child(sun)

    _make_box("Ground", Vector3(14, 0.5, 180), Vector3(0, -0.5, -75), Color(0.20, 0.55, 0.28))

    for i in range(13):
        var z := -i * 12.0
        _make_box("WallL" + str(i), Vector3(0.7, 2.0, 12), Vector3(-7.2, 1.5, z - 5.5), Color(0.15, 0.35, 0.55))
        _make_box("WallR" + str(i), Vector3(0.7, 2.0, 12), Vector3(7.2, 1.5, z - 5.5), Color(0.15, 0.35, 0.55))

    for i in range(10):
        var z := -12.0 - i * 14.0
        _make_obstacle(Vector3(3.5, 0.8, 1.5), Vector3(0, 0.8, z), Color(0.85, 0.25, 0.22))
        _make_obstacle(Vector3(1.5, 1.2, 1.5), Vector3(-3.5, 1.2, z - 5), Color(0.95, 0.65, 0.12))
        _make_obstacle(Vector3(1.5, 1.2, 1.5), Vector3(3.5, 1.2, z - 9), Color(0.55, 0.25, 0.85))

    for i in range(24):
        var z := -6.0 - i * 6.0
        var x := sin(float(i) * 1.7) * 4.2
        _make_coin(Vector3(x, 1.3, z))

    _make_box("FinishPlatform", Vector3(10, 0.4, 4), Vector3(0, 0.2, finish_z), Color(0.15, 0.8, 0.55))

    var portal := MeshInstance3D.new()
    var mesh := TorusMesh.new()
    mesh.inner_radius = 2.2
    mesh.outer_radius = 2.6
    portal.mesh = mesh
    portal.position = Vector3(0, 3, finish_z)
    portal.rotation_degrees.x = 90
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.2, 0.9, 1.0)
    mat.emission_enabled = true
    mat.emission = Color(0.1, 0.8, 1.0)
    mat.emission_energy_multiplier = 3.0
    portal.material_override = mat
    add_child(portal)

func _create_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    player.set_script(PLAYER_SCRIPT)
    player.position = Vector3(0, 2, 4)
    add_child(player)

func _create_ui() -> void:
    var canvas := CanvasLayer.new()
    add_child(canvas)

    score_label = Label.new()
    score_label.position = Vector2(28, 22)
    score_label.add_theme_font_size_override("font_size", 28)
    score_label.text = "العملات: 0"
    canvas.add_child(score_label)

    message_label = Label.new()
    message_label.position = Vector2(28, 62)
    message_label.add_theme_font_size_override("font_size", 20)
    message_label.text = "اسحب في الجهة اليسرى للتحرك • اضغط يمين الشاشة للقفز"
    canvas.add_child(message_label)

    finish_label = Label.new()
    finish_label.position = Vector2(28, 105)
    finish_label.add_theme_font_size_override("font_size", 22)
    finish_label.text = "الوصول إلى البوابة الزرقاء!"
    canvas.add_child(finish_label)

func _process(_delta: float) -> void:
    if not is_instance_valid(player):
        return
    score_label.text = "العملات: %d / %d" % [score, total_coins]
    if player.position.z <= finish_z + 2.0:
        finish_label.text = "أحسنت! وصلت إلى النهاية!"
    elif player.position.y < -4.0:
        player.position = Vector3(0, 2, 4)
        player.velocity = Vector3.ZERO
        message_label.text = "سقطت! تمت إعادتك إلى البداية."
    else:
        message_label.text = "اسحب يسار الشاشة للتحرك • اضغط يمين الشاشة للقفز"

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
    total_coins += 1
    var area := Area3D.new()
    area.position = pos
    add_child(area)
    var mesh_instance := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = 0.35
    mesh.height = 0.7
    mesh_instance.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(1.0, 0.82, 0.12)
    material.metallic = 0.7
    material.roughness = 0.2
    mesh_instance.material_override = material
    area.add_child(mesh_instance)
    var collision := CollisionShape3D.new()
    var shape := SphereShape3D.new()
    shape.radius = 0.5
    collision.shape = shape
    area.add_child(collision)
    area.body_entered.connect(_on_coin_body_entered.bind(area))

func _on_coin_body_entered(body: Node3D, coin: Area3D) -> void:
    if body == player and is_instance_valid(coin):
        score += 1
        coin.queue_free()
