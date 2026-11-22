extends CanvasLayer










signal finished(won: bool)

const MonsterScript: = preload("res://scripts/story_monster.gd")
const W: = 640.0
const H: = 360.0
const GY: = 300.0

const PLAYER_MAX: = 100.0
const BOSS_MAX: = 100.0
const AMMO_MAX: = 12
const BULLET_DMG: = 12.0
const BOSS_DODGE_CHANCE: = 0.5

enum Phase{INTRO, MINIONS, BOSS_INTRO, BOSS, WON, LOST}

var theme_name: = "ground"
## 1 = first arena. Higher levels bring more minions and a boss with more health.
var level: = 1
var _boss_max: = BOSS_MAX

var _g: = 900.0
var _jump: = -330.0
var _speed: = 110.0

var _phase: = Phase.INTRO
var _phase_t: = 0.0


var _px: = 120.0
var _py: = GY
var _pvy: = 0.0
var _p_ground: = true
var _p_face: = 1.0
var _p_hp: = PLAYER_MAX
var _p_ammo: = 0
var _p_gun: = false
var _p_fire_cd: = 0.0
var _p_punch_cd: = 0.0
var _p_punch_t: = 0.0
var _p_inv: = 0.0
var _p_flash: = 0.0


var _minions: Array = []
var _m_total: = 6
var _m_spawned: = 0
var _m_spawn_cd: = 0.0


var _bullets: Array = []


var _boss_on: = false
var _actors: Node2D
var _overlay: Node2D
var _p_sprite: AnimatedSprite2D
var _boss_node: Node2D
var _bx: = W + 40.0
var _by: = GY
var _bvx: = 0.0
var _bvy: = 0.0
var _bhp: = BOSS_MAX
var _b_face: = -1.0
var _b_hop_cd: = 1.5
var _b_dodge_cd: = 0.0
var _b_atk_cd: = 1.0
var _b_punch_t: = 0.0
var _b_flash: = 0.0


var _t_left: = false
var _t_right: = false
var _t_jump: = false
var _jump_queued: = false
var _time: = 0.0

var _stars: Array = []

# hit effects: screen shake + small spark particles
var _shake: = 0.0
var _base_pos: = Vector2.ZERO
var _sparks: Array = []


var _view: Node2D
var _bg: ColorRect
var _banner: Label
var _lbl_p: Label
var _lbl_b: Label
var _lbl_ammo: Label
var _btns: Control
var _btn_action: Button
var _btn_exit: Button
var _done: = false


func _s(en: String, ar: String, fr: String) -> String:
	var code: = str(Loc.current)
	if code == "ar":
		return ar
	if code == "fr":
		return fr
	return en


func _ready() -> void :
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bg = ColorRect.new()
	_bg.color = Color.BLACK
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view = Node2D.new()
	add_child(_view)
	_view.draw.connect(_on_view_draw)
	# Real models: the player is drawn with the skin they equipped, enemies with the game's own monsters.
	_actors = Node2D.new()
	_view.add_child(_actors)
	_p_sprite = AnimatedSprite2D.new()
	_actors.add_child(_p_sprite)
	Economy.bind(_p_sprite)
	_p_sprite.speed_scale = 1.0
	_p_sprite.play(&"idle")
	_overlay = Node2D.new()
	_view.add_child(_overlay)
	_overlay.draw.connect(_on_overlay_draw)
	var rng: = RandomNumberGenerator.new()
	rng.seed = 4242
	for i in 48:
		_stars.append(Vector3(rng.randf() * W, rng.randf() * (GY - 20.0), rng.randf_range(0.6, 1.6)))
	_lbl_p = _make_label(Vector2(10.0, 6.0), Vector2(220.0, 16.0), HORIZONTAL_ALIGNMENT_LEFT, 11)
	_lbl_b = _make_label(Vector2(W - 230.0, 6.0), Vector2(220.0, 16.0), HORIZONTAL_ALIGNMENT_RIGHT, 11)
	_lbl_ammo = _make_label(Vector2(10.0, 44.0), Vector2(300.0, 14.0), HORIZONTAL_ALIGNMENT_LEFT, 9)
	_banner = _make_label(Vector2(40.0, 105.0), Vector2(W - 80.0, 80.0), HORIZONTAL_ALIGNMENT_CENTER, 20)
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_buttons()
	get_viewport().size_changed.connect(_layout)
	_layout()
	set_process(true)


