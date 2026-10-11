extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const BotScript = preload("res://scripts/bot.gd")
var player
var ui_layer: CanvasLayer
var panel: PanelContainer
var hud_label: Label
var message_label: Label
var round_label: Label
var bot_count := 5
var round_number := 1
var team_score := 0
var enemy_score := 0
var money := 800
var bomb_planted := false
var bomb_timer := 35.0
var esp_enabled := false
var menu_open := false
var game_started := false
var round_time := 100.0

func _ready():
    randomize()
    build_world()
    build_ui()
    show_main_menu()

func build_world():
    var env = WorldEnvironment.new()
    var e = Environment.new()
    e.background_mode = Environment.BG_SKY
    e.sky = Sky.new()
    var sky_mat = ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color(0.04,0.12,0.22)
    sky_mat.sky_horizon_color = Color(0.7,0.43,0.25)
    sky_mat.ground_bottom_color = Color(0.04,0.05,0.07)
    sky_mat.ground_horizon_color = Color(0.22,0.18,0.15)
    e.sky.sky_material = sky_mat
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color(0.52,0.59,0.72)
    e.ambient_light_energy = 0.65
    e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    e.glow_enabled = true
    env.environment = e
    add_child(env)
    var sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -32, 0)
    sun.light_energy = 1.4
    sun.shadow_enabled = true
    add_child(sun)
    make_box("Ground", Vector3(0,-0.3,0), Vector3(48,0.6,48), Color(0.28,0.29,0.28), true)
    # Original compact European old-town combat map, two lanes and bomb sites A/B.
    for x in [-19.0,19.0]:
        make_box("Boundary", Vector3(x,2,0), Vector3(1,4,42), Color(0.46,0.39,0.31), true)
    for z in [-20.0,20.0]:
        make_box("Boundary", Vector3(0,2,z), Vector3(40,4,1), Color(0.46,0.39,0.31), true)
    # Buildings define tactical routes with doors/lanes left open.
    make_box("North building", Vector3(-10,2,-10), Vector3(10,4,10), Color(0.62,0.49,0.36), true)
    make_box("North building", Vector3(10,2,-10), Vector3(10,4,10), Color(0.55,0.43,0.33), true)
    make_box("South building", Vector3(-10,2,10), Vector3(10,4,10), Color(0.60,0.48,0.36), true)
    make_box("South building", Vector3(10,2,10), Vector3(10,4,10), Color(0.53,0.43,0.34), true)
    # Alley cuts are created by low walls and cover rather than sealed blocks.
    # Remove solid building centers visually by using facade-like tall wall segments around lanes.
    # Add crates, concrete barriers and site markers.
    for p in [Vector3(-4,0.8,-5),Vector3(4,0.8,-5),Vector3(-5,0.8,5),Vector3(5,0.8,5),Vector3(0,0.65,0)]:
        make_box("Crate",p,Vector3(1.6,1.6,1.6),Color(0.28,0.20,0.13),true)
    for p in [Vector3(-12,0.65,0),Vector3(12,0.65,0),Vector3(0,0.65,-12),Vector3(0,0.65,12)]:
        make_box("Concrete cover",p,Vector3(2.5,1.3,0.8),Color(0.37,0.39,0.39),true)
    make_site("A", Vector3(-12,0.04,-12), Color(0.95,0.25,0.12))
    make_site("B", Vector3(12,0.04,12), Color(0.12,0.55,1.0))
    # Decorative lights
    for p in [Vector3(-8,4,-2),Vector3(8,4,2),Vector3(0,4,0)]:
        var light = OmniLight3D.new()
        light.position = p
        light.light_color = Color(1.0,0.58,0.3)
        light.light_energy = 1.1
        light.omni_range = 9
        add_child(light)

func make_box(label, pos, size, color, collision=true):
    var body = StaticBody3D.new() if collision else Node3D.new()
    body.name = label
    body.position = pos
    var mesh = MeshInstance3D.new()
    var bm = BoxMesh.new()
    bm.size = size
    mesh.mesh = bm
    var mat = StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.84
    mesh.material_override = mat
    body.add_child(mesh)
    if collision:
        var cs = CollisionShape3D.new()
        var shape = BoxShape3D.new()
        shape.size = size
        cs.shape = shape
        body.add_child(cs)
    add_child(body)
    return body

