extends Node3D

const PLAYER_SCRIPT = preload("res://player.gd")
const SAVE_PATH := "user://savegame.json"
const TOTAL_STAGES := 10

var player: CharacterBody3D
var score := 0
var lives := 3
var stage := 1
var elapsed := 0.0
var paused := false
var game_started := false
var respawn_z := 4.0
var checkpoint_stage := 1
var daily_target := 20
var daily_progress := 0
var daily_reward := 50
var daily_claimed := false
var daily_date := ""
var selected_skin := 0
var best_score := 0
var best_time := 0.0
var wallet_coins := 0
var unlocked_skins: Array[bool] = [true, false, false, false, false]
var sound_enabled := true
var music_enabled := true
var vibration_enabled := true
var damage_cooldown := 0.0
var skin_prices := [0, 25, 50, 100, 200]
var hazards: Array[Area3D] = []
var coins: Array[Area3D] = []
var enemies: Array[Area3D] = []

var hud: CanvasLayer
var menu_panel: Panel
var pause_panel: Panel
var end_panel: Panel
var score_label: Label
var lives_label: Label
var stage_label: Label
var timer_label: Label
var message_label: Label
var jump_button: Button
var left_button: Button
var right_button: Button
var progress_bar: ProgressBar
var pause_button: Button
var skin_buttons: Array[Button] = []
var shop_panel: Panel
var settings_panel: Panel
var stage_select_panel: Panel

var skin_colors := [
    Color(0.20, 0.65, 1.0),
    Color(1.0, 0.28, 0.45),
    Color(0.30, 0.90, 0.45),
    Color(1.0, 0.72, 0.15),
    Color(0.70, 0.35, 1.0)
]

func _ready() -> void:
    _load_save()
    _check_daily_reset()
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

    _make_box("Ground", Vector3(14, 0.5, 820), Vector3(0, -0.5, -405), Color(0.18, 0.50, 0.25))
    _make_box("LeftWall", Vector3(0.7, 2.5, 820), Vector3(-7.2, 1.5, -405), Color(0.12, 0.30, 0.48))
    _make_box("RightWall", Vector3(0.7, 2.5, 820), Vector3(7.2, 1.5, -405), Color(0.12, 0.30, 0.48))

    for number in range(1, TOTAL_STAGES + 1):
        var end_z := -80.0 * number
        var start_z := end_z + 80.0
        _build_stage(number, start_z, end_z)
        _make_goal(end_z)
        _make_checkpoint_marker(end_z + 1.5, number)

func _build_stage(number: int, start_z: float, end_z: float) -> void:
    var difficulty := float(number - 1) / 9.0
    for i in range(9):
        var z := start_z - float(i + 1) * 7.2
        var x_options := [-4.0, -2.0, 0.0, 2.0, 4.0, 1.5, -1.5, 3.5, -3.5]
        var x := x_options[(i + number) % x_options.size()]
        var width := 2.6 - difficulty * 0.45
        var height := 0.8 + difficulty * 0.5
        _make_obstacle(Vector3(width, height, 1.3), Vector3(x, height / 2.0, z), Color(0.85, 0.25, 0.22))

        if i % 2 == 0:
            _make_coin(Vector3(x, 1.8 + difficulty, z - 2.5))

    for i in range(5):
        var z := start_z - 10.0 - float(i) * 13.0
        var x := sin(float(i + number) * 1.7) * (4.0 - difficulty * 0.5)
        _make_coin(Vector3(x, 1.5, z))

    if number >= 2:
        _make_hazard(Vector3(-3.0, 1.0, start_z - 28.0), 2.5 + difficulty * 2.5)
    if number >= 4:
        _make_hazard(Vector3(3.0, 1.0, start_z - 55.0), -(3.0 + difficulty * 2.0))

    if number >= 6:
        _make_box("Ramp", Vector3(3.5, 0.6, 5.0), Vector3(0, 0.3, start_z - 68.0), Color(0.30, 0.55, 0.90))

    if number >= 3:
        _make_enemy(Vector3(-3.5, 1.0, start_z - 42.0), 1.5 + difficulty * 1.5, 3.5)
    if number >= 7:
        _make_enemy(Vector3(3.0, 1.0, start_z - 70.0), 2.0 + difficulty * 2.0, 2.5)

