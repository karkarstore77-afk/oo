extends Node









const N: = 32
const M: = 12
const R: = 6.0

const FONT: Font = preload("res://fonts/PixelOperator8.ttf")


const KINDS: = {
	"blue": {
		"top": Color(0.24, 0.48, 0.97), "bottom": Color(0.13, 0.29, 0.74), 
		"rim": Color(0.64, 0.89, 1.0), "text": Color(1, 1, 1), 
	}, 
	"green": {
		"top": Color(0.33, 0.82, 0.42), "bottom": Color(0.14, 0.54, 0.28), 
		"rim": Color(0.82, 1.0, 0.82), "text": Color(1, 1, 1), 
	}, 
	"gold": {
		"top": Color(1.0, 0.8, 0.28), "bottom": Color(0.9, 0.55, 0.1), 
		"rim": Color(1.0, 0.97, 0.72), "text": Color(0.27, 0.12, 0.02), 
	}, 
	"red": {
		"top": Color(0.93, 0.34, 0.36), "bottom": Color(0.64, 0.15, 0.22), 
		"rim": Color(1.0, 0.82, 0.8), "text": Color(1, 1, 1), 
	}, 
}
const BORDER_COLOR: = Color(0.03, 0.05, 0.14)
const PRESSED_RIM: = Color(1.0, 0.86, 0.4)

static var _cache: Dictionary = {}


func _ready() -> void :
	var theme: = build_theme()
	get_tree().root.theme = theme

	var def: = ThemeDB.get_default_theme()
	if def != null:
		def.merge_with(theme)


static func build_theme() -> Theme:
	var theme: = Theme.new()
	_add_button_type(theme, "Button", "blue")
	_add_button_type(theme, "PrimaryButton", "green")
	_add_button_type(theme, "GoldButton", "gold")
	_add_button_type(theme, "DangerButton", "red")
	return theme


static func _add_button_type(theme: Theme, type_name: String, kind: String) -> void :
	if type_name != "Button":
		theme.set_type_variation(type_name, "Button")
	var pal: Dictionary = KINDS[kind]
	var txt: Color = pal["text"]
	theme.set_stylebox("normal", type_name, button_style(kind, "normal"))
	theme.set_stylebox("hover", type_name, button_style(kind, "hover"))
	theme.set_stylebox("pressed", type_name, button_style(kind, "pressed"))
	theme.set_stylebox("disabled", type_name, button_style(kind, "disabled"))
	theme.set_stylebox("focus", type_name, StyleBoxEmpty.new())
	theme.set_font("font", type_name, FONT)
	theme.set_font_size("font_size", type_name, 18)
	theme.set_color("font_color", type_name, txt)
	theme.set_color("font_hover_color", type_name, txt)
	theme.set_color("font_hover_pressed_color", type_name, txt)
	theme.set_color("font_focus_color", type_name, txt)
	theme.set_color("font_pressed_color", type_name, txt.lerp(Color(1.0, 0.95, 0.6), 0.5) if kind != "gold" else txt)
	theme.set_color("font_disabled_color", type_name, Color(0.7, 0.72, 0.8, 0.75))
	if kind == "gold":
		theme.set_constant("outline_size", type_name, 0)
	else:
		theme.set_constant("outline_size", type_name, 4)
		theme.set_color("font_outline_color", type_name, Color(0.03, 0.06, 0.18, 0.95))



