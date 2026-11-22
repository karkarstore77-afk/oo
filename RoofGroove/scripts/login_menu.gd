extends Control
## First screen after the splash: sign in with Pixel Account (email + password), Discord or Google.
## "MORE" holds create account, forgot password and play without an account.

const UI: = preload("res://scripts/ui_kit.gd")
const SAFE_AREA: = preload("res://scripts/safe_area.gd")
const Fx: = preload("res://scripts/ui_fx.gd")
const LOGO: Texture2D = preload("res://branding/logo_fixed.png")

const CHOICE_FILE: = "user://login_choice.cfg"
const NEXT_SCENE: = "res://sence/main_menu.tscn"
const GOLD: = Color("#ffd666")
const MUTED: = Color("#b9b2d6")

var _content: VBoxContainer
var _hero_holder: Control
var _hero_bob: Control
var _status: Label
var _boxes: Dictionary = {}
var _current: String = "main"
var _busy: = false
var _wait_label: Label
var _code_label: Label
var _code_button: Button
var _code_url: = ""
var _discord_btn: Button
var _google_btn: Button
var _email_login: LineEdit
var _pass_login: LineEdit
var _email_new: LineEdit
var _pass_new: LineEdit
var _pass_new2: LineEdit
var _email_reset: LineEdit
var _sign_in_btn: Button
var _create_btn: Button
var _reset_btn: Button


static func guest_chosen() -> bool:
	var cfg: = ConfigFile.new()
	return cfg.load(CHOICE_FILE) == OK and bool(cfg.get_value("login", "guest", false))


static func remember_guest(on: bool) -> void :
	var cfg: = ConfigFile.new()
	cfg.set_value("login", "guest", on)
	cfg.save(CHOICE_FILE)


func _ready() -> void :
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_background()
	var vp: = get_viewport_rect().size
	var safe: = MarginContainer.new()
	safe.set_script(SAFE_AREA)
	add_child(safe)
	for side in ["left", "right", "top", "bottom"]:
		safe.add_theme_constant_override("margin_" + side, 14)
	var scroll: = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	safe.add_child(scroll)
	var center: = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_content = VBoxContainer.new()
	_content.custom_minimum_size = Vector2(minf(vp.x - 36.0, 520.0), 0)
	_content.add_theme_constant_override("separation", 10)
	center.add_child(_content)

	_build_hero(vp)
	_status = UI.label("", 13, GOLD, 500.0)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(_status)

	_build_main()
	_build_pixel()
	_build_more()
	_build_create()
	_build_forgot()
	_build_wait()

	var c: Node = Network.cloud
	if c == null:
		_set_status("Cloud is not available")
	else:
		c.login_succeeded.connect(_on_login_ok)
		c.login_failed.connect(_on_login_failed)
		c.login_status.connect(_on_login_status)
		c.pixel_notice.connect(_on_notice)
		c.device_code_ready.connect(_on_device_code)
		c.browser_login_started.connect(_on_browser_started)
		if not c.is_configured():
			_set_status("Account service is not set up (firebase_config.gd)")
		_discord_btn.disabled = not c.discord_ready()
		_google_btn.disabled = not c.google_configured()
		_sign_in_btn.disabled = not c.is_configured()
		_create_btn.disabled = not c.is_configured()
		_reset_btn.disabled = not c.is_configured()
	_show("main", false)
	GameAudio.play_sfx("ui_open")


func _exit_tree() -> void :
	var c: Node = Network.cloud
	if c == null:
		return
	for pair in [[c.login_succeeded, _on_login_ok], [c.login_failed, _on_login_failed], [c.login_status, _on_login_status], 
			[c.pixel_notice, _on_notice], [c.device_code_ready, _on_device_code], [c.browser_login_started, _on_browser_started]]:
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])


func _unhandled_input(event: InputEvent) -> void :
	if event.is_action_pressed("ui_cancel") and _current != "main":
		_on_back()
		get_viewport().set_input_as_handled()


# ---- look -----------------------------------------------------------------------------------------