func _create_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    player.set_script(PLAYER_SCRIPT)
    player.position = Vector3(0, 2, 4)
    add_child(player)
    player.set_skin(skin_colors[selected_skin])

func _create_hud() -> void:
    hud = CanvasLayer.new()
    add_child(hud)

    score_label = _label("العملات: 0  |  الرصيد: 0", Vector2(24, 18), 26)
    lives_label = _label("الحياة: ♥♥♥", Vector2(24, 52), 22)
    stage_label = _label("المرحلة: 1 / 10", Vector2(24, 82), 22)
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

    left_button = Button.new()
    left_button.text = "◀"
    left_button.position = Vector2(25, 0)
    left_button.size = Vector2(90, 75)
    left_button.anchor_top = 1.0
    left_button.anchor_bottom = 1.0
    left_button.offset_top = -110
    left_button.offset_bottom = -35
    left_button.button_down.connect(func(): if is_instance_valid(player): player.set_mobile_left(true))
    left_button.button_up.connect(func(): if is_instance_valid(player): player.set_mobile_left(false))
    hud.add_child(left_button)

    right_button = Button.new()
    right_button.text = "▶"
    right_button.position = Vector2(125, 0)
    right_button.size = Vector2(90, 75)
    right_button.anchor_top = 1.0
    right_button.anchor_bottom = 1.0
    right_button.offset_top = -110
    right_button.offset_bottom = -35
    right_button.button_down.connect(func(): if is_instance_valid(player): player.set_mobile_right(true))
    right_button.button_up.connect(func(): if is_instance_valid(player): player.set_mobile_right(false))
    hud.add_child(right_button)

    progress_bar = ProgressBar.new()
    progress_bar.position = Vector2(280, 24)
    progress_bar.size = Vector2(500, 18)
    progress_bar.min_value = 0.0
    progress_bar.max_value = 1.0
    progress_bar.value = 0.0
    progress_bar.show_percentage = false
    hud.add_child(progress_bar)

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
    title.position = Vector2(0, 80)
    title.size = Vector2(1280, 70)
    title.add_theme_font_size_override("font_size", 48)
    menu_panel.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "10 مراحل • عقبات • عملات • تحديات متزايدة"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.position = Vector2(0, 150)
    subtitle.size = Vector2(1280, 45)
    subtitle.add_theme_font_size_override("font_size", 22)
    menu_panel.add_child(subtitle)

    var shop := Button.new()
    shop.text = "المتجر"
    shop.position = Vector2(330, 350)
    shop.size = Vector2(140, 65)
    shop.add_theme_font_size_override("font_size", 22)
    shop.pressed.connect(_show_shop)
    menu_panel.add_child(shop)

    var settings := Button.new()
    settings.text = "الإعدادات"
    settings.position = Vector2(750, 430)
    settings.size = Vector2(140, 65)
    settings.add_theme_font_size_override("font_size", 22)
    settings.pressed.connect(_show_settings)
    menu_panel.add_child(settings)

    var stages := Button.new()
    stages.text = "اختيار المرحلة"
    stages.position = Vector2(330, 430)
    stages.size = Vector2(200, 60)
    stages.add_theme_font_size_override("font_size", 20)
    stages.pressed.connect(_show_stage_select)
    menu_panel.add_child(stages)

    var start := Button.new()
    start.text = "ابدأ اللعبة"
    start.position = Vector2(540, 350)
    start.size = Vector2(300, 75)
    start.add_theme_font_size_override("font_size", 28)
    start.pressed.connect(_start_game)
    menu_panel.add_child(start)

    var best := Label.new()
    best.text = "الرصيد: %d    |    أفضل نتيجة: %d    |    أفضل وقت: %s" % [wallet_coins, best_score, _format_time(best_time)]
    best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    best.position = Vector2(0, 440)
    best.size = Vector2(1280, 40)
    best.add_theme_font_size_override("font_size", 18)
    menu_panel.add_child(best)

    var skin_title := Label.new()
    skin_title.text = "اختر الشخصية"
    skin_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    skin_title.position = Vector2(0, 215)
    skin_title.size = Vector2(1280, 35)
    skin_title.add_theme_font_size_override("font_size", 20)
    menu_panel.add_child(skin_title)

    var names := ["أزرق", "وردي", "أخضر", "ذهبي", "بنفسجي"]
    for i in range(skin_colors.size()):
        var b := Button.new()
        b.text = names[i]
        b.position = Vector2(280 + i * 145, 260)
        b.size = Vector2(125, 55)
        b.modulate = skin_colors[i]
        b.pressed.connect(_select_skin.bind(i))
        menu_panel.add_child(b)
        skin_buttons.append(b)
    _refresh_skin_buttons()

    var daily := Label.new()
    daily.text = "مهمة اليوم: اجمع %d عملة — التقدم %d/%d — الجائزة %d" % [daily_target, daily_progress, daily_target, daily_reward]
    daily.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    daily.position = Vector2(0, 555)
    daily.size = Vector2(1280, 45)
    daily.add_theme_font_size_override("font_size", 18)
    menu_panel.add_child(daily)

    var info := Label.new()
    info.text = "الهاتف: اسحب من يسار الشاشة للحركة واضغط قفز. الكمبيوتر: WASD + Space."
    info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    info.position = Vector2(0, 495)
    info.size = Vector2(1280, 50)
    info.add_theme_font_size_override("font_size", 17)
    menu_panel.add_child(info)

