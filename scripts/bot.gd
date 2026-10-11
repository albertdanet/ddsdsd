extends CharacterBody3D
class_name SFBot

var health := 100
var speed := 3.1
var shoot_timer := 1.2
var think_timer := 0.0
var destination := Vector3.ZERO
var player: Node3D
var difficulty := 1.0
var body_mesh: MeshInstance3D
var esp_label: Label3D

func _ready():
    add_to_group("bot")
    var col = CollisionShape3D.new()
    var capsule = CapsuleShape3D.new()
    capsule.radius = 0.38
    capsule.height = 1.75
    col.shape = capsule
    col.position.y = 0.87
    add_child(col)
    body_mesh = MeshInstance3D.new()
    var mesh = CapsuleMesh.new()
    mesh.radius = 0.37
    mesh.height = 1.72
    body_mesh.mesh = mesh
    body_mesh.position.y = 0.87
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(0.72, 0.16, 0.12)
    mat.roughness = 0.7
    body_mesh.material_override = mat
    add_child(body_mesh)
    var head = MeshInstance3D.new()
    var hm = SphereMesh.new()
    hm.radius = 0.22
    hm.height = 0.44
    head.mesh = hm
    head.position.y = 1.82
    head.material_override = mat
    add_child(head)
    esp_label = Label3D.new()
    esp_label.text = "BOT 100 HP"
    esp_label.position.y = 2.25
    esp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    esp_label.font_size = 32
    esp_label.modulate = Color(1.0, 0.25, 0.2)
    add_child(esp_label)
    player = get_tree().get_first_node_in_group("player")
    destination = global_position

func _physics_process(delta):
    if not is_instance_valid(player) or health <= 0:
        return
    shoot_timer -= delta
    think_timer -= delta
    var to_player = player.global_position - global_position
    var distance = to_player.length()
    if think_timer <= 0:
        think_timer = randf_range(0.7, 1.7)
        if distance > 8:
            destination = player.global_position + Vector3(randf_range(-4,4), 0, randf_range(-4,4))
        else:
            destination = global_position + Vector3(randf_range(-5,5), 0, randf_range(-5,5))
    var flat = destination - global_position
    flat.y = 0
    if flat.length() > 1.2:
        var dir = flat.normalized()
        velocity.x = dir.x * speed
        velocity.z = dir.z * speed
        look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
    else:
        velocity.x = move_toward(velocity.x, 0, 8*delta)
        velocity.z = move_toward(velocity.z, 0, 8*delta)
    if not is_on_floor():
        velocity.y -= 18 * delta
    move_and_slide()
    if distance < 18 and shoot_timer <= 0:
        shoot_timer = randf_range(0.8, 1.7) / difficulty
        if randf() < 0.52 * difficulty:
            player.take_damage(randi_range(5, 12))

func take_damage(amount):
    health -= amount
    esp_label.text = "BOT %d HP" % max(0, health)
    body_mesh.scale = Vector3(1.15, 0.9, 1.15)
    var tween = create_tween()
    tween.tween_property(body_mesh, "scale", Vector3.ONE, 0.12)
    if health <= 0:
        get_tree().call_group("game_ui", "bot_eliminated")
        queue_free()
