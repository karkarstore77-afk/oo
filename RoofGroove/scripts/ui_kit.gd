extends RefCounted


const FONT: Font = preload("res://fonts/PixelOperator8.ttf")
const KNIGHT: Texture2D = preload("res://sprites/knight.png")


static func label(text: String, size: int = 16, color: Color = Color.WHITE, wrap_width: float = 0.0) -> Label:
	var l: = Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if wrap_width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(wrap_width, 0)
	return l


static func style_button(b: Button, size: int = 18, min_height: float = 52.0) -> Button:
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(b.custom_minimum_size.x, min_height)
	return b


static func button(text: String, size: int = 18, min_height: float = 52.0) -> Button:
	var b: = Button.new()
	b.text = text
	return style_button(b, size, min_height)



static func make_knight(scale_factor: float = 10.0) -> AnimatedSprite2D:
	var frames: = SpriteFrames.new()
	frames.set_animation_speed("default", 5.0)
	frames.set_animation_loop("default", true)
	for i in 4:
		var tex: = AtlasTexture.new()
		tex.atlas = KNIGHT
		tex.region = Rect2(i * 32, 0, 32, 32)
		frames.add_frame("default", tex)
	var sprite: = AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.scale = Vector2(scale_factor, scale_factor)
	sprite.play("default")
	return sprite