func _select_skin(index: int) -> void:
    if index < 0 or index >= skin_colors.size():
        return
    if not unlocked_skins[index]:
        if wallet_coins >= skin_prices[index]:
            wallet_coins -= skin_prices[index]
            unlocked_skins[index] = true
            message_label.text = "تم فتح شخصية %s!" % ["أزرق", "وردي", "أخضر", "ذهبي", "بنفسجي"][index]
        else:
            message_label.text = "تحتاج %d عملة لفتح هذه الشخصية." % skin_prices[index]
            return
    selected_skin = index
    _refresh_skin_buttons()
    if is_instance_valid(player):
        player.set_skin(skin_colors[selected_skin])
    _save_game()

func _refresh_skin_buttons() -> void:
    var names := ["أزرق", "وردي", "أخضر", "ذهبي", "بنفسجي"]
    for i in range(skin_buttons.size()):
        var label := names[i]
        if not unlocked_skins[i]:
            label += " 🔒 %d" % skin_prices[i]
        elif i == selected_skin:
            label = "✓ " + label
        skin_buttons[i].text = label

func _start_game() -> void:
    stage = clampi(checkpoint_stage, 1, TOTAL_STAGES)
    respawn_z = -80.0 * float(stage - 1) + 4.0
    player.position = Vector3(0, 2, respawn_z)
    player.velocity = Vector3.ZERO
    score = 0
    lives = 3
    elapsed = 0.0
    damage_cooldown = 0.0
    paused = false
    get_tree().paused = false
    game_started = true
    menu_panel.hide()
    pause_button.show()
    jump_button.show()
    message_label.text = "ابدأ! أكمل المراحل العشر للوصول إلى النهاية."

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
    damage_cooldown = maxf(0.0, damage_cooldown - delta)
    score_label.text = "العملات: %d  |  الرصيد: %d" % [score, wallet_coins]
    lives_label.text = "الحياة: " + "♥".repeat(lives) + "♡".repeat(3 - lives)
    stage_label.text = "المرحلة: %d / %d" % [stage, TOTAL_STAGES]
    timer_label.text = "الوقت: %s" % _format_time(elapsed)
    var stage_start := -80.0 * float(stage - 1) + 4.0
    var stage_end := -80.0 * float(stage)
    progress_bar.value = clampf((stage_start - player.position.z) / (stage_start - stage_end), 0.0, 1.0)

    if player.position.y < -5.0:
        _take_damage()

    var target_z := -80.0 * float(stage)
    if player.position.z <= target_z:
        if stage < TOTAL_STAGES:
            _advance_stage(stage + 1)
        else:
            _win_game()

