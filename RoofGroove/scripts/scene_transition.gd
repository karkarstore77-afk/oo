extends CanvasLayer
## One transition for the whole game: a pixel "iris" closes on the screen, the scene changes behind it,
## then it opens again with a small burst of sparks.
## Use  SceneTransition.go("res://sence/x.tscn")  instead of get_tree().change_scene_to_file().

const UIFx: = preload("res://scripts/ui_fx.gd")

const CLOSE_TIME: = 0.34
const OPEN_TIME: = 0.46
const SPARK_COLOR: = Color("#ffd666")
const SHADER_CODE: = """
shader_type canvas_item;
uniform float progress = 0.0;
uniform float aspect = 1.7778;
uniform vec4 cover_color : source_color = vec4(0.04, 0.03, 0.10, 1.0);
uniform vec4 ring_color : source_color = vec4(1.0, 0.84, 0.40, 1.0);
void fragment() {
	vec2 cells = vec2(72.0 * aspect, 72.0);
	vec2 uv = (floor(UV * cells) + 0.5) / cells;
	float d = length((uv - vec2(0.5)) * vec2(aspect, 1.0));
	float max_d = length(vec2(aspect, 1.0) * 0.5) + 0.05;
	float r = (1.0 - progress) * max_d;
	float hole = step(d, r);
	float ring = step(abs(d - r), 0.014) * step(0.001, progress) * step(progress, 0.999);
	vec3 col = mix(cover_color.rgb, ring_color.rgb, ring);
	COLOR = vec4(col, max(1.0 - hole, ring));
}
"""

var _rect: ColorRect
var _mat: ShaderMaterial
var _busy: = false


func _ready() -> void :
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.visible = false
	var shader: = Shader.new()
	shader.code = SHADER_CODE
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_rect.material = _mat
	add_child(_rect)
	get_viewport().size_changed.connect(_update_aspect)
	_update_aspect()
	_set_progress(0.0)


func is_busy() -> bool:
	return _busy


func go(path: String) -> void :
	if _busy:
		return
	if not ResourceLoader.exists(path):
		push_warning("SceneTransition: scene not found: " + path)
		return
	_busy = true
	await _run( func() -> int: return get_tree().change_scene_to_file(path))


func go_packed(scene: PackedScene) -> void :
	if _busy or scene == null:
		return
	_busy = true
	await _run( func() -> int: return get_tree().change_scene_to_packed(scene))


func _run(change: Callable) -> void :
	_rect.visible = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP  # no taps while the screen is changing
	GameAudio.play_sfx("ui_open", 0.9)
	var close: Tween = create_tween().set_ignore_time_scale(true)
	close.tween_method(_set_progress, 0.0, 1.0, CLOSE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await close.finished
	change.call()
	await get_tree().process_frame
	await get_tree().process_frame
	GameAudio.play_sfx("sparkle")
	var center: = get_viewport().get_visible_rect().size * 0.5
	UIFx.burst(self, center, SPARK_COLOR, 20, 190.0)
	UIFx.burst(self, center, Color.WHITE, 10, 120.0)
	var open: Tween = create_tween().set_ignore_time_scale(true)
	open.tween_method(_set_progress, 1.0, 0.0, OPEN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await open.finished
	_rect.visible = false
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func _set_progress(value: float) -> void :
	_mat.set_shader_parameter("progress", value)


func _update_aspect() -> void :
	var size: = get_viewport().get_visible_rect().size
	_mat.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