func make_site(letter, pos, color):
    var ring = MeshInstance3D.new()
    var cylinder = CylinderMesh.new()
    cylinder.top_radius = 2.1
    cylinder.bottom_radius = 2.1
    cylinder.height = 0.04
    ring.mesh = cylinder
    ring.position = pos
    var mat = StandardMaterial3D.new()
    mat.albedo_color = color
    mat.emission_enabled = true
    mat.emission = color * 0.4
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_color.a = 0.55
    ring.material_override = mat
    add_child(ring)
    var label = Label3D.new()
    label.text = "BOMBSITE " + letter
    label.position = pos + Vector3(0,0.25,0)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.font_size = 48
    label.modulate = color
    add_child(label)

func build_ui():
    ui_layer = CanvasLayer.new()
    ui_layer.layer = 5
    add_child(ui_layer)
    var root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui_layer.add_child(root)
    hud_label = Label.new()
    hud_label.position = Vector2(22, 20)
    hud_label.add_theme_font_size_override("font_size", 21)
    hud_label.add_theme_color_override("font_color", Color(0.82,0.94,1))
    root.add_child(hud_label)
    round_label = Label.new()
    round_label.anchor_left = 0.5
    round_label.anchor_right = 0.5
    round_label.position = Vector2(-180, 18)
    round_label.size = Vector2(360, 40)
    round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    round_label.add_theme_font_size_override("font_size", 22)
    round_label.add_theme_color_override("font_color", Color(1,0.58,0.18))
    root.add_child(round_label)
    message_label = Label.new()
    message_label.anchor_left = 0.5
    message_label.anchor_top = 0.72
    message_label.anchor_right = 0.5
    message_label.position = Vector2(-250, 0)
    message_label.size = Vector2(500, 50)
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message_label.add_theme_font_size_override("font_size", 28)
    message_label.add_theme_color_override("font_color", Color(1,0.68,0.2))
    root.add_child(message_label)
    # Minimal crosshair
    var cross = Label.new()
    cross.text = "+"
    cross.anchor_left = 0.5
    cross.anchor_top = 0.5
    cross.anchor_right = 0.5
    cross.anchor_bottom = 0.5
    cross.position = Vector2(-8,-17)
    cross.add_theme_font_size_override("font_size", 30)
    cross.add_theme_color_override("font_color", Color(0.8,1,0.86))
    root.add_child(cross)
    panel = PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    panel.custom_minimum_size = Vector2(440, 480)
    panel.position = Vector2(-220,-240)
    root.add_child(panel)
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.025,0.055,0.085,0.97)
    style.border_color = Color(0.05,0.65,1.0)
    style.set_border_width_all(2)
    style.set_corner_radius_all(12)
    panel.add_theme_stylebox_override("panel", style)

func add_menu_button(parent, text, callback):
    var b = Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(360, 46)
    b.add_theme_font_size_override("font_size", 18)
    b.pressed.connect(callback)
    parent.add_child(b)
    return b

func show_main_menu():
    menu_open = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    clear_panel()
    var v = VBoxContainer.new()
    v.add_theme_constant_override("separation", 12)
    panel.add_child(v)
    var title = Label.new()
    title.text = "STRIKE FORCE"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 34)
    title.add_theme_color_override("font_color", Color(1,0.43,0.12))
    v.add_child(title)
    var sub = Label.new()
    sub.text = "TACTICAL FPS  •  OFFLINE COMBAT"
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sub.add_theme_font_size_override("font_size", 13)
    v.add_child(sub)
    add_menu_button(v,"ИГРАТЬ — БОМБА 5v5", start_game)
    add_menu_button(v,"ТРЕНИРОВКА С БОТАМИ", start_training)
    add_menu_button(v,"АРСЕНАЛ И СКИНЫ", show_skins)
    add_menu_button(v,"МОДИФИКАЦИИ WH / ESP", show_mod_menu)
    add_menu_button(v,"НАСТРОЙКИ", show_settings)
    var foot = Label.new()
    foot.text = "WASD — движение • ЛКМ — огонь • R — перезарядка\nE — взаимодействие • ESC — меню"
    foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    v.add_child(foot)
    panel.visible = true

