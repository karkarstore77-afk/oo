extends Node
## Phone tilt (gravity sensor) -> smoothed Vector2 in -1..1, used for parallax.
## On desktop the mouse position is used instead so it can be tested in the editor.
## If the picture moves the wrong way on a real phone, flip INVERT_X / INVERT_Y.

const INVERT_X: = false
const INVERT_Y: = false
const RANGE: = 3.5
const FOLLOW: = 12.0
const RECENTER: = 0.08

var tilt: = Vector2.ZERO

var _fast: = Vector2.ZERO
var _base: = Vector2.ZERO
var _has_base: = false
var _targets: Array = []


## Make a node follow the tilt. Works for Node2D and for Controls that are not
## inside a Container. amplitude = max shift in pixels.
func attach(node: CanvasItem, amplitude: float = 20.0) -> void :
	if node is Control:
		var c: = node as Control
		if c.get_parent() is Container:
			push_warning("GyroTilt: %s is inside a Container, skipped" % c.name)
			return
		_targets.append({"node": c, "amp": amplitude, 
			"home": Vector4(c.offset_left, c.offset_top, c.offset_right, c.offset_bottom)})
	elif node is Node2D:
		_targets.append({"node": node, "amp": amplitude, "home": (node as Node2D).position})


func _process(delta: float) -> void :
	var want: = _read_tilt(delta)
	var on: = 1.0 if GameSettings.motion_on else 0.0
	tilt = tilt.lerp(want * on, 1.0 - exp( - 10.0 * delta))
	_apply()


func _read_tilt(delta: float) -> Vector2:
	if not OS.has_feature("mobile"):
		var vp: = get_viewport()
		var size: = vp.get_visible_rect().size
		if size.x < 1.0 or size.y < 1.0:
			return Vector2.ZERO
		var m: = (vp.get_mouse_position() / size - Vector2(0.5, 0.5)) * 2.0
		return Vector2(clampf(m.x, -1.0, 1.0), clampf(m.y, -1.0, 1.0))

	var g: = Input.get_gravity()
	if g == Vector3.ZERO:
		g = Input.get_accelerometer()
	if g == Vector3.ZERO:
		return Vector2.ZERO
	var raw: = _to_screen(g)
	if not _has_base:
		_base = raw
		_fast = raw
		_has_base = true
	_fast = _fast.lerp(raw, 1.0 - exp( - FOLLOW * delta))
	_base = _base.lerp(raw, 1.0 - exp( - RECENTER * delta))
	var d: = (_fast - _base) / RANGE
	d = Vector2(clampf(d.x, -1.0, 1.0), clampf(d.y, -1.0, 1.0))
	if INVERT_X:
		d.x = - d.x
	if INVERT_Y:
		d.y = - d.y
	return d


## sensor axes are not rotated with the screen, so map them by orientation
func _to_screen(g: Vector3) -> Vector2:
	match DisplayServer.screen_get_orientation():
		DisplayServer.SCREEN_PORTRAIT:
			return Vector2( - g.x, g.y)
		DisplayServer.SCREEN_REVERSE_PORTRAIT:
			return Vector2(g.x, - g.y)
		DisplayServer.SCREEN_REVERSE_LANDSCAPE:
			return Vector2( - g.y, - g.x)
		_:
			return Vector2(g.y, g.x)


func _apply() -> void :
	for i in range(_targets.size() - 1, -1, -1):
		var t: Dictionary = _targets[i]
		var n: Variant = t["node"]
		if not is_instance_valid(n) or not (n as Node).is_inside_tree():
			_targets.remove_at(i)
			continue
		var o: Vector2 = - tilt * float(t["amp"])
		if n is Control:
			var h: Vector4 = t["home"]
			var c: = n as Control
			c.offset_left = h.x + o.x
			c.offset_right = h.z + o.x
			c.offset_top = h.y + o.y
			c.offset_bottom = h.w + o.y
		else:
			(n as Node2D).position = (t["home"] as Vector2) + o
