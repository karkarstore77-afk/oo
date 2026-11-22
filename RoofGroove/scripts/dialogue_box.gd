extends Control











signal page_shown(index: int, page: Dictionary)
signal finished

const UI: = preload("res://scripts/ui_kit.gd")
const Style: = preload("res://scripts/ui_style.gd")
const StoryData: = preload("res://scripts/story_data.gd")
const SAFE_AREA: = preload("res://scripts/safe_area.gd")
const StoryVoice: = preload("res://scripts/story_voice.gd")

var show_portrait: = false
var allow_skip: = true

var _pages: Array = []
var _index: = -1
var _typing: = false
var _done: = false
var _last_adv: = 0.0
var _tween: Tween
var _arrow_tween: Tween

var _skip_btn: Button
var _panel: PanelContainer
var _name_label: Label
var _text_label: Label
var _arrow: Control
var _portrait_panel: PanelContainer
var _portrait_holder: Control
var _portrait_sprite: AnimatedSprite2D



class Arrow extends Control:
	func _draw() -> void :
		var s: = minf(size.x, size.y)
		var pts: = PackedVector2Array([Vector2(0, 0), Vector2(s, 0), Vector2(s * 0.5, s * 0.75)])
		draw_colored_polygon(pts, Color(1.0, 0.86, 0.4))


func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_apply_sizes()
	get_viewport().size_changed.connect(_apply_sizes)


func _build() -> void :
	var safe: = MarginContainer.new()
	safe.set_script(SAFE_AREA)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(safe)

	var layout: = VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(layout)


	var top: = HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_END
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(top)
	_skip_btn = UI.button(tr("SKIP"), 14, 38.0)
	_skip_btn.focus_mode = Control.FOCUS_NONE
	_skip_btn.visible = allow_skip
	_skip_btn.pressed.connect(_finish)
	top.add_child(_skip_btn)

	var spacer: = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(spacer)


	var center: = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(center)
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(row)

	if show_portrait:
		_portrait_panel = PanelContainer.new()
		_portrait_panel.add_theme_stylebox_override("panel", Style.card_box(true))
		_portrait_panel.size_flags_vertical = Control.SIZE_SHRINK_END
		_portrait_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(_portrait_panel)
		_portrait_holder = Control.new()
		_portrait_holder.clip_contents = true
		_portrait_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_portrait_panel.add_child(_portrait_holder)
		_portrait_sprite = AnimatedSprite2D.new()
		_portrait_holder.add_child(_portrait_sprite)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", Style.dialog_box())
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_panel)

	var inner: = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(inner)

	_name_label = UI.label("", 18, Color.WHITE)
	_name_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.1))
	_name_label.add_theme_constant_override("outline_size", 4)
	inner.add_child(_name_label)

	_text_label = UI.label("", 20, Color.WHITE)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(_text_label)

	var arrow_row: = HBoxContainer.new()
	arrow_row.alignment = BoxContainer.ALIGNMENT_END
	arrow_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(arrow_row)
	_arrow = Arrow.new()
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.visible = false
	arrow_row.add_child(_arrow)

	_arrow_tween = create_tween().set_loops()
	_arrow_tween.tween_property(_arrow, "modulate:a", 0.25, 0.45)
	_arrow_tween.tween_property(_arrow, "modulate:a", 1.0, 0.45)



func _apply_sizes() -> void :
	var vp: = get_viewport_rect().size
	var fs: = clampi(int(vp.y * 0.032), 16, 30)
	_text_label.add_theme_font_size_override("font_size", fs)
	_name_label.add_theme_font_size_override("font_size", maxi(14, int(fs * 0.9)))
	_text_label.custom_minimum_size = Vector2(0, fs * 1.6 * 3.0)
	_panel.custom_minimum_size = Vector2(minf(vp.x * 0.74, 980.0), 0)
	var arrow_size: = float(maxi(12, int(fs * 0.7)))
	_arrow.custom_minimum_size = Vector2(arrow_size, arrow_size)
	var skip_fs: = maxi(12, int(fs * 0.7))
	_skip_btn.add_theme_font_size_override("font_size", skip_fs)
	if _portrait_holder != null:
		var box: = clampf(vp.y * 0.17, 80.0, 190.0)
		_portrait_holder.custom_minimum_size = Vector2(box, box)
		var sc: = box / 34.0
		_portrait_sprite.scale = Vector2(sc, sc)
		_portrait_sprite.position = Vector2(box * 0.5, box * 0.5 + sc * 2.0)



func start(pages: Array) -> void :
	GameAudio.duck(true)
	_pages = pages
	_index = -1
	_done = false
	if _pages.is_empty():
		_finish()
		return
	_show_page(0)


func _show_page(i: int) -> void :
	_index = i
	var page: Dictionary = _pages[i]
	var who: = str(page.get("who", "narrator"))
	var txt: = StoryData.pick(page.get("text", {}))
	var nm: = StoryData.speaker_name(who)
	_name_label.text = nm
	_name_label.visible = nm != ""
	_name_label.add_theme_color_override("font_color", StoryData.speaker_color(who))
	_text_label.text = txt
	_text_label.visible_ratio = 0.0
	_arrow.visible = false
	_update_portrait(who)

	StoryVoice.speak(who, txt)
	_typing = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var dur: = clampf(float(txt.length()) * 0.028, 0.5, 3.2)
	_tween = create_tween()
	_tween.tween_property(_text_label, "visible_ratio", 1.0, dur)
	_tween.tween_callback(_on_typed)
	page_shown.emit(i, page)


func _on_typed() -> void :
	_typing = false
	_arrow.visible = true


func _update_portrait(who: String) -> void :
	if _portrait_panel == null:
		return
	var skin: = StoryData.skin_for(who)
	_portrait_panel.visible = skin != ""
	if skin == "":
		return
	_portrait_sprite.sprite_frames = Economy.frames_for(skin)
	_portrait_sprite.play("idle")


func _advance() -> void :
	var now: = Time.get_ticks_msec() / 1000.0
	if now - _last_adv < 0.15:
		return
	_last_adv = now
	if _typing:
		if _tween != null and _tween.is_valid():
			_tween.kill()
		_text_label.visible_ratio = 1.0
		_on_typed()
		return
	if _index + 1 >= _pages.size():
		_finish()
	else:
		_show_page(_index + 1)


func _finish() -> void :
	if _done:
		return
	_done = true
	StoryVoice.stop()
	GameAudio.duck(false)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	finished.emit()


func _input(event: InputEvent) -> void :
	if _done or _index < 0:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _skip_btn.visible and _skip_btn.get_global_rect().has_point(event.position):
			return
		get_viewport().set_input_as_handled()
		_advance()
	elif event.is_action_pressed("ui_accept") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_advance()
	elif event.is_action_pressed("ui_cancel") and allow_skip:
		get_viewport().set_input_as_handled()
		_finish()


func _notification(what: int) -> void :
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and allow_skip:
		_finish()


func _exit_tree() -> void :
	StoryVoice.stop()
	GameAudio.duck(false)
