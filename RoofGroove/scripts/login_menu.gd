extends Control
## First screen after loading: Pixel Account (email + password), Discord or Google.
## "MORE" holds create account, forgot password and play without an account.
## Language buttons on top: the account emails (verification / password reset) use the same language.

const UI: = preload("res://scripts/ui_kit.gd")
const SAFE_AREA: = preload("res://scripts/safe_area.gd")
const Fx: = preload("res://scripts/ui_fx.gd")
const Backdrop: = preload("res://scripts/menu_backdrop.gd")
const RooftopScene: = preload("res://scripts/rooftop_scene.gd")

const CHOICE_FILE: = "user://login_choice.cfg"
const NEXT_SCENE: = "res://sence/main_menu.tscn"
const GOLD: = Color("#ffd666")
const MUTED: = Color("#b9b2d6")
const CARD_BG: = Color(0.075, 0.05, 0.16, 0.92)
const CARD_BORDER: = Color("#6b4bb0")
const INPUT_BG: = Color("#110a24")
const INPUT_BORDER: = Color("#4b3a82")
# button colours: [fill, text]
const C_PIXEL: = [Color("#ffb83d"), Color("#2a1442")]
const C_DISCORD: = [Color("#5865f2"), Color("#ffffff")]
const C_GOOGLE: = [Color("#f3f3f8"), Color("#33343c")]
const C_DARK: = [Color("#2d2257"), Color("#ffffff")]
const C_BACK: = [Color("#1a1235"), Color("#c9bfe8")]

var _content: VBoxContainer
var _card_box: VBoxContainer
var _hero_holder: Control
var _status_panel: PanelContainer
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


## Small vector icons for the provider buttons.
class Icon extends Control:
	var kind: = "pixel"
	var tint: = Color.WHITE

	func _init(icon_kind: String = "pixel", icon_color: Color = Color.WHITE) -> void :
		kind = icon_kind
		tint = icon_color
		custom_minimum_size = Vector2(26, 26)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void :
		var c: = size * 0.5
		var r: = minf(size.x, size.y) * 0.5
		match kind:
			"pixel":
				# the Pixel Studio mark: 3 x 3 coloured squares
				var cyan: = Color("#38d6ff")
				var purple: = Color("#7b6bff")
				var pink: = Color("#ff5fa8")
				var yellow: = Color("#ffd23f")
				var grid: = [[cyan, cyan, purple], [cyan, pink, purple], [yellow, null, pink]]
				var cell: = minf(size.x, size.y) / 3.0
				for row in 3:
					for col in 3:
						var color: Variant = grid[row][col]
						if color != null:
							draw_rect(Rect2(float(col) * cell + 1.0, float(row) * cell + 1.0, cell - 2.0, cell - 2.0), color as Color)
			"discord":
				draw_rect(Rect2(c.x - r * 0.95, c.y - r * 0.62, r * 1.9, r * 1.3), tint)
				draw_rect(Rect2(c.x - r * 0.95, c.y + r * 0.5, r * 0.5, r * 0.3), tint)
				draw_rect(Rect2(c.x + r * 0.45, c.y + r * 0.5, r * 0.5, r * 0.3), tint)
				draw_circle(c + Vector2(-r * 0.42, 0.0), r * 0.24, Color("#5865f2"))
				draw_circle(c + Vector2(r * 0.42, 0.0), r * 0.24, Color("#5865f2"))
			"google":
				var ring: = r * 0.72
				var w: = r * 0.34
				draw_arc(c, ring, deg_to_rad(205), deg_to_rad(315), 14, Color("#ea4335"), w, true)
				draw_arc(c, ring, deg_to_rad(135), deg_to_rad(205), 10, Color("#fbbc05"), w, true)
				draw_arc(c, ring, deg_to_rad(45), deg_to_rad(135), 12, Color("#34a853"), w, true)
				draw_arc(c, ring, deg_to_rad(-12), deg_to_rad(45), 8, Color("#4285f4"), w, true)
				draw_line(c, c + Vector2(ring + w * 0.4, 0), Color("#4285f4"), w * 0.9, true)
			"more":
				for dx in [-0.6, 0.0, 0.6]:
					draw_circle(c + Vector2(r * float(dx), 0.0), r * 0.17, tint)


static func guest_chosen() -> bool:
	var cfg: = ConfigFile.new()
	return cfg.load(CHOICE_FILE) == OK and bool(cfg.get_value("login", "guest", false))


