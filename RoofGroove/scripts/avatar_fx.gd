extends RefCounted
## Avatar pictures. VIP and DEV players get a special frame: coloured border, a slowly shifting glow
## and a small tag in the corner.

const UI: = preload("res://scripts/ui_kit.gd")
const COLORS: = {"VIP": Color("#ffd447"), "DEV": Color("#48d6c2")}
const ALT_COLORS: = {"VIP": Color("#fff3b0"), "DEV": Color("#b388ff")}
const DEFAULT_FRAME: = Color("#d9e7ff")
const LETTER_COLORS: Array[Color] = [
	Color("#ffffff"), Color("#14141f"), Color("#ffd447"), Color("#7de8ff"), Color("#ff8fc8"), Color("#8dff9c"),
]
const SHAPE_COUNT: = 3  # 0 rounded square, 1 circle, 2 sharp square


## Reads shape / frame / letter colour from a profile dictionary (friends, player cards ...).
static func extras_of(profile: Dictionary) -> Dictionary:
	return {
		"shape": int(profile.get("shape", 0)),
		"frame": int(profile.get("frame", 0)),
		"letter_color": int(profile.get("letter_color", 0)),
	}


## The signed-in player's own look.
static func own_extras() -> Dictionary:
	return {
		"shape": FriendsSystem.profile_shape,
		"frame": FriendsSystem.profile_frame,
		"letter_color": FriendsSystem.profile_letter_color,
	}


static func frame_color(index: int) -> Color:
	if index <= 0:
		return DEFAULT_FRAME
	var colors: Array[Color] = FriendsSystem.PROFILE_COLORS
	return colors[clampi(index - 1, 0, colors.size() - 1)]


static func letter_color(index: int) -> Color:
	return LETTER_COLORS[clampi(index, 0, LETTER_COLORS.size() - 1)]


## Sets corner radius (shape) and frame colour. VIP / DEV badges keep their own gold / teal frame.
static func apply_look(style: StyleBoxFlat, px: float, badge: String, extras: Dictionary = {}) -> void :
	var shape: int = clampi(int(extras.get("shape", 0)), 0, SHAPE_COUNT - 1)
	match shape:
		1:
			style.set_corner_radius_all(int(px * 0.5))
		2:
			style.set_corner_radius_all(0)
		_:
			style.set_corner_radius_all(maxi(6, int(px * 0.14)))
	if not COLORS.has(badge):
		style.border_color = frame_color(int(extras.get("frame", 0)))
	decorate_style(style, badge)


static func is_special(badge: String) -> bool:
	return COLORS.has(badge)


static func badge_color(badge: String) -> Color:
	return COLORS.get(badge, Color.WHITE)


static func decorate_style(style: StyleBoxFlat, badge: String) -> void :
	if not COLORS.has(badge):
		return
	var c: Color = COLORS[badge]
	style.border_color = c
	style.set_border_width_all(maxi(style.border_width_left, 4))
	style.shadow_color = Color(c.r, c.g, c.b, 0.6)
	style.shadow_size = 10


static func animate(node: Control, style: StyleBoxFlat, badge: String) -> void :
	if not COLORS.has(badge):
		return
	if node.is_inside_tree():
		_start_glow(node, style, badge)
	else:
		node.tree_entered.connect(_start_glow.bind(node, style, badge), CONNECT_ONE_SHOT)


static func _start_glow(node: Control, style: StyleBoxFlat, badge: String) -> void :
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	var base: Color = COLORS[badge]
	var alt: Color = ALT_COLORS[badge]
	var tw: Tween = node.create_tween().set_loops()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(style, "border_color", alt, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(style, "shadow_color", Color(alt.r, alt.g, alt.b, 0.8), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(style, "border_color", base, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(style, "shadow_color", Color(base.r, base.g, base.b, 0.5), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Builds a square avatar (letter on a coloured tile). Mouse input passes through to the parent.
static func build(letter: String, color_index: int, px: float, badge: String = "", extras: Dictionary = {}) -> Control:
	var root: = Control.new()
	root.custom_minimum_size = Vector2(px, px)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel: = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style: = StyleBoxFlat.new()
	var colors: Array[Color] = FriendsSystem.PROFILE_COLORS
	style.bg_color = colors[clampi(color_index, 0, colors.size() - 1)]
	style.border_color = DEFAULT_FRAME
	style.set_border_width_all(2)
	apply_look(style, px, badge, extras)
	panel.add_theme_stylebox_override("panel", style)
	var holder: = CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(holder)
	var letter_label: = UI.label(letter.to_upper(), maxi(14, int(px * 0.5)), letter_color(int(extras.get("letter_color", 0))))
	letter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(letter_label)
	if COLORS.has(badge):
		var ribbon: = PanelContainer.new()
		ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rs: = StyleBoxFlat.new()
		rs.bg_color = COLORS[badge]
		rs.set_corner_radius_all(4)
		rs.content_margin_left = 4
		rs.content_margin_right = 4
		rs.content_margin_top = 1
		rs.content_margin_bottom = 1
		ribbon.add_theme_stylebox_override("panel", rs)
		var tag: = UI.label(("♛ " if px >= 56.0 else "") + badge, 9 if px < 56.0 else 10, Color("#14141f"))
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ribbon.add_child(tag)
		root.add_child(ribbon)
		ribbon.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		ribbon.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		ribbon.grow_vertical = Control.GROW_DIRECTION_BEGIN
		animate(panel, style, badge)
	return root
