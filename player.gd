extends CharacterBody3D

const SPEED := 8.0
const ACCELERATION := 24.0
const FRICTION := 20.0
const JUMP_VELOCITY := 11.0
const GRAVITY := 27.0

var gravity_direction := 1.0
var gravity_flipping := false
var gravity_flip_cooldown := 0.0

var touch_id := -1
var touch_start := Vector2.ZERO
var touch_vector := Vector2.ZERO
var mobile_left := false
var mobile_right := false
var camera: Camera3D
var body_material: StandardMaterial3D

func _ready() -> void:
    up_direction = Vector3.UP
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
    body_material = StandardMaterial3D.new()
    body_material.albedo_color = Color(0.20, 0.65, 1.0)
    body_material.roughness = 0.65
    mesh_instance.material_override = body_material
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
    camera.fov = 72.0

func set_skin(color: Color) -> void:
    if body_material:
        body_material.albedo_color = color

func set_mobile_left(active: bool) -> void:
    mobile_left = active

func set_mobile_right(active: bool) -> void:
    mobile_right = active

func jump() -> void:
    if gravity_flipping:
        return
    if is_on_floor() or is_on_ceiling():
        velocity.y = -JUMP_VELOCITY * gravity_direction

func flip_gravity() -> void:
    if gravity_flipping or gravity_flip_cooldown > 0.0:
        return
    gravity_flipping = true
    gravity_flip_cooldown = 0.35
    gravity_direction *= -1.0
    up_direction = Vector3.UP * gravity_direction
    velocity.y = -JUMP_VELOCITY * gravity_direction

    var tween := create_tween()
    tween.tween_property(self, "rotation:z", rotation.z + PI, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_callback(func(): gravity_flipping = false)

func is_gravity_down() -> bool:
    return gravity_direction > 0.0

func _physics_process(delta: float) -> void:
    gravity_flip_cooldown = maxf(0.0, gravity_flip_cooldown - delta)

    if not is_on_floor() and not is_on_ceiling():
        velocity.y -= GRAVITY * gravity_direction * delta

    if Input.is_action_just_pressed("jump"):
        jump()
    if Input.is_action_just_pressed("gravity_flip"):
        flip_gravity()

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
    var mobile := Vector2.ZERO
    if mobile_left:
        mobile.x -= 1.0
    if mobile_right:
        mobile.x += 1.0
    if mobile.length() > 0.05:
        return mobile
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
        var delta: Vector2 = event.position - touch_start
        touch_vector = delta.limit_length(110.0) / 110.0
