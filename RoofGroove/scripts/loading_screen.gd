extends Control
## Shown once after the splash: loads every scene, picture, font and sound before the game starts
## (progress bar + running knight), then a small spark effect and the iris transition into the game.

const UI: = preload("res://scripts/ui_kit.gd")
const SAFE_AREA: = preload("res://scripts/safe_area.gd")
const Fx: = preload("res://scripts/ui_fx.gd")
const Backdrop: = preload("res://scripts/menu_backdrop.gd")
const LoginMenu: = preload("res://scripts/login_menu.gd")
const RooftopScene: = preload("res://scripts/rooftop_scene.gd")

const DIRS: = ["res://sence", "res://sprites", "res://branding", "res://fonts", "res://music", "res://mobile_buttons_png"]
const EXTENSIONS: = ["tscn", "png", "jpg", "jpeg", "webp", "ttf", "otf", "mp3", "ogg", "wav", "tres", "res"]
const MIN_SECONDS: = 1.6   # the bar never finishes faster than this, so the screen is not just a flash
const GOLD: = Color("#ffd666")
const TIPS: = [
	"TIP: Hold the jump button longer to jump higher",
	"TIP: Every checkpoint saves your progress",
	"TIP: Beat the boss arenas to earn gems",
	"TIP: Invite friends and play together online",
	"TIP: Enter secret codes in the codes screen",
	"TIP: Pick your favorite skin in the shop",
]

## Keeps everything loaded in memory (otherwise Godot would drop it again).
static var held: Array = []

var _pending: Array[String] = []
var _total: = 0
var _done: = 0
var _shown: = 0.0
var _elapsed: = 0.0
var _finishing: = false
var _bar: Control
var _knight: AnimatedSprite2D
var _percent: Label
var _detail: Label
var _tip: Label
var _tip_index: = 0
var _tip_timer: = 0.0


class Bar extends Control:
	var progress: = 0.0
	var t: = 0.0
	var flash: = 0.0

	func _process(delta: float) -> void :
		t += delta
		flash = maxf(flash - delta * 2.0, 0.0)
		queue_redraw()

	func _draw() -> void :
		var r: = Rect2(Vector2.ZERO, size)
		var track: = StyleBoxFlat.new()
		track.bg_color = Color("#150e2c")
		track.border_color = Color("#6b4bb0")
		track.set_border_width_all(3)
		track.set_corner_radius_all(int(size.y * 0.5))
		draw_style_box(track, r)
		var inner: = r.grow(-5.0)
		var fill_w: = maxf(inner.size.y, inner.size.x * progress)
		var fill: = Rect2(inner.position, Vector2(fill_w, inner.size.y))
		var fs: = StyleBoxFlat.new()
		fs.bg_color = Color("#ffc857").lerp(Color.WHITE, flash * 0.6)
		fs.set_corner_radius_all(int(inner.size.y * 0.5))
		draw_style_box(fs, fill)
		var top: = StyleBoxFlat.new()
		top.bg_color = Color(1, 1, 1, 0.28)
		top.set_corner_radius_all(int(inner.size.y * 0.25))
		draw_style_box(top, Rect2(fill.position + Vector2(4, 2), Vector2(maxf(fill.size.x - 8.0, 0.0), inner.size.y * 0.3)))
		# moving shine stripes
		for i in 6:
			var x: = fmod(t * 70.0 + float(i) * 46.0, fill.size.x + 40.0) - 20.0
			var stripe: = Rect2(fill.position.x + x, fill.position.y, 14.0, fill.size.y).intersection(fill)
			if stripe.size.x > 0.0:
				draw_rect(stripe, Color(1, 1, 1, 0.16))


