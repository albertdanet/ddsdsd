extends CharacterBody3D
class_name SFPlayer

@export var speed := 7.0
@export var jump_velocity := 4.8
@export var mouse_sensitivity := 0.0018
var gravity := 18.0
var health := 100
var ammo := 30
var reserve := 90
var reloading := false
var fire_cooldown := 0.0
var bob_time := 0.0
var camera: Camera3D
var weapon_root: Node3D
var hud

func _ready():
    name = "Player"
    add_to_group("player")
    var col = CollisionShape3D.new()
    var capsule = CapsuleShape3D.new()
    capsule.radius = 0.38
    capsule.height = 1.8
    col.shape = capsule
    col.position.y = 0.9
    add_child(col)
    camera = Camera3D.new()
    camera.position.y = 1.62
    camera.current = true
    add_child(camera)
    weapon_root = Node3D.new()
    weapon_root.position = Vector3(0.34, -0.28, -0.62)
    camera.add_child(weapon_root)
    var gun = MeshInstance3D.new()
    var mesh = BoxMesh.new()
    mesh.size = Vector3(0.16, 0.16, 0.72)
    gun.mesh = mesh
    gun.position = Vector3(0.04, 0.0, -0.14)
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(0.08, 0.12, 0.16)
    mat.metallic = 0.8
    mat.roughness = 0.28
    gun.material_override = mat
    weapon_root.add_child(gun)
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event):
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-event.relative.x * mouse_sensitivity)
        camera.rotate_x(-event.relative.y * mouse_sensitivity)
        camera.rotation.x = clamp(camera.rotation.x, -1.45, 1.45)
    if event.is_action_pressed("fire"):
        shoot()
    if event.is_action_pressed("reload"):
        reload_weapon()
    if event.is_action_pressed("jump") and is_on_floor():
        velocity.y = jump_velocity

func _physics_process(delta):
    fire_cooldown = maxf(0.0, fire_cooldown - delta)
    if not is_on_floor():
        velocity.y -= gravity * delta
    var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var dir = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    var target = dir * speed
    velocity.x = move_toward(velocity.x, target.x, 24.0 * delta)
    velocity.z = move_toward(velocity.z, target.z, 24.0 * delta)
    bob_time += delta * (12.0 if input_dir.length() > 0.1 else 3.0)
    camera.position.y = 1.62 + (sin(bob_time) * 0.025 if input_dir.length() > 0.1 and is_on_floor() else 0.0)
    move_and_slide()

func shoot():
    if fire_cooldown > 0 or reloading:
        return
    if ammo <= 0:
        reload_weapon()
        return
    ammo -= 1
    fire_cooldown = 0.105
    weapon_root.position.z = -0.52
    var tween = create_tween()
    tween.tween_property(weapon_root, "position:z", -0.62, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    var from = camera.global_position
    var to = from + (-camera.global_transform.basis.z * 120.0)
    var query = PhysicsRayQueryParameters3D.create(from, to)
    query.exclude = [self]
    var hit = get_world_3d().direct_space_state.intersect_ray(query)
    if hit and hit.collider.is_in_group("bot"):
        hit.collider.take_damage(34)
    get_tree().call_group("game_ui", "update_hud")

func reload_weapon():
    if reloading or ammo >= 30 or reserve <= 0:
        return
    reloading = true
    get_tree().call_group("game_ui", "show_message", "ПЕРЕЗАРЯДКА")
    await get_tree().create_timer(1.25).timeout
    var need = 30 - ammo
    var take = mini(need, reserve)
    ammo += take
    reserve -= take
    reloading = false
    get_tree().call_group("game_ui", "update_hud")

func take_damage(amount):
    health = max(0, health - amount)
    get_tree().call_group("game_ui", "update_hud")
    if health <= 0:
        get_tree().call_group("game_ui", "show_message", "ВЫ УСТРАНЕНЫ — нажмите R для перезапуска")