func _make_label(pos: Vector2, sz: Vector2, align: HorizontalAlignment, fs: int) -> Label:
	var l: = Label.new()
	l.position = pos
	l.size = sz
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.add_child(l)
	return l


func _mk_btn(text: String, variation: StringName) -> Button:
	var b: = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.theme_type_variation = variation
	_btns.add_child(b)
	return b


func _build_buttons() -> void :
	_btns = Control.new()
	_btns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_btns)
	_btns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var touch: = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	var bl: = _mk_btn("<", &"")
	var br: = _mk_btn(">", &"")
	var bj: = _mk_btn("^", &"")
	_btn_action = _mk_btn("", &"DangerButton")
	bl.button_down.connect( func() -> void : _t_left = true)
	bl.button_up.connect( func() -> void : _t_left = false)
	br.button_down.connect( func() -> void : _t_right = true)
	br.button_up.connect( func() -> void : _t_right = false)
	bj.button_down.connect( func() -> void : _jump_queued = true)
	_btn_action.button_down.connect(_do_action)
	bl.visible = touch
	br.visible = touch
	bj.visible = touch
	_btn_action.visible = touch
	bl.name = "L"
	br.name = "R"
	bj.name = "J"
	_btn_exit = _mk_btn("EXIT", &"")
	_btn_exit.visible = false  # the arena is mandatory: it can only be left by winning
	_btn_exit.disabled = true


func _layout() -> void :
	var vp: = get_viewport().get_visible_rect().size
	var s: = minf(vp.x / W, vp.y / H)
	_view.scale = Vector2(s, s)
	_view.position = (vp - Vector2(W, H) * s) * 0.5
	_base_pos = _view.position
	var d: = clampf(vp.y * 0.2, 56.0, 120.0)
	var fs: = clampi(int(d * 0.3), 14, 30)
	var pad: = vp.x * 0.03
	var by: = vp.y - d - pad * 0.6
	var names: = {"L": Vector2(pad, by), "R": Vector2(pad + d * 1.15, by), "J": Vector2(vp.x - pad - d * 2.3, by)}
	for k in names.keys():
		var b: = _btns.get_node(str(k)) as Button
		b.custom_minimum_size = Vector2(d, d)
		b.size = Vector2(d, d)
		b.position = names[k]
		b.add_theme_font_size_override("font_size", fs)
	_btn_action.custom_minimum_size = Vector2(d * 1.15, d)
	_btn_action.size = Vector2(d * 1.15, d)
	_btn_action.position = Vector2(vp.x - pad - d * 1.15, by)
	_btn_action.add_theme_font_size_override("font_size", maxi(fs - 4, 11))
	_btn_exit.custom_minimum_size = Vector2(d * 0.9, d * 0.4)
	_btn_exit.size = Vector2(d * 0.9, d * 0.4)
	_btn_exit.position = Vector2((vp.x - d * 0.9) * 0.5, 4.0)
	_btn_exit.add_theme_font_size_override("font_size", clampi(int(d * 0.17), 10, 18))



func start() -> void :
	if theme_name == "space":
		_g = 330.0
		_jump = -250.0
		_speed = 100.0
		_m_total = 8
	else:
		_g = 900.0
		_jump = -330.0
		_speed = 110.0
		_m_total = 6
	var extra: = clampi(level - 1, 0, 8)
	_m_total = mini(_m_total + extra, 14)
	_boss_max = BOSS_MAX + 6.0 * float(mini(extra, 5))
	_px = 120.0
	_py = GY
	_pvy = 0.0
	_p_face = 1.0
	_p_hp = PLAYER_MAX
	_p_gun = false
	_p_ammo = 0
	_p_fire_cd = 0.0
	_p_punch_cd = 0.0
	_p_punch_t = 0.0
	_p_inv = 0.0
	_clear_actors()
	_bullets.clear()
	_sparks.clear()
	_shake = 0.0
	_m_spawned = 0
	_m_spawn_cd = 1.0
	_boss_on = false
	_bx = W + 40.0
	_by = GY
	_bvx = 0.0
	_bvy = 0.0
	_bhp = _boss_max
	_b_hop_cd = 1.5
	_b_atk_cd = 1.0
	_b_dodge_cd = 0.0
	_set_phase(Phase.INTRO)
	GameAudio.play_sfx("power_up")