func clear_panel():
    for c in panel.get_children():
        c.queue_free()

func start_game():
    clear_bots()
    game_started = true
    menu_open = false
    panel.visible = false
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    round_number = 1
    team_score = 0
    enemy_score = 0
    money = 800
    bomb_planted = false
    round_time = 100
    spawn_player()
    spawn_bots(5)
    update_hud()
    show_message("РАУНД 1 — ЗАЩИЩАЙТЕ ТОЧКИ A И B")

func start_training():
    start_game()
    money = 9999
    show_message("ТРЕНИРОВКА — БОТЫ И УПРАЖНЕНИЯ")

func spawn_player():
    if is_instance_valid(player):
        player.queue_free()
    player = PlayerScript.new()
    player.position = Vector3(0,0.1,15)
    add_child(player)

func spawn_bots(count):
    for i in range(count):
        var b = BotScript.new()
        b.position = Vector3(randf_range(-14,14),0.1,randf_range(-12,7))
        b.difficulty = 1.0 + float(i % 3) * 0.15
        add_child(b)

func clear_bots():
    for b in get_tree().get_nodes_in_group("bot"):
        b.queue_free()

func _process(delta):
    if game_started and not menu_open:
        round_time -= delta
        if bomb_planted:
            bomb_timer -= delta
            if bomb_timer <= 0:
                enemy_score += 1
                end_round(false, "БОМБА ВЗОРВАЛАСЬ")
        elif round_time <= 0:
            team_score += 1
            end_round(true, "ВРЕМЯ ВЫШЛО — ПОБЕДА ЗАЩИТЫ")
        if Input.is_action_just_pressed("interact"):
            var dist_a = player.global_position.distance_to(Vector3(-12,0,-12))
            var dist_b = player.global_position.distance_to(Vector3(12,0,12))
            if not bomb_planted and minf(dist_a, dist_b) < 3.0:
                bomb_planted = true
                bomb_timer = 35.0
                show_message("БОМБА УСТАНОВЛЕНА — 35 СЕКУНД")
            elif bomb_planted and minf(dist_a, dist_b) < 3.0:
                bomb_planted = false
                team_score += 1
                end_round(true, "БОМБА ОБЕЗВРЕЖЕНА")
        update_hud()
        if Input.is_action_just_pressed("menu"):
            show_pause_menu()

func _unhandled_input(event):
    if event.is_action_pressed("menu") and game_started:
        show_pause_menu()