static func button_style(kind: String, state: String) -> StyleBoxTexture:
	var key: = "btn_%s_%s" % [kind, state]
	if _cache.has(key):
		return _cache[key]
	var pal: Dictionary = KINDS[kind]
	var top: Color = pal["top"]
	var bottom: Color = pal["bottom"]
	var rim: Color = pal["rim"]
	var shift: = 0
	var lip: = 4
	match state:
		"hover":
			top = top.lightened(0.14)
			bottom = bottom.lightened(0.14)
			rim = rim.lightened(0.5)
		"pressed":
			top = top.darkened(0.1)
			bottom = bottom.darkened(0.1)
			rim = PRESSED_RIM
			shift = 3
			lip = 1
		"disabled":
			top = Color(0.34, 0.36, 0.45)
			bottom = Color(0.22, 0.24, 0.32)
			rim = Color(0.5, 0.52, 0.6)
			lip = 2
	var sb: = _make_style(_make_tex(top, bottom, rim, lip, shift, 1.0), Vector4(16, 8, 16, 12))
	if state == "pressed":
		sb.content_margin_top = 11.0
		sb.content_margin_bottom = 9.0
	_cache[key] = sb
	return sb



static func dialog_box() -> StyleBoxTexture:
	if _cache.has("dialog"):
		return _cache["dialog"]
	var tex: = _make_tex(Color(0.08, 0.12, 0.27), Color(0.04, 0.06, 0.16), 
		Color(0.64, 0.89, 1.0), 2, 0, 0.94)
	var sb: = _make_style(tex, Vector4(22, 16, 22, 20))
	_cache["dialog"] = sb
	return sb



static func card_box(unlocked: bool) -> StyleBoxTexture:
	var key: = "card_%s" % unlocked
	if _cache.has(key):
		return _cache[key]
	var rim: = PRESSED_RIM if unlocked else Color(0.4, 0.46, 0.62)
	var top: = Color(0.12, 0.17, 0.36) if unlocked else Color(0.09, 0.11, 0.21)
	var bottom: = Color(0.06, 0.09, 0.22) if unlocked else Color(0.05, 0.06, 0.14)
	var sb: = _make_style(_make_tex(top, bottom, rim, 2, 0, 0.92), Vector4(14, 10, 14, 12))
	_cache[key] = sb
	return sb


static func _make_style(tex: Texture2D, content: Vector4) -> StyleBoxTexture:
	var sb: = StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = M
	sb.texture_margin_top = M
	sb.texture_margin_right = M
	sb.texture_margin_bottom = M
	sb.content_margin_left = content.x
	sb.content_margin_top = content.y
	sb.content_margin_right = content.z
	sb.content_margin_bottom = content.w
	return sb





static func _make_tex(top: Color, bottom: Color, rim: Color, lip_h: int, shift: int, alpha: float) -> ImageTexture:
	var img: = Image.create(N, N, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var h: = N - shift
	var mid: = top.lerp(bottom, 0.5)
	var lip_col: = bottom.darkened(0.45)
	var gloss: = top.lightened(0.28)
	for y in range(shift, N):
		var ly: = y - shift
		for x in N:
			var k: = _inset(x, ly, N, h)
			if k < 0:
				continue
			var c: Color
			if k < 2:
				c = BORDER_COLOR
			elif k < 4:
				c = rim
			else:
				if ly == 4:
					c = gloss
				elif ly < M:
					c = top
				elif ly < N - M:
					c = mid
				else:
					c = bottom

				if ly >= h - 4 - lip_h and ly < h - 4:
					c = lip_col
			c.a = alpha
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)



static func _inset(x: int, y: int, w: int, h: int) -> int:
	var px: = x + 0.5
	var py: = y + 0.5
	if not _inside(px, py, float(w), float(h), 0.0):
		return -1
	var k: = 0
	while k < 5 and _inside(px, py, float(w), float(h), float(k + 1)):
		k += 1
	return k


static func _inside(px: float, py: float, w: float, h: float, k: float) -> bool:
	var r: = maxf(R - k, 0.0)
	var qx: = absf(px - w * 0.5) - (w * 0.5 - k - r)
	var qy: = absf(py - h * 0.5) - (h * 0.5 - k - r)
	var d: = Vector2(maxf(qx, 0.0), maxf(qy, 0.0)).length() + minf(maxf(qx, qy), 0.0) - r
	return d <= 0.0
