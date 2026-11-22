extends CanvasLayer


const UI: = preload("res://scripts/ui_kit.gd")
const Style: = preload("res://scripts/ui_style.gd")
const SAFE_AREA: = preload("res://scripts/safe_area.gd")
const StoryData: = preload("res://scripts/story_data.gd")
const StoryVoice: = preload("res://scripts/story_voice.gd")

var _panel: PanelContainer
var _name: Label
var _text: Label
var _holder: Control
var _spr: AnimatedSprite2D
var _tween: Tween


func _ready() -> void :
	layer = 10
	var root: = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var safe: = MarginContainer.new()
	safe.set_script(SAFE_AREA)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(safe)

	var col: = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(col)
	var center: = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(center)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", Style.dialog_box())
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.modulate.a = 0.0
	center.add_child(_panel)

	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)

	_holder = Control.new()
	_holder.clip_contents = true
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_holder)
	_spr = AnimatedSprite2D.new()
	_holder.add_child(_spr)

	var inner: = VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(inner)
	_name = UI.label("", 16, Color.WHITE)
	inner.add_child(_name)
	_text = UI.label("", 18, Color.WHITE)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(_text)

	get_viewport().size_changed.connect(_apply_sizes)
	_apply_sizes()


func _apply_sizes() -> void :
	var vp: = get_viewport().get_visible_rect().size
	var fs: = clampi(int(vp.y * 0.028), 13, 24)
	_text.add_theme_font_size_override("font_size", fs)
	_name.add_theme_font_size_override("font_size", maxi(12, int(fs * 0.9)))
	_text.custom_minimum_size = Vector2(minf(vp.x * 0.55, 560.0), 0)
	var box: = clampf(vp.y * 0.12, 52.0, 96.0)
	_holder.custom_minimum_size = Vector2(box, box)
	var sc: = box / 34.0
	_spr.scale = Vector2(sc, sc)
	_spr.position = Vector2(box * 0.5, box * 0.5 + sc * 2.0)


func show_tip(skin: String, text: String) -> void :
	_spr.sprite_frames = Economy.frames_for(skin)
	_spr.play("idle")
	_name.text = StoryData.speaker_name(skin)
	_name.add_theme_color_override("font_color", StoryData.speaker_color(skin))
	_text.text = text
	StoryVoice.speak(skin, text)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", 1.0, 0.25)
	_tween.tween_interval(maxf(3.2, maxf(float(text.length()) * 0.07, StoryVoice.last_length + 0.8)))
	_tween.tween_property(_panel, "modulate:a", 0.0, 0.4)


func _exit_tree() -> void :
	StoryVoice.stop()
