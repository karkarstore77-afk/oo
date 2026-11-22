extends CanvasLayer


const UI: = preload("res://scripts/ui_kit.gd")
const FX: = preload("res://scripts/story_effects.gd")
const StoryData: = preload("res://scripts/story_data.gd")

var _box: VBoxContainer
var _labels: Dictionary = {}


func _ready() -> void :
	layer = 9
	var root: = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m: = MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", 16)
	m.add_theme_constant_override("margin_top", 56)
	root.add_child(m)
	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(_box)


func _process(_delta: float) -> void :
	var fs: = clampi(int(get_viewport().get_visible_rect().size.y * 0.03), 12, 22)
	for k in FX.active.keys():
		if not _labels.has(k):
			var l: = UI.label("", fs, Color.WHITE)
			_box.add_child(l)
			_labels[k] = l
		var lab: Label = _labels[k]
		lab.add_theme_font_size_override("font_size", fs)
		var good: = bool(FX.DEFS[k]["good"])
		lab.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65) if good else Color(1.0, 0.45, 0.45))
		lab.text = "%s  %ds" % [StoryData.effect_name(str(k)), int(ceilf(float(FX.active[k])))]
	for k in _labels.keys():
		if not FX.active.has(k):
			_labels[k].queue_free()
			_labels.erase(k)