func _set_phase(p: Phase) -> void :
	_phase = p
	_phase_t = 0.0
	match p:
		Phase.INTRO:
			if theme_name == "space":
				_banner.text = _s("YOU LANDED IN SPACE!\nNo weapon... use your fists!", "وصلت للفضاء!\nمفيش سلاح... استخدم إيدك!", "TU ES DANS L'ESPACE !\nPas d'arme... utilise tes poings !")
			else:
				_banner.text = _s("YOU LANDED ON THE GROUND!\nNo weapon... use your fists!", "نزلت على الأرض!\nمفيش سلاح... استخدم إيدك!", "TU AS ATTERRI AU SOL !\nPas d'arme... utilise tes poings !")
		Phase.MINIONS:
			_banner.text = ""
		Phase.BOSS_INTRO:
			_p_gun = true
			_p_ammo = AMMO_MAX
			_p_hp = minf(PLAYER_MAX, _p_hp + 35.0)
			_boss_on = true
			if _boss_node == null or not is_instance_valid(_boss_node):
				_boss_node = _make_actor("jumper" if theme_name == "space" else "charger", 2.6)
			_bx = W + 40.0
			_bhp = _boss_max
			GameAudio.play_sfx("power_up")
			var boss_name: = _boss_title()
			_banner.text = _s("%s APPEARS!\nYou found a BLASTER: 12 bullets!", "%s ظهر!\nلقيت مسدس: 12 طلقة!", "%s APPARAÎT !\nTu as trouvé un BLASTER : 12 balles !") % boss_name
		Phase.BOSS:
			_banner.text = ""
		Phase.WON:
			_banner.text = _s("VICTORY!", "انتصرت!", "VICTOIRE !")
			GameAudio.play_sfx("power_up")
		Phase.LOST:
			_banner.text = _s("DEFEATED... TRY AGAIN", "اتهزمت... حاول تاني", "VAINCU... RÉESSAIE")
			GameAudio.play_sfx("explosion")





func _input(event: InputEvent) -> void :
	if _done:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F:
				_do_action()
			KEY_G:
				_punch()
			KEY_UP, KEY_W, KEY_SPACE:
				_jump_queued = true
			KEY_ESCAPE:
				pass  # no way out: beat the boss
		get_viewport().set_input_as_handled()


func _axis() -> float:
	var a: = 0.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A) or _t_left:
		a -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D) or _t_right:
		a += 1.0
	return a



func _do_action() -> void :
	if _done or _phase == Phase.WON or _phase == Phase.LOST:
		return
	if _p_gun and _p_ammo > 0:
		_shoot()
	else:
		_punch()


func _shoot() -> void :
	if _p_fire_cd > 0.0:
		return
	_p_ammo -= 1
	_p_fire_cd = 0.22
	_bullets.append({"x": _px + _p_face * 14.0, "y": _py - 11.0, "dir": _p_face, "rolled": false})
	GameAudio.play_sfx("tap")


func _punch() -> void :
	if _p_punch_cd > 0.0:
		return
	_p_punch_cd = 0.4
	_p_punch_t = 0.18
	GameAudio.play_sfx("hurt")
	var fx: = _px + _p_face * 18.0
	for i in _minions.size():
		var m: Dictionary = _minions[i]
		if absf(float(m["x"]) - fx) < 22.0 and absf(float(m["y"]) - _py) < 30.0:
			m["hp"] = float(m["hp"]) - 12.0
			m["flash"] = 0.15
			_spawn_sparks(float(m["x"]), float(m["y"]) - 10.0, Color(1.0, 0.95, 0.6), 6)
			m["x"] = float(m["x"]) + _p_face * 8.0
	if _boss_on and _phase == Phase.BOSS:
		if absf(_bx - fx) < 26.0 and absf(_by - _py) < 34.0:
			_bhp -= 8.0
			_b_flash = 0.15
			_shake = maxf(_shake, 0.12)
			_spawn_sparks(_bx, _by - 20.0, Color(1.0, 0.95, 0.6), 8)
			_bx += _p_face * 6.0


func _hurt_player(dmg: float) -> void :
	if _p_inv > 0.0 or _phase == Phase.WON or _phase == Phase.LOST:
		return
	_p_hp -= dmg
	_p_inv = 0.9
	_p_flash = 0.2
	_shake = maxf(_shake, 0.25)
	_spawn_sparks(_px, _py - 12.0, Color(1.0, 0.4, 0.4), 10)
	GameAudio.play_sfx("hurt")
	if _p_hp <= 0.0:
		_p_hp = 0.0
		_set_phase(Phase.LOST)