func _advance_stage(next_stage: int) -> void:
    checkpoint_stage = next_stage
    stage = next_stage
    respawn_z = -80.0 * float(checkpoint_stage - 1) + 4.0
    player.position = Vector3(0, 2, respawn_z)
    player.velocity = Vector3.ZERO
    lives = min(3, lives + 1)
    message_label.text = "ممتاز! وصلت إلى المرحلة %d من %d." % [stage, TOTAL_STAGES]
    _save_game()

func _win_game() -> void:
    game_started = false
    wallet_coins += score
    _save_game()
    if best_score < score:
        best_score = score
    if best_time <= 0.0 or elapsed < best_time:
        best_time = elapsed
    _save_game()
    _show_end_panel(true)

func _take_damage() -> void:
    if damage_cooldown > 0.0 or not game_started:
        return
    damage_cooldown = 1.25
    lives -= 1
    if lives <= 0:
        _game_over()
        return
    player.position = Vector3(0, 2, respawn_z)
    player.velocity = Vector3.ZERO
    message_label.text = "انتبه! خسرت حياة."

func _game_over() -> void:
    game_started = false
    wallet_coins += score
    _save_game()
    _show_end_panel(false)

func _show_end_panel(won: bool) -> void:
    left_button.hide()
    right_button.hide()
    jump_button.hide()
    pause_button.hide()
    progress_bar.hide()
    end_panel = Panel.new()
    end_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hud.add_child(end_panel)

    var title := Label.new()
    title.text = "🎉 أكملت اللعبة!" if won else "انتهت اللعبة"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.position = Vector2(0, 170)
    title.size = Vector2(1280, 80)
    title.add_theme_font_size_override("font_size", 46)
    end_panel.add_child(title)

    var stats := Label.new()
    stats.text = "العملات: %d\nالوقت: %s\nالمرحلة: %d / %d" % [score, _format_time(elapsed), stage, TOTAL_STAGES]
    stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stats.position = Vector2(0, 270)
    stats.size = Vector2(1280, 130)
    stats.add_theme_font_size_override("font_size", 25)
    end_panel.add_child(stats)

    var again := Button.new()
    again.text = "العب من جديد"
    again.position = Vector2(490, 440)
    again.size = Vector2(300, 70)
    again.pressed.connect(func(): get_tree().reload_current_scene())
    end_panel.add_child(again)

func _format_time(value: float) -> String:
    if value <= 0.0:
        return "--:--"
    return "%d:%02d" % [int(value) / 60, int(value) % 60]

func _save_game() -> void:
    var data := {
        "best_score": best_score,
        "best_time": best_time,
        "skin": selected_skin,
        "wallet_coins": wallet_coins,
        "unlocked_skins": unlocked_skins,
        "sound_enabled": sound_enabled,
        "music_enabled": music_enabled,
        "vibration_enabled": vibration_enabled,
        "checkpoint_stage": checkpoint_stage,
        "daily_progress": daily_progress,
        "daily_claimed": daily_claimed,
        "daily_date": daily_date
    }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data))
        file.close()