static func remember_guest(on: bool) -> void :
	var cfg: = ConfigFile.new()
	cfg.set_value("login", "guest", on)
	cfg.save(CHOICE_FILE)


func _ready() -> void :
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Same layout in every language (Arabic must not mirror the screen); only the text itself reads right-to-left.
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	Backdrop.add(self)
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
	_content.custom_minimum_size = Vector2(minf(vp.x - 32.0, 500.0), 0)
	_content.add_theme_constant_override("separation", 12)
	center.add_child(_content)

	_build_language_bar()
	_build_hero(vp)
	_build_card()
	_build_footer()

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
	Fx.fade_in(_content, 0.0, 0.35)


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


# ---- styling helpers ------------------------------------------------------------------------------

func _box(fill: Color, edge: Color, down: bool = false) -> StyleBoxFlat:
	var sb: = StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(12)
	sb.border_color = edge
	sb.border_width_bottom = 2 if down else 5
	sb.content_margin_top = 8 if down else 5
	sb.content_margin_bottom = 4 if down else 7
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	return sb


func _style_button(b: Button, colors: Array, font_size: int = 15, min_height: float = 54.0) -> Button:
	var fill: Color = colors[0]
	var text_color: Color = colors[1]
	b.custom_minimum_size = Vector2(0, min_height)
	b.add_theme_font_override("font", UI.FONT)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_stylebox_override("normal", _box(fill, fill.darkened(0.45)))
	b.add_theme_stylebox_override("hover", _box(fill.lightened(0.12), fill.darkened(0.35)))
	b.add_theme_stylebox_override("pressed", _box(fill.darkened(0.1), fill.darkened(0.5), true))
	b.add_theme_stylebox_override("disabled", _box(fill.darkened(0.55), fill.darkened(0.7)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, text_color)
	b.add_theme_color_override("font_disabled_color", text_color.darkened(0.4))
	return b


func _button(text: String, colors: Array, font_size: int = 15, min_height: float = 54.0, icon: String = "") -> Button:
	var b: = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	_style_button(b, colors, font_size, min_height)
	if icon != "":
		var ic: = Icon.new(icon, colors[1] if icon != "google" else Color.WHITE)
		b.add_child(ic)
		ic.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
		ic.offset_left = 14
		ic.offset_right = 14 + 26
		ic.offset_top = -13
		ic.offset_bottom = 13
		b.add_theme_constant_override("h_separation", 6)
	return b


func _link_button(text: String) -> Button:
	var b: = Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", UI.FONT)
	b.add_theme_font_size_override("font_size", 12)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(state, GOLD)
	b.custom_minimum_size = Vector2(0, 36)
	return b


func _style_input(edit: LineEdit) -> void :
	var normal: = StyleBoxFlat.new()
	normal.bg_color = INPUT_BG
	normal.border_color = INPUT_BORDER
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	var focus: = normal.duplicate() as StyleBoxFlat
	focus.border_color = GOLD
	edit.add_theme_stylebox_override("normal", normal)
	edit.add_theme_stylebox_override("focus", focus)
	edit.add_theme_font_override("font", UI.FONT)
	edit.add_theme_font_size_override("font_size", 14)
	edit.add_theme_color_override("font_color", Color.WHITE)
	edit.add_theme_color_override("caret_color", GOLD)
	edit.add_theme_color_override("font_placeholder_color", Color("#7d72a8"))
	edit.custom_minimum_size = Vector2(0, 48)


# ---- layout ---------------------------------------------------------------------------------------

func _build_language_bar() -> void :
	var row: = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	_content.add_child(row)
	var pill: = PanelContainer.new()
	var ps: = StyleBoxFlat.new()
	ps.bg_color = Color(0.08, 0.05, 0.17, 0.85)
	ps.border_color = INPUT_BORDER
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(20)
	ps.content_margin_left = 4
	ps.content_margin_right = 4
	ps.content_margin_top = 3
	ps.content_margin_bottom = 3
	pill.add_theme_stylebox_override("panel", ps)
	row.add_child(pill)
	var langs: = HBoxContainer.new()
	langs.add_theme_constant_override("separation", 2)
	pill.add_child(langs)
	for code in ["ar", "en", "fr"]:
		var b: = Button.new()
		b.text = str(Loc.LANGS[code])
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", UI.FONT)
		b.add_theme_font_size_override("font_size", 12)
		b.custom_minimum_size = Vector2(0, 34)
		var selected: bool = (code == Loc.current)
		var sb: = StyleBoxFlat.new()
		sb.bg_color = GOLD if selected else Color(0, 0, 0, 0)
		sb.set_corner_radius_all(16)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		for state in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(state, sb)
		var fc: = Color("#2a1442") if selected else Color("#d8d0f0")
		for state in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(state, fc)
		b.pressed.connect(_on_language.bind(str(code)))
		langs.add_child(b)


func _build_hero(vp: Vector2) -> void :
	var scene: Control = RooftopScene.new()
	scene.custom_minimum_size = Vector2(0, _hero_height(vp, true))
	_hero_holder = scene
	_content.add_child(scene)


func _hero_height(vp: Vector2, big: bool) -> float:
	return clampf(vp.y * (0.38 if big else 0.2), 120.0, 320.0)


func _build_card() -> void :
	var card: = PanelContainer.new()
	var cs: = StyleBoxFlat.new()
	cs.bg_color = CARD_BG
	cs.border_color = CARD_BORDER
	cs.set_border_width_all(2)
	cs.set_corner_radius_all(18)
	cs.shadow_color = Color(0, 0, 0, 0.55)
	cs.shadow_size = 16
	cs.content_margin_left = 20
	cs.content_margin_right = 20
	cs.content_margin_top = 18
	cs.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", cs)
	_content.add_child(card)
	_card_box = VBoxContainer.new()
	_card_box.add_theme_constant_override("separation", 12)
	card.add_child(_card_box)
	# message banner (errors in red, good news in green)
	_status_panel = PanelContainer.new()
	_status_panel.visible = false
	_card_box.add_child(_status_panel)
	_status = UI.label("", 12, Color.WHITE, 440.0)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_panel.add_child(_status)


func _build_footer() -> void :
	var footer: = UI.label("Pixel Studio   •   v%s" % AppVersion.current(), 11, Color("#8a7fb3"))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(footer)


func _panel(panel_name: String) -> VBoxContainer:
	var box: = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.visible = false
	_card_box.add_child(box)
	_boxes[panel_name] = box
	return box


func _heading(box: VBoxContainer, title: String, subtitle: String = "") -> void :
	var h: = UI.label(title, 20, GOLD, 440.0)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(h)
	if subtitle != "":
		var s: = UI.label(subtitle, 12, MUTED, 440.0)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(s)


func _field(box: VBoxContainer, caption: String, hint: String = "", secret: bool = false, email: bool = false) -> LineEdit:
	box.add_child(UI.label(caption, 12, MUTED))
	var edit: = LineEdit.new()
	edit.secret = secret
	edit.max_length = 128
	edit.placeholder_text = hint
	if email:
		edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	_style_input(edit)
	box.add_child(edit)
	return edit


func _divider(box: VBoxContainer, text: String) -> void :
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	for i in 2:
		if i == 1:
			row.add_child(UI.label(text, 11, MUTED))
		var line: = ColorRect.new()
		line.color = Color(1, 1, 1, 0.14)
		line.custom_minimum_size = Vector2(0, 2)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(line)


func _build_main() -> void :
	var box: = _panel("main")
	_heading(box, "WELCOME", "Sign in to save your progress and play with friends")
	var pixel: = _button("PIXEL ACCOUNT", C_PIXEL, 18, 62.0, "pixel")
	pixel.pressed.connect(_show.bind("pixel", true))
	box.add_child(pixel)
	_divider(box, "OR")
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	_discord_btn = _button("DISCORD", C_DISCORD, 12, 56.0, "discord")
	_discord_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_discord_btn.pressed.connect(_on_discord)
	row.add_child(_discord_btn)
	var more: = _button("MORE", C_DARK, 12, 56.0, "more")
	more.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	more.pressed.connect(_show.bind("more", true))
	row.add_child(more)
	_google_btn = _button("GOOGLE", C_GOOGLE, 12, 56.0, "google")
	_google_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_google_btn.pressed.connect(_on_google)
	row.add_child(_google_btn)


func _build_pixel() -> void :
	var box: = _panel("pixel")
	_heading(box, "PIXEL ACCOUNT", "Sign in with your email")
	_email_login = _field(box, "EMAIL", "name@example.com", false, true)
	_pass_login = _field(box, "PASSWORD", "••••••", true)
	_email_login.text_submitted.connect( func(_t: String) -> void : _pass_login.grab_focus())
	_pass_login.text_submitted.connect( func(_t: String) -> void : _on_pixel_sign_in())
	_sign_in_btn = _button("SIGN IN", C_PIXEL, 18, 56.0)
	_sign_in_btn.pressed.connect(_on_pixel_sign_in)
	box.add_child(_sign_in_btn)
	var links: = HBoxContainer.new()
	links.alignment = BoxContainer.ALIGNMENT_CENTER
	links.add_theme_constant_override("separation", 18)
	box.add_child(links)
	var forgot: = _link_button("FORGOT PASSWORD")
	forgot.pressed.connect(_show.bind("forgot", true))
	links.add_child(forgot)
	var create: = _link_button("CREATE ACCOUNT")
	create.pressed.connect(_show.bind("create", true))
	links.add_child(create)
	var back: = _button("BACK", C_BACK, 14, 46.0)
	back.pressed.connect(_on_back)
	box.add_child(back)


func _build_more() -> void :
	var box: = _panel("more")
	_heading(box, "MORE")
	var create: = _button("CREATE ACCOUNT", C_DARK, 15, 54.0)
	create.pressed.connect(_show.bind("create", true))
	box.add_child(create)
	var forgot: = _button("FORGOT PASSWORD", C_DARK, 15, 54.0)
	forgot.pressed.connect(_show.bind("forgot", true))
	box.add_child(forgot)
	var guest: = _button("PLAY WITHOUT ACCOUNT", C_BACK, 15, 54.0)
	guest.pressed.connect(_on_guest)
	box.add_child(guest)
	var note: = UI.label("Without an account your progress stays on this device only", 11, MUTED, 440.0)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	var back: = _button("BACK", C_BACK, 14, 46.0)
	back.pressed.connect(_on_back)
	box.add_child(back)


func _build_create() -> void :
	var box: = _panel("create")
	_heading(box, "CREATE ACCOUNT", "We will email you a link to confirm your address")
	_email_new = _field(box, "EMAIL", "name@example.com", false, true)
	_pass_new = _field(box, "PASSWORD", "••••••", true)
	_pass_new2 = _field(box, "CONFIRM PASSWORD", "••••••", true)
	_pass_new2.text_submitted.connect( func(_t: String) -> void : _on_create())
	_create_btn = _button("CREATE ACCOUNT", C_PIXEL, 18, 56.0)
	_create_btn.pressed.connect(_on_create)
	box.add_child(_create_btn)
	var back: = _button("BACK", C_BACK, 14, 46.0)
	back.pressed.connect(_on_back)
	box.add_child(back)


func _build_forgot() -> void :
	var box: = _panel("forgot")
	_heading(box, "FORGOT PASSWORD", "We will email you a link to choose a new password")
	_email_reset = _field(box, "EMAIL", "name@example.com", false, true)
	_email_reset.text_submitted.connect( func(_t: String) -> void : _on_reset())
	_reset_btn = _button("SEND RESET LINK", C_PIXEL, 18, 56.0)
	_reset_btn.pressed.connect(_on_reset)
	box.add_child(_reset_btn)
	var back: = _button("BACK", C_BACK, 14, 46.0)
	back.pressed.connect(_on_back)
	box.add_child(back)


func _build_wait() -> void :
	var box: = _panel("wait")
	_wait_label = UI.label("Finish signing in in your browser, then come back to the game.", 14, Color.WHITE, 440.0)
	_wait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_wait_label)
	_code_label = UI.label("", 30, GOLD)
	_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_label.visible = false
	box.add_child(_code_label)
	_code_button = _button("OPEN google.com/device", C_DARK, 14, 48.0)
	_code_button.visible = false
	_code_button.pressed.connect( func() -> void : OS.shell_open(_code_url))
	box.add_child(_code_button)
	var cancel: = _button("CANCEL", C_BACK, 16, 50.0)
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
		"create":
			_show("pixel")
		"forgot":
			_show("pixel")
		_:
			_show("main")


func _set_status(text: String, good: bool = false) -> void :
	if text == "":
		_status_panel.visible = false
		_status.text = ""
		return
	_status.text = tr(text)
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color("#10301f") if good else Color("#3a1226")
	sb.border_color = Color("#4ade80") if good else Color("#ff6b81")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_status_panel.add_theme_stylebox_override("panel", sb)
	_status_panel.visible = true


# ---- actions --------------------------------------------------------------------------------------

func _on_language(code: String) -> void :
	if code == Loc.current:
		return
	Loc.set_language(code)
	# reopen this screen so every text (and the emails the account sends) use the new language
	SceneTransition.go(scene_file_path)


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
	_set_status("Signing in...", true)
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
	_set_status("Creating your account...", true)
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
	_set_status("Sending...", true)
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
	SceneTransition.go(NEXT_SCENE)


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