func _process(delta: float) -> void :
	if _done:
		return
	var dt: = minf(delta, 0.05)
	_time += dt
	_phase_t += dt
	_p_fire_cd = maxf(_p_fire_cd - dt, 0.0)
	_p_punch_cd = maxf(_p_punch_cd - dt, 0.0)
	_p_punch_t = maxf(_p_punch_t - dt, 0.0)
	_p_inv = maxf(_p_inv - dt, 0.0)
	_p_flash = maxf(_p_flash - dt, 0.0)
	_b_flash = maxf(_b_flash - dt, 0.0)
	_btn_action.text = (_s("FIRE", "نار", "TIR") if (_p_gun and _p_ammo > 0) else _s("PUNCH", "ضرب", "COUP"))

	match _phase:
		Phase.INTRO:
			_player_step(dt)
			if _phase_t > 2.6:
				_set_phase(Phase.MINIONS)
		Phase.MINIONS:
			_player_step(dt)
			_minions_step(dt)
			if _m_spawned >= _m_total and _minions.is_empty():
				_set_phase(Phase.BOSS_INTRO)
		Phase.BOSS_INTRO:
			_player_step(dt)
			_bullets_step(dt)
			_bx = lerpf(_bx, 500.0, minf(dt * 2.5, 1.0))
			if _phase_t > 2.6:
				_set_phase(Phase.BOSS)
		Phase.BOSS:
			_player_step(dt)
			_bullets_step(dt)
			_boss_step(dt)
			if _bhp <= 0.0:
				_bhp = 0.0
				_bullets.clear()
				_shake = 0.6
				_spawn_sparks(_bx, _by - 20.0, Color(1.0, 0.8, 0.3), 40)
				_spawn_sparks(_bx, _by - 20.0, Color(1.0, 0.4, 0.3), 24)
				_set_phase(Phase.WON)
		Phase.WON:
			_player_step(dt)
			if _phase_t > 2.4:
				_finish(true)
		Phase.LOST:
			if _phase_t > 1.8:
				start()
	_update_hud()
	_sparks_step(dt)
	_update_actors()
	_shake = maxf(_shake - dt, 0.0)
	if _shake > 0.0:
		_view.position = _base_pos + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake * 18.0 * _view.scale.x
	else:
		_view.position = _base_pos
	_view.queue_redraw()
	_overlay.queue_redraw()


func _player_step(dt: float) -> void :
	var a: = 0.0
	if _phase != Phase.LOST:
		a = _axis()
	if a != 0.0:
		_p_face = signf(a)
	_px = clampf(_px + a * _speed * dt, 12.0, W - 12.0)
	if _jump_queued:
		_jump_queued = false
		if _p_ground and _phase != Phase.LOST:
			_pvy = _jump
			GameAudio.play_sfx("jump")
	_pvy += _g * dt
	_py += _pvy * dt
	if _py >= GY:
		_py = GY
		_pvy = 0.0
		_p_ground = true
	else:
		_p_ground = false


func _minions_step(dt: float) -> void :
	_m_spawn_cd -= dt
	if _m_spawned < _m_total and _minions.size() < 3 and _m_spawn_cd <= 0.0:
		_m_spawned += 1
		_m_spawn_cd = 1.4
		var from_right: = randf() < 0.5
		var space: = theme_name == "space"
		_minions.append({
			"node": _make_actor("bat" if space else "slime", 1.0), 
			"x": W + 14.0 if from_right else -14.0, 
			"y": GY - 22.0 if space else GY, 
			"vy": 0.0, 
			"hp": 20.0, 
			"flash": 0.0, 
			"t": randf() * TAU, 
			"hop": randf_range(0.6, 1.6), 
		})
	var alive: Array = []
	for i in _minions.size():
		var m: Dictionary = _minions[i]
		if float(m["hp"]) <= 0.0:
			GameAudio.play_sfx("explosion")
			_spawn_sparks(float(m["x"]), float(m["y"]) - 10.0, Color(1.0, 0.7, 0.2), 14)
			if is_instance_valid(m["node"]):
				(m["node"] as Node).queue_free()
			continue
		m["flash"] = maxf(float(m["flash"]) - dt, 0.0)
		m["t"] = float(m["t"]) + dt
		var dirx: = signf(_px - float(m["x"]))
		if theme_name == "space":
			m["x"] = float(m["x"]) + dirx * 48.0 * dt
			m["y"] = GY - 22.0 + sin(float(m["t"]) * 2.5) * 14.0
		else:
			m["x"] = float(m["x"]) + dirx * 40.0 * dt
			m["hop"] = float(m["hop"]) - dt
			if float(m["hop"]) <= 0.0 and float(m["y"]) >= GY - 0.1:
				m["vy"] = -150.0
				m["hop"] = randf_range(1.0, 2.0)
			m["vy"] = float(m["vy"]) + 500.0 * dt
			m["y"] = minf(float(m["y"]) + float(m["vy"]) * dt, GY)
			if float(m["y"]) >= GY:
				m["vy"] = 0.0
		var actor: Node2D = m["node"]
		if is_instance_valid(actor):
			actor.position = Vector2(float(m["x"]), float(m["y"]) - 8.0)
			actor.modulate = Color(2.5, 2.5, 2.5) if float(m["flash"]) > 0.0 else Color.WHITE
			actor.call("look", dirx)
		if absf(float(m["x"]) - _px) < 14.0 and absf(float(m["y"]) - _py) < 18.0:
			_hurt_player(6.0)
		alive.append(m)
	_minions = alive


