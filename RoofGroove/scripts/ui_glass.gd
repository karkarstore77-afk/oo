extends RefCounted
## Liquid-Glass style helpers. Use sparingly, on the most important floating panels (dialogs),
## so the content stays the hero.

const SHADER: Shader = preload("res://shaders/glass.gdshader")


## Returns a Control that paints a glass panel behind its siblings. Add it as the first child of
## the panel container and give it PRESET_FULL_RECT; it keeps its shader `size` in sync.
static func make_background(radius: float = 26.0, tint: Color = Color(0.45, 0.55, 1.0, 0.20)) -> ColorRect:
	var rect: = ColorRect.new()
	rect.color = Color.WHITE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat: = ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("radius", radius)
	mat.set_shader_parameter("tint", tint)
	rect.material = mat
	rect.resized.connect(func() -> void :
		mat.set_shader_parameter("size", rect.size))
	return rect


## A rounded translucent StyleBox for controls that sit on top of glass (fields, buttons).
static func field_style(alpha: float = 0.28) -> StyleBoxFlat:
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.16, alpha)
	sb.border_color = Color(1, 1, 1, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

static var _gcache: Dictionary = {}
const UIS: = preload("res://scripts/ui_style.gd")
const FONT: Font = preload("res://fonts/PixelOperator8.ttf")


static func _style(tex: Texture2D, content: Vector4) -> StyleBoxTexture:
	var sb: = StyleBoxTexture.new()
	sb.texture = tex
	sb.content_margin_left = content.x
	sb.content_margin_top = content.y
	sb.content_margin_right = content.z
	sb.content_margin_bottom = content.w
	return sb


const G_N: = 48
const G_M: = 18


static func glass_box(tint: Color, alpha_top: float = 0.6, alpha_bottom: float = 0.5, 
		content: Vector4 = Vector4(14, 10, 14, 10), rim: float = 1.0, radius: int = 16) -> StyleBoxTexture:
	var key: = "glass_%s_%s_%s_%s_%s" % [tint.to_html(), alpha_top, alpha_bottom, rim, radius]
	var tex: ImageTexture
	if _gcache.has(key):
		tex = _gcache[key]
	else:
		tex = _make_glass_tex(tint, alpha_top, alpha_bottom, rim, radius)
		_gcache[key] = tex
	var sb: = _style(tex, content)
	sb.texture_margin_left = G_M
	sb.texture_margin_top = G_M
	sb.texture_margin_right = G_M
	sb.texture_margin_bottom = G_M
	return sb




static func _make_glass_tex(tint: Color, a_top: float, a_bot: float, rim: float, radius: int) -> ImageTexture:
	var img: = Image.create(G_N, G_N, false, Image.FORMAT_RGBA8)
	var r: = float(mini(radius, G_N / 2 - 2))
	var half: = G_N * 0.5
	for y in G_N:
		for x in G_N:
			var px: = x + 0.5 - half
			var py: = y + 0.5 - half
			var qx: = absf(px) - (half - r)
			var qy: = absf(py) - (half - r)
			var d: = Vector2(maxf(qx, 0.0), maxf(qy, 0.0)).length() + minf(maxf(qx, qy), 0.0) - r
			var cover: = clampf(0.5 - d, 0.0, 1.0)
			if cover <= 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var t: = float(y) / float(G_N - 1)
			var c: = tint
			c = c.lerp(Color.WHITE, 0.10 * (1.0 - smoothstep(0.0, 0.5, t)))
			var a: = lerpf(a_top, a_bot, t)
			var inner: = clampf(-d, 0.0, 6.0)
			var n: = Vector2(px, py).normalized()
			var facing: = n.dot(Vector2(-0.6, -0.8)) * 0.5 + 0.5
			var rim_k: = (1.0 - smoothstep(0.0, 1.8, inner)) * rim
			var rim_a: = rim_k * (0.22 + 0.7 * facing * facing)
			c = c.lerp(Color.WHITE, clampf(rim_a, 0.0, 0.95))
			a = clampf(a + rim_a * 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, a * cover))
	return ImageTexture.create_from_image(img)



static func _btn(kind: String, state: String) -> StyleBoxTexture:
	var pal: Dictionary = UIS.KINDS[kind]
	var tint: Color = (pal["top"] as Color).lerp(pal["bottom"], 0.35)
	var a_top: = 0.78
	var a_bot: = 0.62
	var rim: = 1.0
	match state:
		"hover":
			tint = tint.lightened(0.18)
			a_top = 0.88
			a_bot = 0.72
			rim = 1.4
		"pressed":
			tint = tint.darkened(0.12)
			a_top = 0.62
			a_bot = 0.78
			rim = 1.2
		"disabled":
			tint = Color(0.3, 0.33, 0.45)
			a_top = 0.35
			a_bot = 0.3
			rim = 0.4
	var sb: = glass_box(tint, a_top, a_bot, Vector4(16, 8, 16, 10), rim, 16)
	if state == "pressed":
		sb.content_margin_top = 10.0
		sb.content_margin_bottom = 8.0
	return sb


## A Theme used ONLY inside the feedback dialog: glass buttons, fields and drop-down. The rest of the
## game keeps its pixel style.
static func dialog_theme() -> Theme:
	var theme: = Theme.new()
	for entry in [["Button", "blue"], ["PrimaryButton", "green"]]:
		var t: String = entry[0]
		var kind: String = entry[1]
		if t != "Button":
			theme.set_type_variation(t, "Button")
		for st in ["normal", "hover", "pressed", "disabled"]:
			theme.set_stylebox(st, t, _btn(kind, st))
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		theme.set_stylebox(st, "CheckBox", StyleBoxEmpty.new())
	var field: = glass_box(Color(0.02, 0.04, 0.14), 0.55, 0.50, Vector4(12, 8, 12, 8), 0.5)
	var field_focus: = glass_box(Color(0.05, 0.10, 0.30), 0.60, 0.55, Vector4(12, 8, 12, 8), 1.0)
	for t in ["LineEdit", "TextEdit"]:
		theme.set_stylebox("normal", t, field)
		theme.set_stylebox("focus", t, field_focus)
		theme.set_stylebox("read_only", t, field)
		theme.set_color("font_placeholder_color", t, Color(0.75, 0.8, 0.95, 0.55))
	theme.set_stylebox("normal", "OptionButton", field)
	theme.set_stylebox("hover", "OptionButton", field_focus)
	theme.set_stylebox("pressed", "OptionButton", field_focus)
	theme.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	theme.set_stylebox("normal_mirrored", "OptionButton", field)
	theme.set_stylebox("hover_mirrored", "OptionButton", field_focus)
	theme.set_stylebox("pressed_mirrored", "OptionButton", field_focus)
	theme.set_stylebox("panel", "PopupMenu", glass_box(Color(0.05, 0.08, 0.22), 0.95, 0.92, Vector4(8, 8, 8, 8)))
	theme.set_stylebox("hover", "PopupMenu", glass_box(Color(0.3, 0.5, 1.0), 0.55, 0.45, Vector4(8, 4, 8, 4)))
	theme.set_font("font", "PopupMenu", FONT)
	return theme