func _load_save() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if not file:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    if parsed is Dictionary:
        best_score = int(parsed.get("best_score", 0))
        best_time = float(parsed.get("best_time", 0.0))
        selected_skin = clampi(int(parsed.get("skin", 0)), 0, skin_colors.size() - 1)
        wallet_coins = maxi(0, int(parsed.get("wallet_coins", 0)))
        var saved_unlocks = parsed.get("unlocked_skins", unlocked_skins)
        if saved_unlocks is Array and saved_unlocks.size() == skin_colors.size():
            for i in range(skin_colors.size()):
                unlocked_skins[i] = bool(saved_unlocks[i])
        unlocked_skins[0] = true
        if not unlocked_skins[selected_skin]:
            selected_skin = 0
        sound_enabled = bool(parsed.get("sound_enabled", true))
        music_enabled = bool(parsed.get("music_enabled", true))
        vibration_enabled = bool(parsed.get("vibration_enabled", true))
        checkpoint_stage = clampi(int(parsed.get("checkpoint_stage", 1)), 1, TOTAL_STAGES)
        daily_progress = clampi(int(parsed.get("daily_progress", 0)), 0, daily_target)
        daily_claimed = bool(parsed.get("daily_claimed", false))
        daily_date = str(parsed.get("daily_date", ""))

func _check_daily_reset() -> void:
    var today := Time.get_date_string_from_system()
    if daily_date == "":
        daily_date = today
        _save_game()
        return
    if daily_date != today:
        daily_date = today
        daily_progress = 0
        daily_claimed = false
        _save_game()

func _show_stage_select() -> void:
    if is_instance_valid(stage_select_panel):
        stage_select_panel.queue_free()
    stage_select_panel = Panel.new()
    stage_select_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hud.add_child(stage_select_panel)

    var title := Label.new()
    title.text = "اختيار المرحلة"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.position = Vector2(0, 70)
    title.size = Vector2(1280, 60)
    title.add_theme_font_size_override("font_size", 40)
    stage_select_panel.add_child(title)

    var info := Label.new()
    info.text = "المراحل المفتوحة حتى المرحلة %d — افتح مراحل جديدة بإكمال المرحلة الحالية." % checkpoint_stage
    info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    info.position = Vector2(0, 135)
    info.size = Vector2(1280, 45)
    info.add_theme_font_size_override("font_size", 18)
    stage_select_panel.add_child(info)

    for i in range(TOTAL_STAGES):
        var n := i + 1
        var b := Button.new()
        b.text = ("✓ " if n <= checkpoint_stage else "🔒 ") + "المرحلة %d" % n
        var col := i % 5
        var row := i / 5
        b.position = Vector2(170 + col * 195, 220 + row * 115)
        b.size = Vector2(170, 80)
        b.add_theme_font_size_override("font_size", 19)
        b.disabled = n > checkpoint_stage
        if not b.disabled:
            b.pressed.connect(_select_stage.bind(n))
        stage_select_panel.add_child(b)

    var close := Button.new()
    close.text = "رجوع"
    close.position = Vector2(490, 470)
    close.size = Vector2(300, 65)
    close.pressed.connect(_close_stage_select)
    stage_select_panel.add_child(close)

func _select_stage(selected_stage: int) -> void:
    if selected_stage < 1 or selected_stage > checkpoint_stage:
        return
    stage = selected_stage
    respawn_z = -80.0 * float(stage - 1) + 4.0
    player.position = Vector3(0, 2, respawn_z)
    player.velocity = Vector3.ZERO
    score = 0
    lives = 3
    elapsed = 0.0
    game_started = true
    paused = false
    get_tree().paused = false
    if is_instance_valid(stage_select_panel):
        stage_select_panel.queue_free()
    if is_instance_valid(menu_panel):
        menu_panel.hide()
    message_label.text = "بدأت من المرحلة %d." % stage

func _close_stage_select() -> void:
    if is_instance_valid(stage_select_panel):
        stage_select_panel.queue_free()