func _bullets_step(dt: float) -> void :
	var keep: Array = []
	for i in _bullets.size():
		var b: Dictionary = _bullets[i]
		b["x"] = float(b["x"]) + float(b["dir"]) * 330.0 * dt
		var bx: = float(b["x"])
		var by: = float(b["y"])
		if bx < -10.0 or bx > W + 10.0:
			continue
		var used: = false
		for j in _minions.size():
			var m: Dictionary = _minions[j]
			if absf(float(m["x"]) - bx) < 10.0 and absf(float(m["y"]) - 12.0 - by) < 16.0:
				m["hp"] = float(m["hp"]) - 20.0
				_spawn_sparks(bx, by, Color(1.0, 0.9, 0.4), 5)
				used = true
				break
		if not used and _boss_on and _phase == Phase.BOSS:
			var toward: = signf(_bx - bx) == float(b["dir"])

			if toward and not bool(b["rolled"]) and absf(_bx - bx) < 115.0:
				b["rolled"] = true
				if _by >= GY - 0.1 and randf() < BOSS_DODGE_CHANCE:
					_bvy = _jump * 0.95
					_b_dodge_cd = 0.8
			if absf(_bx - bx) < 15.0 and absf(_by - 18.0 - by) < 22.0:
				_bhp -= BULLET_DMG
				_b_flash = 0.15
				_shake = maxf(_shake, 0.15)
				_spawn_sparks(bx, by, Color(1.0, 0.9, 0.4), 8)
				GameAudio.play_sfx("hurt")
				used = true
		if not used:
			keep.append(b)
	_bullets = keep


func _boss_step(dt: float) -> void :
	_b_dodge_cd = maxf(_b_dodge_cd - dt, 0.0)
	_b_atk_cd = maxf(_b_atk_cd - dt, 0.0)
	_b_punch_t = maxf(_b_punch_t - dt, 0.0)
	_b_hop_cd -= dt
	_b_face = signf(_px - _bx) if absf(_px - _bx) > 2.0 else _b_face
	var on_ground: = _by >= GY - 0.1
	if on_ground:
		_bvx = 0.0
		if _b_hop_cd <= 0.0:
			_bvy = _jump * 0.9
			_bvx = _b_face * randf_range(70.0, 110.0)
			_b_hop_cd = randf_range(1.3, 2.2)
		elif absf(_px - _bx) > 34.0:
			_bvx = _b_face * 32.0
	_bvy += _g * dt
	_by += _bvy * dt
	if _by >= GY:
		_by = GY
		_bvy = 0.0
	_bx = clampf(_bx + _bvx * dt, 20.0, W - 20.0)
	if _b_atk_cd <= 0.0 and absf(_px - _bx) < 32.0 and absf(_py - _by) < 34.0:
		_b_atk_cd = 0.9
		_b_punch_t = 0.25
		_hurt_player(10.0)


