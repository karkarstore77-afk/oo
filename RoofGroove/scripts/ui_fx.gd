extends RefCounted
## Calm UI effects: soft fades, a gentle hover/press scale and a slow pulse. Nothing flashy.


static func fade_in(n: CanvasItem, delay: float = 0.0, dur: float = 0.28) -> void :
	if n == null or not n.is_inside_tree():
		return
	n.modulate.a = 0.0
	var tw: Tween = n.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(n, "modulate:a", 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


static func pulse(n: CanvasItem, low: float = 0.45, period: float = 1.8) -> void :
	if n == null or not n.is_inside_tree():
		return
	var tw: Tween = n.create_tween().set_loops()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(n, "modulate:a", low, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(n, "modulate:a", 1.0, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


static func attach_button_fx(b: BaseButton) -> void :
	if b == null or b.has_meta("calm_fx"):
		return
	b.set_meta("calm_fx", true)
	b.mouse_entered.connect(_scale_to.bind(b, 1.03, 0.14))
	b.mouse_exited.connect(_scale_to.bind(b, 1.0, 0.18))
	b.button_down.connect(_scale_to.bind(b, 0.97, 0.08))
	b.button_up.connect(_scale_to.bind(b, 1.0, 0.14))


static func _scale_to(b: BaseButton, target: float, dur: float) -> void :
	if not is_instance_valid(b) or not b.is_inside_tree():
		return
	if target > 1.0 and b.disabled:
		return
	if b.has_meta("calm_tw"):
		var old: Variant = b.get_meta("calm_tw")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	b.pivot_offset = b.size * 0.5
	var tw: Tween = b.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(b, "scale", Vector2(target, target), dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	b.set_meta("calm_tw", tw)


## Small one-shot burst of square sparks (monster pop, orb pickup ...). Frees itself.
static func burst(parent: Node, pos: Vector2, color: Color, amount: int = 12, speed: float = 90.0) -> void :
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var p: = CPUParticles2D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.55
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 260)
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = color
	p.z_index = 20
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	parent.get_tree().create_timer(1.2).timeout.connect(p.queue_free)