func show_pause_menu():
    menu_open = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    panel.visible = true
    clear_panel()
    var v = VBoxContainer.new()
    v.add_theme_constant_override("separation", 14)
    panel.add_child(v)
    var t = Label.new()
    t.text = "ПАУЗА"
    t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    t.add_theme_font_size_override("font_size", 32)
    v.add_child(t)
    add_menu_button(v,"ПРОДОЛЖИТЬ", func():
        panel.visible = false
        menu_open = false
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
    add_menu_button(v,"WH / ESP", show_mod_menu)
    add_menu_button(v,"НАСТРОЙКИ", show_settings)
    add_menu_button(v,"В ГЛАВНОЕ МЕНЮ", show_main_menu)

func show_mod_menu():
    menu_open = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    panel.visible = true
    clear_panel()
    var v = VBoxContainer.new()
    v.add_theme_constant_override("separation", 10)
    panel.add_child(v)
    var t = Label.new()
    t.text = "ПАНЕЛЬ WH / ESP"
    t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    t.add_theme_font_size_override("font_size", 28)
    t.add_theme_color_override("font_color", Color(0.1,0.8,1))
    v.add_child(t)
    var chk = CheckButton.new()
    chk.text = "ESP: подсветка и подписи ботов"
    chk.button_pressed = esp_enabled
    chk.toggled.connect(func(val):
        esp_enabled = val
        for b in get_tree().get_nodes_in_group("bot"):
            b.esp_label.visible = val)
    v.add_child(chk)
    var info = Label.new()
    info.text = "WH/ESP работает только на ботах\nв этой собственной офлайн-игре."
    info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(info)
    add_menu_button(v,"НАЗАД", func():
        if game_started: show_pause_menu()
        else: show_main_menu())

func show_skins():
    menu_open = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    panel.visible = true
    clear_panel()
    var v = VBoxContainer.new()
    v.add_theme_constant_override("separation", 12)
    panel.add_child(v)
    var t = Label.new()
    t.text = "АРСЕНАЛ И СКИНЫ"
    t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    t.add_theme_font_size_override("font_size", 28)
    v.add_child(t)
    var info = Label.new()
    info.text = "АК-стиль • Неоновый импульс • Пустынный камуфляж\nКосметическая витрина прототипа.\nБаланс: $%d" % money
    info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    v.add_child(info)
    add_menu_button(v,"ЭКИПИРОВАТЬ: НЕОНОВЫЙ ИМПУЛЬС", func(): show_message("СКИН ЭКИПИРОВАН"))
    add_menu_button(v,"КУПИТЬ БРОНЮ — $650", func():
        if money >= 650:
            money -= 650
            show_message("БРОНЯ КУПЛЕНА")
        else: show_message("НЕДОСТАТОЧНО ДЕНЕГ"))
    add_menu_button(v,"НАЗАД", show_main_menu)

func show_settings():
    menu_open = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    panel.visible = true
    clear_panel()
    var v = VBoxContainer.new()
    v.add_theme_constant_override("separation", 10)
    panel.add_child(v)
    var t = Label.new()
    t.text = "НАСТРОЙКИ"
    t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    t.add_theme_font_size_override("font_size", 28)
    v.add_child(t)
    var sens_label = Label.new()
    sens_label.text = "Чувствительность мыши"
    v.add_child(sens_label)
    var slider = HSlider.new()
    slider.min_value = 0.0007
    slider.max_value = 0.004
    slider.step = 0.0001
    slider.value = 0.0018
    slider.value_changed.connect(func(val):
        if is_instance_valid(player): player.mouse_sensitivity = val)
    v.add_child(slider)
    var info = Label.new()
    info.text = "WASD — ходьба • Space — прыжок\nЛКМ — стрельба • R — перезарядка\nE — бомба на точке • ESC — пауза"
    info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(info)
    add_menu_button(v,"НАЗАД", show_main_menu)

func update_hud():
    var hp = player.health if is_instance_valid(player) else 100
    var ammo = player.ammo if is_instance_valid(player) else 30
    var reserve = player.reserve if is_instance_valid(player) else 90
    var bots = get_tree().get_nodes_in_group("bot").size()
    hud_label.text = "HP %d   $%d\nПАТРОНЫ %d / %d   БОТЫ %d" % [hp,money,ammo,reserve,bots]
    round_label.text = "РАУНД %d   %d : %d   %s" % [round_number,team_score,enemy_score,("БОМБА %.0fс" % bomb_timer) if bomb_planted else ("%.0fс" % maxf(0,round_time))]

func show_message(msg):
    message_label.text = msg
    var tw = create_tween()
    message_label.modulate.a = 1
    tw.tween_interval(2.0)
    tw.tween_property(message_label, "modulate:a", 0.0, 0.7)

func bot_eliminated():
    money += 200
    update_hud()
    if get_tree().get_nodes_in_group("bot").size() <= 1:
        team_score += 1
        end_round(true, "КОМАНДА ПРОТИВНИКА УСТРАНЕНА")

func end_round(won, msg):
    game_started = false
    bomb_planted = false
    money += 3250 if won else 1400
    show_message(msg)
    round_number += 1
    if team_score >= 13 or enemy_score >= 13:
        show_message("МАТЧ ОКОНЧЕН")
        await get_tree().create_timer(2.0).timeout
        show_main_menu()
    else:
        await get_tree().create_timer(2.0).timeout
        start_game()
