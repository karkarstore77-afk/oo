extends Control



const UI: = preload("res://scripts/ui_kit.gd")
const PAGE_SIZE: = 12
const Abilities: = preload("res://scripts/skin_abilities.gd")
const Fx: = preload("res://scripts/ui_fx.gd")

var _animate_cards: = true

var _tokens_label: Label
var _status: Label
var _grid: GridContainer
var _code_edit: LineEdit
var _welcome: AcceptDialog
var _page: = 0
var _page_label: Label
var _prev_btn: Button
var _next_btn: Button


func _ready() -> void :
	var bg: = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center: = CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 88.0

	var vp: = get_viewport_rect().size
	var root: = VBoxContainer.new()
	root.custom_minimum_size = Vector2(minf(vp.x - 40.0, 680.0), vp.y - 140.0)
	root.add_theme_constant_override("separation", 10)
	center.add_child(root)

	root.add_child(UI.label("SKIN SHOP", 28))
	_tokens_label = UI.label("", 18, Color(1, 0.85, 0.4))
	root.add_child(_tokens_label)

	var scroll: = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 2 if vp.x < 760.0 else 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_grid)

	var nav: = HBoxContainer.new()
	nav.add_theme_constant_override("separation", 8)
	root.add_child(nav)
	_prev_btn = UI.button("<", 18, 44.0)
	_prev_btn.custom_minimum_size.x = 64
	_prev_btn.pressed.connect( func() -> void : _go_page(-1))
	nav.add_child(_prev_btn)
	_page_label = UI.label("", 14)
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(_page_label)
	_next_btn = UI.button(">", 18, 44.0)
	_next_btn.custom_minimum_size.x = 64
	_next_btn.pressed.connect( func() -> void : _go_page(1))
	nav.add_child(_next_btn)

	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	root.add_child(row)
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = tr("Enter code")
	_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_edit.custom_minimum_size = Vector2(0, 48)
	_code_edit.text_submitted.connect( func(_t: String) -> void : _on_redeem())
	row.add_child(_code_edit)
	var redeem: = UI.button("REDEEM CODE", 14, 48.0)
	redeem.pressed.connect(_on_redeem)
	row.add_child(redeem)

	_status = UI.label("", 12, Color(1, 0.85, 0.4))
	root.add_child(_status)

	var back: = UI.button("BACK")
	back.pressed.connect( func() -> void : get_tree().change_scene_to_file("res://sence/account_hub.tscn"))
	root.add_child(back)

	_welcome = AcceptDialog.new()
	_welcome.title = "Roof Groove"
	_welcome.ok_button_text = tr("OK")
	add_child(_welcome)

	Economy.tokens_changed.connect(_refresh)
	Economy.skin_changed.connect(_refresh)
	Economy.dev_welcome.connect(_on_dev_welcome)
	_refresh()

	if Network.cloud != null and Network.cloud.is_signed_in():
		Network.cloud.sync_economy()



func _ordered_ids() -> Array:
	var base_ids: Array = []
	var gen_ids: Array = []
	for id in Economy.SKINS:
		if Economy.SKINS[id].has("gen"):
			gen_ids.append(id)
		else:
			base_ids.append(id)
	gen_ids.sort_custom( func(a: String, b: String) -> bool: return _sort_key(a) < _sort_key(b))
	return base_ids + gen_ids


func _sort_key(id: String) -> int:
	var info: Dictionary = Economy.SKINS[id]
	if info.has("gem_price"):
		return 1000000 + int(info["gem_price"])
	return int(info["price"])


func _page_count() -> int:
	return maxi(1, ceili(float(Economy.SKINS.size()) / float(PAGE_SIZE)))


func _go_page(d: int) -> void :
	_page = clampi(_page + d, 0, _page_count() - 1)
	_animate_cards = true
	_refresh()


func _refresh(_id: Variant = null) -> void :
	_tokens_label.text = tr("Tokens: %d") % Economy.balance() + "     " + tr("Gems: %d") % Economy.gem_balance()
	for c in _grid.get_children():
		c.queue_free()
	var ids: = _ordered_ids()
	_page = clampi(_page, 0, _page_count() - 1)
	for k in range(_page * PAGE_SIZE, mini(ids.size(), (_page + 1) * PAGE_SIZE)):
		var card: = _make_card(ids[k])
		_grid.add_child(card)
		if _animate_cards:
			Fx.fade_in(card, minf(float(k - _page * PAGE_SIZE) * 0.03, 0.3), 0.25)
	_animate_cards = false
	_page_label.text = "%d / %d" % [_page + 1, _page_count()]
	_prev_btn.disabled = _page <= 0
	_next_btn.disabled = _page >= _page_count() - 1


func _make_card(id: String) -> Control:
	var info: Dictionary = Economy.SKINS[id]
	var card: = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box: = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)


	var holder: = Control.new()
	holder.custom_minimum_size = Vector2(96, 96)
	box.add_child(holder)
	var knight: = UI.make_knight(3.0)
	knight.position = Vector2(48, 52)
	Economy.set_skin(knight, id, true)
	holder.add_child(knight)

	var name_color: = Color("#ffd447") if Abilities.is_golden(id) else Color.WHITE
	box.add_child(UI.label(str(info["name"]), 14, name_color))
	var tier_text: = Abilities.tier_label(id)
	if tier_text != "":
		box.add_child(UI.label(tier_text, 10, name_color))
	box.add_child(UI.label(Abilities.describe(id), 10, Color("#8fe3ff"), 150.0))

	var btn: = UI.button("", 12, 44.0)
	var price: int = info["price"]
	if Economy.equipped == id:
		btn.text = "EQUIPPED"
		btn.disabled = true
	elif Economy.owns(id):
		btn.text = "EQUIP"
		btn.pressed.connect( func() -> void : Economy.equip(id))
	elif price < 0:
		btn.text = "LOCKED - CODE ONLY"
		btn.disabled = true
	else:
		if info.has("gem_price"):
			btn.text = tr("BUY - %d GEMS") % int(info["gem_price"])
		else:
			btn.text = tr("BUY - %d") % price
		if not Economy.can_buy(id):
			btn.modulate = Color(1, 1, 1, 0.5)
		btn.pressed.connect( func() -> void : _on_buy(id))
	box.add_child(btn)
	return card


func _on_buy(id: String) -> void :
	if Economy.buy(id):
		_status.text = ""
	else:
		var need_gems: bool = Economy.SKINS.has(id) and Economy.SKINS[id].has("gem_price")
		_status.text = tr("Not enough gems") if need_gems else tr("Not enough tokens")


func _on_redeem() -> void :
	var text: = _code_edit.text
	_code_edit.clear()
	var c: Node = Network.cloud
	if c == null:
		_status.text = tr("Invalid code")
		return
	_status.text = tr("Checking ...")
	var r: Dictionary = await c.redeem_remote_code(text)
	if not is_inside_tree():
		return
	match str(r.get("status", "invalid")):
		"ok": _status.text = tr("Code accepted!")
		"already": _status.text = tr("Already unlocked")
		"used": _status.text = tr("Code already used")
		"inactive": _status.text = tr("This code is disabled")
		"signin": _status.text = tr("Sign in to use codes")
		"offline": _status.text = tr("Could not reach the server")
		"denied": _status.text = tr("Codes are not enabled on the server")
		_: _status.text = tr("Invalid code")


func _on_dev_welcome() -> void :
	_welcome.dialog_text = tr("Welcome to the Developers!")
	_welcome.popup_centered()
