extends Control


const UI: = preload("res://scripts/ui_kit.gd")
const SAFE_AREA: = preload("res://scripts/safe_area.gd")
const ICON_UP: Texture2D = preload("res://mobile_buttons_png/upbutton.png")
const ICON_RIGHT: Texture2D = preload("res://mobile_buttons_png/rightbutton.png")
const ICON_LEFT: Texture2D = preload("res://mobile_buttons_png/leftbutton.png")
const CONTACT: = preload("res://scripts/contact_links.gd")
const Fx: = preload("res://scripts/ui_fx.gd")

const CARD_BG: = Color("#1b1c2a")
const CARD_BORDER: = Color("#3a3c58")
const GOLD: = Color("#ffd666")
const MUTED: = Color(0.8, 0.8, 0.85)

var _info_col: VBoxContainer
var _contact_col: VBoxContainer


func _ready() -> void :
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg: = ColorRect.new()
	bg.color = Color("#07070d")
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_add_floating_dots()

	var safe: = MarginContainer.new()
	safe.set_script(SAFE_AREA)
	add_child(safe)

	var scroll: = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	safe.add_child(scroll)

	var center: = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 56)
	center.add_child(row)

	var knight_holder: = Control.new()
	knight_holder.custom_minimum_size = Vector2(300, 300)
	row.add_child(knight_holder)
	var knight: = UI.make_knight(9.0)
	Economy.bind(knight)
	knight.position = Vector2(150, 150)
	knight_holder.add_child(knight)
	var bob: Tween = knight.create_tween().set_loops()
	bob.tween_property(knight, "position:y", 138.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(knight, "position:y", 158.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var col: = VBoxContainer.new()
	_info_col = col
	col.custom_minimum_size = Vector2(560, 0)
	col.add_theme_constant_override("separation", 14)
	row.add_child(col)

	col.add_child(UI.label("INFORMATION", 34, GOLD))

	var controls: = _card(col)
	controls.add_child(UI.label("CONTROLS", 22))
	controls.add_child(_control_row(ICON_UP, "JUMP  -  UP ARROW"))
	controls.add_child(_control_row(ICON_RIGHT, "RIGHT  -  RIGHT ARROW"))
	controls.add_child(_control_row(ICON_LEFT, "LEFT  -  LEFT ARROW"))
	controls.add_child(UI.label("On phones use the buttons on screen", 13, MUTED, 500.0))

	var about: = _card(col)
	about.add_child(UI.label("MORE INFORMATION", 22))
	about.add_child(UI.label("Developed in Godot", 15))
	about.add_child(UI.label("Pixel Studio", 15, Color.WHITE, 500.0))
	about.add_child(UI.label("Thanks for playing", 15))
	about.add_child(_version_chip())

	var contact_btn: = UI.button("CONTACT US", 20, 52.0)
	contact_btn.pressed.connect(_show_contact.bind(true))
	col.add_child(contact_btn)

	var back: = UI.button("BACK", 22, 56.0)
	back.pressed.connect(_go_back)
	col.add_child(back)

	# cards and buttons slide in one after the other
	var delay: = 0.05
	for item in col.get_children():
		Fx.fade_in(item as CanvasItem, delay, 0.3)
		delay += 0.09
	Fx.fade_in(knight_holder, 0.0, 0.4)
	GameAudio.play_sfx("ui_open")

	_build_contact(row)



func _card(parent: Control) -> VBoxContainer:
	var panel: = PanelContainer.new()
	var style: = StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.border_color = CARD_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 6
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var box: = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	return box


func _version_chip() -> Control:
	var holder: = HBoxContainer.new()
	holder.alignment = BoxContainer.ALIGNMENT_BEGIN
	var chip: = PanelContainer.new()
	var style: = StyleBoxFlat.new()
	style.bg_color = Color("#262842")
	style.border_color = GOLD
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	chip.add_theme_stylebox_override("panel", style)
	chip.add_child(UI.label(tr("Version %s") % Updater.current_version(), 13, GOLD))
	holder.add_child(chip)
	return holder


## A few tiny dots that drift upwards slowly (cheap background life).
func _add_floating_dots() -> void:
	var rng: = RandomNumberGenerator.new()
	rng.randomize()
	var area: = get_viewport_rect().size
	for i in 22:
		var dot: = ColorRect.new()
		var size_px: = rng.randf_range(2.0, 4.0)
		dot.size = Vector2(size_px, size_px)
		dot.color = Color(1.0, 0.84, 0.4, rng.randf_range(0.10, 0.28)) if i % 3 == 0 else Color(0.55, 0.6, 1.0, rng.randf_range(0.10, 0.28))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.position = Vector2(rng.randf_range(0.0, area.x), rng.randf_range(0.0, area.y))
		add_child(dot)
		var rise: = rng.randf_range(60.0, 140.0)
		var tw: Tween = dot.create_tween().set_loops()
		tw.tween_property(dot, "position:y", dot.position.y - rise, rng.randf_range(5.0, 9.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(dot, "position:y", dot.position.y, rng.randf_range(5.0, 9.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _build_contact(row: HBoxContainer) -> void :
	_contact_col = VBoxContainer.new()
	_contact_col.custom_minimum_size = Vector2(560, 0)
	_contact_col.add_theme_constant_override("separation", 14)
	_contact_col.visible = false
	row.add_child(_contact_col)

	_contact_col.add_child(UI.label("CONTACT US", 34, GOLD))
	var shown: = 0


	var my_links: = [
		{"name": "Offical Site", "url": "https://roofgroove.netlify.app/"}, 
		{"name": "Discord", "url": "https://discord.com/users/1358343291426312217"}, 
		{"name": "Instagram", "url": "https://www.instagram.com/rayyanelnahas"}, 
		{"name": "TikTok", "url": "https://www.tiktok.com/@priv_re1"}
	]

	for item in my_links:
		var link_name: = str(item.get("name", "")).strip_edges()
		var url: = str(item.get("url", "")).strip_edges()
		if link_name == "" or url == "":
			continue
		if not url.contains("://"):
			url = "https://" + url
		var btn: = UI.button(link_name, 20, 52.0)
		btn.pressed.connect( func(): OS.shell_open(url))
		_contact_col.add_child(btn)
		shown += 1
	if shown == 0:
		_contact_col.add_child(UI.label("No contact links yet", 16, Color(0.8, 0.8, 0.85), 560.0))

	var contact_back: = UI.button("BACK", 22, 56.0)
	contact_back.pressed.connect(_show_contact.bind(false))
	_contact_col.add_child(contact_back)


func _show_contact(open_contact: bool) -> void :
	_info_col.visible = not open_contact
	_contact_col.visible = open_contact
	GameAudio.play_sfx("ui_open" if open_contact else "ui_back")
	var shown: Control = _contact_col if open_contact else _info_col
	var delay: = 0.0
	for item in shown.get_children():
		Fx.fade_in(item as CanvasItem, delay, 0.25)
		delay += 0.06


func _control_row(icon: Texture2D, text: String) -> HBoxContainer:
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var rect: = TextureRect.new()
	rect.texture = icon
	rect.custom_minimum_size = Vector2(72, 72)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	row.add_child(rect)
	var label: = UI.label(text, 18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row


func _go_back() -> void :
	if _contact_col != null and _contact_col.visible:
		_show_contact(false)
		return
	SceneTransition.go("res://sence/main_menu.tscn")


func _unhandled_input(event: InputEvent) -> void :
	if event.is_action_pressed("ui_cancel"):
		_go_back()


func _notification(what: int) -> void :
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()
