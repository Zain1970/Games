extends CharacterBody3D

const SPEED := 8.0
const ACCELERATION := 24.0
const FRICTION := 20.0
const JUMP_VELOCITY := 11.0
const GRAVITY := 27.0

var touch_id := -1
var touch_start := Vector2.ZERO
var touch_vector := Vector2.ZERO
var camera: Camera3D

func _ready() -> void:
    _create_body()
    _create_camera()

func _create_body() -> void:
    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.65
    capsule.height = 1.8
    collision.shape = capsule
    collision.position.y = 1.0
    add_child(collision)

    var mesh_instance := MeshInstance3D.new()
    var capsule_mesh := CapsuleMesh.new()
    capsule_mesh.radius = 0.65
    capsule_mesh.height = 1.8
    mesh_instance.mesh = capsule_mesh
    mesh_instance.position.y = 1.0
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.20, 0.65, 1.0)
    material.roughness = 0.65
    mesh_instance.material_override = material
    add_child(mesh_instance)

    var eye := MeshInstance3D.new()
    var eye_mesh := SphereMesh.new()
    eye_mesh.radius = 0.14
    eye_mesh.height = 0.28
    eye.mesh = eye_mesh
    eye.position = Vector3(0, 1.35, -0.60)
    var eye_mat := StandardMaterial3D.new()
    eye_mat.albedo_color = Color(0.02, 0.02, 0.03)
    eye.material_override = eye_mat
    add_child(eye)

func _create_camera() -> void:
    camera = Camera3D.new()
    camera.position = Vector3(0, 6.5, 10.5)
    add_child(camera)
    camera.current = true

func jump() -> void:
    if is_on_floor():
        velocity.y = JUMP_VELOCITY

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= GRAVITY * delta

    if Input.is_action_just_pressed("jump"):
        jump()

    var input_vec := _movement_input()
    var direction := Vector3(input_vec.x, 0, input_vec.y)

    if direction.length() > 0.05:
        direction = direction.normalized()
        velocity.x = move_toward(velocity.x, direction.x * SPEED, ACCELERATION * delta)
        velocity.z = move_toward(velocity.z, direction.z * SPEED, ACCELERATION * delta)
        rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 10.0 * delta)
    else:
        velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
        velocity.z = move_toward(velocity.z, 0, FRICTION * delta)

    move_and_slide()

    var target_camera := global_position + Vector3(0, 6.0, 9.5)
    camera.global_position = camera.global_position.lerp(target_camera, 6.0 * delta)
    camera.look_at(global_position + Vector3(0, 1.0, -4.0), Vector3.UP)

func _movement_input() -> Vector2:
    var keyboard := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    if keyboard.length() > 0.05:
        return keyboard
    return touch_vector

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            if event.position.x < get_viewport().get_visible_rect().size.x * 0.55 and touch_id == -1:
                touch_id = event.index
                touch_start = event.position
                touch_vector = Vector2.ZERO
            elif event.position.x >= get_viewport().get_visible_rect().size.x * 0.55:
                jump()
        elif event.index == touch_id:
            touch_id = -1
            touch_vector = Vector2.ZERO

    elif event is InputEventScreenDrag and event.index == touch_id:
        var delta := event.position - touch_start
        touch_vector = delta.limit_length(110.0) / 110.0
