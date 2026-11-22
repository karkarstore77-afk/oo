extends Button
## Small round HUD button drawn in code (no font glyphs, so it looks the same everywhere).
## kind = "mic" or "chat".  Tweak the colours / sizes in the constants below.

const COLOR_BG := Color(0.055, 0.065, 0.11, 0.88)
const COLOR_BG_ON := Color(0.07, 0.26, 0.15, 0.92)
const COLOR_BORDER := Color(0.45, 0.39, 0.72, 0.95)
const COLOR_BORDER_CHAT_OPEN := Color(1.0, 0.84, 0.37, 1.0)
const COLOR_ON := Color(0.30, 0.85, 0.50)
const COLOR_OFF := Color(0.92, 0.36, 0.36)
const COLOR_ICON := Color(0.94, 0.95, 1.0)
const BORDER_WIDTH := 2.5

var kind: String = "mic"
## mic: true = microphone is live.  chat: true = chat panel is open.
var active: bool = false:
	set(value):
		active = value
		queue_redraw()
## Small red dot (used by the chat button for unread messages).
var badge: bool = false:
	set(value):
		badge = value
		queue_redraw()


func _init(button_kind: String = "mic", button_size: float = 46.0) -> void:
	kind = button_kind
	custom_minimum_size = Vector2(button_size, button_size)
	focus_mode = Control.FOCUS_NONE
	flat = true
	text = ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _ready() -> void:
	pivot_offset = size * 0.5
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	button_down.connect(func() -> void: scale = Vector2(0.92, 0.92))
	button_up.connect(func() -> void: scale = Vector2.ONE)
	mouse_exited.connect(func() -> void: scale = Vector2.ONE)


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - BORDER_WIDTH
	var fill: Color = COLOR_BG
	var border: Color = COLOR_BORDER
	var icon: Color = COLOR_ICON
	if kind == "mic":
		border = COLOR_ON if active else COLOR_OFF
		fill = COLOR_BG_ON if active else COLOR_BG
		icon = COLOR_ON.lightened(0.35) if active else COLOR_ICON
	elif active:
		border = COLOR_BORDER_CHAT_OPEN
	if get_draw_mode() == DRAW_HOVER or get_draw_mode() == DRAW_HOVER_PRESSED:
		fill = fill.lightened(0.10)
	draw_circle(c, r, fill)
	draw_arc(c, r, 0.0, TAU, 48, border, BORDER_WIDTH, true)
	if kind == "mic":
		_draw_mic(c, r, icon)
	else:
		_draw_chat(c, r, icon)
	if badge:
		draw_circle(c + Vector2(r * 0.72, -r * 0.72), r * 0.24, COLOR_OFF)
		draw_arc(c + Vector2(r * 0.72, -r * 0.72), r * 0.24, 0.0, TAU, 16, COLOR_BG, 1.5, true)


func _draw_mic(c: Vector2, r: float, color: Color) -> void:
	var half_w: float = r * 0.17
	var top: float = c.y - r * 0.48
	var bottom: float = c.y + r * 0.08
	# capsule body
	draw_circle(Vector2(c.x, top + half_w), half_w, color)
	draw_circle(Vector2(c.x, bottom - half_w), half_w, color)
	draw_rect(Rect2(c.x - half_w, top + half_w, half_w * 2.0, (bottom - half_w) - (top + half_w)), color)
	# holder (U shape), stem and base
	draw_arc(Vector2(c.x, bottom - half_w), r * 0.36, 0.0, PI, 20, color, 2.0, true)
	draw_line(Vector2(c.x, bottom - half_w + r * 0.36), Vector2(c.x, c.y + r * 0.58), color, 2.0, true)
	draw_line(Vector2(c.x - r * 0.22, c.y + r * 0.58), Vector2(c.x + r * 0.22, c.y + r * 0.58), color, 2.0, true)
	if not active:
		# muted: red slash
		draw_line(c + Vector2(-r * 0.55, -r * 0.55), c + Vector2(r * 0.55, r * 0.55), COLOR_BG, 6.0, true)
		draw_line(c + Vector2(-r * 0.55, -r * 0.55), c + Vector2(r * 0.55, r * 0.55), COLOR_OFF, 3.0, true)


func _draw_chat(c: Vector2, r: float, color: Color) -> void:
	var bubble := Rect2(c.x - r * 0.52, c.y - r * 0.40, r * 1.04, r * 0.66)
	draw_rect(bubble, color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - r * 0.28, c.y + r * 0.24),
		Vector2(c.x - r * 0.36, c.y + r * 0.58),
		Vector2(c.x + r * 0.10, c.y + r * 0.24)]), color)
	var dot_y: float = bubble.position.y + bubble.size.y * 0.5
	for dx in [-0.24, 0.0, 0.24]:
		draw_circle(Vector2(c.x + r * float(dx), dot_y), r * 0.075, COLOR_BG)