func _build_background() -> void :
	var gradient: = Gradient.new()
	gradient.colors = PackedColorArray([Color("#0d0820"), Color("#241243"), Color("#3a1d5c")])
	gradient.offsets = PackedFloat32Array([0.0, 0.65, 1.0])
	var tex: = GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	var bg: = TextureRect.new()
	bg.texture = tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# twinkling stars
	var rng: = RandomNumberGenerator.new()
	rng.randomize()
	var area: = get_viewport_rect().size
	for i in 46:
		var star: = ColorRect.new()
		var px: = 2.0 if rng.randf() < 0.7 else 3.0
		star.size = Vector2(px, px)
		star.position = Vector2(rng.randf_range(0.0, area.x), rng.randf_range(0.0, area.y * 0.75))
		star.color = Color(1.0, 0.96, 0.85, rng.randf_range(0.25, 0.9))
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(star)
		var tw: Tween = star.create_tween().set_loops()
		tw.tween_interval(rng.randf_range(0.0, 2.0))
		tw.tween_property(star, "modulate:a", 0.15, rng.randf_range(0.8, 1.8))
		tw.tween_property(star, "modulate:a", 1.0, rng.randf_range(0.8, 1.8))


func _build_hero(vp: Vector2) -> void :
	_hero_holder = Control.new()
	_hero_holder.custom_minimum_size = Vector2(0, _hero_height(vp, true))
	_hero_holder.clip_contents = false
	_content.add_child(_hero_holder)
	_hero_bob = Control.new()
	_hero_holder.add_child(_hero_bob)
	var logo: = TextureRect.new()
	logo.texture = LOGO
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_bob.add_child(logo)
	logo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hero_holder.resized.connect(func() -> void :
		_hero_bob.size = _hero_holder.size
		_hero_bob.pivot_offset = _hero_holder.size * 0.5)
	# the logo floats up and down and breathes
	var bob: Tween = _hero_bob.create_tween().set_loops()
	bob.tween_property(_hero_bob, "position:y", -8.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(_hero_bob, "position:y", 8.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var breathe: Tween = _hero_bob.create_tween().set_loops()
	breathe.tween_property(_hero_bob, "scale", Vector2(1.035, 1.035), 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breathe.tween_property(_hero_bob, "scale", Vector2.ONE, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _hero_height(vp: Vector2, big: bool) -> float:
	return clampf(vp.y * (0.46 if big else 0.2), 110.0, 380.0)


# ---- panels ---------------------------------------------------------------------------------------

func _panel(panel_name: String) -> VBoxContainer:
	var box: = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.visible = false
	_content.add_child(box)
	_boxes[panel_name] = box
	return box


func _field(box: VBoxContainer, caption: String, secret: bool = false, email: bool = false) -> LineEdit:
	var l: = UI.label(caption, 12, MUTED)
	box.add_child(l)
	var edit: = LineEdit.new()
	edit.secret = secret
	edit.custom_minimum_size = Vector2(0, 46)
	edit.add_theme_font_override("font", UI.FONT)
	edit.add_theme_font_size_override("font_size", 14)
	edit.max_length = 128
	if email:
		edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	box.add_child(edit)
	return edit


func _build_main() -> void :
	var box: = _panel("main")
	var pixel: Button = UI.button("PIXEL ACCOUNT", 20, 60.0)
	pixel.pressed.connect(_show.bind("pixel", true))
	box.add_child(pixel)
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	_discord_btn = UI.button("DISCORD", 14, 54.0)
	_discord_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_discord_btn.pressed.connect(_on_discord)
	row.add_child(_discord_btn)
	_google_btn = UI.button("GOOGLE", 14, 54.0)
	_google_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_google_btn.pressed.connect(_on_google)
	row.add_child(_google_btn)
	var more: Button = UI.button("MORE", 14, 54.0)
	more.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	more.pressed.connect(_show.bind("more", true))
	row.add_child(more)


func _build_pixel() -> void :
	var box: = _panel("pixel")
	box.add_child(UI.label("PIXEL ACCOUNT", 20, GOLD))
	_email_login = _field(box, "EMAIL", false, true)
	_pass_login = _field(box, "PASSWORD", true)
	_email_login.text_submitted.connect(func(_t: String) -> void : _pass_login.grab_focus())
	_pass_login.text_submitted.connect(func(_t: String) -> void : _on_pixel_sign_in())
	_sign_in_btn = UI.button("SIGN IN", 18, 54.0)
	_sign_in_btn.pressed.connect(_on_pixel_sign_in)
	box.add_child(_sign_in_btn)
	var forgot: Button = UI.button("FORGOT PASSWORD", 13, 46.0)
	forgot.pressed.connect(_show.bind("forgot", true))
	box.add_child(forgot)
	var back: Button = UI.button("BACK", 14, 46.0)
	back.pressed.connect(_on_back)
	box.add_child(back)


func _build_more() -> void :
	var box: = _panel("more")
	box.add_child(UI.label("MORE", 20, GOLD))
	var create: Button = UI.button("CREATE ACCOUNT", 16, 54.0)
	create.pressed.connect(_show.bind("create", true))
	box.add_child(create)
	var forgot: Button = UI.button("FORGOT PASSWORD", 16, 54.0)
	forgot.pressed.connect(_show.bind("forgot", true))
	box.add_child(forgot)
	var guest: Button = UI.button("PLAY WITHOUT ACCOUNT", 16, 54.0)
	guest.pressed.connect(_on_guest)
	box.add_child(guest)
	box.add_child(UI.label("Without an account your progress stays on this device only", 11, MUTED, 500.0))
	var back: Button = UI.button("BACK", 14, 46.0)
	back.pressed.connect(_on_back)
	box.add_child(back)


func _build_create() -> void :
	var box: = _panel("create")
	box.add_child(UI.label("CREATE ACCOUNT", 20, GOLD))
	_email_new = _field(box, "EMAIL", false, true)
	_pass_new = _field(box, "PASSWORD", true)
	_pass_new2 = _field(box, "CONFIRM PASSWORD", true)
	_pass_new2.text_submitted.connect(func(_t: String) -> void : _on_create())
	_create_btn = UI.button("CREATE ACCOUNT", 18, 54.0)
	_create_btn.pressed.connect(_on_create)
	box.add_child(_create_btn)
	box.add_child(UI.label("We will email you a link to confirm your address", 11, MUTED, 500.0))
	var back: Button = UI.button("BACK", 14, 46.0)
	back.pressed.connect(_on_back)
	box.add_child(back)


func _build_forgot() -> void :
	var box: = _panel("forgot")
	box.add_child(UI.label("FORGOT PASSWORD", 20, GOLD))
	_email_reset = _field(box, "EMAIL", false, true)
	_email_reset.text_submitted.connect(func(_t: String) -> void : _on_reset())
	_reset_btn = UI.button("SEND RESET LINK", 18, 54.0)
	_reset_btn.pressed.connect(_on_reset)
	box.add_child(_reset_btn)
	var back: Button = UI.button("BACK", 14, 46.0)
	back.pressed.connect(_on_back)
	box.add_child(back)


func _build_wait() -> void :
	var box: = _panel("wait")
	_wait_label = UI.label("Finish signing in in your browser, then come back to the game.", 14, Color.WHITE, 500.0)
	_wait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_wait_label)
	_code_label = UI.label("", 30, GOLD)
	_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_label.visible = false
	box.add_child(_code_label)
	_code_button = UI.button("OPEN google.com/device", 14, 48.0)
	_code_button.visible = false
	_code_button.pressed.connect(func() -> void : OS.shell_open(_code_url))
	box.add_child(_code_button)
	var cancel: Button = UI.button("CANCEL", 16, 50.0)
	cancel.pressed.connect(_on_cancel)
	box.add_child(cancel)


func _show(panel_name: String, animate: bool = true) -> void :
	_current = panel_name
	for key in _boxes:
		(_boxes[key] as Control).visible = (key == panel_name)
	var vp: = get_viewport_rect().size
	_hero_holder.custom_minimum_size.y = _hero_height(vp, panel_name == "main" or panel_name == "wait")
	if animate:
		_set_status("")
		GameAudio.play_sfx("ui_open")
		var delay: = 0.0
		for item in (_boxes[panel_name] as Control).get_children():
			Fx.fade_in(item as CanvasItem, delay, 0.22)
			delay += 0.05


func _on_back() -> void :
	GameAudio.play_sfx("ui_back")
	match _current:
		"pixel", "more":
			_show("main")
		"create", "forgot":
			_show("more" if _current == "create" else "pixel")
		_:
			_show("main")


func _set_status(text: String, good: bool = false) -> void :
	_status.text = tr(text)
	_status.add_theme_color_override("font_color", Color("#7be495") if good else GOLD)


# ---- actions --------------------------------------------------------------------------------------

func _valid_email(mail: String) -> bool:
	return mail.contains("@") and mail.get_slice("@", 1).contains(".") and mail.length() >= 6


func _on_pixel_sign_in() -> void :
	if _busy:
		return
	var mail: = _email_login.text.strip_edges()
	if mail == "" or _pass_login.text == "":
		_set_status("Enter your email and password")
		GameAudio.play_sfx("error")
		return
	if not _valid_email(mail):
		_set_status("Enter a valid email address")
		GameAudio.play_sfx("error")
		return
	_busy = true
	_set_status("Signing in...")
	Network.cloud.start_pixel_login(mail, _pass_login.text)


func _on_create() -> void :
	if _busy:
		return
	var mail: = _email_new.text.strip_edges()
	if not _valid_email(mail):
		_set_status("Enter a valid email address")
		GameAudio.play_sfx("error")
		return
	if _pass_new.text.length() < 6:
		_set_status("Password must be at least 6 characters")
		GameAudio.play_sfx("error")
		return
	if _pass_new.text != _pass_new2.text:
		_set_status("Passwords do not match")
		GameAudio.play_sfx("error")
		return
	_busy = true
	_set_status("Creating your account...")
	Network.cloud.start_pixel_signup(mail, _pass_new.text)


func _on_reset() -> void :
	if _busy:
		return
	var mail: = _email_reset.text.strip_edges()
	if not _valid_email(mail):
		_set_status("Enter a valid email address")
		GameAudio.play_sfx("error")
		return
	_busy = true
	_set_status("Sending...")
	Network.cloud.start_password_reset(mail)


func _on_discord() -> void :
	_wait_label.text = tr("Finish signing in in your browser, then come back to the game.")
	_code_label.visible = false
	_code_button.visible = false
	_show("wait")
	_busy = true
	Network.cloud.start_discord_login()


func _on_google() -> void :
	_wait_label.text = tr("Finish signing in in your browser, then come back to the game.")
	_code_label.visible = false
	_code_button.visible = false
	_show("wait")
	_busy = true
	Network.cloud.start_google_login()


func _on_cancel() -> void :
	Network.cloud.cancel_login()
	_busy = false
	_show("main")


func _on_guest() -> void :
	remember_guest(true)
	_go_next()


func _go_next() -> void :
	get_tree().change_scene_to_file(NEXT_SCENE)


# ---- signals from the cloud -----------------------------------------------------------------------

func _on_login_ok() -> void :
	_busy = false
	remember_guest(false)
	GameAudio.play_sfx("success")
	_set_status("Signed in", true)
	await get_tree().create_timer(0.35).timeout
	_go_next()


func _on_login_failed(reason: String) -> void :
	_busy = false
	GameAudio.play_sfx("error")
	if _current == "wait":
		_show("main", false)
	_set_status(reason)


func _on_login_status(text: String) -> void :
	if _current == "wait":
		_wait_label.text = tr(text)


func _on_notice(text: String) -> void :
	_busy = false
	GameAudio.play_sfx("success")
	if _current == "create":
		_show("pixel", false)
	_set_status(text, true)


func _on_browser_started(_provider: String) -> void :
	_wait_label.text = tr("Finish signing in in your browser, then come back to the game.")


func _on_device_code(code: String, url: String) -> void :
	_code_url = url
	_code_label.text = code
	_code_label.visible = true
	_code_button.visible = true
	_wait_label.text = tr("OPEN THE PAGE BELOW AND ENTER THIS CODE:")