func _update_hud() -> void :
	_lbl_p.text = str(Network.player_name)
	if _boss_on:
		_lbl_b.text = _boss_title()
	else:
		_lbl_b.text = ""
	if _p_gun:
		if _p_ammo > 0:
			_lbl_ammo.text = _s("AMMO", "طلقات", "MUNITIONS") + "  %d / %d" % [_p_ammo, AMMO_MAX]
		else:
			_lbl_ammo.text = _s("OUT OF AMMO - PUNCH!", "الطلقات خلصت - اضرب بإيدك!", "PLUS DE BALLES - FRAPPE !")
	else:
		_lbl_ammo.text = ""


func _make_actor(monster_kind: String, big: float) -> Node2D:
	var n: Node2D = MonsterScript.new()
	n.set("kind", monster_kind)
	n.set("visual_only", true)
	n.scale = Vector2(big, big)
	_actors.add_child(n)
	return n


func _clear_actors() -> void :
	for m in _minions:
		if is_instance_valid(m["node"]):
			(m["node"] as Node).queue_free()
	_minions.clear()
	if _boss_node != null and is_instance_valid(_boss_node):
		_boss_node.queue_free()
	_boss_node = null


func _update_actors() -> void :
	# player: the exact skin the player equipped (idle / run / jump like in the real game)
	var anim: = &"jump" if not _p_ground else (&"run" if _axis() != 0.0 and _phase != Phase.LOST else &"idle")
	if _p_sprite.animation != anim or not _p_sprite.is_playing():
		_p_sprite.play(anim)
	_p_sprite.flip_h = _p_face < 0.0
	_p_sprite.position = Vector2(_px, _py - 10.0)
	_p_sprite.visible = not (_p_inv > 0.0 and int(_time * 20.0) % 2 == 0 and _phase != Phase.LOST)
	_p_sprite.modulate = Color(1.6, 0.55, 0.55) if _p_flash > 0.0 else Color.WHITE
	if _boss_node != null and is_instance_valid(_boss_node):
		_boss_node.visible = _boss_on
		_boss_node.position = Vector2(_bx, _by - 23.0)
		_boss_node.modulate = Color(2.5, 2.5, 2.5) if _b_flash > 0.0 else Color.WHITE
		_boss_node.call("look", _b_face, _b_punch_t > 0.0)


func _boss_title() -> String:
	var base: = _s("ALIEN KING", "ملك الفضائيين", "ROI ALIEN") if theme_name == "space" else _s("THE BEAST", "الوحش", "LA BÊTE")
	return base if level <= 1 else "%s  Lv.%d" % [base, level]


func _spawn_sparks(x: float, y: float, col: Color, n: int = 8) -> void :
	for i in n:
		var a: = randf() * TAU
		var sp: = randf_range(40.0, 140.0)
		_sparks.append({"x": x, "y": y, "vx": cos(a) * sp, "vy": sin(a) * sp - 40.0, "life": randf_range(0.25, 0.5), "col": col})
	if _sparks.size() > 160:
		_sparks = _sparks.slice(_sparks.size() - 160)


func _sparks_step(dt: float) -> void :
	var keep: Array = []
	for i in _sparks.size():
		var s: Dictionary = _sparks[i]
		s["life"] = float(s["life"]) - dt
		if float(s["life"]) <= 0.0:
			continue
		s["vy"] = float(s["vy"]) + 300.0 * dt
		s["x"] = float(s["x"]) + float(s["vx"]) * dt
		s["y"] = float(s["y"]) + float(s["vy"]) * dt
		keep.append(s)
	_sparks = keep


func _finish(won: bool) -> void :
	if _done:
		return
	_done = true
	finished.emit(won)





