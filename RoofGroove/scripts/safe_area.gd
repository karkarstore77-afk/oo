extends MarginContainer



const Layout: = preload("res://scripts/menu_layout.gd")

@export var base_margin: = 16


func _ready() -> void :
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(_apply)
	_apply()


func _apply() -> void :
	var left: = 0.0
	var right: = 0.0
	var top: = 0.0
	var bottom: = 0.0
	var os_name: = OS.get_name()
	if os_name == "Android" or os_name == "iOS":
		var win: = Vector2(DisplayServer.window_get_size())
		var safe: = Rect2(DisplayServer.get_display_safe_area())
		var vp: = get_viewport().get_visible_rect().size
		if win.x > 0.0 and win.y > 0.0:
			var kx: = vp.x / win.x
			var ky: = vp.y / win.y
			left = maxf(0.0, safe.position.x) * kx
			top = maxf(0.0, safe.position.y) * ky
			right = maxf(0.0, win.x - safe.end.x) * kx
			bottom = maxf(0.0, win.y - safe.end.y) * ky
	add_theme_constant_override("margin_left", int(left) + base_margin)
	add_theme_constant_override("margin_right", int(right) + base_margin)
	var bar_space: = Layout.SPACE if Layout.is_menu_node(self) else 0
	add_theme_constant_override("margin_top", int(top) + base_margin + bar_space)
	add_theme_constant_override("margin_bottom", int(bottom) + base_margin)
