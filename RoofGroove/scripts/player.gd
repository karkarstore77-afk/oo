extends CharacterBody2D

const SPEED = 150
const JUMP_FORCE = -200
const GRAVITY = 900
const TouchSkin: = preload("res://scripts/touch_skin.gd")
const StoryEffects: = preload("res://scripts/story_effects.gd")
const SkinAbilities: = preload("res://scripts/skin_abilities.gd")


var is_remote: = false
var display_name: = ""
var peer_id: = 0


var input_locked: = false

@onready var anim = $AnimatedSprite2D

var _target: = Vector2.ZERO
var _got_first: = false
var _ab: Dictionary = {"speed": 1.0, "jump": 1.0, "gravity": 1.0, "air_jumps": 0, "air_jump_power": 0.0, "coyote": 0.0}
var _coyote_left: = 0.0
var _air_jumps_left: = 0


func _ready() -> void :


	var old_sync: = get_node_or_null("MultiplayerSynchronizer")
	if old_sync:
		old_sync.queue_free()

	if is_remote:
		collision_layer = 0
		collision_mask = 0
		modulate = Color(1, 1, 1, 0.65)

		for extra in ["CanvasLayer2", "Camera2D", "Node2D"]:
			var n: = get_node_or_null(extra)
			if n:
				n.queue_free()
		var tag: = Label.new()
		tag.text = display_name
		tag.add_theme_font_size_override("font_size", 8)
		tag.position = Vector2(-24, -40)
		tag.custom_minimum_size = Vector2(48, 0)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(tag)

		Economy.set_skin(anim, Network.skin_of(peer_id))
		Network.skin_received.connect(_on_remote_skin)
	else:
		add_to_group("local_player")
		Economy.bind(anim)
		_refresh_abilities()
		Economy.skin_changed.connect(_on_local_skin_changed)
		_setup_touch_controls()


func _on_local_skin_changed(_id: String) -> void :
	_refresh_abilities()


func _refresh_abilities() -> void :
	_ab = SkinAbilities.get_for(Economy.equipped)


func _on_remote_skin(id: int, skin: String) -> void :
	if id == peer_id and is_instance_valid(anim):
		Economy.set_skin(anim, skin)




func _setup_touch_controls() -> void :
	var layer: = get_node_or_null("CanvasLayer2")
	if layer == null:
		return
	var show_touch: = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	layer.visible = show_touch
	if not show_touch:
		return
	_apply_touch_skin(layer)
	get_viewport().size_changed.connect(_layout_touch_controls)
	_layout_touch_controls()



func _apply_touch_skin(layer: Node) -> void :
	for pair in [["Left", "left"], ["Right", "right"], ["Jump", "up"]]:
		var b: = layer.get_node_or_null(pair[0]) as TouchScreenButton
		if b == null:
			continue
		b.texture_normal = TouchSkin.get_texture(pair[1], false)
		b.texture_pressed = TouchSkin.get_texture(pair[1], true)
		var circle: = CircleShape2D.new()
		circle.radius = TouchSkin.SIZE * 0.58
		b.shape = circle
		b.shape_centered = true
		b.shape_visible = false




func _touch_diameter(vp: Vector2) -> float:
	var d: = vp.y * 0.2
	var win: = Vector2(DisplayServer.window_get_size())
	var dpi: = float(DisplayServer.screen_get_dpi())
	if dpi > 0.0 and win.y > 0.0:
		d = 0.63 * dpi * vp.y / win.y
	return clampf(d, vp.y * 0.15, vp.y * 0.27)


func _layout_touch_controls() -> void :
	var layer: = get_node_or_null("CanvasLayer2")
	if layer == null:
		return
	var jump: = layer.get_node_or_null("Jump") as TouchScreenButton
	var left: = layer.get_node_or_null("Left") as TouchScreenButton
	var right: = layer.get_node_or_null("Right") as TouchScreenButton
	if jump == null or left == null or right == null:
		return

	var vp: = get_viewport().get_visible_rect().size
	var d: = _touch_diameter(vp)
	var s: = d / float(TouchSkin.SIZE)
	for b in [jump, left, right]:
		b.scale = Vector2(s, s)

	var margin_x: = d * 0.35
	var margin_y: = d * 0.3
	var gap: = d * 0.25
	var safe_left: = 0.0
	var safe_right: = 0.0
	var safe_bottom: = 0.0
	if OS.has_feature("mobile"):
		var win: = Vector2(DisplayServer.window_get_size())
		var safe: = Rect2(DisplayServer.get_display_safe_area())
		if win.x > 0.0 and win.y > 0.0:
			safe_left = maxf(0.0, safe.position.x) * vp.x / win.x
			safe_right = maxf(0.0, win.x - safe.end.x) * vp.x / win.x
			safe_bottom = maxf(0.0, win.y - safe.end.y) * vp.y / win.y

	var bottom: = vp.y - safe_bottom - margin_y

	jump.position = Vector2(safe_left + margin_x, bottom - d)
	right.position = Vector2(vp.x - safe_right - margin_x - d, bottom - d)
	left.position = Vector2(right.position.x - gap - d, bottom - d)


func lock_input() -> void :
	input_locked = true


func apply_net_state(pos: Vector2, anim_name: String, flip: bool) -> void :
	if not _got_first:
		_got_first = true
		global_position = pos
	_target = pos
	_play(StringName(anim_name))
	anim.flip_h = flip



func _play(anim_name: StringName) -> void :
	var frames: SpriteFrames = anim.sprite_frames
	if frames == null:
		return
	if not frames.has_animation(anim_name):

		if anim_name == &"idle" and frames.has_animation(&"idel"):
			anim_name = &"idel"
		elif anim_name == &"idel" and frames.has_animation(&"idle"):
			anim_name = &"idle"
		else:
			return
	if anim.animation != anim_name or not anim.is_playing():
		anim.play(anim_name)


func _physics_process(delta):
	if get_tree().paused:
		return


	if is_remote:
		global_position = global_position.lerp(_target, 0.3)
		return


	velocity.y += GRAVITY * StoryEffects.gravity_mult() * float(_ab["gravity"]) * delta


	var direction: = 0.0
	if not input_locked:
		direction = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	velocity.x = direction * SPEED * StoryEffects.speed_mult() * float(_ab["speed"])


	if is_on_floor():
		_coyote_left = float(_ab["coyote"])
		_air_jumps_left = int(_ab["air_jumps"])
	else:
		_coyote_left = maxf(0.0, _coyote_left - delta)
	if not input_locked and Input.is_action_just_pressed("ui_up"):
		if is_on_floor() or _coyote_left > 0.0:
			velocity.y = JUMP_FORCE * StoryEffects.jump_mult() * float(_ab["jump"])
			_coyote_left = 0.0
			GameAudio.play_sfx("jump")
		elif _air_jumps_left > 0:
			_air_jumps_left -= 1
			velocity.y = JUMP_FORCE * StoryEffects.jump_mult() * float(_ab["jump"]) * float(_ab["air_jump_power"])
			GameAudio.play_sfx("jump")


	move_and_slide()


	if not is_on_floor():
		_play(&"jump")
	elif direction != 0:
		_play(&"run")
		anim.flip_h = direction < 0
	else:
		_play(&"idle")