func _show_shop() -> void:
    shop_panel = Panel.new()
    shop_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shop_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
    hud.add_child(shop_panel)

    var title := Label.new()
    title.text = "متجر الشخصيات"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.position = Vector2(0, 90)
    title.size = Vector2(1280, 60)
    title.add_theme_font_size_override("font_size", 40)
    shop_panel.add_child(title)

    var balance := Label.new()
    balance.text = "رصيدك: %d عملة" % wallet_coins
    balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    balance.position = Vector2(0, 155)
    balance.size = Vector2(1280, 40)
    balance.add_theme_font_size_override("font_size", 24)
    shop_panel.add_child(balance)

    var names := ["أزرق", "وردي", "أخضر", "ذهبي", "بنفسجي"]
    for i in range(skin_colors.size()):
        var b := Button.new()
        b.text = names[i] + ("\nمفتوحة" if unlocked_skins[i] else "\nفتح بـ %d" % skin_prices[i])
        b.position = Vector2(190 + i * 190, 250)
        b.size = Vector2(165, 100)
        b.modulate = skin_colors[i]
        b.add_theme_font_size_override("font_size", 18)
        b.pressed.connect(_shop_skin_pressed.bind(i, balance))
        shop_panel.add_child(b)

    var close := Button.new()
    close.text = "إغلاق"
    close.position = Vector2(490, 430)
    close.size = Vector2(300, 65)
    close.pressed.connect(_close_shop)
    shop_panel.add_child(close)

func _shop_skin_pressed(index: int, balance: Label) -> void:
    if not unlocked_skins[index]:
        if wallet_coins < skin_prices[index]:
            balance.text = "رصيدك: %d — تحتاج %d عملة إضافية" % [wallet_coins, skin_prices[index] - wallet_coins]
            return
        wallet_coins -= skin_prices[index]
        unlocked_skins[index] = true
    selected_skin = index
    if is_instance_valid(player):
        player.set_skin(skin_colors[selected_skin])
    balance.text = "رصيدك: %d عملة — الشخصية المختارة: %s" % [wallet_coins, ["أزرق", "وردي", "أخضر", "ذهبي", "بنفسجي"][index]]
    _save_game()
    _refresh_skin_buttons()

func _close_shop() -> void:
    if is_instance_valid(shop_panel):
        shop_panel.queue_free()
    if is_instance_valid(menu_panel):
        _refresh_skin_buttons()

func _show_settings() -> void:
    settings_panel = Panel.new()
    settings_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hud.add_child(settings_panel)

    var title := Label.new()
    title.text = "الإعدادات"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.position = Vector2(0, 120)
    title.size = Vector2(1280, 60)
    title.add_theme_font_size_override("font_size", 40)
    settings_panel.add_child(title)

    var sound := CheckButton.new()
    sound.text = "المؤثرات الصوتية"
    sound.button_pressed = sound_enabled
    sound.position = Vector2(490, 220)
    sound.size = Vector2(300, 60)
    sound.toggled.connect(func(v): sound_enabled = v; _save_game())
    settings_panel.add_child(sound)

    var music := CheckButton.new()
    music.text = "الموسيقى"
    music.button_pressed = music_enabled
    music.position = Vector2(490, 290)
    music.size = Vector2(300, 60)
    music.toggled.connect(func(v): music_enabled = v; _save_game())
    settings_panel.add_child(music)

    var vibration := CheckButton.new()
    vibration.text = "الاهتزاز"
    vibration.button_pressed = vibration_enabled
    vibration.position = Vector2(490, 360)
    vibration.size = Vector2(300, 60)
    vibration.toggled.connect(func(v): vibration_enabled = v; _save_game())
    settings_panel.add_child(vibration)

    var note := Label.new()
    note.text = "تم تجهيز الخيارات للحفظ، وسيتم ربط الصوت والاهتزاز بالمؤثرات عند إضافتها."
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    note.position = Vector2(100, 440)
    note.size = Vector2(1080, 50)
    settings_panel.add_child(note)

    var close := Button.new()
    close.text = "إغلاق"
    close.position = Vector2(490, 520)
    close.size = Vector2(300, 65)
    close.pressed.connect(func(): settings_panel.queue_free())
    settings_panel.add_child(close)

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
        daily_progress = mini(daily_target, daily_progress + 1)
        if daily_progress >= daily_target and not daily_claimed:
            daily_claimed = true
            wallet_coins += daily_reward
            message_label.text = "🎁 أكملت مهمة اليوم! حصلت على %d عملة." % daily_reward
        coin.queue_free()
        _save_game()

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
    if body == player and game_started:
        _take_damage()