func _on_view_draw() -> void :
	var v: = _view
	var space: = theme_name == "space"

	if space:
		v.draw_rect(Rect2(0, 0, W, GY), Color(0.03, 0.03, 0.1))
		for st in _stars:
			var s3: Vector3 = st
			var tw: = 0.6 + 0.4 * sin(_time * 2.0 + s3.x)
			v.draw_rect(Rect2(s3.x, s3.y, s3.z, s3.z), Color(1, 1, 1, tw))
		v.draw_circle(Vector2(500, 90), 44.0, Color(0.35, 0.25, 0.55))
		v.draw_circle(Vector2(488, 80), 12.0, Color(0.3, 0.2, 0.48))
		v.draw_circle(Vector2(90, 70), 18.0, Color(0.7, 0.72, 0.8))
	else:
		v.draw_rect(Rect2(0, 0, W, GY * 0.55), Color(0.28, 0.2, 0.38))
		v.draw_rect(Rect2(0, GY * 0.55, W, GY * 0.45), Color(0.55, 0.3, 0.4))
		for i in 9:
			var bw: = 46.0 + float((i * 37) % 30)
			var bh: = 70.0 + float((i * 53) % 90)
			var bx0: = float(i) * 76.0 - 10.0
			v.draw_rect(Rect2(bx0, GY - bh, bw, bh), Color(0.16, 0.12, 0.24))
			for wy in int(bh / 18.0):
				if (wy + i) % 2 == 0:
					v.draw_rect(Rect2(bx0 + 8.0, GY - bh + 8.0 + float(wy) * 18.0, 6.0, 8.0), Color(1.0, 0.85, 0.4, 0.7))

	var gc: = Color(0.45, 0.45, 0.52) if space else Color(0.3, 0.22, 0.18)
	var gt: = Color(0.62, 0.62, 0.7) if space else Color(0.35, 0.55, 0.28)
	v.draw_rect(Rect2(0, GY, W, H - GY), gc)
	v.draw_rect(Rect2(0, GY, W, 5), gt)


func _on_overlay_draw() -> void :
	var v: = _overlay
	# fist / blaster (the body itself is the player's skin)
	var f: = _p_face
	var hy: = _py - 9.0
	if _p_punch_t > 0.0:
		var ext: = 10.0 + 8.0 * (_p_punch_t / 0.18)
		v.draw_rect(Rect2(_px + (6.0 if f > 0.0 else -6.0 - ext), hy - 2.0, ext, 4.0), Color(0.95, 0.82, 0.68))
		v.draw_rect(Rect2(_px + f * (6.0 + ext) - 3.0, hy - 3.0, 6.0, 6.0), Color(1.0, 0.9, 0.7))
	elif _p_gun:
		v.draw_rect(Rect2(_px + (6.0 if f > 0.0 else -15.0), hy - 1.0, 9.0, 3.0), Color(0.25, 0.25, 0.3))
		v.draw_rect(Rect2(_px + (6.0 if f > 0.0 else -8.0), hy + 1.0, 2.0, 4.0), Color(0.2, 0.2, 0.25))
	if _boss_on and _b_punch_t > 0.0:
		var ext2: = 12.0 + 12.0 * (_b_punch_t / 0.25)
		var bf: = _b_face
		v.draw_rect(Rect2(_bx + (12.0 if bf > 0.0 else -12.0 - ext2), _by - 20.0, ext2, 6.0), Color(0.3, 0.1, 0.25) if theme_name != "space" else Color(0.3, 0.7, 0.4))
	for i in _bullets.size():
		var b: Dictionary = _bullets[i]
		var bx: = float(b["x"])
		var dir: = float(b["dir"])
		v.draw_rect(Rect2(bx - 4.0, float(b["y"]) - 1.5, 8.0, 3.0), Color(1.0, 0.92, 0.35))
		v.draw_rect(Rect2(bx - 4.0 - dir * 4.0 - (3.0 if dir > 0.0 else 0.0), float(b["y"]) - 1.0, 3.0, 2.0), Color(1.0, 0.5, 0.1))

	for i in _sparks.size():
		var sp: Dictionary = _sparks[i]
		var sc: Color = sp["col"]
		sc.a = clampf(float(sp["life"]) * 3.0, 0.0, 1.0)
		v.draw_rect(Rect2(float(sp["x"]) - 1.5, float(sp["y"]) - 1.5, 3.0, 3.0), sc)

	_draw_bar(v, Rect2(10, 24, 150, 8), _p_hp / PLAYER_MAX, Color(0.3, 0.9, 0.4))
	if _boss_on:
		_draw_bar(v, Rect2(W - 160, 24, 150, 8), _bhp / _boss_max, Color(0.95, 0.3, 0.3))
	if _p_gun:
		for i in AMMO_MAX:
			var c: = Color(1.0, 0.85, 0.3) if i < _p_ammo else Color(0.3, 0.3, 0.3)
			v.draw_rect(Rect2(10.0 + float(i) * 12.5, 36.0, 9.0, 4.0), c)


func _draw_bar(v: Node2D, r: Rect2, frac: float, col: Color) -> void :
	v.draw_rect(Rect2(r.position - Vector2(2, 2), r.size + Vector2(4, 4)), Color(0, 0, 0, 0.8))
	v.draw_rect(r, Color(0.25, 0.1, 0.1))
	v.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y)), col)