func _ready() -> void :
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	Backdrop.add(self)
	var vp: = get_viewport_rect().size
	var safe: = MarginContainer.new()
	safe.set_script(SAFE_AREA)
	add_child(safe)
	for side in ["left", "right", "top", "bottom"]:
		safe.add_theme_constant_override("margin_" + side, 18)
	var center: = CenterContainer.new()
	safe.add_child(center)
	var col: = VBoxContainer.new()
	col.custom_minimum_size = Vector2(minf(vp.x - 40.0, 560.0), 0)
	col.add_theme_constant_override("separation", 12)
	center.add_child(col)

	var scene: Control = RooftopScene.new()
	scene.set("show_knight", false)  # the knight runs on the progress bar instead
	scene.custom_minimum_size = Vector2(0, clampf(vp.y * 0.36, 120.0, 290.0))
	col.add_child(scene)

	var runner: = Control.new()
	runner.custom_minimum_size = Vector2(0, 70)
	col.add_child(runner)
	_bar = Bar.new()
	_bar.custom_minimum_size = Vector2(0, 26)
	col.add_child(_bar)
	_knight = UI.make_knight(3.0)
	_bar.add_child(_knight)
	Economy.bind(_knight)  # the skin the player wears (adds the idle / run / jump animations)
	_knight.play(&"run")
	_knight.speed_scale = 1.4

	var info: = HBoxContainer.new()
	col.add_child(info)
	_detail = UI.label("Loading game resources...", 13, Color("#c9bfe8"))
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(_detail)
	_percent = UI.label("0%", 16, GOLD)
	info.add_child(_percent)
	_tip = UI.label(TIPS[0], 12, Color("#a89fcb"), 520.0)
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_tip)
	Fx.fade_in(col, 0.0, 0.4)

	_start_loading()


func _start_loading() -> void :
	var found: Dictionary = {}
	for d in DIRS:
		_collect(d, found)
	var me: = scene_file_path
	for path in found:
		if str(path) == me:
			continue
		if ResourceLoader.exists(str(path)):
			if ResourceLoader.load_threaded_request(str(path)) == OK:
				_pending.append(str(path))
	_total = _pending.size()


func _collect(dir: String, out: Dictionary) -> void :
	for f in DirAccess.get_files_at(dir):
		var file_name: String = f
		for suffix in [".import", ".remap"]:
			if file_name.ends_with(suffix):
				file_name = file_name.trim_suffix(suffix)
		if EXTENSIONS.has(file_name.get_extension().to_lower()):
			out[dir.path_join(file_name)] = true
	for sub in DirAccess.get_directories_at(dir):
		if not sub.begins_with("."):
			_collect(dir.path_join(sub), out)


func _process(delta: float) -> void :
	_elapsed += delta
	var still: Array[String] = []
	for path in _pending:
		match ResourceLoader.load_threaded_get_status(path):
			ResourceLoader.THREAD_LOAD_LOADED:
				held.append(ResourceLoader.load_threaded_get(path))
				_done += 1
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				still.append(path)
			_:
				_done += 1  # failed or missing: do not block the game
	_pending = still
	var real: = 1.0 if _total == 0 else float(_done) / float(_total)
	var target: = minf(real, clampf(_elapsed / MIN_SECONDS, 0.0, 1.0))
	_shown = move_toward(_shown, target, delta * 1.5)
	var bar: = _bar as Bar
	bar.progress = _shown
	var fill_end: = 5.0 + (bar.size.x - 10.0) * _shown
	_knight.position = Vector2(clampf(fill_end - 4.0, 18.0, bar.size.x - 18.0), -30.0)
	_percent.text = "%d%%" % int(_shown * 100.0)
	_detail.text = "%s  (%d / %d)" % [tr("Loading game resources..."), _done, _total]
	_tip_timer += delta
	if _tip_timer > 2.4:
		_tip_timer = 0.0
		_tip_index = (_tip_index + 1) % TIPS.size()
		_tip.text = tr(TIPS[_tip_index])
	if _shown >= 0.999 and not _finishing:
		_finishing = true
		_finish()


func _finish() -> void :
	set_process(false)
	_percent.text = "100%"
	(_bar as Bar).flash = 1.0
	GameAudio.play_sfx("success")
	_knight.play(&"jump")
	var spot: = _knight.global_position
	Fx.burst(self, spot, GOLD, 26, 210.0)
	Fx.burst(self, spot, Color.WHITE, 12, 130.0)
	var tw: Tween = create_tween()
	tw.tween_property(_knight, "position:y", -52.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_knight, "position:y", -30.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(0.5).timeout
	SceneTransition.go(_target_scene())


func _target_scene() -> String:
	var c: Node = Network.cloud
	if c != null and c.is_configured() and not c.is_signed_in() and not c.banned and not LoginMenu.guest_chosen():
		return "res://sence/login_menu.tscn"
	return "res://sence/main_menu.tscn"