func _make_enemy(pos: Vector3, speed: float, range_x: float) -> void:
    var enemy := Area3D.new()
    enemy.position = pos
    enemy.set_meta("base_x", pos.x)
    enemy.set_meta("base_z", pos.z)
    enemy.set_meta("speed", speed)
    enemy.set_meta("range_x", range_x)
    add_child(enemy)
    enemies.append(enemy)

    var mesh_instance := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = 0.9
    mesh.height = 1.8
    mesh_instance.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.75, 0.12, 0.85)
    material.emission_enabled = true
    material.emission = Color(0.25, 0.02, 0.35)
    mesh_instance.material_override = material
    enemy.add_child(mesh_instance)

    var eye := MeshInstance3D.new()
    var eye_mesh := SphereMesh.new()
    eye_mesh.radius = 0.16
    eye_mesh.height = 0.32
    eye.mesh = eye_mesh
    eye.position = Vector3(0, 0.25, -0.8)
    var eye_mat := StandardMaterial3D.new()
    eye_mat.albedo_color = Color(0.95, 0.95, 1.0)
    eye.material_override = eye_mat
    enemy.add_child(eye)

    var collision := CollisionShape3D.new()
    var shape := SphereShape3D.new()
    shape.radius = 1.0
    collision.shape = shape
    enemy.add_child(collision)
    enemy.body_entered.connect(_on_enemy.bind(enemy))

func _on_enemy(body: Node3D, enemy: Area3D) -> void:
    if body == player and game_started and is_instance_valid(enemy):
        _take_damage()
        player.position = Vector3(0, 2, respawn_z)
        player.velocity = Vector3.ZERO

func _make_checkpoint_marker(z: float, number: int) -> void:
    var left := MeshInstance3D.new()
    var pillar_mesh := BoxMesh.new()
    pillar_mesh.size = Vector3(0.45, 4.0, 0.45)
    left.mesh = pillar_mesh
    left.position = Vector3(-5.5, 2.0, z)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.15, 0.85, 0.95)
    mat.emission_enabled = true
    mat.emission = Color(0.05, 0.45, 0.8)
    mat.emission_energy_multiplier = 1.5
    left.material_override = mat
    add_child(left)

    var right := left.duplicate()
    right.position.x = 5.5
    add_child(right)

    var banner := Label3D.new()
    banner.text = "CHECKPOINT %d" % number
    banner.position = Vector3(0, 4.0, z)
    banner.font_size = 48
    banner.modulate = Color(0.7, 0.95, 1.0)
    add_child(banner)

func _make_goal(z: float) -> void:
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
    var now := Time.get_ticks_msec() / 1000.0
    for h in hazards:
        if is_instance_valid(h):
            var base_x: float = h.get_meta("base_x")
            var speed: float = h.get_meta("speed")
            h.position.x = base_x + sin(now * speed) * 3.0

    for enemy in enemies:
        if is_instance_valid(enemy):
            var base_x: float = enemy.get_meta("base_x")
            var base_z: float = enemy.get_meta("base_z")
            var speed: float = enemy.get_meta("speed")
            var range_x: float = enemy.get_meta("range_x")
            enemy.position.x = base_x + sin(now * speed) * range_x
            enemy.position.z = base_z + cos(now * speed * 0.6) * 2.0
